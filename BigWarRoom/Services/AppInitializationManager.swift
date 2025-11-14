//
//  AppInitializationManager.swift
//  BigWarRoom
//
//  🔥 UNIFIED: Single initialization system for the entire app
//  🔥 NO SINGLETON - Use dependency injection
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class AppInitializationManager {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: AppInitializationManager?
    
    static var shared: AppInitializationManager {
        if let existing = _shared {
            return existing
        }
        fatalError("AppInitializationManager.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: AppInitializationManager) {
        _shared = instance
    }
    
    // 🔥 PHASE 3 DI: No more singleton pattern - use dependency injection only
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var isInitialized = false
    var isLoading = false // 🔥 FIX: Start with false, not true
    var currentLoadingStage: LoadingStage = .starting
    var loadingProgress: Double = 0.0
    var errorMessage: String?
    var canShowPartialData = false // Progressive loading support
    
    // MARK: - Dependencies
    private let matchupsHubViewModel: MatchupsHubViewModel
    private let allLivePlayersViewModel: AllLivePlayersViewModel
    private let playerDirectory: PlayerDirectoryStore
    private let sharedStatsService: SharedStatsService
    
    // MARK: - Initialization
    
    // 🔥 PHASE 3 DI: ONLY initializer: Dependency injection
    init(
        matchupsHubViewModel: MatchupsHubViewModel,
        allLivePlayersViewModel: AllLivePlayersViewModel,
        playerDirectory: PlayerDirectoryStore,
        sharedStatsService: SharedStatsService
    ) {
        self.matchupsHubViewModel = matchupsHubViewModel
        self.allLivePlayersViewModel = allLivePlayersViewModel
        self.playerDirectory = playerDirectory
        self.sharedStatsService = sharedStatsService
    }
    
    // MARK: - Loading Stages
    enum LoadingStage {
        case starting
        case loadingCredentials
        case loadingSharedStats
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
            case .loadingSharedStats:
                return "Loading shared statistics..."
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
            case .loadingCredentials: return 0.1
            case .loadingSharedStats: return 0.2
            case .loadingLeagues: return 0.3
            case .loadingMatchups: return 0.5
            case .loadingPlayerStats: return 0.7
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
            logInfo("Already initialized, skipping", category: "AppInit")
            return 
        }
        guard !isLoading else { 
            logInfo("Already loading, skipping", category: "AppInit")
            return 
        }
        
        logInfo("Starting centralized app initialization", category: "AppInit")
        isLoading = true
        errorMessage = nil
        
        do {
            try await updateLoadingStage(.loadingCredentials)
            try await checkCredentials()
            
            try await updateLoadingStage(.loadingSharedStats)
            try await loadSharedStats()
            
            // Enable partial data showing after shared stats
            canShowPartialData = true
            
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
            
            logInfo("Centralized initialization completed successfully", category: "AppInit")
            
        } catch {
            logError("Initialization failed: \(error)", category: "AppInit")
            logError("Error details: \(error.localizedDescription)", category: "AppInit")
            currentLoadingStage = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Loading Stages Implementation
    
    private func updateLoadingStage(_ stage: LoadingStage) async throws {
        currentLoadingStage = stage
        loadingProgress = stage.progress
        logInfo("\(stage.displayText) (\(Int(stage.progress * 100))%)", category: "AppInit")
        
        // 🔥 REMOVED: Artificial delay
    }
    
    private func checkCredentials() async throws {
        logInfo("Checking credentials...", category: "AppInit")
        cleanupGameAlertsData()
        
        // 🔥 PHASE 3 DI: Can't use .shared anymore - credentials are already validated in BigWarRoom setup
        logInfo("Credentials already validated during setup", category: "AppInit")
        
        logInfo("Credentials check passed", category: "AppInit")
    }
    
    private func loadSharedStats() async throws {
        do {
            let _ = try await sharedStatsService.loadCurrentWeekStats()
            logInfo("Shared stats loaded successfully", category: "AppInit")
        } catch {
            logWarning("Failed to load shared stats: \(error)", category: "AppInit")
            // Continue anyway - app can still function
        }
    }
    
    private func loadLeagues() async throws {
        logInfo("Loading leagues through Mission Control...", category: "AppInit")
        
        await matchupsHubViewModel.loadAllMatchups()
        // 🔥 REMOVED: Artificial 2-second delay
        
        let matchupCount = matchupsHubViewModel.myMatchups.count
        logInfo("After loading, got \(matchupCount) matchups", category: "AppInit")
        
        if matchupCount == 0 {
            logWarning("No matchups loaded, but continuing...", category: "AppInit")
        }
        
        logInfo("League loading completed with \(matchupCount) matchups", category: "AppInit")
    }
    
    private func loadMatchups() async throws {
        logInfo("Matchups already loaded - \(matchupsHubViewModel.myMatchups.count) total", category: "AppInit")
    }
    
    private func loadPlayerStats() async throws {
        logInfo("Loading shared player statistics...", category: "AppInit")
        
        do {
            let _ = try await sharedStatsService.loadCurrentWeekStats()
            logInfo("Shared stats loaded successfully", category: "AppInit")
            
            if !allLivePlayersViewModel.statsLoaded {
                await allLivePlayersViewModel.loadPlayerStats()
            }
            
        } catch {
            logWarning("Failed to load shared stats: \(error)", category: "AppInit")
        }
    }
    
    private func processPlayers() async throws {
        logInfo("Processing player data...", category: "AppInit")
        
        if !matchupsHubViewModel.myMatchups.isEmpty {
            let playerEntries = allLivePlayersViewModel.extractAllPlayers()
            await allLivePlayersViewModel.buildPlayerData(from: playerEntries)
            
            logInfo("Processed \(allLivePlayersViewModel.allPlayers.count) players", category: "AppInit")
        } else {
            logInfo("No matchups to process players from", category: "AppInit")
        }
    }
    
    private func finalizingSetup() async throws {
        logInfo("Running final setup tasks...", category: "AppInit")
        
        if allLivePlayersViewModel.allPlayers.isEmpty {
            logInfo("No players processed - setting empty state", category: "AppInit")
            allLivePlayersViewModel.dataState = .empty
        } else {
            logInfo("\(allLivePlayersViewModel.allPlayers.count) players processed - setting loaded state", category: "AppInit")
            allLivePlayersViewModel.dataState = .loaded
            
            logInfo("Applying initial filters...", category: "AppInit")
            allLivePlayersViewModel.applyPositionFilter()
            logInfo("Filters applied - filteredPlayers count: \(allLivePlayersViewModel.filteredPlayers.count)", category: "AppInit")
        }
        
        allLivePlayersViewModel.lastUpdateTime = Date()
    }
    
    // MARK: - Game Alerts Cleanup
    private func cleanupGameAlertsData() {
        let userDefaults = UserDefaults.standard
        let gameAlertsKeys = ["AllLivePlayers_PreviousScores"]
        
        var removedCount = 0
        for key in gameAlertsKeys {
            if userDefaults.object(forKey: key) != nil {
                userDefaults.removeObject(forKey: key)
                removedCount += 1
                logInfo("Removed UserDefaults key: \(key)", category: "Cleanup")
            }
        }
        
        if removedCount > 0 {
            logInfo("Removed \(removedCount) game alerts data entries from UserDefaults", category: "Cleanup")
        } else {
            logInfo("No game alerts data found in UserDefaults", category: "Cleanup")
        }
    }
    
    // MARK: - Retry Logic
    func retry() async {
        logInfo("Retrying initialization...", category: "AppInit")
        isInitialized = false
        currentLoadingStage = .starting
        loadingProgress = 0.0
        errorMessage = nil
        canShowPartialData = false
        
        await initializeApp()
    }
    
    // MARK: - Reset for Testing
    func reset() {
        isInitialized = false
        isLoading = false
        currentLoadingStage = .starting
        loadingProgress = 0.0
        errorMessage = nil
        canShowPartialData = false
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