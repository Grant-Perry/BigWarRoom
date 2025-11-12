//
//  LineupOptimizerService.swift
//  BigWarRoom
//
//  💊 Optimizes fantasy lineups using projections and constraint satisfaction
//

import Foundation

@MainActor
@Observable
final class LineupOptimizerService {
    static let shared = LineupOptimizerService()
    
    // MARK: - Models
    
    struct OptimizationResult {
        let optimalLineup: [String: [FantasyPlayer]]  // Position -> Players
        let benchedPlayers: [FantasyPlayer]
        let projectedPoints: Double
        let currentPoints: Double
        let improvement: Double
        let changes: [LineupChange]
        let playerProjections: [String: Double]  // SleeperID -> Projected Points
    }
    
    struct LineupChange {
        let playerOut: FantasyPlayer  // Player being removed from starting lineup
        let playerIn: FantasyPlayer   // Player being added to starting lineup
        let position: String           // Position being swapped
        let projectedPointsOut: Double
        let projectedPointsIn: Double
        let improvement: Double        // Net point improvement
        
        var reason: String {
            return "Projected +\(String(format: "%.1f", improvement)) pts"
        }
    }
    
    struct WaiverRecommendation {
        let playerToAdd: PlayerInfo
        let playerToDrop: FantasyPlayer
        let projectedImpact: Double
        let projectedPointsDrop: Double  // Projected points for player being dropped
        let reason: String
    }
    
    struct PlayerInfo {
        let playerID: String
        let name: String
        let position: String
        let team: String
        let projectedPoints: Double
    }
    
    // MARK: - Lineup Optimization
    
    /// Optimize the current lineup for maximum projected points
    /// - Parameters:
    ///   - matchup: The matchup containing team and league info
    ///   - week: Week number for projections
    ///   - year: Season year
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: OptimizationResult with optimal lineup and changes
    func optimizeLineup(
        for matchup: UnifiedMatchup,
        week: Int,
        year: String,
        scoringFormat: String = "ppr"
    ) async throws -> OptimizationResult {
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Starting lineup optimization for \(matchup.league.league.name)")
        
        guard let myTeam = matchup.myTeam else {
            DebugPrint(mode: .lineupRX, "❌ OPTIMIZER: No team data in matchup")
            throw OptimizerError.noTeamData
        }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Team: \(myTeam.ownerName), Roster: \(myTeam.roster.count) players")
        
        // Fetch projections for all players on the roster
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Fetching projections for week \(week) \(year)...")
        
        let projections: [String: SleeperProjectionsService.SleeperProjection]
        do {
            projections = try await SleeperProjectionsService.shared.fetchProjections(
                week: week,
                year: year
            )
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: ✅ Fetched \(projections.count) player projections")
        } catch {
            DebugPrint(mode: .lineupRX, "❌ OPTIMIZER: Failed to fetch projections - \(error.localizedDescription)")
            throw error
        }
        
        // Get lineup requirements from league settings
        let lineupRequirements = getLineupRequirements(for: matchup)
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Lineup requirements: \(lineupRequirements)")
        
        // Build player projections map
        var playerProjections: [String: Double] = [:]
        for player in myTeam.roster {
            guard let sleeperID = player.sleeperID else {
                continue
            }
            
            guard let projection = projections[sleeperID] else {
                continue
            }
            
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
                playerProjections[sleeperID] = points
            }
        }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Got projections for \(playerProjections.count) players out of \(myTeam.roster.count) roster players")
        
        // Run optimization algorithm
        let optimalLineup = optimizeWithConstraints(
            roster: myTeam.roster,
            projections: playerProjections,
            requirements: lineupRequirements
        )
        
        // Calculate improvements
        let currentPoints = myTeam.currentScore ?? 0
        let projectedPoints = calculateTotalProjectedPoints(lineup: optimalLineup, projections: playerProjections)
        let improvement = projectedPoints - currentPoints
        
        // Identify changes
        let changes = identifyLineupChanges(
            currentRoster: myTeam.roster,
            optimalLineup: optimalLineup,
            projections: playerProjections
        )
        
        // Identify benched players
        let startedPlayerIDs = Set(optimalLineup.values.flatMap { $0 }.compactMap { $0.sleeperID })
        let benchedPlayers = myTeam.roster.filter { player in
            guard let sleeperID = player.sleeperID else { return false }
            return !startedPlayerIDs.contains(sleeperID)
        }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Optimization complete. \(changes.count) changes recommended")
        
