//
//  AppInitializationManager.swift
//  BigWarRoom
//
//  🔥 SOLUTION: Centralized app initialization that loads ALL data before showing tabs
//  This eliminates race conditions between different views trying to load independently
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppInitializationManager: ObservableObject {
    static let shared = AppInitializationManager()
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var isLoading = true
    @Published var currentLoadingStage: LoadingStage = .starting
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let matchupsHubViewModel = MatchupsHubViewModel.shared
    private let allLivePlayersViewModel = AllLivePlayersViewModel.shared
    
    private init() {}
    
    // MARK: - Loading Stages
    enum LoadingStage {
        case starting
        case loadingCredentials
        case loadingLeagues
        case loadingMatchups
        case loadingPlayerStats
        case processingPlayers
        case finalizing
        case completed
        case error(String)
        
        var displayText: String {
            switch self {
            case .starting:
                return "Initializing BigWarRoom..."
            case .loadingCredentials:
                return "Checking credentials..."
            case .loadingLeagues:
                return "Finding your leagues..."
            case .loadingMatchups:
                return "Loading matchup data..."
            case .loadingPlayerStats:
                return "Loading player statistics..."
            case .processingPlayers:
                return "Processing player data..."
            case .finalizing:
                return "Finalizing setup..."
            case .completed:
                return "Ready to go!"
            case .error(let message):
                return "Error: \(message)"
            }
        }
        
        var progress: Double {
            switch self {
            case .starting: return 0.0
            case .loadingCredentials: return 0.15
            case .loadingLeagues: return 0.25
            case .loadingMatchups: return 0.50
            case .loadingPlayerStats: return 0.75
            case .processingPlayers: return 0.85
            case .finalizing: return 0.95
            case .completed: return 1.0
            case .error: return 0.0
            }
        }
    }
    
    // MARK: - Main Initialization
    func initializeApp() async {
        guard !isInitialized else { 
            print("🚀 APP INIT: Already initialized, skipping")
            return 
        }
        
        guard !isLoading else { 
            print("🚀 APP INIT: Already loading, skipping")
            return 
        }
        
        print("🚀 APP INIT: Starting centralized app initialization")
        isLoading = true
        errorMessage = nil
        
        do {
            try await updateLoadingStage(.loadingCredentials)
            try await checkCredentials()
            
            try await updateLoadingStage(.loadingLeagues)
            try await loadLeagues()
            
            try await updateLoadingStage(.loadingMatchups)
            try await loadMatchups()
            
            try await updateLoadingStage(.loadingPlayerStats)
            try await loadPlayerStats()
            
            try await updateLoadingStage(.processingPlayers)
            try await processPlayers()
            
            try await updateLoadingStage(.finalizing)
            try await finalizingSetup()
            
            try await updateLoadingStage(.completed)
            
            isInitialized = true
            isLoading = false
            
            print("✅ APP INIT: Centralized initialization completed successfully")
            
        } catch {
            print("❌ APP INIT: Failed - \(error)")
            currentLoadingStage = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Loading Stages Implementation
    
    private func updateLoadingStage(_ stage: LoadingStage) async throws {
        currentLoadingStage = stage
        loadingProgress = stage.progress
        print("🚀 APP INIT: \(stage.displayText) (\(Int(stage.progress * 100))%)")
        
        // Small delay to show progress visually
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    private func checkCredentials() async throws {
        // Check if we have valid credentials
        let sleeperManager = SleeperCredentialsManager.shared
        let espnManager = ESPNCredentialsManager.shared
        
        print("🚀 APP INIT: Sleeper valid: \(sleeperManager.hasValidCredentials)")
        print("🚀 APP INIT: ESPN valid: \(espnManager.hasValidCredentials)")
        
        if !sleeperManager.hasValidCredentials && !espnManager.hasValidCredentials {
            throw AppInitError.noCredentials
        }
    }
    
    private func loadLeagues() async throws {
        // Use Mission Control's league loading
        print("🚀 APP INIT: Loading leagues through Mission Control...")
        
        // This loads all leagues and handles all the heavy lifting
        await matchupsHubViewModel.loadAllMatchups()
        
        // Wait a bit for all async operations to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Verify we got some leagues
        let matchupCount = matchupsHubViewModel.myMatchups.count
        print("🚀 APP INIT: After loading, got \(matchupCount) matchups")
        
        if matchupCount == 0 {
            print("🚀 APP INIT: Warning - No matchups loaded, but continuing...")
            // Don't throw error - could be offseason or no active leagues
        }
        
        print("🚀 APP INIT: League loading completed with \(matchupCount) matchups")
    }
    
    private func loadMatchups() async throws {
        // Matchups are already loaded in the previous step
        // This stage is for any additional matchup processing if needed
        print("🚀 APP INIT: Matchups already loaded - \(matchupsHubViewModel.myMatchups.count) total")
    }
    
    private func loadPlayerStats() async throws {
        // Load player stats for Live Players
        print("🚀 APP INIT: Loading player statistics...")
        
        if !allLivePlayersViewModel.statsLoaded {
            await allLivePlayersViewModel.loadPlayerStats()
        }
        
        print("🚀 APP INIT: Player stats loaded: \(allLivePlayersViewModel.statsLoaded)")
    }
    
    private func processPlayers() async throws {
        // Process players for Live Players view
        print("🚀 APP INIT: Processing player data...")
        
        if !matchupsHubViewModel.myMatchups.isEmpty {
            // Extract and build player data
            let playerEntries = allLivePlayersViewModel.extractAllPlayers()
            await allLivePlayersViewModel.buildPlayerData(from: playerEntries)
            
            print("🚀 APP INIT: Processed \(allLivePlayersViewModel.allPlayers.count) players")
        } else {
            print("🚀 APP INIT: No matchups to process players from")
        }
    }
    
    private func finalizingSetup() async throws {
        // Any final setup tasks
        print("🚀 APP INIT: Running final setup tasks...")
        
        // Update All Live Players state
        if allLivePlayersViewModel.allPlayers.isEmpty {
            print("🚀 APP INIT: No players processed - setting empty state")
            allLivePlayersViewModel.dataState = .empty
        } else {
            print("🚀 APP INIT: \(allLivePlayersViewModel.allPlayers.count) players processed - setting loaded state")
            allLivePlayersViewModel.dataState = .loaded
            
            // 🔥 IMPORTANT: Apply filters AFTER confirming we have data
            print("🚀 APP INIT: Applying initial filters...")
            allLivePlayersViewModel.applyPositionFilter()
            print("🚀 APP INIT: Filters applied - filteredPlayers count: \(allLivePlayersViewModel.filteredPlayers.count)")
        }
        
        // Mark last load time
        allLivePlayersViewModel.lastUpdateTime = Date()
    }
    
    // MARK: - Retry Logic
    func retry() async {
        print("🔄 APP INIT: Retrying initialization...")
        isInitialized = false
        currentLoadingStage = .starting
        loadingProgress = 0.0
        errorMessage = nil
        
        await initializeApp()
    }
    
    // MARK: - Reset for Testing
    func reset() {
        isInitialized = false
        isLoading = false
        currentLoadingStage = .starting
        loadingProgress = 0.0
        errorMessage = nil
    }
}

// MARK: - Error Types
enum AppInitError: LocalizedError {
    case noCredentials
    case noLeaguesFound
    case networkError
    case dataProcessingError
    
    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No valid ESPN or Sleeper credentials found. Please set up your accounts in Settings."
        case .noLeaguesFound:
            return "No active leagues found. Please check your league connections."
        case .networkError:
            return "Network error occurred. Please check your connection and try again."
        case .dataProcessingError:
            return "Error processing league data. Please try again."
        }
    }
}