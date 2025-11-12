//
//  AvailablePlayersService.swift
//  BigWarRoom
//
//  💊 Identifies available (unrostered) players for waiver wire recommendations
//

import Foundation

@MainActor
@Observable
final class AvailablePlayersService {
    static let shared = AvailablePlayersService()
    
    // MARK: - Public API
    
    /// Get all available players for a league (not rostered by any team)
    /// - Parameters:
    ///   - matchup: The matchup containing league and roster info
    ///   - position: Optional position filter (e.g., "RB", "WR", "QB")
    /// - Returns: Array of available player IDs
    func getAvailablePlayers(
        for matchup: UnifiedMatchup,
        position: String? = nil
    ) async -> [String] {
        DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: Finding available players for \(matchup.league.league.name)")
        
        // Get all rostered player IDs in the league
        let rosteredPlayerIDs = await getAllRosteredPlayerIDs(for: matchup)
        
        DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: Found \(rosteredPlayerIDs.count) rostered players")
        
        // Get all players from PlayerDirectoryStore
        let allPlayers = PlayerDirectoryStore.shared.players
        
        // Filter to available players
        var availablePlayers = allPlayers.values.filter { player in
            // Get Sleeper ID
            let sleeperID = player.playerID
            
            // Debug: Log key players
            let debugNames = ["McCaffrey", "Achane", "Nacua", "St. Brown"]
            if debugNames.contains(where: { player.fullName.contains($0) }) {
                let isRostered = rosteredPlayerIDs.contains(sleeperID)
                DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: Checking \(player.fullName) - Sleeper ID: \(sleeperID), Is Rostered: \(isRostered)")
            }
            
            // Must not be rostered
            guard !rosteredPlayerIDs.contains(sleeperID) else { return false }
            
            // Must have a valid position (not DEF, K unless specified)
            guard let playerPosition = player.position else { return false }
            let validPositions = ["QB", "RB", "WR", "TE"]
            guard validPositions.contains(playerPosition) else { return false }
            
            // Position filter if specified
            if let position = position {
                guard playerPosition == position else { return false }
            }
            
            return true
        }
        
        // Sort by some relevance metric (for now, just alphabetically)
        availablePlayers.sort { $0.fullName < $1.fullName }
        
        let availablePlayerIDs = availablePlayers.map { $0.playerID }
        
        DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: Found \(availablePlayerIDs.count) available players" + (position != nil ? " at \(position!)" : ""))
        
        return availablePlayerIDs
    }
    
    /// Get top available players sorted by projected points
    /// - Parameters:
    ///   - matchup: The matchup containing league and roster info
    ///   - position: Optional position filter
    ///   - week: Week number for projections
    ///   - year: Season year
    ///   - limit: Maximum number of players to return
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Array of (playerID, projectedPoints) tuples
    func getTopAvailablePlayers(
        for matchup: UnifiedMatchup,
        position: String? = nil,
        week: Int,
        year: String,
        limit: Int = 20,
        scoringFormat: String = "ppr"
    ) async throws -> [(playerID: String, projectedPoints: Double)] {
        // Get available players
        let availablePlayerIDs = await getAvailablePlayers(for: matchup, position: position)
        
        // Fetch projections for the week
        let projections = try await SleeperProjectionsService.shared.fetchProjections(
            week: week,
            year: year
        )
        
        // Map available players to their projections
        var playerProjections: [(playerID: String, projectedPoints: Double)] = []
        
        for playerID in availablePlayerIDs {
            guard let projection = projections[playerID] else { continue }
            
            let points: Double?
            switch scoringFormat.lowercased() {
            case "ppr":
                points = projection.pts_ppr
            case "half_ppr", "half":
                points = projection.pts_half_ppr
            case "std", "standard":
                points = projection.pts_std
            default:
                points = projection.pts_ppr
            }
            
            if let points = points, points > 0 {
                playerProjections.append((playerID: playerID, projectedPoints: points))
            }
        }
        
        // Sort by projected points (descending)
        playerProjections.sort { $0.projectedPoints > $1.projectedPoints }
        
        // Limit results
        let topPlayers = Array(playerProjections.prefix(limit))
        
        DebugPrint(mode: .lineupRX, "💊 TOP AVAILABLE: Found \(topPlayers.count) top available players" + (position != nil ? " at \(position!)" : ""))
        
        return topPlayers
    }
    
    // MARK: - Private Helpers
    
    /// Get all rostered player IDs across all teams in the league
    private func getAllRosteredPlayerIDs(for matchup: UnifiedMatchup) async -> Set<String> {
        var rosteredIDs = Set<String>()
        
        // For Sleeper leagues, fetch all rosters
        if matchup.league.source == .sleeper {
            if let rosters = try? await fetchSleeperRosters(leagueID: matchup.league.league.leagueID) {
                for roster in rosters {
                    rosteredIDs.formUnion(roster.players)
                }
            }
        }
        // For ESPN leagues, fetch ALL teams in the league
        else if matchup.league.source == .espn {
            if let espnLeague = try? await fetchESPNLeague(leagueID: matchup.league.league.leagueID) {
                // Iterate through ALL teams in the league
                if let teams = espnLeague.teams {
                    for team in teams {
                        // Get all players from this team's roster
                        if let entries = team.roster?.entries {
                            for entry in entries {
                                let espnPlayerID = String(entry.playerId)
                                
                                // Try ESPN ID lookup first
                                var sleeperPlayer = PlayerDirectoryStore.shared.playerByESPNID(espnPlayerID)
                                
                                // If that fails, try name-based lookup as fallback
                                if sleeperPlayer == nil, let playerName = entry.player?.fullName {
                                    sleeperPlayer = PlayerDirectoryStore.shared.players.values.first(where: { 
                                        $0.fullName.lowercased() == playerName.lowercased() 
                                    })
                                }
                                
                                if let sleeperPlayer = sleeperPlayer {
                                    let sleeperID = sleeperPlayer.playerID
                                    rosteredIDs.insert(sleeperID)
                                    
                                    // Debug: Log key players
                                    let debugNames = ["McCaffrey", "Achane", "Nacua", "St. Brown"]
                                    if debugNames.contains(where: { sleeperPlayer.fullName.contains($0) }) {
                                        DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: Found \(sleeperPlayer.fullName) - ESPN ID: \(espnPlayerID), Sleeper ID: \(sleeperID)")
                                    }
                                }
                            }
                        }
                    }
                }
                
                DebugPrint(mode: .lineupRX, "💊 AVAILABLE PLAYERS: ESPN league has \(espnLeague.teams?.count ?? 0) teams with \(rosteredIDs.count) total rostered players")
            }
        }
        
        return rosteredIDs
    }
    
    /// Fetch all rosters for a Sleeper league
    private func fetchSleeperRosters(leagueID: String) async throws -> [SleeperRoster] {
        let urlString = "https://api.sleeper.app/v1/league/\(leagueID)/rosters"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AvailablePlayersService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode([SleeperRoster].self, from: data)
    }
    
    /// Fetch ESPN league data (includes all teams and rosters)
    private func fetchESPNLeague(leagueID: String) async throws -> ESPNLeague {
        return try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: leagueID)
    }
    
    // MARK: - Models
    
    struct SleeperRoster: Codable {
        let roster_id: Int
        let owner_id: String
        let players: [String]
        let starters: [String]?
    }
}

