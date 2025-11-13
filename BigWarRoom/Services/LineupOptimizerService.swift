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
        let optimalLineup: [String: [FantasyPlayer]]
        let benchedPlayers: [FantasyPlayer]
        let projectedPoints: Double
        let currentPoints: Double
        let improvement: Double
        let changes: [LineupChange]
        let moveChains: [MoveChain]
        let playerProjections: [String: Double]
    }
    
    struct LineupChange {
        let playerOut: FantasyPlayer?
        let playerIn: FantasyPlayer
        let position: String
        let projectedPointsOut: Double
        let projectedPointsIn: Double
        let improvement: Double
        let moveChain: MoveChain
        
        var reason: String {
            return "Projected +\(String(format: "%.1f", improvement)) pts"
        }
    }
    
    struct MoveChain {
        let steps: [MoveStep]
        let netImprovement: Double
        let playerBenched: FantasyPlayer?
        let playerStarted: FantasyPlayer
        
        var description: String {
            let stepDescriptions = steps.enumerated().map { index, step in
                "Step \(index + 1): \(step.description)"
            }.joined(separator: "\n")
            return "\(stepDescriptions)\nNet: +\(String(format: "%.1f", netImprovement)) pts"
        }
    }
    
    struct MoveStep {
        let player: FantasyPlayer
        let fromSlot: String
        let toSlot: String
        let reason: String
        let projection: Double
        let isRepositioning: Bool
        
        var description: String {
            if toSlot == "BENCH" {
                return "Bench \(player.fullName) from \(fromSlot) (\(player.position), \(String(format: "%.1f", projection)) pts) - \(reason)"
            } else if fromSlot == "BENCH" {
                return "Start \(player.fullName) in \(toSlot) (\(player.position), \(String(format: "%.1f", projection)) pts) - \(reason)"
            } else {
                return "Move \(player.fullName) from \(fromSlot) to \(toSlot) (\(String(format: "%.1f", projection)) pts) - \(reason)"
            }
        }
    }
    
    struct WaiverRecommendation {
        let playerToAdd: PlayerInfo
        let playerToDrop: FantasyPlayer
        let projectedImpact: Double
        let projectedPointsDrop: Double
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
        
        // Fetch projections
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
        
        // Get lineup requirements
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
        let currentPoints = calculateCurrentLineupProjectedPoints(
            roster: myTeam.roster,
            projections: playerProjections
        )
        let projectedPoints = calculateTotalProjectedPoints(lineup: optimalLineup, projections: playerProjections)
        let improvement = projectedPoints - currentPoints
        
        // 🔥 NEW: Generate move chains by diffing current vs optimal
        let changes = generateMoveChains(
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
            moveChains: changes.map { $0.moveChain },
            playerProjections: playerProjections
        )
    }
    
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
            
            // Find worst player on roster at this position
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
                            projectedPointsDrop: worstPlayerProjection,
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
    
    private func getLineupRequirements(for matchup: UnifiedMatchup) -> [String: Int] {
        var requirements: [String: Int] = [:]
        
        // Try to get actual league roster positions
        if let rosterPositions = matchup.league.league.rosterPositions {
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Using league roster positions: \(rosterPositions)")
            
            // Count each position type
            for position in rosterPositions {
                let posKey = position.uppercased()
                requirements[posKey, default: 0] += 1
            }
            
            // Add unlimited bench
            requirements["BN"] = 99
            requirements["BENCH"] = 99
            requirements["IR"] = 99
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Parsed requirements: \(requirements)")
            
            return requirements
        }
        
        // Fallback: Try to infer from current roster's lineup slots
        if let myTeam = matchup.myTeam {
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Inferring requirements from current roster...")
            
            let starters = myTeam.roster.filter { $0.isStarter }
            
            for player in starters {
                if let slot = player.lineupSlot {
                    let posKey = slot.uppercased()
                    // Skip bench/IR slots
                    if !["BN", "BENCH", "IR"].contains(posKey) {
                        requirements[posKey, default: 0] += 1
                    }
                }
            }
            
            // Add unlimited bench
            requirements["BN"] = 99
            requirements["BENCH"] = 99
            requirements["IR"] = 99
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Inferred requirements: \(requirements)")
            
            return requirements
        }
        
        // Final fallback: Default NFL lineup
        DebugPrint(mode: .lineupRX, "⚠️ OPTIMIZER: Using default lineup requirements")
        return [
            "QB": 1,
            "RB": 2,
            "WR": 2,
            "TE": 1,
            "FLEX": 1,
            "K": 1,
            "DEF": 1,
            "D/ST": 1,
            "BENCH": 99,
            "BN": 99,
            "IR": 99
        ]
    }
    
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
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Starting optimization with \(availablePlayers.count) players")
        
        // Fill standard positions first (QB, RB, WR, TE, K, DEF, D/ST)
        let standardPositions = ["QB", "RB", "WR", "TE", "K", "DEF", "D/ST"]
        
        for position in standardPositions {
            guard let count = requirements[position], count > 0 else { continue }
            
            var filled = 0
            var playersForPosition: [FantasyPlayer] = []
            
            for player in availablePlayers where player.position == position && filled < count {
                playersForPosition.append(player)
                filled += 1
                DebugPrint(mode: .lineupRX, "   Assigned \(player.fullName) to \(position)")
            }
            
            optimalLineup[position] = playersForPosition
            // Remove assigned players from available pool
            availablePlayers.removeAll { player in
                playersForPosition.contains(where: { $0.id == player.id })
            }
        }
        
        // Fill SUPER_FLEX positions (QB/RB/WR/TE)
        if let superFlexCount = requirements["SUPER_FLEX"], superFlexCount > 0 {
            var superFlexPlayers: [FantasyPlayer] = []
            let superFlexEligible = availablePlayers.filter { ["QB", "RB", "WR", "TE"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(superFlexCount) SUPER_FLEX slots from \(superFlexEligible.count) eligible players")
            
            for player in superFlexEligible.prefix(superFlexCount) {
                superFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   Assigned \(player.fullName) (\(player.position)) to SUPER_FLEX")
            }
            
            optimalLineup["SUPER_FLEX"] = superFlexPlayers
            availablePlayers.removeAll { player in
                superFlexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Fill FLEX positions (RB/WR/TE)
        if let flexCount = requirements["FLEX"], flexCount > 0 {
            var flexPlayers: [FantasyPlayer] = []
            let flexEligible = availablePlayers.filter { ["RB", "WR", "TE"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(flexCount) FLEX slots from \(flexEligible.count) eligible players")
            
            for player in flexEligible.prefix(flexCount) {
                flexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   Assigned \(player.fullName) (\(player.position)) to FLEX")
            }
            
            optimalLineup["FLEX"] = flexPlayers
            availablePlayers.removeAll { player in
                flexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Fill WRRB_FLEX positions (WR/RB)
        if let wrrbFlexCount = requirements["WRRB_FLEX"], wrrbFlexCount > 0 {
            var wrrbFlexPlayers: [FantasyPlayer] = []
            let wrrbFlexEligible = availablePlayers.filter { ["WR", "RB"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(wrrbFlexCount) WRRB_FLEX slots from \(wrrbFlexEligible.count) eligible players")
            
            for player in wrrbFlexEligible.prefix(wrrbFlexCount) {
                wrrbFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   Assigned \(player.fullName) (\(player.position)) to WRRB_FLEX")
            }
            
            optimalLineup["WRRB_FLEX"] = wrrbFlexPlayers
            availablePlayers.removeAll { player in
                wrrbFlexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Fill REC_FLEX positions (WR/TE)
        if let recFlexCount = requirements["REC_FLEX"], recFlexCount > 0 {
            var recFlexPlayers: [FantasyPlayer] = []
            let recFlexEligible = availablePlayers.filter { ["WR", "TE"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(recFlexCount) REC_FLEX slots from \(recFlexEligible.count) eligible players")
            
            for player in recFlexEligible.prefix(recFlexCount) {
                recFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   Assigned \(player.fullName) (\(player.position)) to REC_FLEX")
            }
            
            optimalLineup["REC_FLEX"] = recFlexPlayers
            availablePlayers.removeAll { player in
                recFlexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Remaining players go to bench
        optimalLineup["BENCH"] = availablePlayers
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Optimization complete. Bench: \(availablePlayers.count) players")
        
        return optimalLineup
    }
    
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
    
    private func calculateCurrentLineupProjectedPoints(
        roster: [FantasyPlayer],
        projections: [String: Double]
    ) -> Double {
        var total: Double = 0
        
        DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP ANALYSIS:")
        DebugPrint(mode: .lineupRX, "   Total roster size: \(roster.count)")
        
        // Get current starters using the isStarter flag
        let starters = roster.filter { $0.isStarter }
        
        DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: Found \(starters.count) starters out of \(roster.count) total players")
        
        // Sum projected points for starters
        for player in starters {
            if let sleeperID = player.sleeperID,
               let projection = projections[sleeperID] {
                total += projection
                DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: \(player.fullName) (\(player.lineupSlot ?? "?")) - \(String(format: "%.1f", projection)) pts")
            } else {
                DebugPrint(mode: .lineupRX, "⚠️ CURRENT LINEUP: \(player.fullName) (\(player.lineupSlot ?? "?")) - No projection data")
            }
        }
        
        DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: Total projected = \(String(format: "%.1f", total)) pts")
        
        return total
    }
    
    /// 🔥 NEW: Generate move chains using GP's human heuristic - ONLY CRITICAL PATH
    private func generateMoveChains(
        currentRoster: [FantasyPlayer],
        optimalLineup: [String: [FantasyPlayer]],
        projections: [String: Double]
    ) -> [LineupChange] {
        
        DebugPrint(mode: .lineupRX, "🎯 CRITICAL PATH FINDER: Identifying key moves only")
        
        var changes: [LineupChange] = []
        
        // Get current starters and bench players
        let currentStarters = currentRoster.filter { $0.isStarter }
        let benchPlayers = currentRoster.filter { !$0.isStarter }
        
        // Build current lineup map: playerID -> RAW slot
        var currentRawSlotMap: [String: String] = [:]
        for starter in currentStarters {
            if let slot = starter.lineupSlot {
                currentRawSlotMap[starter.id] = slot
                DebugPrint(mode: .lineupRX, "🎯 CURRENT: \(starter.fullName) in \(slot)")
            }
        }
        
        // Build optimal lineup map: playerID -> position from optimal
        var optimalStarterIDs = Set<String>()
        var optimalSlotMap: [String: String] = [:]
        
        for (position, players) in optimalLineup {
            if position != "BENCH" && position != "BN" && position != "IR" {
                for player in players {
                    optimalStarterIDs.insert(player.id)
                    optimalSlotMap[player.id] = position
                    DebugPrint(mode: .lineupRX, "🎯 OPTIMAL: \(player.fullName) in \(position)")
                }
            }
        }
        
        DebugPrint(mode: .lineupRX, "🎯 Comparing Current vs Optimal:")
        
        // Find players who MUST move (not just flex shuffling)
        var criticalBench: [FantasyPlayer] = []
        var criticalStart: [FantasyPlayer] = []
        var criticalReposition: [(player: FantasyPlayer, from: String, to: String)] = []
        
        // 1. Find bench players who should start
        for bench in benchPlayers {
            if optimalStarterIDs.contains(bench.id) {
                criticalStart.append(bench)
                let optimalSlot = optimalSlotMap[bench.id] ?? "?"
                DebugPrint(mode: .lineupRX, "🎯 CRITICAL START: \(bench.fullName) → \(optimalSlot)")
            }
        }
        
        // 2. Find starters who should be benched
        for starter in currentStarters {
            if !optimalStarterIDs.contains(starter.id) {
                criticalBench.append(starter)
                let currentSlot = currentRawSlotMap[starter.id] ?? "?"
                DebugPrint(mode: .lineupRX, "🎯 CRITICAL BENCH: \(starter.fullName) from \(currentSlot)")
            }
        }
        
        // 3. 🔥 PATH-FINDING: Only include moves on the direct path to getting bench players started
        // For each bench player, trace the path of moves needed
        
        for benchPlayer in criticalStart {
            let benchOptimalSlot = normalizeSlotName(optimalSlotMap[benchPlayer.id] ?? "")
            
            DebugPrint(mode: .lineupRX, "🎯 Tracing path for \(benchPlayer.fullName) → \(benchOptimalSlot)")
            
            // Find who's currently in that slot
            var currentSlot = benchOptimalSlot
            var pathPlayers: [FantasyPlayer] = []
            var visitedSlots = Set<String>()
            
            while true {
                // Safety: Prevent infinite loops
                if visitedSlots.contains(currentSlot) {
                    DebugPrint(mode: .lineupRX, "   ⚠️ Loop detected at \(currentSlot)")
                    break
                }
                visitedSlots.insert(currentSlot)
                
                // Find who's currently in this slot
                guard let occupant = currentStarters.first(where: {
                    normalizeSlotName(currentRawSlotMap[$0.id] ?? "") == currentSlot
                }) else {
                    // Slot is empty or we've reached the end
                    DebugPrint(mode: .lineupRX, "   ✅ \(currentSlot) is available")
                    break
                }
                
                DebugPrint(mode: .lineupRX, "   → \(occupant.fullName) occupies \(currentSlot)")
                
                // Where does this occupant want to go?
                let occupantOptimalSlot = normalizeSlotName(optimalSlotMap[occupant.id] ?? "")
                
                if occupantOptimalSlot == currentSlot {
                    // Occupant is already in optimal slot - can't move
                    DebugPrint(mode: .lineupRX, "   ❌ \(occupant.fullName) is already optimal, can't displace")
                    break
                }
                
                // Add to path
                pathPlayers.append(occupant)
                
                // Check if occupant should be benched
                if !optimalStarterIDs.contains(occupant.id) {
                    DebugPrint(mode: .lineupRX, "   ✅ \(occupant.fullName) will be benched")
                    break
                }
                
                // Continue following the chain
                currentSlot = occupantOptimalSlot
                DebugPrint(mode: .lineupRX, "   → Need to free \(currentSlot) for \(occupant.fullName)")
            }
            
            // Add all players in this path to critical repositioning
            for player in pathPlayers {
                guard let currentRawSlot = currentRawSlotMap[player.id],
                      let optimalSlot = optimalSlotMap[player.id] else { continue }
                
                let currentNormalized = normalizeSlotName(currentRawSlot)
                let optimalNormalized = normalizeSlotName(optimalSlot)
                
                if currentNormalized != optimalNormalized {
                    // Check if already added
                    if !criticalReposition.contains(where: { $0.player.id == player.id }) {
                        criticalReposition.append((
                            player: player,
                            from: currentRawSlot,
                            to: optimalSlot
                        ))
                        DebugPrint(mode: .lineupRX, "   ✅ CRITICAL: \(player.fullName) \(currentNormalized) → \(optimalNormalized)")
                    }
                }
            }
        }
        
        // Build chain if there are critical moves
        if !criticalBench.isEmpty || !criticalReposition.isEmpty || !criticalStart.isEmpty {
            var steps: [MoveStep] = []
            
            DebugPrint(mode: .lineupRX, "🎯 Building chain with:")
            DebugPrint(mode: .lineupRX, "🎯   Bench: \(criticalBench.count)")
            DebugPrint(mode: .lineupRX, "🎯   Reposition: \(criticalReposition.count)")
            DebugPrint(mode: .lineupRX, "🎯   Start: \(criticalStart.count)")
            
            // STEP 1: Bench players
            for player in criticalBench {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                let fromSlot = player.lineupSlot ?? "UNKNOWN"
                
                steps.append(MoveStep(
                    player: player,
                    fromSlot: formatSlotName(fromSlot),
                    toSlot: "Bench",
                    reason: "Free up \(formatSlotName(normalizeSlotName(fromSlot))) slot",
                    projection: proj,
                    isRepositioning: false
                ))
            }
            
            // STEP 2: Reposition players (only critical moves)
            // 🔥 SORT: FROM SUPER_FLEX moves first
            let sortedReposition = criticalReposition.sorted { r1, r2 in
                let from1 = normalizeSlotName(r1.from)
                let from2 = normalizeSlotName(r2.from)
                
                if from1 == "SUPER_FLEX" && from2 != "SUPER_FLEX" { return true }
                if from2 == "SUPER_FLEX" && from1 != "SUPER_FLEX" { return false }
                
                return false
            }
            
            for (player, from, to) in sortedReposition {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                
                steps.append(MoveStep(
                    player: player,
                    fromSlot: formatSlotName(from),
                    toSlot: formatSlotName(to),
                    reason: "Free up \(formatSlotName(from)) slot",
                    projection: proj,
                    isRepositioning: true
                ))
                
                DebugPrint(mode: .lineupRX, "🎯 Added step: Move \(player.fullName) \(formatSlotName(from)) → \(formatSlotName(to))")
            }
            
            // STEP 3: Start bench players
            for player in criticalStart {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                let toSlot = optimalSlotMap[player.id] ?? "UNKNOWN"
                
                steps.append(MoveStep(
                    player: player,
                    fromSlot: "Bench",
                    toSlot: formatSlotName(toSlot),
                    reason: "Start in \(formatSlotName(toSlot))",
                    projection: proj,
                    isRepositioning: false
                ))
            }
            
            // Calculate net improvement
            let pointsLost = criticalBench.compactMap { $0.sleeperID.flatMap { projections[$0] } }.reduce(0, +)
            let pointsGained = criticalStart.compactMap { $0.sleeperID.flatMap { projections[$0] } }.reduce(0, +)
            let netImprovement = pointsGained - pointsLost
            
            DebugPrint(mode: .lineupRX, "🎯 Total steps: \(steps.count)")
            DebugPrint(mode: .lineupRX, "🎯 Net: +\(String(format: "%.1f", netImprovement)) pts")
            
            let primaryStarter = criticalStart.max { p1, p2 in
                let proj1 = p1.sleeperID.flatMap { projections[$0] } ?? 0
                let proj2 = p2.sleeperID.flatMap { projections[$0] } ?? 0
                return proj1 < proj2
            } ?? criticalStart.first
            
            if let primaryStarter = primaryStarter {
                let chain = MoveChain(
                    steps: steps,
                    netImprovement: netImprovement,
                    playerBenched: criticalBench.first,
                    playerStarted: primaryStarter
                )
                
                let primaryPos = optimalSlotMap[primaryStarter.id] ?? "UNKNOWN"
                
                let change = LineupChange(
                    playerOut: criticalBench.first,
                    playerIn: primaryStarter,
                    position: formatSlotName(primaryPos),
                    projectedPointsOut: criticalBench.first?.sleeperID.flatMap { projections[$0] } ?? 0,
                    projectedPointsIn: primaryStarter.sleeperID.flatMap { projections[$0] } ?? 0,
                    improvement: netImprovement,
                    moveChain: chain
                )
                
                changes.append(change)
            }
        }
        
        DebugPrint(mode: .lineupRX, "🎯 Generated \(changes.count) move chains")
        
        return changes
    }
    
    /// Format slot names for display
    private func formatSlotName(_ slot: String) -> String {
        let upper = slot.uppercased()
        
        // Handle specific cases
        switch upper {
        case "SUPER_FLEX", "SUPERFLEX":
            return "Super Flex"
        case "WRRB_FLEX":
            return "WR|RB Flex"
        case "REC_FLEX":
            return "WR|TE Flex"
        case "FLEX":
            return "Flex"
        case "BENCH", "BN":
            return "Bench"
        case "DEF", "D/ST":
            return "DEF"
        default:
            // For position slots (QB, RB, WR, TE, K), just return as-is
            return upper
        }
    }
    
    /// Get eligible slot types for a position
    private func getEligibleSlots(for position: String) -> [String] {
        switch position {
        case "QB":
            return ["QB", "SUPER_FLEX"]
        case "RB":
            return ["RB", "FLEX", "WRRB_FLEX", "SUPER_FLEX"]
        case "WR":
            return ["WR", "FLEX", "WRRB_FLEX", "REC_FLEX", "SUPER_FLEX"]
        case "TE":
            return ["TE", "FLEX", "REC_FLEX", "SUPER_FLEX"]
        case "K":
            return ["K"]
        case "DEF", "D/ST":
            return ["DEF", "D/ST"]
        default:
            return []
        }
    }
    
    /// Normalize slot names (strip numbers like "RB2" → "RB")
    private func normalizeSlotName(_ slot: String) -> String {
        let normalized = slot.uppercased()
        // Remove trailing numbers
        if let lastChar = normalized.last, lastChar.isNumber {
            return String(normalized.dropLast())
        }
        return normalized
    }
    
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