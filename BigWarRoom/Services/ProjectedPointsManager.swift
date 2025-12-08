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
    private let scoringSettingsManager: ScoringSettingsManager
    
    // MARK: - Cache
    @ObservationIgnored private var playerProjectionsCache: [String: Double] = [:]
    @ObservationIgnored private var lastCacheUpdate = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    
    init(
        sleeperProjectionsService: SleeperProjectionsService,
        weekManager: WeekSelectionManager,
        scoringSettingsManager: ScoringSettingsManager
    ) {
        self.sleeperProjectionsService = sleeperProjectionsService
        self.weekManager = weekManager
        self.scoringSettingsManager = scoringSettingsManager
    }
    
    init() {
        self.sleeperProjectionsService = SleeperProjectionsService()
        self.weekManager = WeekSelectionManager.shared
        self.scoringSettingsManager = ScoringSettingsManager.shared
    }
    
    // MARK: - Public API
    
    /// 🔥 NEW: Get projected points using league-specific scoring rules
    /// - Parameters:
    ///   - player: FantasyPlayer to get projection for
    ///   - leagueID: League ID for scoring rules
    ///   - source: League source (ESPN or Sleeper)
    /// - Returns: Custom projected points based on league rules
    func getCustomProjectedPoints(
        for player: FantasyPlayer,
        leagueID: String,
        source: LeagueSource
    ) async -> Double? {
        DebugPrint(mode: .liveUpdates, "🎯 CUSTOM PROJECTION START: \(player.fullName) for league \(leagueID)")
        
        // Try cache first
        let cacheKey = "\(player.id)_\(leagueID)"
        if let cached = getCachedProjection(for: cacheKey) {
            DebugPrint(mode: .liveUpdates, "🎯 CUSTOM CACHE HIT: \(player.fullName) = \(cached)")
            return cached
        }
        
        // Get league scoring settings - wait a moment if they're not loaded yet
        var scoringSettings = scoringSettingsManager.getScoringSettings(for: leagueID, source: source)
        
        // If scoring settings aren't available yet, wait a bit and try again (they might be loading)
        if scoringSettings == nil {
            DebugPrint(mode: .liveUpdates, "🎯 SCORING SETTINGS NOT READY - waiting 100ms for league \(leagueID)")
            try? await Task.sleep(nanoseconds: 100_000_000) // Wait 100ms
            scoringSettings = scoringSettingsManager.getScoringSettings(for: leagueID, source: source)
        }
        
        guard let scoringSettings = scoringSettings else {
            DebugPrint(mode: .liveUpdates, "🎯 NO SCORING SETTINGS for league \(leagueID) - falling back to generic")
            // Fallback to standard projection
            return await getProjectedPoints(for: player)
        }
        
        DebugPrint(mode: .liveUpdates, "🎯 SCORING SETTINGS FOUND: \(scoringSettings.count) rules for league \(leagueID)")
        
        // 🔥 FIX: D/ST and Kickers often don't have Sleeper IDs or raw stats - use fallback projection
        guard let sleeperID = player.sleeperID else {
            DebugPrint(mode: .projectedScores, "🎯 NO SLEEPER ID: \(player.fullName) - falling back to standard projection")
            let fallback = await getProjectedPoints(for: player, scoringFormat: "ppr")
            DebugPrint(mode: .projectedScores, "🎯 FALLBACK RESULT for \(player.fullName): \(fallback ?? 0.0)")
            return fallback
        }
        
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let currentWeek = weekManager.selectedWeek
        
        DebugPrint(mode: .liveUpdates, "🎯 FETCHING PROJECTION: \(player.fullName) (ID: \(sleeperID)) - Week \(currentWeek), Year \(currentYear)")
        
        // Get the full projection with raw stats
        guard let projection = try? await sleeperProjectionsService.getProjection(
            for: sleeperID,
            week: currentWeek,
            year: currentYear
        ) else {
            DebugPrint(mode: .liveUpdates, "🎯 NO PROJECTION DATA: \(player.fullName)")
            return nil
        }
        
        // Extract raw stats and apply league scoring
        let rawStats = projection.toRawStats()
        
        DebugPrint(mode: .liveUpdates, "🎯 RAW STATS EXTRACTED: \(rawStats.count) stats for \(player.fullName)")
        for (key, value) in rawStats {
            DebugPrint(mode: .liveUpdates, "   📊 \(key): \(value)")
        }
        
        // 🔥 FIX: For players without raw stats (kickers, D/ST), fall back to standard projection
        guard !rawStats.isEmpty else {
            DebugPrint(mode: .projectedScores, "🎯 NO RAW STATS AVAILABLE: \(player.fullName) - falling back to standard projection")
            let fallback = await getProjectedPoints(for: player, scoringFormat: "ppr")
            DebugPrint(mode: .projectedScores, "🎯 FALLBACK RESULT for \(player.fullName): \(fallback ?? 0.0)")
            return fallback
        }
        
        // Calculate custom projection using league rules
        let customProjection = calculateCustomProjection(
            rawStats: rawStats,
            scoringSettings: scoringSettings
        )
        
        DebugPrint(mode: .liveUpdates, "🎯 CUSTOM SUCCESS: \(player.fullName) = \(customProjection) (League: \(leagueID))")
        
        // Cache the result
        cacheProjection(customProjection, for: cacheKey)
        
        return customProjection
    }
    
    /// Get projected points for a single player (fallback to generic PPR)
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
            
            DebugPrint(mode: .projectedScores, "🎯 API CALL: Fetching projection for \(player.fullName) (Sleeper ID: \(sleeperID))")
            
            if let projection = try? await sleeperProjectionsService.getProjectedPoints(
                for: sleeperID,
                week: currentWeek,
                year: currentYear,
                scoringFormat: scoringFormat
            ) {
                DebugPrint(mode: .projectedScores, "🎯 API SUCCESS: \(player.fullName) = \(projection)")
                cacheProjection(projection, for: player.id)
                return projection
            } else {
                DebugPrint(mode: .projectedScores, "🎯 API FAILED: No projection for \(player.fullName)")
            }
        } else {
            DebugPrint(mode: .projectedScores, "🎯 NO SLEEPER ID: \(player.fullName) - checking player.projectedPoints property")
        }
        
        // Fallback: Use player's existing projectedPoints property
        if let existing = player.projectedPoints, existing > 0 {
            DebugPrint(mode: .projectedScores, "🎯 FALLBACK SUCCESS: \(player.fullName) = \(existing) from projectedPoints property")
            cacheProjection(existing, for: player.id)
            return existing
        }
        
        // 🔥 FINAL FALLBACK: For D/ST and Kickers with no data, return average projection
        DebugPrint(mode: .projectedScores, "🎯 CHECKING POSITION for \(player.fullName): '\(player.position)'")
        
        if player.position == "D/ST" || player.position == "DEF" {
            let defaultDST = 5.0  // Average D/ST projection
            DebugPrint(mode: .projectedScores, "🎯 DEFAULT D/ST PROJECTION: \(player.fullName) = \(defaultDST)")
            cacheProjection(defaultDST, for: player.id)
            return defaultDST
        }
        
        if player.position == "K" {
            let defaultKicker = 8.0  // Average kicker projection
            DebugPrint(mode: .projectedScores, "🎯 DEFAULT KICKER PROJECTION: \(player.fullName) = \(defaultKicker)")
            cacheProjection(defaultKicker, for: player.id)
            return defaultKicker
        }
        
        DebugPrint(mode: .projectedScores, "🎯 NO PROJECTION FOUND: \(player.fullName) - returning nil")
        return nil
    }
    
    /// Get projected total score for a fantasy team
    /// - Parameters:
    ///   - team: FantasyTeam to calculate projection for
    ///   - leagueID: League ID for scoring rules (optional - uses generic if nil)
    ///   - source: League source (optional - uses generic if nil)
    /// - Returns: Projected total score (current + remaining projections)
    func getProjectedTeamScore(
        for team: FantasyTeam,
        leagueID: String? = nil,
        source: LeagueSource? = nil
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
            else {
                let projection: Double?
                
                // Use custom projection if league context is provided
                if let leagueID = leagueID, let source = source {
                    projection = try? await getCustomProjectedPoints(for: player, leagueID: leagueID, source: source)
                } else {
                    projection = try? await getProjectedPoints(for: player)
                }
                
                if let proj = projection {
                    total += proj
                    DebugPrint(mode: .liveUpdates, "🎯 PROJECTION: \(player.fullName) projected \(proj)")
                }
            }
        }
        
        return total
    }
    
    /// Get projected scores for both teams in a matchup
    /// - Parameters:
    ///   - matchup: UnifiedMatchup to get projections for
    ///   - leagueID: League ID for scoring rules (optional)
    ///   - source: League source (optional)
    /// - Returns: Tuple of (myTeamProjected, opponentProjected)
    func getProjectedMatchupScores(
        for matchup: UnifiedMatchup,
        leagueID: String? = nil,
        source: LeagueSource? = nil
    ) async -> (myTeam: Double, opponent: Double) {
        let leagueName = matchup.fantasyMatchup?.leagueID ?? "Unknown League"
        DebugPrint(mode: .liveUpdates, "🎯 MATCHUP PROJECTIONS: Starting for \(leagueName)")
        
        // Handle Chopped leagues differently
        if matchup.isChoppedLeague {
            // For Chopped, we only care about myTeam projection
            if let myRanking = matchup.myTeamRanking {
                let myProjected = await getProjectedTeamScore(
                    for: myRanking.team,
                    leagueID: leagueID,
                    source: source
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
        
        async let myProjected = getProjectedTeamScore(for: myTeam, leagueID: leagueID, source: source)
        async let opponentProjected = getProjectedTeamScore(for: opponentTeam, leagueID: leagueID, source: source)
        
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
    
    // MARK: - Private Helper Methods
    
    /// Calculate custom projection using league-specific scoring rules
    private func calculateCustomProjection(
        rawStats: [String: Double],
        scoringSettings: [String: Double]
    ) -> Double {
        var totalPoints: Double = 0.0
        
        for (statKey, statValue) in rawStats {
            guard statValue != 0.0,
                  let pointsPerStat = scoringSettings[statKey] else { continue }
            
            // Apply league scoring rules
            let points = statValue * pointsPerStat
            totalPoints += points
            
            DebugPrint(mode: .liveUpdates, "  📊 \(statKey): \(statValue) × \(pointsPerStat) = \(points)")
        }
        
        return totalPoints
    }
}