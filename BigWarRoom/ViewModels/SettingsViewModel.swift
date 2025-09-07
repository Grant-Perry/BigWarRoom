//
//  SettingsViewModel.swift
//  BigWarRoom
//
//  ViewModel for both OnBoarding and Settings views
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties (Settings)
    @Published var selectedYear: String = AppConstants.ESPNLeagueYear
    @Published var autoRefreshEnabled: Bool = true
    @Published var debugModeEnabled: Bool = AppConstants.debug
    @Published var isTestingConnection: Bool = false
    
    // MARK: - Published Properties (OnBoarding)
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
    private let nflWeekService = NFLWeekService.shared
    
    // MARK: - Available Options
    let availableYears = ["2023", "2024", "2025"]
    
    // MARK: - Computed Properties
    var espnStatus: String {
        if espnCredentials.hasValidCredentials {
            return "Connected • \(espnCredentials.leagueIDs.count) leagues"
        } else {
            return "Not configured"
        }
    }
    
    var sleeperStatus: String {
        if sleeperCredentials.hasValidCredentials {
            let cachedCount = sleeperCredentials.cachedLeagues.count
            if cachedCount > 0 {
                return "Connected • \(cachedCount) leagues"
            } else {
                let identifier = sleeperCredentials.currentUsername.isEmpty ? 
                    sleeperCredentials.currentUserID : sleeperCredentials.currentUsername
                return "Connected • @\(identifier)"
            }
        } else {
            return "Not configured"
        }
    }
    
    var espnHasCredentials: Bool {
        espnCredentials.hasValidCredentials
    }
    
    var sleeperHasCredentials: Bool {
        sleeperCredentials.hasValidCredentials
    }
    
    var currentNFLWeek: Int {
        nflWeekService.currentWeek
    }
    
    // MARK: - Initialization
    init() {
        // Load saved settings
        loadUserPreferences()
        
        // Watch for debug mode changes
        $debugModeEnabled
            .sink { [weak self] newValue in
                self?.updateDebugMode(newValue)
            }
            .store(in: &cancellables)
        
        // Watch for year changes
        $selectedYear
            .sink { [weak self] newYear in
                self?.updateSelectedYear(newYear)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings Management
    
    private func loadUserPreferences() {
        // Load debug mode preference
        debugModeEnabled = UserDefaults.standard.bool(forKey: "debugModeEnabled")
        
        // Load auto refresh preference
        if UserDefaults.standard.object(forKey: "autoRefreshEnabled") != nil {
            autoRefreshEnabled = UserDefaults.standard.bool(forKey: "autoRefreshEnabled")
        }
        
        // Load selected year preference
        if let savedYear = UserDefaults.standard.string(forKey: "selectedYear") {
            selectedYear = savedYear
            AppConstants.ESPNLeagueYear = savedYear
        }
    }
    
    private func updateDebugMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "debugModeEnabled")
        
        NSLog("🔧 Debug mode \(enabled ? "enabled" : "disabled")")
    }
    
    func updateSelectedYear(_ newYear: String) {
        // Don't set selectedYear here - it creates an infinite loop!
        // selectedYear = newYear
        
        AppConstants.ESPNLeagueYear = newYear
        UserDefaults.standard.set(newYear, forKey: "selectedYear")
        
        NSLog("📅 Updated selected year to: \(newYear)")
    }
    
    // MARK: - OnBoarding Methods
    func showESPNSetup() {
        showingESPNSetup = true
    }
    
    func showSleeperSetup() {
        showingSleeperSetup = true
    }
    
    func showAbout() {
        showingAbout = true
    }
    
    // MARK: - Connection Testing
    
    func testESPNConnection() {
        guard let firstLeagueID = espnCredentials.leagueIDs.first else {
            clearResultMessage = "❌ No ESPN league IDs configured to test with"
            showingClearResult = true
            return
        }
        
        isTestingConnection = true
        
        Task {
            do {
                let league = try await ESPNAPIClient.shared.fetchLeague(leagueID: firstLeagueID)
                
                await MainActor.run {
                    clearResultMessage = "✅ ESPN connection successful!\n\nLeague: \(league.name)\nTeams: \(league.totalRosters)"
                    showingClearResult = true
                    isTestingConnection = false
                }
                
                NSLog("✅ ESPN connection test successful: \(league.name)")
            } catch {
                await MainActor.run {
                    clearResultMessage = "❌ ESPN connection failed:\n\n\(error.localizedDescription)"
                    showingClearResult = true
                    isTestingConnection = false
                }
                
                NSLog("❌ ESPN connection test failed: \(error)")
            }
        }
    }
    
    func exportDebugLogs() {
        // For now, just show a message about debug logs
        clearResultMessage = "📋 Debug logging enabled!\n\nLogs are printed to the console during development. In a production build, you would implement proper log export functionality here."
        showingClearResult = true
        
        NSLog("📤 Debug log export requested")
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
    
    func requestClearAllPersistedData() {
        pendingClearAction = {
            self.performClearAllPersistedData()
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
        NSLog("🧹 Clearing all app cache...")
    }
    
    private func performClearAllServices() {
        espnCredentials.clearCredentials()
        sleeperCredentials.clearCredentials()
        
        clearResultMessage = "✅ All service credentials cleared successfully!\n\nYou'll need to reconnect your ESPN and Sleeper accounts."
        showingClearResult = true
        NSLog("🧹 Cleared ALL service credentials and data")
    }
    
    private func performClearAllPersistedData() {
        // Clear ALL UserDefaults data for the app
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // Clear Keychain data - be more thorough
        espnCredentials.clearCredentials()
        sleeperCredentials.clearCredentials()
        
        // 🔥 ENHANCED: Clear additional Keychain entries that might exist
        let additionalKeychainKeys = [
            "ESPN_SWID_BACKUP", "ESPN_S2_BACKUP", "SLEEPER_USER_BACKUP",
            "ESPN_LEGACY", "SLEEPER_LEGACY", "BIGWARROOM_ESPN", "BIGWARROOM_SLEEPER"
        ]
        
        for key in additionalKeychainKeys {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "BigWarRoom_ESPN", 
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
        
        // Clear any other persisted data
        let cacheKeys = ["cached_leagues", "cached_drafts", "cached_players", "selectedESPNYear", "debugModeEnabled", "autoRefreshEnabled", "ESPN_LEAGUE_IDS"]
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // 🔥 DEBUG: Log the reset action
        if AppConstants.debug {
            print("🧹🧹🧹 FACTORY RESET COMPLETE:")
            print("   - Cleared bundle domain: \(Bundle.main.bundleIdentifier ?? "unknown")")
            print("   - Cleared ESPN Keychain entries")
            print("   - Cleared Sleeper Keychain entries") 
            print("   - Cleared additional Keychain entries")
            print("   - Cleared UserDefaults cache keys")
        }
        
        clearResultMessage = "✅ Factory reset complete!\n\nALL data has been cleared. The app has been reset to factory defaults."
        showingClearResult = true
        NSLog("🧹🧹🧹 NUCLEAR OPTION: Cleared ALL persisted data - app reset to factory state")
        
        // Reset local state
        debugModeEnabled = false
        autoRefreshEnabled = true
        selectedYear = "2024"
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
    
    // MARK: - Default Connection
    
    func connectToDefaultServices() {
        Task {
            var espnSuccess = false
            var sleeperSuccess = false
            
            // Connect ESPN if not already connected
            if !espnCredentials.hasValidCredentials {
                espnCredentials.saveCredentials(
                    swid: AppConstants.SWID,
                    espnS2: AppConstants.ESPN_S2,
                    leagueIDs: AppConstants.ESPNLeagueID
                )
                espnSuccess = true
            }
            
            // Connect Sleeper if not already connected
            if !sleeperCredentials.hasValidCredentials {
                sleeperCredentials.saveCredentials(
                    username: AppConstants.SleeperUser,
                    userID: AppConstants.GpSleeperID,
                    season: "2025"
                )
                sleeperSuccess = true
            }
            
            // Show success message
            await MainActor.run {
                var messages: [String] = []
                
                if espnSuccess {
                    let leagueCount = AppConstants.ESPNLeagueID.count
                    messages.append("✅ ESPN Fantasy: Connected • \(leagueCount) leagues")
                }
                
                if sleeperSuccess {
                    messages.append("✅ Sleeper Fantasy: Connected • @\(AppConstants.SleeperUser)")
                }
                
                if messages.isEmpty {
                    clearResultMessage = "ℹ️ You're already connected to both services!"
                } else {
                    clearResultMessage = "🎉 Default Connection Successful!\n\n" + messages.joined(separator: "\n\n")
                }
                
                showingClearResult = true
                
                // Force UI refresh by triggering computed property updates
                objectWillChange.send()
            }
        }
    }
    
    // MARK: - Status Refresh
    
    func refreshConnectionStatus() {
        // Force UI update by triggering objectWillChange
        objectWillChange.send()
    }
}

// Create a typealias for backward compatibility
typealias OnBoardingViewModel = SettingsViewModel

// MARK: - Debug Mode Helper

extension UserDefaults {
    var isDebugModeEnabled: Bool {
        return bool(forKey: "debugModeEnabled")
    }
}