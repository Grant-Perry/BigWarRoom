//
//  CentralizedAppLoader.swift
//  BigWarRoom
//
//  Centralized app initialization - loads ALL core data before showing main app
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
    
    private var loadingMessages = [
        "Connecting to leagues...",
        "Loading matchups...", 
        "Gathering player data...",
        "Loading player statistics...",
        "Finalizing setup..."
    ]
    
    private init() {}
    
    /// Main initialization method - loads ALL core data upfront
    func initializeApp() async {
        guard !hasCompletedInitialization else { return }
        
        isLoading = true
        loadingProgress = 0.0
        
        do {
            // Step 1: Load matchups (20%)
            await updateProgress(0.2, message: loadingMessages[0])
            await MatchupsHubViewModel.shared.loadAllMatchups()
            
            // Step 2: Load all live players data (40%)
            await updateProgress(0.4, message: loadingMessages[1])
            await AllLivePlayersViewModel.shared.forceLoadAllPlayers()
            
            // Step 3: Load player stats (60%)
            await updateProgress(0.6, message: loadingMessages[2])
            await AllLivePlayersViewModel.shared.forceLoadStats()
            
            // Step 4: Load any other core data (80%)
            await updateProgress(0.8, message: loadingMessages[3])
            // Add any other core data loading here
            
            // Step 5: Finalization (100%)
            await updateProgress(1.0, message: loadingMessages[4])
            try await Task.sleep(nanoseconds: 500_000_000) // Brief pause for UX
            
            // Mark as complete
            isLoading = false
            hasCompletedInitialization = true
            
        } catch {
            print("❌ App initialization failed: \(error)")
            // For now, still mark as complete to let user access app
            isLoading = false
            hasCompletedInitialization = true
        }
    }
    
    private func updateProgress(_ progress: Double, message: String) async {
        loadingProgress = progress
        currentLoadingMessage = message
        
        // Give UI time to update
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        } catch {
            // Handle sleep error silently
        }
    }
    
    /// Reset initialization state (for debugging/testing)
    func resetInitialization() {
        hasCompletedInitialization = false
        isLoading = true
        loadingProgress = 0.0
    }
}