        return OptimizationResult(
            optimalLineup: optimalLineup,
            benchedPlayers: benchedPlayers,
            projectedPoints: projectedPoints,
            currentPoints: currentPoints,
            improvement: improvement,
            changes: changes,
            playerProjections: playerProjections
        )
    }
    
    /// Get waiver wire recommendations
    /// - Parameters:
    ///   - matchup: The matchup containing team and league info
    ///   - week: Week number for projections
    ///   - year: Season year
    ///   - limit: Maximum number of recommendations
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Array of waiver recommendations
    func getWaiverRecommendations(
        for matchup: UnifiedMatchup,
        week: Int,
        year: String,
        limit: Int = 5,
        scoringFormat: String = "ppr"
    ) async throws -> [WaiverRecommendation] {
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Finding waiver recommendations")
        
        guard let myTeam = matchup.myTeam else {
            throw OptimizerError.noTeamData
        }
        
        var recommendations: [WaiverRecommendation] = []
        
        // Fetch projections first
        let projections = try await SleeperProjectionsService.shared.fetchProjections(
            week: week,
            year: year
        )
        
        // For each position, find top available players
        let positions = ["QB", "RB", "WR", "TE"]
        
        for position in positions {
            let topAvailable = try await AvailablePlayersService.shared.getTopAvailablePlayers(
                for: matchup,
                position: position,
                week: week,
                year: year,
                limit: 10,
                scoringFormat: scoringFormat
            )
            
            // Find worst player on roster at this position (using actual projections)
            let positionPlayers = myTeam.roster.filter { $0.position == position }
            
            // Get projections for each position player
            var playerProjections: [(player: FantasyPlayer, projection: Double)] = []
            for player in positionPlayers {
                if let sleeperID = player.sleeperID,
                   let projection = projections[sleeperID] {
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
                        playerProjections.append((player: player, projection: points))
                    }
                }
            }
            
            // Find worst projected player
            guard let worstPlayerTuple = playerProjections.min(by: { $0.projection < $1.projection }) else {
                continue
            }
            
            let worstPlayer = worstPlayerTuple.player
            let worstPlayerProjection = worstPlayerTuple.projection
            
            // Compare with top available
            for (playerID, projectedPoints) in topAvailable {
                let impact = projectedPoints - worstPlayerProjection
                
                // Only recommend if significant improvement (>3 points)
                if impact > 3.0 {
                    if let playerInfo = getPlayerInfo(playerID: playerID, projectedPoints: projectedPoints) {
                        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Recommending ADD: \(playerInfo.name) (Sleeper ID: \(playerID)) - \(projectedPoints) pts")
                        recommendations.append(WaiverRecommendation(
                            playerToAdd: playerInfo,
                            playerToDrop: worstPlayer,
                            projectedImpact: impact,
                            projectedPointsDrop: worstPlayerProjection,  // Add this
                            reason: "Projected +\(String(format: "%.1f", impact)) pts over \(worstPlayer.fullName)"
                        ))
                    }
                }
            }
        }
        
        // Sort by projected impact (descending)
        recommendations.sort { $0.projectedImpact > $1.projectedImpact }
        
        // Limit results
        let topRecommendations = Array(recommendations.prefix(limit))
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Found \(topRecommendations.count) waiver recommendations")
        
        return topRecommendations
    }
    
    // MARK: - Private Helpers
    
    /// Get lineup requirements from league settings
    private func getLineupRequirements(for matchup: UnifiedMatchup) -> [String: Int] {
        // Default NFL lineup
        var requirements: [String: Int] = [
            "QB": 1,
            "RB": 2,
            "WR": 2,
            "TE": 1,
            "FLEX": 1,  // RB/WR/TE
            "BENCH": 99  // Unlimited bench
        ]
        
        // TODO: Parse actual league settings from matchup.league.league
        // For now, use defaults
        
        return requirements
    }
    
    /// Optimize lineup using greedy algorithm with constraints
    private func optimizeWithConstraints(
        roster: [FantasyPlayer],
        projections: [String: Double],
        requirements: [String: Int]
    ) -> [String: [FantasyPlayer]] {
        var optimalLineup: [String: [FantasyPlayer]] = [:]
        var availablePlayers = roster
        
        // Sort players by projected points (descending)
        availablePlayers.sort { player1, player2 in
            let proj1 = player1.sleeperID.flatMap { projections[$0] } ?? 0
            let proj2 = player2.sleeperID.flatMap { projections[$0] } ?? 0
            return proj1 > proj2
        }
        
        // Fill required positions first
        for (position, count) in requirements where position != "FLEX" && position != "BENCH" {
            var filled = 0
            var playersForPosition: [FantasyPlayer] = []
            
            for player in availablePlayers where player.position == position && filled < count {
                playersForPosition.append(player)
                filled += 1
            }
            
            optimalLineup[position] = playersForPosition
            // Remove assigned players from available pool
            availablePlayers.removeAll { player in
                playersForPosition.contains(where: { $0.id == player.id })
            }
        }
        
        // Fill FLEX positions with best remaining RB/WR/TE
        if let flexCount = requirements["FLEX"], flexCount > 0 {
            var flexPlayers: [FantasyPlayer] = []
            let flexEligible = availablePlayers.filter { ["RB", "WR", "TE"].contains($0.position) }
            
            for player in flexEligible.prefix(flexCount) {
                flexPlayers.append(player)
            }
            
            optimalLineup["FLEX"] = flexPlayers
            availablePlayers.removeAll { player in
                flexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Remaining players go to bench
        optimalLineup["BENCH"] = availablePlayers
        
        return optimalLineup
    }
    
    /// Calculate total projected points for a lineup
    private func calculateTotalProjectedPoints(
        lineup: [String: [FantasyPlayer]],
        projections: [String: Double]
    ) -> Double {
        var total: Double = 0
        
        for (position, players) in lineup where position != "BENCH" {
            for player in players {
                if let sleeperID = player.sleeperID,
                   let projection = projections[sleeperID] {
                    total += projection
                }
            }
        }
        
        return total
    }
    
    /// Identify changes between current starters and bench players
    private func identifyLineupChanges(
        currentRoster: [FantasyPlayer],
        optimalLineup: [String: [FantasyPlayer]],
        projections: [String: Double]
    ) -> [LineupChange] {
        var changes: [LineupChange] = []
        
        // Separate starters and bench
        let currentStarters = currentRoster.filter { $0.isStarter }
        var availableBenchPlayers = currentRoster.filter { !$0.isStarter }
        
        // Track which bench players have been used in recommendations
        var usedBenchPlayerIDs = Set<String>()
        
        // Build list of potential swaps
        var potentialSwaps: [LineupChange] = []
        
        for starter in currentStarters {
            let starterPosition = starter.position
            let starterProj = starter.sleeperID.flatMap { projections[$0] } ?? 0
            
            // Find bench players at the same position (excluding already used ones)
            let eligibleBenchPlayers = availableBenchPlayers.filter { benchPlayer in
                // Skip if already used
                if usedBenchPlayerIDs.contains(benchPlayer.id) {
                    return false
                }
                
                // Same position OR FLEX-eligible
                if benchPlayer.position == starterPosition {
                    return true
                }
                // TODO: Handle FLEX logic (RB/WR/TE can go in FLEX)
                return false
            }
            
            // Find the best available bench player for this position
            var bestBenchPlayer: FantasyPlayer?
            var bestBenchProj: Double = 0
            
            for benchPlayer in eligibleBenchPlayers {
                let benchProj = benchPlayer.sleeperID.flatMap { projections[$0] } ?? 0
                if benchProj > bestBenchProj {
                    bestBenchProj = benchProj
                    bestBenchPlayer = benchPlayer
                }
            }
            
            // If best bench player is better than starter, add to potential swaps
            if let bestBenchPlayer = bestBenchPlayer {
                let improvement = bestBenchProj - starterProj
                
                if improvement > 0.5 {  // At least 0.5 point improvement
                    potentialSwaps.append(LineupChange(
                        playerOut: starter,
                        playerIn: bestBenchPlayer,
                        position: starter.lineupSlot ?? starterPosition,
                        projectedPointsOut: starterProj,
                        projectedPointsIn: bestBenchProj,
                        improvement: improvement
                    ))
                }
            }
        }
        
        // Sort potential swaps by improvement (highest first)
        potentialSwaps.sort { $0.improvement > $1.improvement }
        
        // Select swaps, ensuring each bench player is only used once
        for swap in potentialSwaps {
            // Only add if this bench player hasn't been used yet
            if !usedBenchPlayerIDs.contains(swap.playerIn.id) {
                changes.append(swap)
                usedBenchPlayerIDs.insert(swap.playerIn.id)
            }
        }
        
        return changes
    }
    
    /// Get player info from PlayerDirectoryStore
    private func getPlayerInfo(playerID: String, projectedPoints: Double) -> PlayerInfo? {
        let player = PlayerDirectoryStore.shared.players.values.first { $0.playerID == playerID }
        
        guard let player = player, let position = player.position else { return nil }
        
        return PlayerInfo(
            playerID: playerID,
            name: player.fullName,
            position: position,
            team: player.team ?? "FA",
            projectedPoints: projectedPoints
        )
    }
    
    // MARK: - Errors
    
    enum OptimizerError: Error, LocalizedError {
        case noTeamData
        case noProjections
        case invalidLineupRequirements
        
        var errorDescription: String? {
            switch self {
            case .noTeamData:
                return "No team data available"
            case .noProjections:
                return "No projections available"
            case .invalidLineupRequirements:
                return "Invalid lineup requirements"
            }
        }
    }
}

