//
//  PlayoffEliminationService.swift
//  BigWarRoom
//
//  🔥 DRY: Single source of truth for ALL playoff elimination logic
//  Consolidates duplicate logic from MatchupsHubViewModel+Loading and MatchupDataStore
//

import Foundation
import Observation

/// Service for handling all playoff elimination detection logic
/// Supports both Sleeper and ESPN platforms
@Observable
@MainActor
final class PlayoffEliminationService {
    
    // MARK: - Singleton (temporary bridge pattern)
    private static var _shared: PlayoffEliminationService?
    
    static var shared: PlayoffEliminationService {
        if let existing = _shared {
            return existing
        }
        fatalError("PlayoffEliminationService.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: PlayoffEliminationService) {
        _shared = instance
    }
    
    // MARK: - Dependencies
    private let sleeperAPIClient: SleeperAPIClient
    private let espnAPIClient: ESPNAPIClient
    
    // MARK: - Initialization
    init(sleeperAPIClient: SleeperAPIClient, espnAPIClient: ESPNAPIClient) {
        self.sleeperAPIClient = sleeperAPIClient
        self.espnAPIClient = espnAPIClient
    }
    
    // MARK: - Public Interface
    
    /// Check if the current week is a playoff week for a given league
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
    
    /// Determine if a league should be hidden because user is eliminated from playoffs
    func shouldHideEliminatedPlayoffLeague(
        league: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        guard !UserDefaults.standard.showEliminatedPlayoffLeagues else { return false }
        guard isPlayoffWeek(league: league, week: week) else { return false }
        
        let isInWinnersBracket: Bool
        switch league.source {
        case .espn:
            isInWinnersBracket = await isESPNTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
        case .sleeper:
            isInWinnersBracket = await isSleeperTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
        }
        
        return !isInWinnersBracket
    }
    
    // MARK: - Sleeper Winners Bracket Detection
    
    /// Check if a Sleeper team is in the winners bracket
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
            
            // Check for bye week into later round
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
    
    // MARK: - ESPN Winners Bracket Detection
    
    /// Check if an ESPN team is in the winners bracket
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
            let year = getCurrentYear()
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
            
            guard let schedule = model.schedule else { return true }
            
            // Check if in winners bracket this week
            if let entry = schedule.first(where: { entry in
                guard entry.matchupPeriodId == week else { return false }
                let homeId = entry.home.teamId
                let awayId = entry.away?.teamId
                return homeId == myTeamIdInt || awayId == myTeamIdInt
            }) {
                return (entry.playoffTierType ?? "NONE") == "WINNERS_BRACKET"
            }
            
            // Check if appears in future winners bracket matchups
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
    
    // MARK: - Helper Methods
    
    private func getCurrentYear() -> String {
        return AppConstants.currentSeasonYear
    }
}