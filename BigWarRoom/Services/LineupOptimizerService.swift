//
//  LineupOptimizerService.swift
//  BigWarRoom
//
//  💊 Optimizes fantasy lineups using projections and constraint satisfaction
//  🔥 NO SINGLETON - Owned by views via @State for proper memory management
//

import Foundation

@MainActor
@Observable
final class LineupOptimizerService {
    
    // 🔥 NO MORE SINGLETON - Each view owns its own instance
    // static let shared = LineupOptimizerService() ← REMOVED
    
    // 🔥 NEW: Own instances of dependent services for proper lifecycle management
    private let projectionsService = SleeperProjectionsService()
    private let availablePlayersService: AvailablePlayersService
    
    private let gameDataService: NFLGameDataService
    
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
        let currentRoster: [FantasyPlayer]
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
        
        // 🔥 NEW: Check if this change meets the minimum improvement threshold
        var meetsThreshold: Bool {
            return improvement >= LineupOptimizerService.minimumImprovementThreshold
        }
        
        // 🔥 NEW: Calculate improvement percentage
        var improvementPercentage: Double {
            guard projectedPointsOut > 0 else { return 100.0 }
            return (improvement / projectedPointsOut) * 100.0
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
    
    // MARK: - Initialization
    
    init(gameDataService: NFLGameDataService) {
        // Store injected dependency
        self.gameDataService = gameDataService
        
        // Initialize other services
        self.availablePlayersService = AvailablePlayersService(projectionsService: projectionsService)
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: New instance created (view-owned)")
    }
    
    deinit {
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Instance deallocated (memory freed) ✅")
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
        
        // 🔥 NEW: Log ALL roster players BEFORE optimization
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: FULL ROSTER DUMP:")
        for player in myTeam.roster {
            let name = player.fullName
            let pos = player.position
            let starterStr = player.isStarter ? "STARTER" : "BENCH"
            let slotStr = player.lineupSlot ?? "nil"
            let sleeperStr = player.sleeperID ?? "nil"
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER:    - \(name) (\(pos)) | \(starterStr) | Slot: \(slotStr) | SID: \(sleeperStr)")
        }
        
        // Fetch projections
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Fetching projections for week \(week) \(year)...")
        
        let projections: [String: SleeperProjectionsService.SleeperProjection]
        do {
            // 🔥 CHANGED: Use instance instead of .shared
            projections = try await projectionsService.fetchProjections(
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
        
        // Build player projections map with BYE WEEK OVERRIDE
        var playerProjections: [String: Double] = [:]
        for player in myTeam.roster {
            guard let sleeperID = player.sleeperID else {
                DebugPrint(mode: .lineupRX, "⚠️ OPTIMIZER: \(player.fullName) has no Sleeper ID - skipping projections")
                continue
            }
            
            // 🔥 CRITICAL FIX: Check if player is on BYE WEEK
            let isByeWeek = checkIfPlayerOnBye(player: player)
            
            if isByeWeek {
                // 🚨 BYE WEEK = 0.0 POINTS GUARANTEED
                playerProjections[sleeperID] = 0.0
                DebugPrint(mode: .lineupRX, "🚨 OPTIMIZER: \(player.fullName) is on BYE → 0.0 pts")
                continue
            }
            
            guard let projection = projections[sleeperID] else {
                DebugPrint(mode: .lineupRX, "⚠️ OPTIMIZER: \(player.fullName) has no projection data")
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
                DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: \(player.fullName) projection = \(String(format: "%.1f", points)) pts")
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
        
        // 🔥 FIX: Calculate improvement based on ACTUAL recommended changes (after filtering)
        // This ensures improvement matches what's actually being recommended to the user
        let actualImprovement = changes.reduce(0.0) { $0 + $1.improvement }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Raw improvement: \(improvement), Actual improvement after filtering: \(actualImprovement)")
        
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
            improvement: actualImprovement,
            changes: changes,
            moveChains: changes.map { $0.moveChain },
            playerProjections: playerProjections,
            currentRoster: myTeam.roster
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
        // 🔥 CHANGED: Use instance instead of .shared
        let projections = try await projectionsService.fetchProjections(
            week: week,
            year: year
        )
        
        // For each position, find top available players
        let positions = ["QB", "RB", "WR", "TE"]
        
        for position in positions {
            // 🔥 CHANGED: Use instance instead of .shared
            let topAvailable = try await availablePlayersService.getTopAvailablePlayers(
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
            
            // 🔥 NEW: More robust WR/TE detection logic
            // Count position occurrences and look for TEs in non-TE slots
            var positionCounts: [String: Int] = [:]
            var teInFlexPosition = false
            var wrteFlexCount = 0
            
            for player in starters {
                guard let slot = player.lineupSlot else { continue }
                let posKey = slot.uppercased()
                let playerPos = player.position.uppercased()
                
                // Skip bench slots
                if ["BN", "BENCH", "IR"].contains(posKey) { continue }
                
                // 🔥 CRITICAL: Detect TE in WR position = WR/TE flex
                if posKey == "WR" && playerPos == "TE" {
                    teInFlexPosition = true
                    wrteFlexCount += 1
                    DebugPrint(mode: .lineupRX, "🔥 Detected WR/TE flex: \(player.fullName) (TE) in WR slot")
                    continue // Don't count as regular WR
                }
                
                // 🔥 ALSO: Check if the slot itself is named "WR/TE"
                if posKey == "WR/TE" || posKey.contains("WR/TE") {
                    teInFlexPosition = true
                    wrteFlexCount += 1
                    DebugPrint(mode: .lineupRX, "🔥 Detected WR/TE flex: slot name \(posKey)")
                    continue
                }
                
                // Count regular positions
                positionCounts[posKey, default: 0] += 1
            }
            
            // Add unlimited bench
            requirements["BN"] = 99
            requirements["BENCH"] = 99
            requirements["IR"] = 99
            
            // Add WR/TE flex count
            if wrteFlexCount > 0 {
                requirements["WR/TE"] = wrteFlexCount
                DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Detected \(wrteFlexCount) WR/TE flex slots")
            }
            
            // Add standard positions
            for (pos, count) in positionCounts {
                requirements[pos] = count
            }
            
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
        
        // 🔥 CRITICAL: Lock all FINAL players in their current positions FIRST
        var lockedPlayers: [FantasyPlayer] = []
        var lockedPlayerIDs = Set<String>()
        
        for player in roster {
            // 🔥 MODEL-BASED CP: Use hasPlayedThisWeek instead of helper function
            if player.hasPlayedThisWeek(gameDataService: gameDataService) {
                lockedPlayers.append(player)
                lockedPlayerIDs.insert(player.id)
                DebugPrint(mode: .lineupRX, "🔒 LOCKED PLAYER: \(player.fullName) in \(player.lineupSlot ?? "?") - game is FINAL")
                
                // If they're a starter, add them to optimal lineup in their current slot
                if player.isStarter, let slot = player.lineupSlot {
                    let normalizedSlot = slot.uppercased()
                    if optimalLineup[normalizedSlot] == nil {
                        optimalLineup[normalizedSlot] = []
                    }
                    optimalLineup[normalizedSlot]?.append(player)
                    DebugPrint(mode: .lineupRX, "   → Keeping \(player.fullName) in \(normalizedSlot) (locked)")
                } else {
                    // If they're on bench, lock them there
                    if optimalLineup["BENCH"] == nil {
                        optimalLineup["BENCH"] = []
                    }
                    optimalLineup["BENCH"]?.append(player)
                    DebugPrint(mode: .lineupRX, "   → Keeping \(player.fullName) on BENCH (locked)")
                }
            }
        }
        
        // Remove locked players from available pool
        availablePlayers.removeAll { lockedPlayerIDs.contains($0.id) }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: \(lockedPlayers.count) players locked, \(availablePlayers.count) players available to optimize")
        
        // Sort available players by projected points (descending)
        availablePlayers.sort { player1, player2 in
            let proj1 = player1.sleeperID.flatMap { projections[$0] } ?? 0
            let proj2 = player2.sleeperID.flatMap { projections[$0] } ?? 0
            return proj1 > proj2
        }
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Starting optimization with \(availablePlayers.count) available players")
        if !availablePlayers.isEmpty {
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Top 5 available players:")
            for (index, player) in availablePlayers.prefix(5).enumerated() {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                DebugPrint(mode: .lineupRX, "💊 OPTIMIZER:    \(index + 1). \(player.fullName) (\(player.position)) - \(String(format: "%.1f", proj)) pts")
            }
        }
        
        // Fill standard positions first (QB, RB, WR, TE, K, DEF, D/ST)
        let standardPositions = ["QB", "RB", "WR", "TE", "K", "DEF", "D/ST"]
        
        for position in standardPositions {
            guard let count = requirements[position], count > 0 else { continue }
            
            // Check how many slots are already filled by locked players
            let lockedInPosition = optimalLineup[position]?.count ?? 0
            let slotsNeeded = count - lockedInPosition
            
            guard slotsNeeded > 0 else {
                DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: \(position) fully occupied by \(lockedInPosition) locked player(s)")
                continue
            }
            
            var filled = 0
            var playersForPosition: [FantasyPlayer] = []
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(slotsNeeded) \(position) slot(s) (\(lockedInPosition) already locked)")
            
            for player in availablePlayers where player.position == position && filled < slotsNeeded {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                playersForPosition.append(player)
                filled += 1
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) to \(position) (\(String(format: "%.1f", proj)) pts)")
            }
            
            if !playersForPosition.isEmpty {
                if optimalLineup[position] == nil {
                    optimalLineup[position] = playersForPosition
                } else {
                    optimalLineup[position]?.append(contentsOf: playersForPosition)
                }
                
                // Remove assigned players from available pool
                availablePlayers.removeAll { player in
                    playersForPosition.contains(where: { $0.id == player.id })
                }
            }
        }
        
        // Fill SUPER_FLEX positions (QB/RB/WR/TE)
        if let superFlexCount = requirements["SUPER_FLEX"], superFlexCount > 0 {
            var superFlexPlayers: [FantasyPlayer] = []
            let superFlexEligible = availablePlayers.filter { ["QB", "RB", "WR", "TE"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(superFlexCount) SUPER_FLEX slots from \(superFlexEligible.count) eligible players")
            
            for player in superFlexEligible.prefix(superFlexCount) {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                superFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) (\(player.position)) to SUPER_FLEX (\(String(format: "%.1f", proj)) pts)")
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
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Top FLEX-eligible players:")
            for (index, player) in flexEligible.prefix(flexCount + 3).enumerated() {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                DebugPrint(mode: .lineupRX, "   \(index + 1). \(player.fullName) (\(player.position)) - \(String(format: "%.1f", proj)) pts")
            }
            
            for player in flexEligible.prefix(flexCount) {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                flexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) (\(player.position)) to FLEX (\(String(format: "%.1f", proj)) pts)")
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
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                wrrbFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) (\(player.position)) to WRRB_FLEX (\(String(format: "%.1f", proj)) pts)")
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
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                recFlexPlayers.append(player)
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) (\(player.position)) to REC_FLEX (\(String(format: "%.1f", proj)) pts)")
            }
            
            optimalLineup["REC_FLEX"] = recFlexPlayers
            availablePlayers.removeAll { player in
                recFlexPlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // 🔥 NEW: Fill WR/TE positions (ESPN's WR/TE flex)
        if let wrteCount = requirements["WR/TE"], wrteCount > 0 {
            var wrtePlayers: [FantasyPlayer] = []
            let wrteEligible = availablePlayers.filter { ["WR", "TE"].contains($0.position) }
            
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Filling \(wrteCount) WR/TE slots from \(wrteEligible.count) eligible players")
            
            for player in wrteEligible.prefix(wrteCount) {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                wrtePlayers.append(player)
                DebugPrint(mode: .lineupRX, "   ✅ Assigned \(player.fullName) (\(player.position)) to WR/TE (\(String(format: "%.1f", proj)) pts)")
            }
            
            optimalLineup["WR/TE"] = wrtePlayers
            availablePlayers.removeAll { player in
                wrtePlayers.contains(where: { $0.id == player.id })
            }
        }
        
        // Remaining players go to bench
        optimalLineup["BENCH"] = availablePlayers
        
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Optimization complete. Bench: \(availablePlayers.count) players")
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Benched players with projections:")
        for player in availablePlayers.prefix(10) {
            let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
            DebugPrint(mode: .lineupRX, "💊 OPTIMIZER:    🪑 \(player.fullName) (\(player.position)) - \(String(format: "%.1f", proj)) pts")
        }
        
        return optimalLineup
    }
    
    private func calculateTotalProjectedPoints(
        lineup: [String: [FantasyPlayer]],
        projections: [String: Double]
    ) -> Double {
        var total: Double = 0
        
        for (position, players) in lineup where position != "BENCH" {
            for player in players {
                let points: Double
                
                // 🔥 MODEL-BASED CP: Use hasPlayedThisWeek for finished games
                if player.hasPlayedThisWeek(gameDataService: gameDataService), let actualPoints = player.currentPoints {
                    points = actualPoints
                } else if let sleeperID = player.sleeperID, let projection = projections[sleeperID] {
                    points = projection
                } else {
                    continue
                }
                
                total += points
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
        DebugPrint(mode: .lineupRX, "💊 OPTIMIZER: Current starters (\(starters.count)):")
        
        // Sum points for starters - use ACTUAL points for finished games, PROJECTIONS for upcoming games
        for player in starters {
            let points: Double
            
            // 🔥 MODEL-BASED CP: Use hasPlayedThisWeek for finished games
            if player.hasPlayedThisWeek(gameDataService: gameDataService), let actualPoints = player.currentPoints {
                points = actualPoints
                DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: \(player.fullName) (\(player.lineupSlot ?? "?")) - \(String(format: "%.1f", points)) pts [ACTUAL]")
            } else if let sleeperID = player.sleeperID, let projection = projections[sleeperID] {
                points = projection
                DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: \(player.fullName) (\(player.lineupSlot ?? "?")) - \(String(format: "%.1f", points)) pts [PROJECTED]")
            } else {
                DebugPrint(mode: .lineupRX, "⚠️ CURRENT LINEUP: \(player.fullName) (\(player.lineupSlot ?? "?")) - No points data")
                continue
            }
            
            total += points
        }
        
        DebugPrint(mode: .lineupRX, "💊 CURRENT LINEUP: Total = \(String(format: "%.1f", total)) pts")
        
        return total
    }
    
    /// 🔥 NEW: Generate move chains using GP's human heuristic - ONLY CRITICAL PATH
    private func generateMoveChains(
        currentRoster: [FantasyPlayer],
        optimalLineup: [String: [FantasyPlayer]],
        projections: [String: Double]
    ) -> [LineupChange] {
        
        DebugPrint(mode: .lineupRX, "🎯 CHANGE DETECTOR: Finding all starter swaps")
        
        var changes: [LineupChange] = []
        
        let currentStarters = currentRoster.filter { $0.isStarter }
        let benchPlayers = currentRoster.filter { !$0.isStarter }
        
        DebugPrint(mode: .lineupRX, "📊 OPTIMAL LINEUP:")
        for (position, players) in optimalLineup {
            DebugPrint(mode: .lineupRX, "   \(position): \(players.count) player(s)")
            for player in players {
                let proj = player.sleeperID.flatMap { projections[$0] } ?? 0
                DebugPrint(mode: .lineupRX, "      - \(player.fullName) (\(String(format: "%.1f", proj)) pts)")
            }
        }
        
        var currentStarterIDs = Set<String>()
        for starter in currentStarters {
            currentStarterIDs.insert(starter.id)
        }
        
        var optimalStarterIDs = Set<String>()
        for (position, players) in optimalLineup {
            if position != "BENCH" && position != "BN" && position != "IR" {
                for player in players {
                    optimalStarterIDs.insert(player.id)
                }
            }
        }
        
        DebugPrint(mode: .lineupRX, "🔍 Current starter IDs: \(currentStarterIDs.count)")
        DebugPrint(mode: .lineupRX, "🔍 Optimal starter IDs: \(optimalStarterIDs.count)")
        
        // 🔥 CRITICAL: Build list of ALL players whose games are FINAL (locked - can't be moved)
        var lockedPlayerIDs = Set<String>()
        for player in currentRoster {
            if player.hasPlayedThisWeek(gameDataService: gameDataService) {
                lockedPlayerIDs.insert(player.id)
                DebugPrint(mode: .lineupRX, "🔒 LOCKED: \(player.fullName) - game is FINAL, cannot be moved")
            }
        }
        
        var playersToBench: [FantasyPlayer] = []
        var playersToStart: [FantasyPlayer] = []
        
        for starter in currentStarters {
            if !optimalStarterIDs.contains(starter.id) {
                // 🔥 Skip if player is locked (game FINAL)
                if lockedPlayerIDs.contains(starter.id) {
                    DebugPrint(mode: .lineupRX, "⚠️ SKIPPING BENCH: \(starter.fullName) - locked (game FINAL)")
                    continue
                }
                
                playersToBench.append(starter)
                let proj = starter.sleeperID.flatMap { projections[$0] } ?? 0
                DebugPrint(mode: .lineupRX, "🎯 BENCH: \(starter.fullName) (\(String(format: "%.1f", proj)) pts)")
            }
        }
        
        for bench in benchPlayers {
            if optimalStarterIDs.contains(bench.id) {
                // 🔥 Skip if player is locked (game FINAL)
                if lockedPlayerIDs.contains(bench.id) {
                    DebugPrint(mode: .lineupRX, "⚠️ SKIPPING START: \(bench.fullName) - locked (game FINAL)")
                    continue
                }
                
                playersToStart.append(bench)
                let proj = bench.sleeperID.flatMap { projections[$0] } ?? 0
                DebugPrint(mode: .lineupRX, "🎯 START: \(bench.fullName) (\(String(format: "%.1f", proj)) pts)")
            }
        }
        
        let sortedToBench = playersToBench.sorted { p1, p2 in
            let proj1 = p1.sleeperID.flatMap { projections[$0] } ?? 0
            let proj2 = p2.sleeperID.flatMap { projections[$0] } ?? 0
            return proj1 < proj2
        }
        
        let sortedToStart = playersToStart.sorted { p1, p2 in
            let proj1 = p1.sleeperID.flatMap { projections[$0] } ?? 0
            let proj2 = p2.sleeperID.flatMap { projections[$0] } ?? 0
            return proj1 > proj2
        }
        
        DebugPrint(mode: .lineupRX, "🎯 Creating individual changes for \(sortedToStart.count) players to start")
        
        for playerToStart in sortedToStart {
            let playerProj = playerToStart.sleeperID.flatMap { projections[$0] } ?? 0
            let targetSlot = findTargetSlot(for: playerToStart, in: optimalLineup)
            
            let playerOut = sortedToBench.first { benchedPlayer in
                let benchedSlot = benchedPlayer.lineupSlot ?? ""
                return normalizeSlotName(benchedSlot) == normalizeSlotName(targetSlot) ||
                       benchedPlayer.position == playerToStart.position
            }
            
            // 🔥 DOUBLE CHECK: Even though we filtered above, verify playerOut isn't locked
            // (This is extra safety in case logic changes)
            if let playerOut = playerOut, lockedPlayerIDs.contains(playerOut.id) {
                DebugPrint(mode: .lineupRX, "⚠️ SKIPPING SWAP: \(playerOut.fullName) is locked (game FINAL)")
                continue
            }
            
            let playerOutProj = playerOut?.sleeperID.flatMap { projections[$0] } ?? 0
            let improvement = playerProj - playerOutProj
            
            // 🔥 NEW: Check if improvement meets minimum threshold (percentage-based)
            let improvementPercentage = playerOutProj > 0 ? (improvement / playerOutProj) : 0.0
            
            if improvementPercentage < Self.minimumImprovementThreshold {
                DebugPrint(mode: .lineupRX, "⚠️ SKIPPING LOW-VALUE SWAP: \(playerToStart.fullName) → \(playerOut?.fullName ?? "?") (+\(String(format: "%.1f", improvement)) pts / \(String(format: "%.1f%%", improvementPercentage * 100))) - below threshold (\(String(format: "%.0f%%", Self.minimumImprovementThreshold * 100)))")
                continue
            }
            
            var steps: [MoveStep] = []
            
            if let playerOut = playerOut {
                let slot = playerOut.lineupSlot ?? playerOut.position
                steps.append(MoveStep(
                    player: playerOut,
                    fromSlot: slot,
                    toSlot: "Bench",
                    reason: playerOutProj == 0.0 ? "Player on BYE" : "Lower projection",
                    projection: playerOutProj,
                    isRepositioning: false
                ))
            }
            
            steps.append(MoveStep(
                player: playerToStart,
                fromSlot: "Bench",
                toSlot: targetSlot,
                reason: "Higher projection",
                projection: playerProj,
                isRepositioning: false
            ))
            
            let chain = MoveChain(
                steps: steps,
                netImprovement: improvement,
                playerBenched: playerOut,
                playerStarted: playerToStart
            )
            
            let change = LineupChange(
                playerOut: playerOut,
                playerIn: playerToStart,
                position: targetSlot,
                projectedPointsOut: playerOutProj,
                projectedPointsIn: playerProj,
                improvement: improvement,
                moveChain: chain
            )
            
            changes.append(change)
            
            DebugPrint(mode: .lineupRX, "✅ Created change: \(playerOut?.fullName ?? "Empty") → \(playerToStart.fullName) at \(targetSlot) (+\(String(format: "%.1f", improvement)) pts / \(String(format: "%.1f", improvementPercentage))%)")
        }
        
        changes.sort { $0.improvement > $1.improvement }
        
        DebugPrint(mode: .lineupRX, "🎯 Generated \(changes.count) lineup changes (after threshold filtering)")
        
        return changes
    }
    
    /// 🔥 NEW: Check if a player's game status is FINAL (already played - can't be moved)
    
    /// Find what slot a player should go to in the optimal lineup
    private func findTargetSlot(for player: FantasyPlayer, in optimalLineup: [String: [FantasyPlayer]]) -> String {
        for (position, players) in optimalLineup {
            if position != "BENCH" && position != "BN" && position != "IR" {
                if players.contains(where: { $0.id == player.id }) {
                    return formatSlotName(position)
                }
            }
        }
        return "Unknown"
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
    
    /// Check if player is on BYE week using game status service
    private func checkIfPlayerOnBye(player: FantasyPlayer) -> Bool {
        guard let team = player.team else { 
            return false 
        }
        
        if let gameInfo = gameDataService.getGameInfo(for: team) {
            let isBye = gameInfo.gameStatus.lowercased() == "bye"
            if isBye {
                DebugPrint(mode: .lineupRX, "🚨 BYE WEEK: \(player.fullName) (\(team)) is on BYE")
            }
            return isBye
        }
        
        return false
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
    
    // 🔥 NEW: Minimum improvement threshold - only suggest changes with meaningful impact
    // Uses user's saved preference from Settings (default 10%)
    static var minimumImprovementThreshold: Double {
        let percentageThreshold = UserDefaults.standard.lineupOptimizationThreshold
        // Convert percentage to decimal (10% = 0.10)
        return percentageThreshold / 100.0
    }
    
    // 🔥 DEPRECATED: Old static threshold - now using user preference
    // static let minimumImprovementThreshold: Double = 1.0 // At least 1.0 points improvement
    // static let minimumImprovementPercentage: Double = 10.0 // Or at least 10% improvement
}