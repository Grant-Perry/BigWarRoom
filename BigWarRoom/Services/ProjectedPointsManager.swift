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
            let expectedScore = await getLiveExpectedScore(for: player, scoringFormat: scoringFormat)
            total += expectedScore
        }
        
        return total
    }
    
    // MARK: - Live Expected Score Calculation
    
    /// Calculate expected final score for a player based on current score + remaining projection
    /// This creates smooth transitions instead of jarring drops when games start
    ///
    /// Formula: expected = current_score + (projection × remaining_game_percentage)
    ///
    /// Examples:
    /// - Pre-game (0% complete): 0 + (20 × 1.0) = 20 pts
    /// - Q1 (25% done), 2 pts: 2 + (20 × 0.75) = 17 pts
    /// - Halftime (50% done), 8 pts: 8 + (20 × 0.5) = 18 pts
    /// - Final, 15 pts: 15 + (20 × 0.0) = 15 pts
    private func getLiveExpectedScore(
        for player: FantasyPlayer,
        scoringFormat: String = "ppr"
    ) async -> Double {
        let currentScore = player.currentPoints ?? 0.0
        
        // Get game info for this player's team
        guard let team = player.team else {
            // No team = can't determine game status, use projection
            if let projection = await getProjectedPoints(for: player, scoringFormat: scoringFormat) {
                DebugPrint(mode: .liveUpdates, "🎯 NO_TEAM: \(player.fullName) using projection \(projection)")
                return projection
            }
            return currentScore
        }
        
        // Get game progress
        let gameProgress = getGameProgress(for: team)
        let remainingPercentage = 1.0 - gameProgress
        
        // Get projection for remaining calculation
        guard let projection = await getProjectedPoints(for: player, scoringFormat: scoringFormat) else {
            // No projection available, just use current score
            DebugPrint(mode: .liveUpdates, "🎯 NO_PROJ: \(player.fullName) using current \(currentScore)")
            return currentScore
        }
        
        // Calculate remaining expected points
        let remainingExpected = projection * remainingPercentage
        let expectedTotal = currentScore + remainingExpected
        
        DebugPrint(mode: .liveUpdates, "🎯 LIVE_PROJ: \(player.fullName) = \(String(format: "%.1f", currentScore)) + (\(String(format: "%.1f", projection)) × \(String(format: "%.0f%%", remainingPercentage * 100))) = \(String(format: "%.1f", expectedTotal))")
        
        return expectedTotal
    }
    
    /// Calculate game progress percentage (0.0 = not started, 1.0 = finished)
    /// Uses quarter and time remaining to estimate progress
    private func getGameProgress(for team: String) -> Double {
        let gameService = NFLGameDataService.shared
        
        guard let gameInfo = gameService.getGameInfo(for: team) else {
            // No game info = assume not started
            return 0.0
        }
        
        // Game finished = 100% complete
        if gameInfo.isCompleted {
            return 1.0
        }
        
        // Game not started = 0% complete
        if !gameInfo.isLive {
            return 0.0
        }
        
        // Parse the display time to get quarter and time
        let displayTime = gameInfo.displayTime.uppercased()
        
        // Handle special cases
        if displayTime.contains("HALFTIME") || displayTime.contains("HALF") {
            return 0.5
        }
        if displayTime.contains("FINAL") {
            return 1.0
        }
        if displayTime.contains("PREGAME") {
            return 0.0
        }
        
        // Parse quarter (Q1, Q2, Q3, Q4, OT)
        var quarterProgress: Double = 0.0
        
        if displayTime.contains("Q1") || displayTime.contains("1ST") {
            quarterProgress = 0.0  // 0-25%
        } else if displayTime.contains("Q2") || displayTime.contains("2ND") {
            quarterProgress = 0.25  // 25-50%
        } else if displayTime.contains("Q3") || displayTime.contains("3RD") {
            quarterProgress = 0.5  // 50-75%
        } else if displayTime.contains("Q4") || displayTime.contains("4TH") {
            quarterProgress = 0.75  // 75-100%
        } else if displayTime.contains("OT") {
            quarterProgress = 0.9  // OT = nearly done
        }
        
        // Try to parse time remaining in quarter (e.g., "Q2 14:15" → 14:15 remaining)
        // Each quarter is 15 minutes, so time remaining tells us progress within quarter
        let timePattern = #"(\d{1,2}):(\d{2})"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: displayTime, range: NSRange(displayTime.startIndex..., in: displayTime)) {
            
            if let minutesRange = Range(match.range(at: 1), in: displayTime),
               let secondsRange = Range(match.range(at: 2), in: displayTime),
               let minutes = Double(displayTime[minutesRange]),
               let seconds = Double(displayTime[secondsRange]) {
                
                // Time remaining in quarter (max 15:00)
                let timeRemaining = minutes + (seconds / 60.0)
                let quarterLength = 15.0
                
                // Progress within this quarter (0 = just started quarter, 1 = quarter ending)
                let withinQuarterProgress = max(0, min(1, (quarterLength - timeRemaining) / quarterLength))
                
                // Add within-quarter progress (each quarter is 25% of game)
                quarterProgress += withinQuarterProgress * 0.25
            }
        }
        
        return min(1.0, max(0.0, quarterProgress))
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