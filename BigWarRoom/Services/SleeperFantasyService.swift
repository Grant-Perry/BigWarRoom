//
//  SleeperFantasyService.swift
//  BigWarRoom
//
//  🔥 DRY: Single source of truth for Sleeper fantasy data fetching and transformation
//  Extracted from FantasyViewModel+Sleeper to follow MVVM and SRP
//

import Foundation

/// Service for handling all Sleeper fantasy league operations
/// Handles API calls, data transformation, and team/player building
@MainActor
final class SleeperFantasyService {
    
    // MARK: - Dependencies
    private let gameStatusService: GameStatusService
    private let playerDirectoryStore: PlayerDirectoryStore
    
    // MARK: - Initialization
    init(
        gameStatusService: GameStatusService,
        playerDirectoryStore: PlayerDirectoryStore
    ) {
        self.gameStatusService = gameStatusService
        self.playerDirectoryStore = playerDirectoryStore
    }
    
    // MARK: - Public Interface
    
    /// Fetch complete Sleeper fantasy data for a league and week
    func fetchFantasyData(
        leagueID: String,
        week: Int
    ) async throws -> SleeperFantasyDataPackage {
        
        // Fetch all data in parallel
        async let leagueTask = fetchLeague(leagueID: leagueID)
        async let usersTask = fetchUsers(leagueID: leagueID)
        async let rostersTask = fetchRosters(leagueID: leagueID)
        async let matchupsTask = fetchMatchups(leagueID: leagueID, week: week)
        
        let (league, users, rosters, matchups) = try await (leagueTask, usersTask, rostersTask, matchupsTask)
        
        DebugPrint(mode: .fantasy, "✅ Sleeper data fetch complete:")
        DebugPrint(mode: .fantasy, "   Users: \(users.count)")
        DebugPrint(mode: .fantasy, "   Rosters: \(rosters.count)")
        DebugPrint(mode: .fantasy, "   Matchup entries: \(matchups.count)")
        
        return SleeperFantasyDataPackage(
            league: league,
            users: users,
            rosters: rosters,
            matchups: matchups
        )
    }
    
    /// Process Sleeper fantasy data into matchups
    func processFantasyData(
        package: SleeperFantasyDataPackage,
        leagueID: String,
        week: Int,
        year: String
    ) async throws -> SleeperProcessedData {
        
        let processedMatchups = try await processMatchupData(
            matchups: package.matchups,
            rosters: package.rosters,
            users: package.users,
            leagueID: leagueID,
            week: week,
            year: year
        )
        
        DebugPrint(mode: .fantasy, "   Processed matchups: \(processedMatchups.count)")
        
        // Build roster ID to manager ID mapping
        var rosterIDToManagerID: [Int: String] = [:]
        for roster in package.rosters {
            if let ownerID = roster.ownerID {
                rosterIDToManagerID[roster.rosterID] = ownerID
            }
        }
        
        // Build user ID to display name mapping
        var userIDs: [String: String] = [:]
        for user in package.users {
            userIDs[user.userID] = user.displayName
        }
        
        return SleeperProcessedData(
            matchups: processedMatchups,
            rosterIDToManagerID: rosterIDToManagerID,
            userIDs: userIDs,
            league: package.league,
            rosters: package.rosters
        )
    }
    
    // MARK: - API Calls
    
    /// Fetch Sleeper league data
    private func fetchLeague(leagueID: String) async throws -> SleeperLeague {
        let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let league = try JSONDecoder().decode(SleeperLeague.self, from: data)
        
        if let scoringSettings = league.scoringSettings {
            DebugPrint(mode: .scoring, "Loaded \(scoringSettings.count) rules for league \(leagueID)")
            
            let manager = ScoringSettingsManager.shared
            manager.registerSleeperScoringSettings(from: league, leagueID: leagueID)
            
            DebugPrint(mode: .scoring, "Registered with ScoringSettingsManager for league \(leagueID)")
        }
        
        return league
    }
    
