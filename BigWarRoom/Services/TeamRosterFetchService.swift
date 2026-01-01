//
//  TeamRosterFetchService.swift
//  BigWarRoom
//
//  Phase 2: Service to consolidate team roster fetching logic (DRY principle)
//  Handles fetching roster data for playoff-eliminated teams from ESPN and Sleeper
//

import Foundation

/// Service responsible for fetching team roster data
/// Consolidates: roster fetching for eliminated teams, player data loading, score calculation
@MainActor
final class TeamRosterFetchService {
    
    // MARK: - Dependencies
    
    private let sleeperClient: SleeperAPIClient
    private let espnClient: ESPNAPIClient
    private let playerDirectory: PlayerDirectoryStore
    private let gameStatusService: GameStatusService
    private let seasonYearManager: SeasonYearManager
    
    // MARK: - Initialization
    
    init(
        sleeperClient: SleeperAPIClient,
        espnClient: ESPNAPIClient,
        playerDirectory: PlayerDirectoryStore,
        gameStatusService: GameStatusService,
        seasonYearManager: SeasonYearManager
    ) {
        self.sleeperClient = sleeperClient
        self.espnClient = espnClient
        self.playerDirectory = playerDirectory
        self.gameStatusService = gameStatusService
        self.seasonYearManager = seasonYearManager
    }
    
    // MARK: - Main Entry Point
    
    /// Fetch roster data for an eliminated team
    func fetchEliminatedTeamRoster(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        if league.source == .sleeper {
            return await fetchEliminatedSleeperTeam(league: league, myTeamID: myTeamID, week: week)
        } else if league.source == .espn {
            return await fetchEliminatedESPNTeam(league: league, myTeamID: myTeamID, week: week)
        }
        
        return nil
    }
    
    // MARK: - Sleeper Roster Fetching
    
