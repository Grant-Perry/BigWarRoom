//
//  CentralizedAppLoader.swift
//  BigWarRoom
//
//  🔥 UPDATED: Progressive loading - show data as it becomes available
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class CentralizedAppLoader {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: CentralizedAppLoader?
    
    static var shared: CentralizedAppLoader {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = CentralizedAppLoader()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: CentralizedAppLoader) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var isLoading = true
    var loadingProgress: Double = 0.0
    var currentLoadingMessage = "Initializing BigWarRoom..."
    var hasCompletedInitialization = false
    var canShowPartialData = false  // 🔥 NEW: Allow showing partial data
    
    // MARK: - Dependencies
    private let matchupsHubViewModel: MatchupsHubViewModel
    private let allLivePlayersViewModel: AllLivePlayersViewModel
    
    private var loadingMessages = [
        "Loading your fantasy data...",
        "Fetching player statistics...", 
        "Processing matchups...",
        "Finalizing setup..."
    ]
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Default initializer for bridge pattern
    convenience init() {
        self.init(
            matchupsHubViewModel: MatchupsHubViewModel.shared,
            allLivePlayersViewModel: AllLivePlayersViewModel.shared
        )
    }
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    init(matchupsHubViewModel: MatchupsHubViewModel, allLivePlayersViewModel: AllLivePlayersViewModel) {
        self.matchupsHubViewModel = matchupsHubViewModel
        self.allLivePlayersViewModel = allLivePlayersViewModel
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
        
//        print("✅ Progressive app initialization completed")
    }
    
    /// Load shared stats first to eliminate redundant API calls
    private func loadSharedStats() async {
        do {
            let _ = try await SharedStatsService.shared.loadCurrentWeekStats()
//            print("✅ CentralizedAppLoader: Shared stats loaded")
        } catch {
//            print("❌ CentralizedAppLoader: Failed to load shared stats: \(error)")
            // Continue anyway - app can still function
        }
    }
    
    /// Load matchups in background without blocking UI
    private func loadMatchupsInBackground() async {
//        print("🚀 CentralizedAppLoader: Loading matchups in background...")
        await matchupsHubViewModel.loadAllMatchups()
//        print("✅ CentralizedAppLoader: Background matchup loading completed")
    }
    
    /// Load player data in background
    private func loadPlayerDataInBackground() async {
//        print("🚀 CentralizedAppLoader: Loading player data in background...")
        
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
        
//        print("✅ CentralizedAppLoader: Player data processing completed")
    }
    
    /// 🔥 DEPRECATED: Old "load everything first" method
    @available(*, deprecated, message: "Use initializeAppProgressively() instead")
    func initializeApp() async {
        await initializeAppProgressively()
    }
    
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