    /// Fetch Sleeper rosters
    private func fetchRosters(leagueID: String) async throws -> [SleeperRoster] {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else {
            throw SleeperFantasyError.invalidURL
        }
        
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper roster data for league \(leagueID)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            DebugPrint(mode: .sleeperAPI, "Sleeper rosters HTTP Status \(httpResponse.statusCode)")
        }
        
        let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
        DebugPrint(mode: .sleeperAPI, "Decoded \(rosters.count) Sleeper rosters")
        
        // Debug record data
        for (index, roster) in rosters.enumerated() {
            let winsDisplay = roster.wins != nil ? "\(roster.wins!)" : "nil"
            let lossesDisplay = roster.losses != nil ? "\(roster.losses!)" : "nil"
            let tieValue = roster.ties ?? 0
            
            DebugPrint(mode: .fantasy, "   Roster \(index): ID=\(roster.rosterID), Owner=\(roster.ownerID ?? "nil")")
            DebugPrint(mode: .fantasy, "      Root level - wins:\(winsDisplay), losses:\(lossesDisplay), ties:\(tieValue)")
        }
        
        return rosters
    }
    
    /// Fetch Sleeper users
    private func fetchUsers(leagueID: String) async throws -> [SleeperLeagueUser] {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else {
            throw SleeperFantasyError.invalidURL
        }
        
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper user data for league \(leagueID)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            DebugPrint(mode: .sleeperAPI, "Sleeper users HTTP Status \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw SleeperFantasyError.httpError(httpResponse.statusCode)
            }
        }
        
        let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: data)
        DebugPrint(mode: .sleeperAPI, "Decoded \(users.count) Sleeper users")
        
        return users
    }
    
    /// Fetch Sleeper matchups
    private func fetchMatchups(leagueID: String, week: Int) async throws -> [SleeperMatchup] {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            throw SleeperFantasyError.invalidURL
        }
        
        DebugPrint(mode: .sleeperAPI, "Fetching Sleeper matchup data for league \(leagueID) week \(week)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            DebugPrint(mode: .sleeperAPI, "Sleeper matchups HTTP Status \(httpResponse.statusCode)")
        }
        
        let matchups = try JSONDecoder().decode([SleeperMatchup].self, from: data)
        DebugPrint(mode: .sleeperAPI, "Decoded \(matchups.count) Sleeper matchup entries")
        
        return matchups
    }
    
    // MARK: - Data Processing
    
    /// Process Sleeper matchup data into FantasyMatchup objects
    private func processMatchupData(
        matchups: [SleeperMatchup],
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser],
        leagueID: String,
        week: Int,
        year: String
    ) async throws -> [FantasyMatchup] {
        
        // Group matchups by matchup_id
        var groupedMatchups: [Int: [SleeperMatchup]] = [:]
        for matchup in matchups {
            groupedMatchups[matchup.matchup_id, default: []].append(matchup)
        }
        
        var fantasyMatchups: [FantasyMatchup] = []
        
        for (matchupID, matchupPair) in groupedMatchups {
            guard matchupPair.count == 2 else {
                DebugPrint(mode: .fantasy, "⚠️ Matchup \(matchupID) has \(matchupPair.count) entries (expected 2)")
                continue
            }
            
            let matchup1 = matchupPair[0]
            let matchup2 = matchupPair[1]
            
            guard let team1 = try await buildFantasyTeam(
                    from: matchup1,
                    rosters: rosters,
                    users: users,
                    leagueID: leagueID
                ),
                  let team2 = try await buildFantasyTeam(
                    from: matchup2,
                    rosters: rosters,
                    users: users,
                    leagueID: leagueID
                ) else {
                DebugPrint(mode: .fantasy, "❌ Failed to build teams for matchup \(matchupID)")
                continue
            }
            
            let fantasyMatchup = FantasyMatchup(
                id: "\(leagueID)_\(matchupID)_\(week)",
                leagueID: leagueID,
                week: week,
                year: year,
                homeTeam: team1,
                awayTeam: team2,
                status: .live,
                winProbability: nil,
                startTime: nil,
                sleeperMatchups: (matchup1, matchup2)
            )
            
            fantasyMatchups.append(fantasyMatchup)
        }
        
        return fantasyMatchups
    }
    
    /// Build FantasyTeam from Sleeper matchup data
    private func buildFantasyTeam(
        from matchup: SleeperMatchup,
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser],
        leagueID: String
    ) async throws -> FantasyTeam? {
        
        guard let roster = rosters.first(where: { $0.rosterID == matchup.roster_id }) else {
            DebugPrint(mode: .fantasy, "❌ No roster found for roster_id \(matchup.roster_id)")
            return nil
        }
        
        guard let user = users.first(where: { $0.userID == roster.ownerID }) else {
            DebugPrint(mode: .fantasy, "❌ No user found for ownerID \(roster.ownerID ?? "nil")")
            return nil
        }
        
        let record = TeamRecord(
            wins: roster.wins ?? roster.settings?.wins ?? 0,
            losses: roster.losses ?? roster.settings?.losses ?? 0,
            ties: roster.ties ?? roster.settings?.ties ?? 0
        )
        
        let avatarURL = user.avatar != nil ? "https://sleepercdn.com/avatars/\(user.avatar!)" : nil
        
        let fantasyPlayers = try await buildFantasyPlayers(from: matchup, leagueID: leagueID)
        
        let teamName = user.displayName ?? user.username ?? "Team \(matchup.roster_id)"
        
        return FantasyTeam(
            id: String(matchup.roster_id),
            name: teamName,
            ownerName: teamName,
            record: record,
            avatar: avatarURL,
            currentScore: matchup.points,
            projectedScore: matchup.projected_points,
            roster: fantasyPlayers,
            rosterID: matchup.roster_id,
            faabTotal: nil,
            faabUsed: roster.waiversBudgetUsed
        )
    }
    
    /// Build FantasyPlayer array from Sleeper matchup
    private func buildFantasyPlayers(
        from matchup: SleeperMatchup,
        leagueID: String
    ) async throws -> [FantasyPlayer] {
        
        guard let allPlayers = matchup.players,
              let starters = matchup.starters else {
            return []
        }
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        for playerID in allPlayers {
            if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                let isStarter = starters.contains(playerID)
                
                let fantasyPlayer = FantasyPlayer(
                    id: playerID,
                    sleeperID: playerID,
                    espnID: sleeperPlayer.espnID,
                    firstName: sleeperPlayer.firstName,
                    lastName: sleeperPlayer.lastName,
                    position: sleeperPlayer.position ?? "FLEX",
                    team: sleeperPlayer.team,
                    jerseyNumber: sleeperPlayer.number?.description,
                    currentPoints: 0.0,
                    projectedPoints: 0.0,
                    gameStatus: gameStatusService.getGameStatusWithFallback(for: sleeperPlayer.team ?? ""),
                    isStarter: isStarter,
                    lineupSlot: isStarter ? sleeperPlayer.position : nil,
                    injuryStatus: sleeperPlayer.injuryStatus
                )
                
                fantasyPlayers.append(fantasyPlayer)
            }
        }
        
        return fantasyPlayers
    }
}

// MARK: - Data Models

/// Package of Sleeper data fetched from API
struct SleeperFantasyDataPackage {
    let league: SleeperLeague
    let users: [SleeperLeagueUser]
    let rosters: [SleeperRoster]
    let matchups: [SleeperMatchup]
}

/// Processed Sleeper data ready for ViewModel
struct SleeperProcessedData {
    let matchups: [FantasyMatchup]
    let rosterIDToManagerID: [Int: String]
    let userIDs: [String: String]
    let league: SleeperLeague
    let rosters: [SleeperRoster]
}

/// Sleeper-specific errors
enum SleeperFantasyError: Error {
    case invalidURL
    case httpError(Int)
    case noRosterFound
    case noUserFound
}