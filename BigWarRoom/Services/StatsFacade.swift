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
    
    /// Get player stats with automatic fallback through all available sources
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider (ChoppedTeamRosterViewModel, etc.)
    /// - Returns: Player stats dictionary or nil if no stats found
    static func getPlayerStats(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil
    ) -> [String: Double]? {
        
        // STEP 1: Try local stats provider first (highest priority)
        if let localStats = localStatsProvider?.getLocalPlayerStats(for: playerID) {
            print("📊 StatsFacade: Found local stats for \(playerID) (\(localStats.count) stats)")
            return localStats
        }
        
        // STEP 2: Try PlayerStatsCache (cached API data)
        if let cachedStats = PlayerStatsCache.shared.getPlayerStats(playerID: playerID, week: week) {
            print("📊 StatsFacade: Found cached stats for \(playerID) (\(cachedStats.count) stats)")
            return cachedStats
        }
        
        // STEP 3: Try AllLivePlayersViewModel (global live data)
        if let globalStats = AllLivePlayersViewModel.shared.playerStats[playerID] {
            print("📊 StatsFacade: Found global stats for \(playerID) (\(globalStats.count) stats)")
            return globalStats
        }
        
        print("📊 StatsFacade: NO STATS FOUND for playerID: \(playerID), week: \(week)")
        return nil
    }
    
    /// Convenience method that gets current selected week automatically
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - localStatsProvider: Optional local stats provider
    /// - Returns: Player stats dictionary or nil
    static func getPlayerStats(
        playerID: String,
        localStatsProvider: LocalStatsProvider? = nil
    ) -> [String: Double]? {
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        return getPlayerStats(playerID: playerID, week: currentWeek, localStatsProvider: localStatsProvider)
    }
    
    /// Check if any stats are available for a player
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider
    /// - Returns: True if stats are available from any source
    static func hasStats(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil
    ) -> Bool {
        return getPlayerStats(playerID: playerID, week: week, localStatsProvider: localStatsProvider) != nil
    }
    
    /// Get stats source description for debugging
    /// - Parameters:
    ///   - playerID: Sleeper player ID  
    ///   - week: NFL week number
    ///   - localStatsProvider: Optional local stats provider
    /// - Returns: Description of which source provided the stats
    static func getStatsSource(
        playerID: String,
        week: Int,
        localStatsProvider: LocalStatsProvider? = nil
    ) -> String {
        
        if localStatsProvider?.getLocalPlayerStats(for: playerID) != nil {
            return "Local (\(type(of: localStatsProvider!)))"
        }
        
        if PlayerStatsCache.shared.getPlayerStats(playerID: playerID, week: week) != nil {
            return "Cache"
        }
        
        if AllLivePlayersViewModel.shared.playerStats[playerID] != nil {
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

/// Wrapper for AllLivePlayersViewModel to provide LocalStatsProvider interface  
struct GlobalStatsProvider: LocalStatsProvider {
    let viewModel: AllLivePlayersViewModel
    
    func getLocalPlayerStats(for playerID: String) -> [String: Double]? {
        return viewModel.playerStats[playerID]
    }
}

// MARK: - Convenience Extensions

extension ChoppedTeamRosterViewModel {
    /// Get a LocalStatsProvider wrapper for this view model
    var statsProvider: LocalStatsProvider {
        return ChoppedStatsProvider(viewModel: self)
    }
}

extension AllLivePlayersViewModel {
    /// Get a LocalStatsProvider wrapper for this view model
    var statsProvider: LocalStatsProvider {
        return GlobalStatsProvider(viewModel: self)
    }
}