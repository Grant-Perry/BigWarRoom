//
//  PlayoffEliminationService.swift
//  BigWarRoom
//
//  Phase 2: Service to consolidate all playoff elimination logic (DRY principle)
//

import Foundation

/// Service responsible for all playoff elimination logic
/// Consolidates: isPlayoffWeek(), shouldHideEliminated(), bracket checks, etc.
@MainActor
final class PlayoffEliminationService {
    
    // MARK: - Dependencies
    
    private let sleeperClient: SleeperAPIClient
    private let espnClient: ESPNAPIClient
    
    // MARK: - Initialization
    
    init(
        sleeperClient: SleeperAPIClient = .shared,
        espnClient: ESPNAPIClient = .shared
    ) {
        self.sleeperClient = sleeperClient
        self.espnClient = espnClient
    }
    
    // MARK: - Playoff Week Detection
    
    /// Check if the current week is a playoff week
    func isPlayoffWeek(league: UnifiedLeagueManager.LeagueWrapper, week: Int) -> Bool {
        DebugPrint(mode: .matchupLoading, limit: 10, "🔍 isPlayoffWeek called for \(league.league.name), week \(week)")
        
        // Hard rule: Week 15+ is always playoffs
        if week >= 15 {
            DebugPrint(mode: .matchupLoading, limit: 10, "      ✅ PlayoffWeek HARD-RULE: week \(week) >= 15")
            return true
        }
        
        // Get playoff start week from league settings
        let playoffStart: Int?
        
        if league.source == .sleeper {
            let start = league.league.settings?.playoffWeekStart ?? 15
            playoffStart = start
            DebugPrint(mode: .matchupLoading, limit: 10, "   Sleeper playoff start: \(start)")
        } else if league.source == .espn {
            playoffStart = 15
            DebugPrint(mode: .matchupLoading, limit: 10, "   ESPN playoff start: 15 (default)")
        } else {
            playoffStart = nil
        }
        
        guard let playoffWeekStart = playoffStart else {
            DebugPrint(mode: .matchupLoading, limit: 10, "   ❌ No playoff start found")
            return false
        }
        
        let isPlayoffs = week >= playoffWeekStart
        DebugPrint(mode: .matchupLoading, limit: 10, "   Result: \(isPlayoffs ? "YES" : "NO") (week \(week) >= \(playoffWeekStart))")
        return isPlayoffs
    }
    
    // MARK: - Elimination Filtering
    
    /// Should this league be hidden because the user is eliminated from the winners bracket?
    func shouldHideEliminatedPlayoffLeague(
        league: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        // User toggle: show eliminated leagues?
        guard !UserDefaults.standard.showEliminatedPlayoffLeagues else { return false }
        
        // Not playoffs? Don't hide
        guard isPlayoffWeek(league: league, week: week) else { return false }
        
        // Check winners bracket
        let isInWinnersBracket: Bool
        switch league.source {
        case .espn:
            isInWinnersBracket = await isESPNTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
        case .sleeper:
            isInWinnersBracket = await isSleeperTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
        }
        
        return !isInWinnersBracket
    }
    
    // MARK: - Sleeper Winners Bracket Check
    
    /// Sleeper: evaluate winners bracket membership via `/winners_bracket`
    func isSleeperTeamInWinnersBracket(
        league: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        guard league.source == .sleeper else { return true }
        
        guard let myRosterID = Int(myTeamID) else {
            DebugPrint(mode: .matchupLoading, limit: 3, "⚠️ Sleeper winners bracket: could not parse myTeamID '\(myTeamID)'")
            return UserDefaults.standard.showEliminatedPlayoffLeagues
        }
        
        let playoffStartWeek = league.league.settings?.playoffWeekStart ?? 15
        let round = max(1, week - playoffStartWeek + 1)
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/winners_bracket") else {
            return UserDefaults.standard.showEliminatedPlayoffLeagues
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let winnersBracket = try JSONDecoder().decode([SleeperPlayoffBracketMatchup].self, from: data)
            
            // Check if eliminated in winners bracket
            let eliminatedInWinners = winnersBracket.contains { matchup in
                let isParticipant = matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID
                return isParticipant && matchup.loserRosterID == myRosterID
            }
            if eliminatedInWinners { return false }
            
            // Check if appears in current round
            let appearsThisRound = winnersBracket.contains { matchup in
                matchup.round == round && (matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID)
            }
            
            // Check for bye week
            let myRounds = winnersBracket.compactMap { matchup -> Int? in
                let isParticipant = matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID
                return isParticipant ? matchup.round : nil
            }
            let firstAppearanceRound = myRounds.min()
            let hasByeIntoLaterRound = (firstAppearanceRound != nil && firstAppearanceRound! > round)
            
            return appearsThisRound || hasByeIntoLaterRound
        } catch {
            let showEliminated = UserDefaults.standard.showEliminatedPlayoffLeagues
            DebugPrint(mode: .matchupLoading, limit: 3, "⚠️ Sleeper winners bracket check failed for \(league.league.name) (showEliminated=\(showEliminated)): \(error)")
            return showEliminated
        }
    }
    
    // MARK: - ESPN Winners Bracket Check
    
    /// ESPN: determine if team is in winners bracket by inspecting `playoffTierType` in schedule
    func isESPNTeamInWinnersBracket(
        league: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        guard league.source == .espn else { return true }
        
        guard let myTeamIdInt = Int(myTeamID) else {
            return UserDefaults.standard.showEliminatedPlayoffLeagues
        }
        
        do {
            let year = SeasonYearManager.shared.selectedYear
            guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
                return UserDefaults.standard.showEliminatedPlayoffLeagues
            }
            
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
            request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            let playoffStartWeek = league.league.settings?.playoffWeekStart ?? 15
            guard week >= playoffStartWeek else { return true }
            
            // Unwrap optional schedule
            guard let schedule = model.schedule else { return true }
            
            // Check current week matchup
            if let entry = schedule.first(where: { entry in
                guard entry.matchupPeriodId == week else { return false }
                let homeId = entry.home.teamId
                let awayId = entry.away?.teamId
                return homeId == myTeamIdInt || awayId == myTeamIdInt
            }) {
                return (entry.playoffTierType ?? "NONE") == "WINNERS_BRACKET"
            }
            
            // Check future winners bracket appearances
            let appearsInFutureWinners = schedule.contains { entry in
                guard (entry.playoffTierType ?? "NONE") == "WINNERS_BRACKET" else { return false }
                guard entry.matchupPeriodId >= week else { return false }
                let homeId = entry.home.teamId
                let awayId = entry.away?.teamId
                return homeId == myTeamIdInt || awayId == myTeamIdInt
            }
            
            return appearsInFutureWinners
        } catch {
            return true
        }
    }
}