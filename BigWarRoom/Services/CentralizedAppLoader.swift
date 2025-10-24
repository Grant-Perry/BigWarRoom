//
//  CentralizedAppLoader.swift
//  BigWarRoom
//
//  🔥 UPDATED: Progressive loading - show data as it becomes available
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CentralizedAppLoader: ObservableObject {
    static let shared = CentralizedAppLoader()
    
    @Published var isLoading = true
    @Published var loadingProgress: Double = 0.0
    @Published var currentLoadingMessage = "Initializing BigWarRoom..."
    @Published var hasCompletedInitialization = false
    @Published var canShowPartialData = false  // 🔥 NEW: Allow showing partial data
    
    private var loadingMessages = [
        "Loading your fantasy data...",
        "Fetching player statistics...", 
        "Processing matchups...",
        "Finalizing setup..."
    ]
    
    private init() {}
    
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
        await MatchupsHubViewModel.shared.loadAllMatchups()
//        print("✅ CentralizedAppLoader: Background matchup loading completed")
    }
    
    /// Load player data in background
    private func loadPlayerDataInBackground() async {
//        print("🚀 CentralizedAppLoader: Loading player data in background...")
        
        if !AllLivePlayersViewModel.shared.statsLoaded {
            await AllLivePlayersViewModel.shared.loadPlayerStats()
        }
        
        // Process players if we have matchups
        if !MatchupsHubViewModel.shared.myMatchups.isEmpty {
            let playerEntries = AllLivePlayersViewModel.shared.extractAllPlayers()
            await AllLivePlayersViewModel.shared.buildPlayerData(from: playerEntries)
            
            // Update state
            if AllLivePlayersViewModel.shared.allPlayers.isEmpty {
                AllLivePlayersViewModel.shared.dataState = .empty
            } else {
                AllLivePlayersViewModel.shared.dataState = .loaded
                AllLivePlayersViewModel.shared.applyPositionFilter()
            }
            
            AllLivePlayersViewModel.shared.lastUpdateTime = Date()
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