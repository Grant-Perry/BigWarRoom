//
//  ProjectedPointsManager.swift
//  BigWarRoom
//
//  🎯 DRY SERVICE: Centralized projected points logic for all views
//  Handles Sleeper & ESPN projections with caching
//

import Foundation
import Observation

@MainActor
@Observable
final class ProjectedPointsManager {
    
    // MARK: - Singleton (for convenience, but can be injected)
    static let shared = ProjectedPointsManager()
    
    // MARK: - Dependencies
    private let sleeperProjectionsService: SleeperProjectionsService
    private let weekManager: WeekSelectionManager
    
    // MARK: - Cache
    @ObservationIgnored private var playerProjectionsCache: [String: Double] = [:]
    @ObservationIgnored private var lastCacheUpdate = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    init(
        sleeperProjectionsService: SleeperProjectionsService,
        weekManager: WeekSelectionManager
    ) {
        self.sleeperProjectionsService = sleeperProjectionsService
        self.weekManager = weekManager
    }
    
    init() {
        self.sleeperProjectionsService = SleeperProjectionsService()
        self.weekManager = WeekSelectionManager.shared
    }
    
    // MARK: - Public API
    
    /// Get projected points for a single player
    /// - Parameters:
    ///   - player: FantasyPlayer to get projection for
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Projected points or nil
    func getProjectedPoints(
        for player: FantasyPlayer,
        scoringFormat: String = "ppr"
    ) async -> Double? {
        // Try cache first
        if let cached = getCachedProjection(for: player.id) {
            DebugPrint(mode: .liveUpdates, "🎯 CACHE HIT: \(player.fullName) = \(cached)")
            return cached
        }
        
        // Try to get from Sleeper ID
        if let sleeperID = player.sleeperID {
            let currentYear = String(Calendar.current.component(.year, from: Date()))
            let currentWeek = weekManager.selectedWeek
            
            DebugPrint(mode: .liveUpdates, "🎯 API CALL: Fetching projection for \(player.fullName) (Sleeper ID: \(sleeperID))")
            
            if let projection = try? await sleeperProjectionsService.getProjectedPoints(
                for: sleeperID,
                week: currentWeek,
                year: currentYear,
                scoringFormat: scoringFormat
            ) {
                DebugPrint(mode: .liveUpdates, "🎯 API SUCCESS: \(player.fullName) = \(projection)")
                cacheProjection(projection, for: player.id)
                return projection
            } else {
                DebugPrint(mode: .liveUpdates, "🎯 API FAILED: No projection for \(player.fullName)")
            }
        } else {
            DebugPrint(mode: .liveUpdates, "🎯 NO SLEEPER ID: \(player.fullName)")
        }
        
        // Fallback: Use player's existing projectedPoints property
        if let existing = player.projectedPoints, existing > 0 {
            DebugPrint(mode: .liveUpdates, "🎯 FALLBACK: \(player.fullName) = \(existing)")
            cacheProjection(existing, for: player.id)
            return existing
        }
        
        // 🔥 FINAL FALLBACK: DST positions get a default 5.0 projection
        if player.position == "D/ST" || player.position == "DEF" {
            let dstDefault = 5.0
            DebugPrint(mode: .liveUpdates, "🎯 DST DEFAULT: \(player.fullName) = \(dstDefault)")
            cacheProjection(dstDefault, for: player.id)
            return dstDefault
        }
        
        DebugPrint(mode: .liveUpdates, "🎯 NO PROJECTION: \(player.fullName)")
        return nil
    }
    
    /// Get projected total score for a fantasy team
    /// - Parameters:
    ///   - team: FantasyTeam to calculate projection for
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Projected total score (current + remaining projections)
    func getProjectedTeamScore(
        for team: FantasyTeam,
        scoringFormat: String = "ppr"
    ) async -> Double {
        var total: Double = 0.0
        
        // Only count starters
        let starters = team.roster.filter { $0.isStarter }
        
        for player in starters {
            // If player has already played/is playing, use current score
            if let currentScore = player.currentPoints, currentScore > 0 {
                total += currentScore
                DebugPrint(mode: .liveUpdates, "🎯 CURRENT: \(player.fullName) already scored \(currentScore)")
            } 
            // If player hasn't played yet, use projection
            else if let projection = await getProjectedPoints(for: player, scoringFormat: scoringFormat) {
                total += projection
                DebugPrint(mode: .liveUpdates, "🎯 PROJECTION: \(player.fullName) projected \(projection)")
            }
        }
        
        return total
    }
    
    /// Get projected scores for both teams in a matchup
    /// - Parameters:
    ///   - matchup: UnifiedMatchup to get projections for
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Tuple of (myTeamProjected, opponentProjected)
    func getProjectedMatchupScores(
        for matchup: UnifiedMatchup,
        scoringFormat: String = "ppr"
    ) async -> (myTeam: Double, opponent: Double) {
        let leagueName = matchup.fantasyMatchup?.leagueID ?? "Unknown League"
        DebugPrint(mode: .liveUpdates, "🎯 MATCHUP PROJECTIONS: Starting for \(leagueName)")
        
        // Handle Chopped leagues differently
        if matchup.isChoppedLeague {
            // For Chopped, we only care about myTeam projection
            if let myRanking = matchup.myTeamRanking {
                let myProjected = await getProjectedTeamScore(
                    for: myRanking.team,
                    scoringFormat: scoringFormat
                )
                DebugPrint(mode: .liveUpdates, "🎯 CHOPPED RESULT: My Team = \(myProjected)")
                return (myProjected, 0.0)
            }
            DebugPrint(mode: .liveUpdates, "🎯 CHOPPED ERROR: No team ranking")
            return (0.0, 0.0)
        }
        
        // Regular matchup
        guard let myTeam = matchup.myTeam,
              let opponentTeam = matchup.opponentTeam else {
            DebugPrint(mode: .liveUpdates, "🎯 ERROR: Missing teams")
            return (0.0, 0.0)
        }
        
        async let myProjected = getProjectedTeamScore(for: myTeam, scoringFormat: scoringFormat)
        async let opponentProjected = getProjectedTeamScore(for: opponentTeam, scoringFormat: scoringFormat)
        
        let results = await (myProjected, opponentProjected)
        DebugPrint(mode: .liveUpdates, "🎯 MATCHUP RESULT: My=\(results.0), Opp=\(results.1)")
        return results
    }
    
    /// Clear all cached projections (useful when week changes)
    func clearCache() {
        playerProjectionsCache.removeAll()
        lastCacheUpdate = Date.distantPast
        DebugPrint(mode: .liveUpdates, "🗑️ PROJECTIONS CACHE: Cleared all cached projections")
    }
    
    // MARK: - Private Cache Methods
    
    private func getCachedProjection(for playerID: String) -> Double? {
        // Check if cache is still valid
        guard Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration else {
            return nil
        }
        
        return playerProjectionsCache[playerID]
    }
    
    private func cacheProjection(_ projection: Double, for playerID: String) {
        playerProjectionsCache[playerID] = projection
        lastCacheUpdate = Date()
    }
}