    /// Fetch Sleeper team roster for eliminated team
    private func fetchEliminatedSleeperTeam(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        do {
            let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters")!
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            let myRoster = rosters.first { roster in
                String(roster.rosterID) == myTeamID || roster.ownerID == myTeamID
            }
            
            guard let myRoster = myRoster else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find roster for team ID: \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found roster ID: \(myRoster.rosterID)")
            
            let matchupsURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)")!
            let (matchupData, _) = try await URLSession.shared.data(from: matchupsURL)
            let matchupResponses = try JSONDecoder().decode([SleeperMatchupResponse].self, from: matchupData)
            
            guard let myMatchupResponse = matchupResponses.first(where: { $0.rosterID == myRoster.rosterID }) else {
                DebugPrint(mode: .matchupLoading, "   ⚠️ No matchup response found, creating with empty roster")
                let record = TeamRecord(
                    wins: myRoster.wins ?? 0,
                    losses: myRoster.losses ?? 0,
                    ties: myRoster.ties ?? 0
                )
                
                return FantasyTeam(
                    id: myTeamID,
                    name: "Team \(myRoster.rosterID)",
                    ownerName: "Team \(myRoster.rosterID)",
                    record: record,
                    avatar: nil,
                    currentScore: 0.0,
                    projectedScore: 0.0,
                    roster: [],
                    rosterID: myRoster.rosterID,
                    faabTotal: league.league.settings?.waiverBudget,
                    faabUsed: myRoster.waiversBudgetUsed
                )
            }
            
            let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users")!
            let (userData, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: userData)
            
            let myUser = users.first { $0.userID == myRoster.ownerID }
            let managerName = myUser?.displayName ?? "Team \(myRoster.rosterID)"
            
            let starters = myMatchupResponse.starters ?? []
            let allPlayers = myMatchupResponse.players ?? []
            
            var fantasyPlayers: [FantasyPlayer] = []
            
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectory.player(for: playerID) {
                    let isStarter = starters.contains(playerID)
                    let playerTeam = sleeperPlayer.team ?? "UNK"
                    let playerPosition = sleeperPlayer.position ?? "FLEX"
                    
                    let gameStatus = gameStatusService.getGameStatusWithFallback(for: playerTeam)
                    
                    let playerScore = 0.0
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: playerPosition,
                        team: playerTeam,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerScore * 1.1,
                        gameStatus: gameStatus,
                        isStarter: isStarter,
                        lineupSlot: isStarter ? playerPosition : nil,
                        injuryStatus: sleeperPlayer.injuryStatus
                    )
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
            
            let record = TeamRecord(
                wins: myRoster.wins ?? 0,
                losses: myRoster.losses ?? 0,
                ties: myRoster.ties ?? 0
            )
            
            let avatarURL = myUser?.avatar != nil ? "https://sleepercdn.com/avatars/\(myUser!.avatar!)" : nil
            
            let team = FantasyTeam(
                id: myTeamID,
                name: managerName,
                ownerName: managerName,
                record: record,
                avatar: avatarURL,
                currentScore: myMatchupResponse.points ?? 0.0,
                projectedScore: (myMatchupResponse.points ?? 0.0) * 1.05,
                roster: fantasyPlayers,
                rosterID: myRoster.rosterID,
                faabTotal: league.league.settings?.waiverBudget,
                faabUsed: myRoster.waiversBudgetUsed
            )
            
            DebugPrint(mode: .matchupLoading, "   ✅ Built Sleeper eliminated team: \(managerName) with \(fantasyPlayers.count) players, score: \(myMatchupResponse.points ?? 0.0)")
            return team
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated Sleeper team: \(error)")
            return nil
        }
    }
    
    // MARK: - ESPN Roster Fetching
    
    /// Fetch ESPN team roster for eliminated team
    private func fetchEliminatedESPNTeam(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        DebugPrint(mode: .matchupLoading, "   🔍 Fetching eliminated ESPN team for league \(league.league.name), team ID \(myTeamID), week \(week)")
        
        do {
            let currentYear = seasonYearManager.selectedYear
            guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(currentYear)/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   🌐 Fetching from ESPN API...")
            
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let espnToken = currentYear == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
            request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
            
            DebugPrint(mode: .matchupLoading, "   🔐 Using credentials for year \(currentYear)")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded ESPN league data, found \(model.teams.count) teams")
            
            guard let myTeam = model.teams.first(where: { String($0.id) == myTeamID }) else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find team with ID \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found team: \(myTeam.name ?? "Unknown")")
            
            let myScore = myTeam.activeRosterScore(for: week)
            let teamName = myTeam.name ?? "Team \(myTeam.id)"
            
            var fantasyPlayers: [FantasyPlayer] = []
            
            if let roster = myTeam.roster {
                fantasyPlayers = roster.entries.map { entry in
                    let player = entry.playerPoolEntry.player
                    let isActive = true

                    let weeklyScore = player.stats.first { stat in
                        stat.scoringPeriodId == week && stat.statSourceId == 0
                    }?.appliedTotal ?? 0.0

                    let projectedScore = player.stats.first { stat in
                        stat.scoringPeriodId == week && stat.statSourceId == 1
                    }?.appliedTotal ?? 0.0

                    return FantasyPlayer(
                        id: String(player.id),
                        sleeperID: nil,
                        espnID: String(player.id),
                        firstName: player.fullName,
                        lastName: "",
                        position: entry.positionString,
                        team: player.nflTeamAbbreviation ?? "UNK",
                        jerseyNumber: nil,
                        currentPoints: weeklyScore,
                        projectedPoints: projectedScore,
                        gameStatus: gameStatusService.getGameStatusWithFallback(for: player.nflTeamAbbreviation ?? "UNK"),
                        isStarter: isActive,
                        lineupSlot: nil,
                        injuryStatus: nil
                    )
                }
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Built ESPN eliminated team: \(teamName) with \(fantasyPlayers.count) players")
            
            return FantasyTeam(
                id: myTeamID,
                name: teamName,
                ownerName: teamName,
                record: TeamRecord(
                    wins: myTeam.record?.overall.wins ?? 0,
                    losses: myTeam.record?.overall.losses ?? 0,
                    ties: myTeam.record?.overall.ties ?? 0
                ),
                avatar: nil,
                currentScore: myScore,
                projectedScore: myScore * 1.05,
                roster: fantasyPlayers,
                rosterID: myTeam.id,
                faabTotal: nil,
                faabUsed: nil
            )
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated ESPN team: \(error)")
            return nil
        }
    }
}