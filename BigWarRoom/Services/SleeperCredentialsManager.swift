//
//  SleeperCredentialsManager.swift
//  BigWarRoom
//
//  Manages Sleeper user credentials and preferences
//

import Foundation
import Combine

/// Manages Sleeper user credentials and settings
final class SleeperCredentialsManager: ObservableObject {
    static let shared = SleeperCredentialsManager()
    
    // MARK: - Published Properties
    @Published var hasValidCredentials: Bool = false
    @Published var currentUsername: String = ""
    @Published var currentUserID: String = ""
    @Published var selectedSeason: String = "2025"
    @Published var cachedLeagues: [String] = [] // Optional: Cache discovered league IDs
    
    // MARK: - UserDefaults Keys
    private let usernameKey = "SLEEPER_USERNAME"
    private let userIDKey = "SLEEPER_USER_ID"
    private let seasonKey = "SLEEPER_SEASON"
    private let cachedLeaguesKey = "SLEEPER_CACHED_LEAGUES"
    private let leagueCacheTimestampKey = "SLEEPER_LEAGUE_CACHE_TIMESTAMP"
    
    private init() {
        loadCredentials()
    }
    
    // MARK: - Public Methods
    
    /// Save Sleeper credentials
    func saveCredentials(username: String, userID: String, season: String = "2025") {
        UserDefaults.standard.set(username, forKey: usernameKey)
        UserDefaults.standard.set(userID, forKey: userIDKey)
        UserDefaults.standard.set(season, forKey: seasonKey)
        
        // Update published properties
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
            let user = try await SleeperAPIClient.shared.fetchUser(username: usernameOrID)
            
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
            let user = try await SleeperAPIClient.shared.fetchUser(username: identifier)
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
    @MainActor
    func refreshLeagueCache() async {
        guard let identifier = getUserIdentifier() else { return }
        
        do {
            let user = try await SleeperAPIClient.shared.fetchUser(username: identifier)
            let leagues = try await SleeperAPIClient.shared.fetchLeagues(userID: user.userID, season: selectedSeason)
            let leagueIDs = leagues.map { $0.leagueID }
            
            cacheDiscoveredLeagues(leagueIDs)
        } catch {
            // x// x Print("❌ Failed to refresh Sleeper league cache: \(error)")
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