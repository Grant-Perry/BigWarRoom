//
//  OnBoardingViewModel.swift
//  BigWarRoom
//
//  ViewModel for main onboarding view
//

import Foundation
import Combine

@MainActor
final class OnBoardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedYear: String = AppConstants.ESPNLeagueYear
    @Published var showingESPNSetup: Bool = false
    @Published var showingSleeperSetup: Bool = false
    @Published var showingAbout: Bool = false
    @Published var showingClearConfirmation: Bool = false
    @Published var showingClearResult: Bool = false
    @Published var clearResultMessage: String = ""
    @Published var pendingClearAction: (() -> Void)?

    // MARK: - Dependencies
    private let espnCredentials = ESPNCredentialsManager.shared
    private let sleeperCredentials = SleeperCredentialsManager.shared
    
    // MARK: - Computed Properties
    var espnStatus: String {
        if espnCredentials.hasValidCredentials {
            return "Connected • \(espnCredentials.leagueIDs.count) leagues"
        } else {
            return "Not configured"
        }
    }
    
    var espnStatusColor: String {
        espnCredentials.hasValidCredentials ? "green" : "secondary"
    }
    
    var sleeperStatus: String {
        if sleeperCredentials.hasValidCredentials {
            let identifier = sleeperCredentials.currentUsername.isEmpty ? 
                sleeperCredentials.currentUserID : sleeperCredentials.currentUsername
            return "Connected • @\(identifier)"
        } else {
            return "Not configured"
        }
    }
    
    var sleeperStatusColor: String {
        sleeperCredentials.hasValidCredentials ? "green" : "secondary"
    }
    
    var espnHasCredentials: Bool {
        espnCredentials.hasValidCredentials
    }
    
    var sleeperHasCredentials: Bool {
        sleeperCredentials.hasValidCredentials
    }
    
    // MARK: - Actions
    
    func updateSelectedYear(_ newYear: String) {
        selectedYear = newYear
        AppConstants.ESPNLeagueYear = newYear
    }
    
    func showESPNSetup() {
        showingESPNSetup = true
    }
    
    func showSleeperSetup() {
        showingSleeperSetup = true
    }
    
    func showAbout() {
        showingAbout = true
    }
    
    // MARK: - Clear Actions with Confirmation
    
    func requestClearAllCache() {
        pendingClearAction = {
            self.performClearAllCache()
        }
        showingClearConfirmation = true
    }
    
    func requestClearAllServices() {
        pendingClearAction = {
            self.performClearAllServices()
        }
        showingClearConfirmation = true
    }
    
    private func performClearAllCache() {
        let cacheKeys = ["cached_leagues", "cached_drafts", "cached_players"]
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        clearResultMessage = "✅ All app cache cleared successfully!"
        showingClearResult = true
        print("🧹 Clearing all app cache...")
    }
    
    private func performClearAllServices() {
        espnCredentials.clearCredentials()
        sleeperCredentials.clearCredentials()
        
        clearResultMessage = "✅ All service credentials cleared successfully!"
        showingClearResult = true
        print("🧹 Cleared ALL service credentials and data")
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
    
    func dismissClearResult() {
        showingClearResult = false
    }
    
    func testESPNConnection() {
        guard let firstLeagueID = espnCredentials.leagueIDs.first else {
            print("❌ No ESPN league IDs to test with")
            return
        }
        
        Task {
            do {
                let league = try await ESPNAPIClient.shared.fetchLeague(leagueID: firstLeagueID)
                print("✅ ESPN connection test successful: \(league.name)")
            } catch {
                print("❌ ESPN connection test failed: \(error)")
            }
        }
    }
    
    func exportDebugLogs() {
        print("📤 Exporting debug logs...")
        // Implement debug log export if you have a logging system
    }
}