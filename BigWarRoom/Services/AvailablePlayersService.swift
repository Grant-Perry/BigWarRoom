import Foundation

/// Service for determining which players are available (not rostered) in a league
/// 🔥 NO SINGLETON - Instance-based for proper dependency management
actor AvailablePlayersService {
    
    // 🔥 REMOVED: static let shared = AvailablePlayersService()
    
    // 🔥 NEW: Dependency injection for projections service
    private let projectionsService: SleeperProjectionsService
    
    init(projectionsService: SleeperProjectionsService) {
        self.projectionsService = projectionsService
    }
    
    /// Get available players for a specific position in a league
    /// - Parameters:
    ///   - leagueWrapper: The league wrapper to check
    ///   - position: Optional position filter (nil = all positions)
    /// - Returns: Array of available SleeperPlayer objects
    func getAvailablePlayers(
        for leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        position: String? = nil
    ) async -> [SleeperPlayer] {
        await MainActor.run {
            DebugPrint(mode: .waivers, "💊 Finding available players for \(leagueWrapper.league.name)")
        }
        
        // Get all rostered player IDs/ESPNIDs based on league source
        let rosteredInfo = await getAllRosteredPlayerInfo(for: leagueWrapper)
        await MainActor.run {
            DebugPrint(mode: .waivers, "💊 Found \(rosteredInfo.sleeperIDs.count) rostered players")
        }
        
        // Get all Sleeper players from MainActor context
        let allPlayers = await MainActor.run {
            Array(PlayerDirectoryStore.shared.players.values)
        }
        
        // Filter by position if specified
        var filteredPlayers = allPlayers
        if let position = position {
            filteredPlayers = allPlayers.filter { $0.position == position }
        }
        
        // Remove rostered players based on league source
        let availablePlayers = filteredPlayers.filter { player in
            // For ESPN leagues, check both Sleeper ID and ESPN ID
            if leagueWrapper.source == .espn {
                let isRosteredBySleeperID = rosteredInfo.sleeperIDs.contains(player.playerID)
                let isRosteredByESPNID = player.espnID.map { rosteredInfo.espnIDs.contains($0) } ?? false
                
                let isRostered = isRosteredBySleeperID || isRosteredByESPNID
                return !isRostered
            } else {
                // For Sleeper leagues, only check Sleeper ID
                let isRostered = rosteredInfo.sleeperIDs.contains(player.playerID)
                return !isRostered
            }
        }
        
        // Sort by some relevance criteria (e.g., projected points if available)
        let sortedPlayers = availablePlayers.sorted { player1, player2 in
            // Sort by position priority, then by name
            let positionPriority = ["QB": 0, "RB": 1, "WR": 2, "TE": 3, "K": 4, "DEF": 5]
            let pos1Priority = positionPriority[player1.position ?? ""] ?? 99
            let pos2Priority = positionPriority[player2.position ?? ""] ?? 99
            
            if pos1Priority != pos2Priority {
                return pos1Priority < pos2Priority
            }
            return player1.fullName < player2.fullName
        }
        
        await MainActor.run {
            DebugPrint(mode: .waivers, "💊 Found \(sortedPlayers.count) available players at \(position ?? "all positions")")
        }
        
        return sortedPlayers
    }
    
    /// Get top available players by projections for a position
    func getTopAvailablePlayers(
        for matchup: UnifiedMatchup,
        position: String,
        week: Int,
        year: String,
        limit: Int = 10,
        scoringFormat: String = "ppr"
    ) async throws -> [(String, Double)] {
        // Get all available players for the position
        let availablePlayers = await getAvailablePlayers(
            for: matchup.league,
            position: position
        )
        
        // Fetch projections using injected service
        // 🔥 CHANGED: Use injected instance instead of .shared
        let projections = try await projectionsService.fetchProjections(
            week: week,
            year: year
        )
        
        // Build list of (playerID, projectedPoints) tuples
        var playerProjectionsList: [(String, Double)] = []
        
        for player in availablePlayers {
            guard let projection = projections[player.playerID] else { continue }
            
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
            
            if let points = points {
                playerProjectionsList.append((player.playerID, points))
            }
        }
        
        // Sort by projected points (descending) and take top N
        let topPlayers = playerProjectionsList
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
        
        return Array(topPlayers)
    }
    
    /// Get all rostered player information (both Sleeper IDs and ESPN IDs)
    private func getAllRosteredPlayerInfo(for leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async -> RosteredPlayerInfo {
        var rosteredSleeperIDs: Set<String> = []
        var rosteredESPNIDs: Set<String> = []
        
        switch leagueWrapper.source {
        case .sleeper:
            // For Sleeper leagues, get Sleeper player IDs directly
            do {
                guard let sleeperClient = await leagueWrapper.client as? SleeperAPIClient else {
                    return RosteredPlayerInfo(sleeperIDs: [], espnIDs: [])
                }
                
                let rosters = try await sleeperClient.fetchRosters(leagueID: leagueWrapper.league.id)
                rosteredSleeperIDs = Set(rosters.flatMap { $0.playerIDs ?? [] })
            } catch {
                await MainActor.run {
                    DebugPrint(mode: .waivers, "❌ Failed to fetch Sleeper rosters: \(error)")
                }
            }
            
        case .espn:
            // 🔥 USE HYBRID APPROACH: Canonical mapping + name/team fallback
            do {
                guard let espnClient = await leagueWrapper.client as? ESPNAPIClient else {
                    return RosteredPlayerInfo(sleeperIDs: [], espnIDs: [])
                }
                
                let espnLeagueData = try await espnClient.fetchESPNLeagueData(leagueID: leagueWrapper.league.id)
                
                // Get player directory for name/team lookups
                let playerDirectory = await MainActor.run {
                    PlayerDirectoryStore.shared.players
                }
                
                var canonicalHits = 0
                var fallbackHits = 0
                
                // Extract player IDs with hybrid approach
                if let teams = espnLeagueData.teams {
                    for team in teams {
                        guard let roster = team.roster, let entries = roster.entries else { continue }
                        
                        for entry in entries {
                            let espnID = String(entry.playerId)
                            rosteredESPNIDs.insert(espnID)
                            
                            // Try canonical mapping first
                            let canonicalID = await MainActor.run {
                                ESPNSleeperIDCanonicalizer.shared.getCanonicalSleeperID(forESPNID: espnID)
                            }
                            
                            // Check if canonical mapping found a match (returns different ID)
                            if canonicalID != espnID {
                                // Canonical mapping succeeded
                                rosteredSleeperIDs.insert(canonicalID)
                                canonicalHits += 1
                            } else {
                                // 🔥 FALLBACK: Look up by name + team
                                if let espnPlayer = entry.playerPoolEntry?.player,
                                   let fullName = espnPlayer.fullName,
                                   let proTeamId = espnPlayer.proTeamId,
                                   let teamAbbrev = ESPNTeamMap.teamIdToAbbreviation[proTeamId] {
                                    
                                    // Search player directory by name + team
                                    let normalizedName = normalizePlayerName(fullName)
                                    
                                    if let sleeperPlayer = playerDirectory.values.first(where: { player in
                                        let playerNormalizedName = normalizePlayerName(player.fullName)
                                        let teamMatches = player.team?.uppercased() == teamAbbrev.uppercased()
                                        return playerNormalizedName == normalizedName && teamMatches
                                    }) {
                                        rosteredSleeperIDs.insert(sleeperPlayer.playerID)
                                        fallbackHits += 1
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check if debug is enabled
                let isDebugEnabled = await MainActor.run {
                    AppConstants.debug
                }
                
                if isDebugEnabled {
                    await MainActor.run {
                        DebugPrint(mode: .waivers, "✅ ESPN→Sleeper: \(canonicalHits) canonical, \(fallbackHits) fallback, \(rosteredSleeperIDs.count) total")
                    }
                }
                
            } catch {
                await MainActor.run {
                    DebugPrint(mode: .waivers, "❌ Failed to fetch ESPN league data: \(error)")
                }
            }
        }
        
        return RosteredPlayerInfo(
            sleeperIDs: rosteredSleeperIDs,
            espnIDs: rosteredESPNIDs
        )
    }
    
    /// Normalize player name for matching (remove punctuation, lowercase, etc.)
    private func normalizePlayerName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: " jr", with: "")
            .replacingOccurrences(of: " sr", with: "")
            .replacingOccurrences(of: " iii", with: "")
            .replacingOccurrences(of: " ii", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

/// Container for rostered player information
private struct RosteredPlayerInfo {
    let sleeperIDs: Set<String>
    let espnIDs: Set<String>
}