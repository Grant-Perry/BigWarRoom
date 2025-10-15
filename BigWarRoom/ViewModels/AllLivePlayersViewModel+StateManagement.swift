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
        print("🔄 HARD RESET: Resetting all filtering state to defaults")
        
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
        print("🔄 FILTER PRESERVATION: Refreshing while preserving user filter settings")
        
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
        print("🔧 RECOVERY: Attempting to recover from stuck filter state")
        
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
    
    // MARK: - Debug Utilities
    
    func debugESPNIDCoverage() {
        print("🔍 ESPN ID COVERAGE ANALYSIS")
        print(String(repeating: "=", count: 50))
        
        var totalPlayers = 0
        var playersWithESPNID = 0
        var coverageByPosition: [String: (Int, Int)] = [:]
        
        for entry in allPlayers {
            totalPlayers += 1
            let position = entry.position
            
            let current = coverageByPosition[position] ?? (0, 0)
            coverageByPosition[position] = (current.0 + 1, current.1)
            
            if entry.player.espnID != nil {
                playersWithESPNID += 1
                coverageByPosition[position] = (current.0 + 1, current.1 + 1)
            }
        }
        
        let coveragePercentage = totalPlayers > 0 ? (Double(playersWithESPNID) / Double(totalPlayers) * 100) : 0
        
        print("📊 OVERALL COVERAGE:")
        print("   Total Players: \(totalPlayers)")
        print("   With ESPN ID: \(playersWithESPNID)")
        print("   Coverage: \(String(format: "%.1f", coveragePercentage))%")
        print()
        
        print("📍 BY POSITION:")
        for (position, counts) in coverageByPosition.sorted(by: { $0.key < $1.key }) {
            let positionCoverage = counts.0 > 0 ? (Double(counts.1) / Double(counts.0) * 100) : 0
            print("   \(position): \(counts.1)/\(counts.0) (\(String(format: "%.1f", positionCoverage))%)")
        }
        
        print(String(repeating: "=", count: 50))
    }
    
    func debugCurrentState() {
        print("🔍 CURRENT STATE DEBUG")
        print(String(repeating: "=", count: 50))
        
        let metrics = getPerformanceMetrics()
        for (key, value) in metrics {
            print("   \(key): \(value)")
        }
        
        let issues = validateDataConsistency()
        if !issues.isEmpty {
            print("\n❌ DATA CONSISTENCY ISSUES:")
            for issue in issues {
                print("   - \(issue)")
            }
        } else {
            print("\n✅ No data consistency issues detected")
        }
        
        print(String(repeating: "=", count: 50))
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