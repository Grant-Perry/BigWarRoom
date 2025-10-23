//
//  AllLivePlayersViewModel+StateManagement.swift
//  BigWarRoom
//
//  🔥 FOCUSED: State management, recovery methods, and debug utilities
//

import Foundation
import Combine

extension AllLivePlayersViewModel {
    // MARK: - State Recovery Methods
    
    func hardResetFilteringState() async {
        // Reset all filtering state
        showActiveOnly = false
        selectedPosition = .all
        sortHighToLow = true
        sortingMethod = .score

        // Clear all player data
        allPlayers = []
        filteredPlayers = []
        
        // Clear caches
        clearLiveGameCache()

        // Force reload from scratch
        await matchupsHubViewModel.loadAllMatchups()
        await performDataLoad()
    }

    func refreshWithFilterPreservation() async {
        // Store current filter settings
        let currentActiveOnly = showActiveOnly
        let currentPosition = selectedPosition
        let currentSortHighToLow = sortHighToLow
        let currentSortingMethod = sortingMethod
        
        // Perform hard reset
        await hardResetFilteringState()
        
        // Restore user settings
        showActiveOnly = currentActiveOnly
        selectedPosition = currentPosition
        sortHighToLow = currentSortHighToLow
        sortingMethod = currentSortingMethod
        
        // Apply the restored filters
        applyPositionFilter()
    }

    func recoverFromStuckState() {
        // Reset filters to safe defaults
        showActiveOnly = false
        selectedPosition = .all

        // Force re-apply filtering
        applyPositionFilter()

        // Trigger UI update
        objectWillChange.send()
    }
    
    // MARK: - State Validation
    
    var hasNoPlayersWithRecovery: Bool {
        let hasNoPlayers = filteredPlayers.isEmpty && !allPlayers.isEmpty && isDataLoaded
        return hasNoPlayers
    }
    
    func validateDataConsistency() -> [String] {
        var issues: [String] = []
        
        // Check for basic data consistency
        if !allPlayers.isEmpty && filteredPlayers.isEmpty && selectedPosition == .all && !showActiveOnly {
            issues.append("All players loaded but filtered players empty with no filters applied")
        }
        
        if isLoading && !allPlayers.isEmpty {
            issues.append("Loading state active but players already loaded")
        }
        
        if case .loaded = dataState, allPlayers.isEmpty {
            issues.append("Data state is 'loaded' but no players exist")
        }
        
        if case .empty = dataState, !allPlayers.isEmpty {
            issues.append("Data state is 'empty' but players exist")
        }
        
        return issues
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "totalPlayers": allPlayers.count,
            "filteredPlayers": filteredPlayers.count,
            "isLoading": isLoading,
            "dataState": String(describing: dataState),
            "selectedPosition": selectedPosition.rawValue,
            "showActiveOnly": showActiveOnly,
            "sortingMethod": sortingMethod.rawValue,
            "statsLoaded": statsLoaded,
            "connectedLeagues": connectedLeaguesCount,
            "activeLiveGames": activeLiveGamesCount,
            "lastUpdateTime": lastUpdateTime
        ]
    }
    
    // MARK: - Batch Update Control
    
    internal func performBatchUpdate(_ updates: () -> Void) async {
        guard !isBatchingUpdates else { return }

        isBatchingUpdates = true

        // Perform all updates in one batch
        updates()

        // Single UI update notification
        objectWillChange.send()

        isBatchingUpdates = false
    }
}