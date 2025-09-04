//
//  ESPNCredentialsManager.swift
//  BigWarRoom
//
//  Manages ESPN authentication credentials securely
//

import Foundation
import Combine
import Security

/// Manages ESPN authentication credentials with secure Keychain storage
final class ESPNCredentialsManager: ObservableObject {
    static let shared = ESPNCredentialsManager()
    
    // MARK: - Published Properties
    @Published var hasValidCredentials: Bool = false
    @Published var currentSWID: String = ""
    @Published var leagueIDs: [String] = []
    
    // MARK: - Keychain Keys
    private let swidKey = "ESPN_SWID"
    private let espnS2Key = "ESPN_S2"
    private let leagueIDsKey = "ESPN_LEAGUE_IDS"
    private let keychainService = "BigWarRoom_ESPN"
    
    private init() {
        loadCredentials()
    }
    
    // MARK: - Public Methods
    
    /// Save ESPN credentials securely
    func saveCredentials(swid: String, espnS2: String, leagueIDs: [String]) {
        // Save to Keychain
        saveToKeychain(key: swidKey, value: swid)
        saveToKeychain(key: espnS2Key, value: espnS2)
        
        // Save league IDs to UserDefaults (not sensitive)
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        
        // Update published properties
        self.currentSWID = swid
        self.leagueIDs = leagueIDs
        self.hasValidCredentials = !swid.isEmpty && !espnS2.isEmpty
        
        // xprint("✅ ESPN credentials saved successfully")
    }
    
    /// Load saved ESPN credentials
    private func loadCredentials() {
        let swid = loadFromKeychain(key: swidKey) ?? ""
        let espnS2 = loadFromKeychain(key: espnS2Key) ?? ""
        let leagueIDs = UserDefaults.standard.stringArray(forKey: leagueIDsKey) ?? []
        
        self.currentSWID = swid
        self.leagueIDs = leagueIDs
        self.hasValidCredentials = !swid.isEmpty && !espnS2.isEmpty
        
        // xprint("📱 Loaded ESPN credentials - Has valid: \(hasValidCredentials)")
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
    
    /// Clear all ESPN credentials
    func clearCredentials() {
        deleteFromKeychain(key: swidKey)
        deleteFromKeychain(key: espnS2Key)
        UserDefaults.standard.removeObject(forKey: leagueIDsKey)
        
        currentSWID = ""
        leagueIDs = []
        hasValidCredentials = false
        
        // xprint("🗑️ ESPN credentials cleared")
    }
    
    /// Validate credentials by attempting a test API call
    func validateCredentials() async -> Bool {
        guard hasValidCredentials, let firstLeagueID = leagueIDs.first else {
            return false
        }
        
        do {
            // Use the updated API client to test credentials
            let league = try await ESPNAPIClient.shared.fetchLeague(leagueID: firstLeagueID)
            // xprint("✅ ESPN credentials validation successful: \(league.name)")
            return true
        } catch {
            // xprint("❌ ESPN credentials validation failed: \(error)")
            return false
        }
    }
    
    /// Add a new league ID to the saved list
    func addLeagueID(_ leagueID: String) {
        guard !leagueIDs.contains(leagueID) else { return }
        
        leagueIDs.append(leagueID)
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        
        // xprint("➕ Added ESPN league ID: \(leagueID)")
    }
    
    /// Remove a league ID from the saved list
    func removeLeagueID(_ leagueID: String) {
        leagueIDs.removeAll { $0 == leagueID }
        UserDefaults.standard.set(leagueIDs, forKey: leagueIDsKey)
        
        // xprint("➖ Removed ESPN league ID: \(leagueID)")
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
            // xprint("❌ Failed to save \(key) to Keychain: \(status)")
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
