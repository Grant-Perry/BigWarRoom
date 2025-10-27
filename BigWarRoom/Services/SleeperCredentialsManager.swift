//
//  SleeperCredentialsManager.swift
//  BigWarRoom
//
//  Manages Sleeper user credentials and preferences
//

import Foundation
import Observation

/// Manages Sleeper user credentials and settings
@Observable
@MainActor
final class SleeperCredentialsManager {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: SleeperCredentialsManager?
    
    static var shared: SleeperCredentialsManager {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default SleeperAPIClient
        let instance = SleeperCredentialsManager(apiClient: SleeperAPIClient())
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: SleeperCredentialsManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties
    var hasValidCredentials: Bool = false
    var currentUsername: String = ""
    var currentUserID: String = ""
    var selectedSeason: String = "2025"
    var cachedLeagues: [String] = [] // Optional: Cache discovered league IDs
    
    // MARK: - UserDefaults Keys - Use @ObservationIgnored for constants
    @ObservationIgnored private let usernameKey = "SLEEPER_USERNAME"
    @ObservationIgnored private let userIDKey = "SLEEPER_USER_ID"
    @ObservationIgnored private let seasonKey = "SLEEPER_SEASON"
    @ObservationIgnored private let cachedLeaguesKey = "SLEEPER_CACHED_LEAGUES"
    @ObservationIgnored private let leagueCacheTimestampKey = "SLEEPER_LEAGUE_CACHE_TIMESTAMP"
    
    // Dependencies - inject instead of using .shared
    private let apiClient: SleeperAPIClient
    
    init(apiClient: SleeperAPIClient) {
        self.apiClient = apiClient
        loadCredentials()
    }
    
    // MARK: - Public Methods
    
    /// Save Sleeper credentials
    func saveCredentials(username: String, userID: String, season: String = "2025") {
        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(season, forKey: seasonKey)
        
        // Update properties - @Observable will automatically notify observers
        self.currentUsername = username
        self.currentUserID = userID
        self.selectedSeason = season
        self.hasValidCredentials = !username.isEmpty || !userID.isEmpty
        
        // x// x Print("✅ Sleeper credentials saved successfully")
    }
    
    /// Load saved Sleeper credentials
    private func loadCredentials() {
        let username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        let userID = UserDefaults.standard.string(forKey: userIDKey) ?? ""
        let season = UserDefaults.standard.string(forKey: seasonKey) ?? "2025"
        let leagues = UserDefaults.standard.stringArray(forKey: cachedLeaguesKey) ?? []
        
        self.currentUsername = username
        self.currentUserID = userID
        self.selectedSeason = season
        self.cachedLeagues = leagues
        self.hasValidCredentials = !username.isEmpty || !userID.isEmpty
        
        // x// x Print("📱 Loaded Sleeper credentials - Has valid: \(hasValidCredentials), Cached leagues: \(leagues.count)")
    }
    
    /// Get current username or user ID for API calls
    func getUserIdentifier() -> String? {
        // print("🔍 SleeperCredentialsManager.getUserIdentifier() called:")
        // print("   - currentUsername: '\(currentUsername)'")
        // print("   - currentUserID: '\(currentUserID)'")
        // print("   - hasValidCredentials: \(hasValidCredentials)")
        
        if !currentUsername.isEmpty {
            // print("   - Returning username: '\(currentUsername)'")
            return currentUsername
        } else if !currentUserID.isEmpty {
            // print("   - Returning userID: '\(currentUserID)'")
            return currentUserID
        }
        // 🔥 FIX: Don't fallback to defaults - return nil if no credentials saved
        // This forces proper credential setup instead of using hardcoded values
        // print("   - No credentials found, returning nil")
        return nil
    }
    
    /// Get numeric user ID for external URLs (like sleeper.com links)
    func getNumericUserID() -> String? {
        // Always return the numeric userID for URL generation
        return currentUserID.isEmpty ? nil : currentUserID
    }
    
    /// Save credentials with automatic userID resolution if needed
    func saveCredentialsWithResolution(usernameOrID: String, season: String = "2025") async -> Bool {
        do {
            // Try to fetch user info to resolve username → userID
            let user = try await apiClient.fetchUser(username: usernameOrID)
            
            // Determine what the user entered
            let enteredUsername = user.displayName?.lowercased() == usernameOrID.lowercased() || user.username?.lowercased() == usernameOrID.lowercased()
            
            if enteredUsername {
                // User entered a username, save both username and resolved userID
                saveCredentials(username: usernameOrID, userID: user.userID, season: season)
                print("✅ Resolved username '\(usernameOrID)' → userID '\(user.userID)'")
            } else {
                // User entered a userID, save it and try to get username
                saveCredentials(username: user.username ?? "", userID: user.userID, season: season)
                print("✅ Used userID '\(user.userID)' with username '\(user.username ?? "N/A")'")
            }
            
            return true
        } catch {
            print("❌ Failed to resolve Sleeper credentials: \(error)")
            return false
        }
    }
    
    /// Clear all Sleeper credentials and cache
    func clearCredentials() {
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: seasonKey)
        UserDefaults.standard.removeObject(forKey: cachedLeaguesKey)
        UserDefaults.standard.removeObject(forKey: leagueCacheTimestampKey)
        
        currentUsername = ""
        currentUserID = ""
        selectedSeason = "2025"
        cachedLeagues = []
        hasValidCredentials = false
        
        // x// x Print("🗑️ Sleeper credentials and cache cleared")
    }
    
