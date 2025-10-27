//
//  ESPNSetupViewModel.swift
//  BigWarRoom
//
//  ViewModel for ESPN setup and credential management
//

import Foundation
import Observation

@Observable
@MainActor
final class ESPNSetupViewModel {
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var swid: String = ""
    var espnS2: String = ""
    var newLeagueID: String = ""
    var isValidating: Bool = false
    var validationMessage: String = ""
    var showingValidation: Bool = false
    var showingInstructions: Bool = false
    var showingClearConfirmation: Bool = false
    var showingClearResult: Bool = false
    var clearResultMessage: String = ""
    var pendingClearAction: (() -> Void)?
    
    // MARK: - Dependencies
    private let credentialsManager = ESPNCredentialsManager.shared
    
    // MARK: - Computed Properties
    var hasValidCredentials: Bool {
        credentialsManager.hasValidCredentials
    }
    
    var leagueIDs: [String] {
        credentialsManager.leagueIDs
    }
    
    var canSaveCredentials: Bool {
        !swid.isEmpty && !espnS2.isEmpty
    }
    
    var canAddLeague: Bool {
        !newLeagueID.isEmpty
    }
    
    var isSetupComplete: Bool {
        hasValidCredentials && !leagueIDs.isEmpty
    }
    
    // MARK: - Initialization
    init() {
        loadSavedCredentials()
    }
    
    // MARK: - Actions
    
    func fillDefaultCredentials() {
        swid = AppConstants.SWID
        espnS2 = AppConstants.ESPN_S2
    }
    
    func saveCredentials() {
        guard canSaveCredentials else { return }
        
        credentialsManager.saveCredentials(
            swid: swid.trimmingCharacters(in: .whitespacesAndNewlines),
            espnS2: espnS2.trimmingCharacters(in: .whitespacesAndNewlines),
            leagueIDs: credentialsManager.leagueIDs
        )
        
        // NEW: Resolve team IDs after saving credentials
        Task {
            await credentialsManager.resolveAllTeamIDs()
        }
        
        // Show success feedback
        clearResultMessage = "✅ ESPN credentials saved successfully!"
        showingClearResult = true
    }
    
    func addLeagueID() {
        guard canAddLeague else { return }
        
        let trimmedID = newLeagueID.trimmingCharacters(in: .whitespacesAndNewlines)
        credentialsManager.addLeagueID(trimmedID)
        newLeagueID = ""
        
        // NEW: Resolve team ID for the newly added league
        if credentialsManager.hasValidCredentials {
            Task {
                await credentialsManager.resolveAllTeamIDs()
            }
        }
        
        // Show success feedback
        clearResultMessage = "✅ League ID added successfully!"
        showingClearResult = true
    }
    
    func removeLeagueID(_ leagueID: String) {
        credentialsManager.removeLeagueID(leagueID)
        
        // Show success feedback
        clearResultMessage = "✅ League ID removed successfully!"
        showingClearResult = true
    }
    
    func addDefaultLeagueIDs() {
        let previousCount = credentialsManager.leagueIDs.count
        
        for leagueID in AppConstants.ESPNLeagueID {
            if !credentialsManager.leagueIDs.contains(leagueID) {
                credentialsManager.addLeagueID(leagueID)
            }
        }
        
        let newCount = credentialsManager.leagueIDs.count
        let addedCount = newCount - previousCount
        
        // NEW: Resolve team IDs for newly added leagues
        if addedCount > 0 && credentialsManager.hasValidCredentials {
            Task {
                await credentialsManager.resolveAllTeamIDs()
            }
        }
        
        if addedCount > 0 {
            clearResultMessage = "✅ Added \(addedCount) default league ID(s)!"
        } else {
            clearResultMessage = "ℹ️ All default leagues already added"
        }
        showingClearResult = true
    }
    
    func validateCredentials() {
        isValidating = true
        
        Task {
            let isValid = await credentialsManager.validateCredentials()
            
            // NEW: If validation successful and we have leagues, resolve team IDs
            if isValid && !credentialsManager.leagueIDs.isEmpty {
                await credentialsManager.resolveAllTeamIDs()
            }
            
            await MainActor.run {
                isValidating = false
                validationMessage = isValid ? 
                    "✅ Credentials are valid and working!" : 
                    "❌ Failed to validate credentials. Please check your SWID, ESPN_S2, and league IDs."
                showingValidation = true
            }
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
    
    func requestClearLeagueIDsOnly() {
        pendingClearAction = {
            self.performClearLeagueIDsOnly()
        }
        showingClearConfirmation = true
    }
    
    private func performClearCredentials() {
        credentialsManager.clearCredentials()
        swid = ""
        espnS2 = ""
        newLeagueID = ""
        
        clearResultMessage = "✅ All ESPN data cleared successfully!"
        showingClearResult = true
    }
    
    private func performClearCredentialsOnly() {
        let currentLeagues = credentialsManager.leagueIDs
        credentialsManager.clearCredentials()
        credentialsManager.saveCredentials(swid: "", espnS2: "", leagueIDs: currentLeagues)
        swid = ""
        espnS2 = ""
        
        clearResultMessage = "✅ ESPN credentials cleared (leagues kept)!"
        showingClearResult = true
    }
    
    private func performClearLeagueIDsOnly() {
        let clearedCount = credentialsManager.leagueIDs.count
        credentialsManager.leagueIDs.removeAll()
        UserDefaults.standard.set([], forKey: "ESPN_LEAGUE_IDS")
        
        clearResultMessage = "✅ Cleared \(clearedCount) league ID(s)!"
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
        if credentialsManager.hasValidCredentials {
            swid = credentialsManager.currentSWID
            espnS2 = credentialsManager.getESPN_S2() ?? ""
        }
    }
}