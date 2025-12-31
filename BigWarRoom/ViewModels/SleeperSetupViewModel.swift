//
//  SleeperSetupViewModel.swift
//  BigWarRoom
//
//  ViewModel for Sleeper setup and credential management
//

import Foundation
import Observation

@Observable
@MainActor
final class SleeperSetupViewModel {
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var username: String = ""
    var userID: String = ""
    var selectedSeason: String = "2025"
    var isValidating: Bool = false
    var validationMessage: String = ""
    var showingValidation: Bool = false
    var showingInstructions: Bool = false
    var showingClearConfirmation: Bool = false
    var showingClearResult: Bool = false
    var clearResultMessage: String = ""
    var pendingClearAction: (() -> Void)?
    
    // MARK: - Dependencies
    private let credentialsManager = SleeperCredentialsManager.shared
    
    // MARK: - Computed Properties
    var hasValidCredentials: Bool {
        credentialsManager.hasValidCredentials
    }
    
    var cachedLeagues: [String] {
        credentialsManager.cachedLeagues
    }
    
    var cachedLeagueCount: Int {
        credentialsManager.cachedLeagues.count
    }
    
    var canSaveCredentials: Bool {
        // 🔥 FIX: Only require username, ignore user ID
        !username.isEmpty
    }
    
    var isSetupComplete: Bool {
        hasValidCredentials
    }

    // MARK: - Initialization
    init() {
        // Load saved credentials, don't default to Gp's hardcoded values
        loadSavedCredentials()
    }
    
    // MARK: - Actions
    
    func fillDefaultCredentials() {
        username = AppConstants.SleeperUser
        // 🔥 FIX: Don't auto-fill user ID - let the system resolve it
        userID = ""
        selectedSeason = "2025"
        
        // 🔥 FIX: Auto-save when using default credentials
        saveCredentials()
    }
    
    func saveCredentials() {
        guard canSaveCredentials else { return }
        
        
        // NEW: Use resolution method to ensure we get numeric userID
        Task {
            let success = await credentialsManager.saveCredentialsWithResolution(
                usernameOrID: username.trimmingCharacters(in: .whitespacesAndNewlines),
                season: selectedSeason
            )
            
            await MainActor.run {
                if success {
                    clearResultMessage = "✅ Sleeper credentials saved and resolved successfully!"
                } else {
                    clearResultMessage = "❌ Failed to save Sleeper credentials. Please check your username/ID."
                }
                showingClearResult = true
            }
        }
    }
    
    func validateCredentials() {
        isValidating = true
        
        Task {
            let isValid = await credentialsManager.validateCredentials()
            
            await MainActor.run {
                isValidating = false
                validationMessage = isValid ? 
                    "✅ Credentials are valid and working!" : 
                    "❌ Failed to validate credentials. Please check your username or user ID."
                showingValidation = true
            }
        }
    }
    
    func refreshLeagueCache() {
        Task {
            await credentialsManager.refreshLeagueCache()
        }
    }
    
    // MARK: - Clear Actions with Confirmation
    
    func requestClearCredentials() {
        pendingClearAction = {
            self.performClearCredentials()
        }
        showingClearConfirmation = true
    }
    
    func requestClearCredentialsOnly() {
        pendingClearAction = {
            self.performClearCredentialsOnly()
        }
        showingClearConfirmation = true
    }
    
    func requestClearCacheOnly() {
        pendingClearAction = {
            self.performClearCacheOnly()
        }
        showingClearConfirmation = true
    }
    
    private func performClearCredentials() {
        credentialsManager.clearCredentials()
        username = ""
        userID = ""
        selectedSeason = "2025"
        
        clearResultMessage = "✅ All Sleeper data cleared successfully!"
        showingClearResult = true
    }
    
    private func performClearCredentialsOnly() {
        let currentCache = credentialsManager.cachedLeagues
        credentialsManager.clearCredentials()
        credentialsManager.cacheDiscoveredLeagues(currentCache)
        username = ""
        userID = ""
        
        clearResultMessage = "✅ Sleeper credentials cleared (cache kept)!"
        showingClearResult = true
    }
    
    private func performClearCacheOnly() {
        let clearedCount = credentialsManager.cachedLeagues.count
        credentialsManager.cachedLeagues.removeAll()
        UserDefaults.standard.set([], forKey: "SLEEPER_CACHED_LEAGUES")
        UserDefaults.standard.removeObject(forKey: "SLEEPER_LEAGUE_CACHE_TIMESTAMP")
        
        clearResultMessage = "✅ Cleared \(clearedCount) cached league(s)!"
        showingClearResult = true
    }
    
    func confirmClearAction() {
        pendingClearAction?()
        pendingClearAction = nil
        showingClearConfirmation = false
    }
    
    func cancelClearAction() {
        pendingClearAction = nil
        showingClearConfirmation = false
    }
    
    func showInstructions() {
        showingInstructions = true
    }
    
    func dismissValidation() {
        showingValidation = false
    }
    
    func dismissClearResult() {
        showingClearResult = false
    }
    
    // MARK: - Private Methods
    
    private func loadSavedCredentials() {
        // Load from credentials manager, not hardcoded AppConstants
        if credentialsManager.hasValidCredentials {
            username = credentialsManager.currentUsername
            // 🔥 FIX: Don't load user ID into the UI field - keep it hidden
            userID = ""
            selectedSeason = credentialsManager.selectedSeason
        }
        // Don't auto-fill with Gp's credentials - let users enter their own
    }
}