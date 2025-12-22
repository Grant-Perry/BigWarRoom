//
//  StatsFacade.swift
//  BigWarRoom
//
//  Unified facade for player stats lookup - hides the three-step lookup complexity
//

import Foundation

/// **StatsFacade**
/// 
/// Unified interface for player stats lookup that handles the three-step lookup:
/// 1. Local (ChoppedTeamRosterViewModel, etc.)
/// 2. Cache (PlayerStatsCache)
/// 3. Global (AllLivePlayersViewModel)
struct StatsFacade {
    
    // 🔥 PHASE 3 DI: Accept playerStatsCache as parameter
    
    /// Get player stats with automatic fallback through all available sources
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider (ChoppedTeamRosterViewModel, etc.)
    ///   - allLivePlayersViewModel: Optional AllLivePlayersViewModel for global stats lookup
    ///   - playerStatsCache: PlayerStatsCache instance for cached stats
    ///   - weekSelectionManager: WeekSelectionManager for current week
    /// - Returns: Player stats dictionary or nil if no stats found
    static func getPlayerStats(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil,
        playerStatsCache: PlayerStatsCache? = nil,
        weekSelectionManager: WeekSelectionManager? = nil
    ) -> [String: Double]? {
        
        DebugPrint(mode: .scoring, "📊 StatsFacade: Looking up stats for playerID: \(playerID), week: \(week)")
        
        // STEP 1: Try local stats provider first (highest priority)
        if let localStats = localStatsProvider?.getLocalPlayerStats(for: playerID) {
            DebugPrint(mode: .scoring, "✅ StatsFacade: Found LOCAL stats for \(playerID) (\(localStats.count) stats)")
            return localStats
        }
        DebugPrint(mode: .scoring, "⏭️ StatsFacade: No local stats provider or no local stats")
        
        // STEP 2: Try PlayerStatsCache (cached API data) if provided
        if let cache = playerStatsCache {
            DebugPrint(mode: .scoring, "🔍 StatsFacade: Checking cache for playerID: \(playerID), week: \(week)")
            if let cachedStats = cache.getPlayerStats(playerID: playerID, week: week) {
                DebugPrint(mode: .scoring, "✅ StatsFacade: Found CACHED stats for \(playerID) (\(cachedStats.count) stats)")
                return cachedStats
            } else {
                DebugPrint(mode: .scoring, "❌ StatsFacade: No cached stats found")
            }
        } else {
            DebugPrint(mode: .scoring, "⚠️ StatsFacade: PlayerStatsCache NOT PROVIDED")
        }
        
        // STEP 3: Try AllLivePlayersViewModel (global live data) if provided
        if let viewModel = allLivePlayersViewModel {
            DebugPrint(mode: .scoring, "🔍 StatsFacade: Checking AllLivePlayersViewModel (\(viewModel.playerStats.count) players)")
            if let globalStats = viewModel.playerStats[playerID] {
                DebugPrint(mode: .scoring, "✅ StatsFacade: Found GLOBAL stats for \(playerID) (\(globalStats.count) stats)")
                return globalStats
            } else {
                DebugPrint(mode: .scoring, "❌ StatsFacade: Player \(playerID) not in AllLivePlayersViewModel")
            }
        } else {
            DebugPrint(mode: .scoring, "⚠️ StatsFacade: AllLivePlayersViewModel NOT PROVIDED")
        }
        
        DebugPrint(mode: .scoring, "❌ StatsFacade: NO STATS FOUND for playerID: \(playerID), week: \(week)")
        return nil
    }
    
    /// Convenience method that gets current selected week automatically
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - localStatsProvider: Optional local stats provider
    ///   - allLivePlayersViewModel: Optional AllLivePlayersViewModel for global stats lookup
    ///   - playerStatsCache: PlayerStatsCache instance for cached stats
    ///   - weekSelectionManager: WeekSelectionManager for current week
    /// - Returns: Player stats dictionary or nil
    static func getPlayerStats(
        playerID: String,
        localStatsProvider: LocalStatsProvider? = nil,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil,
        playerStatsCache: PlayerStatsCache? = nil,
        weekSelectionManager: WeekSelectionManager? = nil
    ) -> [String: Double]? {
        let currentWeek = weekSelectionManager?.selectedWeek ?? 1
        return getPlayerStats(
            playerID: playerID,
            week: currentWeek,
            localStatsProvider: localStatsProvider,
            allLivePlayersViewModel: allLivePlayersViewModel,
            playerStatsCache: playerStatsCache,
            weekSelectionManager: weekSelectionManager
        )
    }
    
    /// Check if any stats are available for a player
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider
    ///   - allLivePlayersViewModel: Optional AllLivePlayersViewModel for global stats lookup
    ///   - playerStatsCache: PlayerStatsCache instance for cached stats
    ///   - weekSelectionManager: WeekSelectionManager for current week
    /// - Returns: True if stats are available from any source
    static func hasStats(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil,
        playerStatsCache: PlayerStatsCache? = nil,
        weekSelectionManager: WeekSelectionManager? = nil
    ) -> Bool {
        return getPlayerStats(
            playerID: playerID,
            week: week,
            localStatsProvider: localStatsProvider,
            allLivePlayersViewModel: allLivePlayersViewModel,
            playerStatsCache: playerStatsCache,
            weekSelectionManager: weekSelectionManager
        ) != nil
    }
    
    /// Get stats source description for debugging
    /// - Parameters:
    ///   - playerID: Sleeper player ID  
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider
    ///   - allLivePlayersViewModel: Optional AllLivePlayersViewModel for global stats lookup
    ///   - playerStatsCache: PlayerStatsCache instance for cached stats
    ///   - weekSelectionManager: WeekSelectionManager for current week
    /// - Returns: Description of which source provided the stats
    static func getStatsSource(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil,
        playerStatsCache: PlayerStatsCache? = nil,
        weekSelectionManager: WeekSelectionManager? = nil
    ) -> String {
        
        if localStatsProvider?.getLocalPlayerStats(for: playerID) != nil {
            return "Local (\(type(of: localStatsProvider!)))"
        }
        
        if let cache = playerStatsCache,
           cache.getPlayerStats(playerID: playerID, week: week) != nil {
            return "Cache"
        }
        
        if let viewModel = allLivePlayersViewModel, viewModel.playerStats[playerID] != nil {
            return "Global"
        }
        
        return "None"
    }
}

// MARK: - LocalStatsProvider Protocol

/// Protocol for view models that provide local player stats
protocol LocalStatsProvider {
    /// Get player stats from the local provider
    /// - Parameter playerID: Sleeper player ID
    /// - Returns: Stats dictionary or nil
    func getLocalPlayerStats(for playerID: String) -> [String: Double]?
}

// MARK: - LocalStatsProvider Implementations

/// Wrapper for ChoppedTeamRosterViewModel to provide LocalStatsProvider interface
struct ChoppedStatsProvider: LocalStatsProvider {
    let viewModel: ChoppedTeamRosterViewModel

    func getLocalPlayerStats(for playerID: String) -> [String: Double]? {
        return viewModel.getPlayerStats(for: playerID)
    }
}

// MARK: - Direct Protocol Conformance

extension ChoppedTeamRosterViewModel: LocalStatsProvider {
    func getLocalPlayerStats(for playerID: String) -> [String: Double]? {
        return getPlayerStats(for: playerID)
    }
}

extension AllLivePlayersViewModel: LocalStatsProvider {
    func getLocalPlayerStats(for playerID: String) -> [String: Double]? {
        return playerStats[playerID]
    }
}