    /// Check if we have actual user-entered credentials (not just defaults)
    func hasUserEnteredCredentials() -> Bool {
        return !currentUsername.isEmpty || !currentUserID.isEmpty
    }
    
    /// Cache discovered league IDs for better performance
    func cacheDiscoveredLeagues(_ leagueIDs: [String]) {
        cachedLeagues = leagueIDs
        UserDefaults.standard.set(leagueIDs, forKey: cachedLeaguesKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: leagueCacheTimestampKey)
        
        // x// x Print("💾 Cached \(leagueIDs.count) Sleeper league IDs")
    }
    
    /// Check if league cache is still valid (within 1 hour)
    func isLeagueCacheValid() -> Bool {
        let timestamp = UserDefaults.standard.double(forKey: leagueCacheTimestampKey)
        let cacheAge = Date().timeIntervalSince1970 - timestamp
        return cacheAge < 3600 // 1 hour cache
    }
    
    /// Validate credentials by attempting a test API call
    func validateCredentials() async -> Bool {
        guard let identifier = getUserIdentifier() else {
            return false
        }
        
        do {
            // Try to fetch user info to validate
            let user = try await apiClient.fetchUser(username: identifier)
            // x// x Print("✅ Sleeper credentials validation successful: \(user.displayName ?? identifier)")
            
            // Update user ID if we only had username
            if currentUserID.isEmpty && !user.userID.isEmpty {
                saveCredentials(username: currentUsername, userID: user.userID, season: selectedSeason)
            }
            
            // Optionally refresh league cache
            if !isLeagueCacheValid() {
                Task {
                    await refreshLeagueCache()
                }
            }
            
            return true
        } catch {
            // x// x Print("❌ Sleeper credentials validation failed: \(error)")
            return false
        }
    }
    
    /// Refresh the league cache in background
    func refreshLeagueCache() async {
        guard let identifier = getUserIdentifier() else { return }
        
        do {
            let user = try await apiClient.fetchUser(username: identifier)
            let leagues = try await apiClient.fetchLeagues(userID: user.userID, season: selectedSeason)
            let leagueIDs = leagues.map { $0.leagueID }
            
            cacheDiscoveredLeagues(leagueIDs)
        } catch {
        }
    }
    
    /// Update season and refresh cache if needed
    func updateSeason(_ newSeason: String) {
        selectedSeason = newSeason
        UserDefaults.standard.set(newSeason, forKey: seasonKey)
        
        // Clear league cache since season changed
        cachedLeagues = []
        UserDefaults.standard.removeObject(forKey: cachedLeaguesKey)
        UserDefaults.standard.removeObject(forKey: leagueCacheTimestampKey)
        
        // Refresh cache for new season
        Task {
            await refreshLeagueCache()
        }
    }
}