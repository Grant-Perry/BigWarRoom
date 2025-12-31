//
//  CentralizedAppLoader.swift
//  BigWarRoom
//
//  🔥 UPDATED: Progressive loading - show data as it becomes available
//  🔥 PHASE 3 DI: Removed bridge pattern, pure dependency injection
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class CentralizedAppLoader {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: CentralizedAppLoader?
    
    static var shared: CentralizedAppLoader {
        if let existing = _shared {
            return existing
        }
        fatalError("CentralizedAppLoader.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: CentralizedAppLoader) {
        _shared = instance
    }

    // MARK: - Observable Properties (No @Published needed with @Observable)
    var isLoading = true
    var loadingProgress: Double = 0.0
    var currentLoadingMessage = "Initializing BigWarRoom..."
    var hasCompletedInitialization = false
    var canShowPartialData = false  // 🔥 NEW: Allow showing partial data
    
    // MARK: - Dependencies (injected)
    private let matchupsHubViewModel: MatchupsHubViewModel
    private let allLivePlayersViewModel: AllLivePlayersViewModel
    private let sharedStatsService: SharedStatsService
    
    private var loadingMessages = [
        "Loading your fantasy data...",
        "Fetching player statistics...", 
        "Processing matchups...",
        "Finalizing setup..."
    ]
    
    // MARK: - Initialization
    
    // 🔥 PHASE 3 DI: Pure dependency injection - no more bridge pattern
    init(
        matchupsHubViewModel: MatchupsHubViewModel,
        allLivePlayersViewModel: AllLivePlayersViewModel,
        sharedStatsService: SharedStatsService
    ) {
        self.matchupsHubViewModel = matchupsHubViewModel
        self.allLivePlayersViewModel = allLivePlayersViewModel
        self.sharedStatsService = sharedStatsService
    }
    
    /// 🔥 NEW: Progressive initialization - show data as it becomes available
    func initializeAppProgressively() async {
        guard !hasCompletedInitialization else { return }
        
        isLoading = true
        loadingProgress = 0.0
        
        // Step 1: Load core stats (40%) - this eliminates the redundant API calls
        await updateProgress(0.2, message: loadingMessages[0])
        await loadSharedStats()
        
        // Step 2: Allow showing partial data while the rest loads
        await updateProgress(0.4, message: loadingMessages[1])
        canShowPartialData = true
        
        // Step 3: Load matchups progressively (don't block UI)
        Task.detached { @MainActor in
            await self.loadMatchupsInBackground()
        }
        
        // Step 4: Load player data (80%)
        await updateProgress(0.6, message: loadingMessages[2])
        await loadPlayerDataInBackground()
        
        // Step 5: Finalization (100%)
        await updateProgress(1.0, message: loadingMessages[3])
        try? await Task.sleep(nanoseconds: 300_000_000) // Brief pause
        
        // Mark as complete
        isLoading = false
        hasCompletedInitialization = true
    }
    
    /// Load shared stats first to eliminate redundant API calls
    private func loadSharedStats() async {
        do {
            let _ = try await sharedStatsService.loadCurrentWeekStats()
        } catch {
            // Continue anyway - app can still function
        }
    }
    
    /// Load matchups in background without blocking UI
    private func loadMatchupsInBackground() async {
        await matchupsHubViewModel.loadAllMatchups()
    }
    
    /// Load player data in background
    private func loadPlayerDataInBackground() async {

        if !allLivePlayersViewModel.statsLoaded {
            await allLivePlayersViewModel.loadPlayerStats()
        }
        
        // Process players if we have matchups
        if !matchupsHubViewModel.myMatchups.isEmpty {
            let playerEntries = allLivePlayersViewModel.extractAllPlayers()
            await allLivePlayersViewModel.buildPlayerData(from: playerEntries)
            
            // Update state
            if allLivePlayersViewModel.allPlayers.isEmpty {
                allLivePlayersViewModel.dataState = .empty
            } else {
                allLivePlayersViewModel.dataState = .loaded
                allLivePlayersViewModel.applyPositionFilter()
            }
            
            allLivePlayersViewModel.lastUpdateTime = Date()
        }
    }
    
//    /// 🔥 DEPRECATED: Old "load everything first" method
//    @available(*, deprecated, message: "Use initializeAppProgressively() instead")
//    func initializeAppxx() async {
//        await initializeAppProgressively()
//    }
    
    private func updateProgress(_ progress: Double, message: String) async {
        loadingProgress = progress
        currentLoadingMessage = message
        
        // Give UI time to update
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    /// Reset initialization state (for debugging/testing)
    func resetInitialization() {
        hasCompletedInitialization = false
        canShowPartialData = false
        isLoading = true
        loadingProgress = 0.0
    }
}
