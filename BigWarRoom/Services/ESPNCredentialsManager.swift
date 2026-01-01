//
//  ESPNCredentialsManager.swift
//  BigWarRoom
//
//  Manages ESPN authentication credentials securely
//

import Foundation
import Observation
import Security

/// Manages ESPN authentication credentials with secure Keychain storage
@Observable
@MainActor
final class ESPNCredentialsManager {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: ESPNCredentialsManager?
    
    static var shared: ESPNCredentialsManager {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = ESPNCredentialsManager()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: ESPNCredentialsManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties
    var hasValidCredentials: Bool = false
    var currentSWID: String = ""
    var leagueIDs: [String] = []
    var leagueTeamIDs: [String: String] = [:] // LeagueID -> TeamID mapping
    
    // MARK: - Keychain Keys - Use @ObservationIgnored for constants
    @ObservationIgnored private let swidKey = "ESPN_SWID"
    @ObservationIgnored private let espnS2Key = "ESPN_S2"
    @ObservationIgnored private let leagueIDsKey = "ESPN_LEAGUE_IDS"
    @ObservationIgnored private let leagueTeamIDsKey = "ESPN_LEAGUE_TEAM_IDS"
    @ObservationIgnored private let keychainService = "BigWarRoom_ESPN"
    
    // Dependencies - inject instead of using .shared
    private var apiClient: ESPNAPIClient?
    
    // 🔥 PHASE 2: Fix circular dependency - allow initialization without API client
    init() {
        loadCredentials()
    }
    
    // 🔥 PHASE 2: Set API client after initialization to break circular dependency
    func setAPIClient(_ apiClient: ESPNAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    /// Save ESPN credentials securely with optional team IDs
    func saveCredentials(swid: String, espnS2: String, leagueIDs: [String], leagueTeamIDs: [String: String] = [:]) {
        // Save to Keychain
        saveToKeychain(key: swidKey, value: swid)
        saveToKeychain(key: espnS2Key, value: espnS2)
        
        // Save league IDs and team IDs to UserDefaults (not sensitive)
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        UserDefaults.standard.set(leagueTeamIDs, forKey: leagueTeamIDsKey)
        
        // Update properties - @Observable will automatically notify observers
        self.currentSWID = swid
        self.leagueIDs = leagueIDs
        self.leagueTeamIDs = leagueTeamIDs
        self.hasValidCredentials = !swid.isEmpty && !espnS2.isEmpty
        
        DebugPrint(mode: .matchupLoading, "✅ ESPN credentials saved successfully - \(leagueIDs.count) leagues")
    }
    
    /// Load saved ESPN credentials
    private func loadCredentials() {
        let swid = loadFromKeychain(key: swidKey) ?? ""
        let espnS2 = loadFromKeychain(key: espnS2Key) ?? ""
        var leagueIDs = UserDefaults.standard.stringArray(forKey: leagueIDsKey) ?? []
        let leagueTeamIDs = UserDefaults.standard.dictionary(forKey: leagueTeamIDsKey) as? [String: String] ?? [:]
        
        // 🔥 FIX: If league IDs are empty in UserDefaults, fallback to AppConstants for backward compatibility
        if leagueIDs.isEmpty {
            DebugPrint(mode: .matchupLoading, "⚠️ ESPN league IDs empty in UserDefaults - falling back to AppConstants")
            leagueIDs = AppConstants.ESPNLeagueID
            
            // Save them to UserDefaults for next time
            if !leagueIDs.isEmpty {
                UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
                DebugPrint(mode: .matchupLoading, "✅ Saved \(leagueIDs.count) ESPN league IDs to UserDefaults from AppConstants")
            }
        }
        
        // 🔥 FIX: If SWID/ESPN_S2 are empty in Keychain, fallback to AppConstants for backward compatibility
        let finalSWID: String
        let finalESPN_S2: String
        
        if swid.isEmpty {
            DebugPrint(mode: .matchupLoading, "⚠️ ESPN SWID empty in Keychain - falling back to AppConstants")
            finalSWID = AppConstants.SWID
            // Save it to Keychain for next time
            saveToKeychain(key: swidKey, value: finalSWID)
        } else {
            finalSWID = swid
        }
        
        if espnS2.isEmpty {
            DebugPrint(mode: .matchupLoading, "⚠️ ESPN_S2 empty in Keychain - falling back to AppConstants")
            finalESPN_S2 = AppConstants.currentESPNToken
            // Save it to Keychain for next time
            saveToKeychain(key: espnS2Key, value: finalESPN_S2)
        } else {
            finalESPN_S2 = espnS2
        }
        
        self.currentSWID = finalSWID
        self.leagueIDs = leagueIDs
        self.leagueTeamIDs = leagueTeamIDs
        self.hasValidCredentials = !finalSWID.isEmpty && !finalESPN_S2.isEmpty
        
        // 🔥 DEBUG: Log what we're loading
        DebugPrint(mode: .matchupLoading, "🔍 ESPNCredentialsManager loadCredentials:")
        DebugPrint(mode: .matchupLoading, "   SWID: '\(finalSWID.isEmpty ? "EMPTY" : "HAS_VALUE")'")
        DebugPrint(mode: .matchupLoading, "   ESPN_S2: '\(finalESPN_S2.isEmpty ? "EMPTY" : "HAS_VALUE")'")
        DebugPrint(mode: .matchupLoading, "   League IDs: \(leagueIDs.count) - \(leagueIDs)")
        DebugPrint(mode: .matchupLoading, "   Team IDs: \(leagueTeamIDs.count)")
        DebugPrint(mode: .matchupLoading, "   hasValidCredentials: \(hasValidCredentials)")
    }
    
    /// Get current ESPN_S2 cookie
    func getESPN_S2() -> String? {
        return loadFromKeychain(key: espnS2Key)
    }
    
    /// Get current SWID
    func getSWID() -> String? {
        let swid = loadFromKeychain(key: swidKey)
        return swid?.isEmpty == false ? swid : nil
    }
    
    /// Get team ID for a specific league
    func getTeamID(for leagueID: String) -> String? {
        return leagueTeamIDs[leagueID]
    }
    
    /// Store team ID for a specific league
    func setTeamID(_ teamID: String, for leagueID: String) {
        leagueTeamIDs[leagueID] = teamID
        UserDefaults.standard.set(leagueTeamIDs, forKey: leagueTeamIDsKey)
    }
    
    /// Resolve and store team IDs for all configured leagues
    func resolveAllTeamIDs() async {
        guard hasValidCredentials, let apiClient = apiClient else { return }
        
        for leagueID in leagueIDs {
            do {
                if let teamID = try await apiClient.getCurrentUserMemberID(leagueID: leagueID) {
                    setTeamID(teamID, for: leagueID)
                }
            } catch {
                // Silent fail - team ID resolution is not critical
            }
        }
    }
    
    /// Clear all ESPN credentials
    func clearCredentials() {
        deleteFromKeychain(key: swidKey)
        deleteFromKeychain(key: espnS2Key)
        UserDefaults.standard.removeObject(forKey: leagueIDsKey)
        UserDefaults.standard.removeObject(forKey: leagueTeamIDsKey)
        
        currentSWID = ""
        leagueIDs = []
        leagueTeamIDs = [:]
        hasValidCredentials = false
        
        DebugPrint(mode: .matchupLoading, "🗑️ ESPN credentials cleared")
    }
    
    /// Validate credentials by attempting a test API call
    func validateCredentials() async -> Bool {
        guard hasValidCredentials, 
              let firstLeagueID = leagueIDs.first,
              let apiClient = apiClient else {
            return false
        }
        
        do {
            // Use the injected API client to test credentials
            let league = try await apiClient.fetchLeague(leagueID: firstLeagueID)
            DebugPrint(mode: .matchupLoading, "✅ ESPN credentials validation successful: \(league.name)")
            return true
        } catch {
            DebugPrint(mode: .matchupLoading, "❌ ESPN credentials validation failed: \(error)")
            return false
        }
    }
    
    /// Add a new league ID to the saved list
    func addLeagueID(_ leagueID: String) {
        guard !leagueIDs.contains(leagueID) else { return }
        
        leagueIDs.append(leagueID)
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        
        DebugPrint(mode: .matchupLoading, "➕ Added ESPN league ID: \(leagueID)")
    }
    
    /// Remove a league ID from the saved list
    func removeLeagueID(_ leagueID: String) {
        leagueIDs.removeAll { $0 == leagueID }
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        
        DebugPrint(mode: .matchupLoading, "➖ Removed ESPN league ID: \(leagueID)")
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            DebugPrint(mode: .matchupLoading, "❌ Failed to save \(key) to Keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Extensions

extension ESPNCredentialsManager {
    /// Generate authentication headers using stored credentials
    func generateAuthHeaders() -> [String: String]? {
        guard let swid = getSWID(),
              let espnS2 = getESPN_S2() else {
            return nil
        }
        
        let cookieValue = "SWID=\(swid); espn_s2=\(espnS2)"
        
        return [
            "Cookie": cookieValue,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "BigWarRoom/3.12 (iOS)"
        ]
    }
}