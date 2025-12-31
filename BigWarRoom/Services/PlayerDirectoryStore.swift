//
//  PlayerDirectoryStore.swift
//  BigWarRoom
//
//  Manages the master directory of NFL players from Sleeper API
//
// MARK: -> Player Directory Store

import Foundation
import Observation

@Observable
@MainActor
final class PlayerDirectoryStore {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: PlayerDirectoryStore?
    
    static var shared: PlayerDirectoryStore {
        if let existing = _shared {
            return existing
        }
        fatalError("PlayerDirectoryStore.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: PlayerDirectoryStore) {
        _shared = instance
    }
    
    private(set) var players: [String: SleeperPlayer] = [:]
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    private(set) var error: Error?
    
    // NEW: Positional rankings cache
    private(set) var positionalRankings: [String: [String: Int]] = [:] // [position: [playerID: rank]]
    
    // Dependencies - these will need to be injected instead of .shared
    private let apiClient: SleeperAPIClient
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "SleeperPlayers"
    private let lastUpdatedKey = "SleeperPlayersLastUpdated"
    
    // Cache duration (24 hours)
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    // MARK: -> Initialization
    
    init(apiClient: SleeperAPIClient) {
        self.apiClient = apiClient
        loadCachedPlayers()
        calculatePositionalRankings()
        
        // 🆔 Debug ESPN ID coverage
        if AppConstants.debug {
            debugESPNIDCoverage()
            
            // 🔥 PHASE 3: Defer canonical mapping build to avoid circular dependency
            // Will be built lazily when needed
        }
    }
    
    // MARK: -> Public Interface
    
    /// Check if the player directory needs to be refreshed
    var needsRefresh: Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > cacheExpirationInterval
    }
    
    /// Get a player by their ESPN ID (for ESPN league integration)
    func playerByESPNID(_ espnID: String) -> SleeperPlayer? {
        return players.values.first { $0.espnID == espnID }
    }
    
    /// Get a player by their ESPN ID as Int
    func playerByESPNID(_ espnID: Int) -> SleeperPlayer? {
        let espnIDString = String(espnID)
        return playerByESPNID(espnIDString)
    }
    
    /// Get a player by their Sleeper ID
    func player(for playerID: String) -> SleeperPlayer? {
        return players[playerID]
    }
    
    /// Get positional rank for a player (e.g., RB1, WR2)
    func positionalRank(for playerID: String) -> String? {
        guard let player = players[playerID],
              let position = player.position?.uppercased(),
              let rankings = positionalRankings[position],
              let rank = rankings[playerID] else {
            return nil
        }
        return "\(position)\(rank)"
    }
    
    /// Get numeric positional rank for a player
    func numericPositionalRank(for playerID: String) -> Int? {
        guard let player = players[playerID],
              let position = player.position?.uppercased(),
              let rankings = positionalRankings[position] else {
            return nil
        }
        return rankings[playerID]
    }
    
    /// Refresh the player directory from Sleeper API
    func refreshPlayers() async {
        // x// x Print("🔄 Refreshing player directory from Sleeper API...")
        isLoading = true
        error = nil
        
        do {
            let fetchedPlayers = try await apiClient.fetchAllPlayers() // Returns [String: SleeperPlayer]
            // x// x Print("✅ Fetched \(fetchedPlayers.count) players from Sleeper")
            
            players = fetchedPlayers
            lastUpdated = Date()
            
            // Recalculate positional rankings
            calculatePositionalRankings()
            
            // Cache the results
            cachePlayers()
            
            // x// x Print("🎯 Player directory updated with \(players.count) players")
            
        } catch {
            // x// x Print("❌ Failed to refresh players: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: -> Positional Rankings Calculation
    
    private func calculatePositionalRankings() {
        // x// x Print("📊 Calculating NFL team positional rankings...")
        
        var rankings: [String: [String: Int]] = [:]
        
        // Group players by position
        let playersByPosition = Dictionary(grouping: players.values) { player in
            player.position?.uppercased() ?? "UNKNOWN"
        }
        
        // Calculate rankings for each position based on NFL team depth charts
        for (position, positionPlayers) in playersByPosition {
            guard position != "UNKNOWN" else { continue }
            
            // Group by team, then sort by depth chart order within each team
            let playersByTeam = Dictionary(grouping: positionPlayers) { player in
                player.team?.uppercased() ?? "UNKNOWN"
            }
            
            var positionRankings: [String: Int] = [:]
            
            for (team, teamPlayers) in playersByTeam {
                guard team != "UNKNOWN" else { continue }
                
                // Sort players by depth chart order (lower = starter)
                let sortedTeamPlayers = teamPlayers
                    .filter { $0.status == "Active" }
                    .sorted { player1, player2 in
                        let order1 = player1.depthChartOrder ?? 99
                        let order2 = player2.depthChartOrder ?? 99
                        
                        // If depth chart orders are the same, use searchRank as tiebreaker
                        if order1 == order2 {
                            let rank1 = player1.searchRank ?? 999
                            let rank2 = player2.searchRank ?? 999
                            return rank1 < rank2
                        }
                        
                        return order1 < order2
                    }
                
                // Assign team positional ranks (QB1, QB2, RB1, RB2, etc.)
                for (index, player) in sortedTeamPlayers.enumerated() {
                    positionRankings[player.playerID] = index + 1
                    
                    // Debug output for first few players of each team/position
                    if index < 3 {
                        let name = player.shortName
                        let depthOrder = player.depthChartOrder ?? 99
                        // x// x Print("     \(team) \(position)\(index + 1): \(name) (Depth: \(depthOrder))")
                    }
                }
            }
            
            rankings[position] = positionRankings
            // x// x Print("   \(position): \(positionRankings.count) players ranked across all teams")
        }
        
        positionalRankings = rankings
        // x// x Print("✅ NFL team positional rankings calculated for \(rankings.keys.count) positions")
    }
    
    // MARK: -> Player Conversion
    
    /// Convert a SleeperPlayer to internal Player model
    func convertToInternalPlayer(_ sleeperPlayer: SleeperPlayer) -> Player? {
        guard let firstName = sleeperPlayer.firstName,
              let lastName = sleeperPlayer.lastName,
              let positionString = sleeperPlayer.position,
              let position = Position(rawValue: positionString.uppercased()),
              let team = sleeperPlayer.team else {
            return nil
        }
        
        // Use search rank to determine tier
        let tier = calculateTier(searchRank: sleeperPlayer.searchRank, position: position)
        
        return Player(
            id: sleeperPlayer.playerID,
            firstInitial: String(firstName.prefix(1)),
            lastName: lastName,
            position: position,
            team: team,
            tier: tier
        )
    }
    
    private func calculateTier(searchRank: Int?, position: Position) -> Int {
        guard let rank = searchRank else { return 4 }
        
        switch position {
        case .qb:
            if rank <= 12 { return 1 }
            if rank <= 24 { return 2 }
            if rank <= 36 { return 3 }
            return 4
            
        case .rb:
            if rank <= 24 { return 1 }
            if rank <= 48 { return 2 }
            if rank <= 84 { return 3 }
            return 4
            
        case .wr:
            if rank <= 36 { return 1 }
            if rank <= 72 { return 2 }
            if rank <= 120 { return 3 }
            return 4
            
        case .te:
            if rank <= 12 { return 1 }
            if rank <= 24 { return 2 }
            if rank <= 36 { return 3 }
            return 4
            
        case .k, .dst:
            if rank <= 12 { return 3 }
            return 4
        }
    }
    
    // MARK: -> Caching

    // 🔥 CRITICAL FIX: Use local file storage instead of UserDefaults to prevent 4MB+ overflow
    private var cacheFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("PlayerDirectory_Cache.json")
    }
    
    private var lastUpdatedFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("PlayerDirectory_LastUpdated.json")
    }
    
    private func cachePlayers() {
        do {
            let data = try JSONEncoder().encode(Array(players.values))
            try data.write(to: cacheFileURL)
            
            // Store last updated timestamp
            let timestampData = try JSONEncoder().encode(Date())
            try timestampData.write(to: lastUpdatedFileURL)
            
            if AppConstants.debug {
                let sizeKB = Double(data.count) / 1024.0
            }
        } catch {
        }
    }
    
    private func loadCachedPlayers() {
        // 🔥 MIGRATION: First check if we need to migrate from UserDefaults
        if let legacyData = userDefaults.data(forKey: cacheKey) {
            do {
                try legacyData.write(to: cacheFileURL)
                userDefaults.removeObject(forKey: cacheKey)
                userDefaults.removeObject(forKey: lastUpdatedKey)
            } catch {
            }
        }
        
        // Load from file
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let cachedPlayers = try JSONDecoder().decode([SleeperPlayer].self, from: data)
            
            var playerDict: [String: SleeperPlayer] = [:]
            for player in cachedPlayers {
                playerDict[player.playerID] = player
            }
            
            players = playerDict
            
            // Load last updated timestamp
            if FileManager.default.fileExists(atPath: lastUpdatedFileURL.path) {
                do {
                    let timestampData = try Data(contentsOf: lastUpdatedFileURL)
                    lastUpdated = try JSONDecoder().decode(Date.self, from: timestampData)
                } catch {
                    lastUpdated = nil
                }
            }
            
            if AppConstants.debug {
                let sizeKB = Double(data.count) / 1024.0
                if let lastUpdated = lastUpdated {
                }
            }
            
            // Calculate positional rankings for cached data
            calculatePositionalRankings()
            
        } catch {
        }
    }
    
    /// Debug method to analyze ESPN ID coverage in Sleeper player data
    func debugESPNIDCoverage() {
        let totalPlayers = players.count
        let playersWithESPNID = players.values.filter { 
            $0.espnID != nil && !$0.espnID!.isEmpty 
        }.count
        
        DebugPrint(mode: .playerIDMapping, "ESPN ID Coverage: \(playersWithESPNID)/\(totalPlayers) players have ESPN IDs (\(String(format: "%.1f", Double(playersWithESPNID)/Double(totalPlayers)*100))%)")
        
        DebugPrint(mode: .playerIDMapping, "Players WITH ESPN IDs:")
        for player in players.values.filter({ $0.espnID != nil }).prefix(10) {
            DebugPrint(mode: .playerIDMapping, "  ✅ \(player.fullName) (\(player.position ?? "?")) -> ESPN ID: '\(player.espnID!)'")
        }
        
        DebugPrint(mode: .playerIDMapping, "Players WITHOUT ESPN IDs:")
        for player in players.values.filter({ $0.espnID == nil }).prefix(10) {
            DebugPrint(mode: .playerIDMapping, "  ❌ \(player.fullName) (\(player.position ?? "?")) -> ESPN ID: '\(player.espnID ?? "nil")'")
        }
        
        DebugPrint(mode: .playerIDMapping, "High-profile player ESPN ID check:")
        for testName in ["Patrick Mahomes", "Christian McCaffrey", "Travis Kelce"] {
            if let foundPlayer = players.values.first(where: { $0.fullName.lowercased().contains(testName.lowercased()) }) {
                DebugPrint(mode: .playerIDMapping, "  \(foundPlayer.fullName) -> ESPN ID: '\(foundPlayer.espnID ?? "nil")'")
            } else {
                DebugPrint(mode: .playerIDMapping, "  \(testName) -> NOT FOUND in player database")
            }
        }
    }
}

// MARK: -> Helper Extensions (UPDATED to use dependency injection)

extension SleeperPlayer {
    /// Get the player's positional ranking (e.g., "RB1", "WR2")
    /// Requires PlayerDirectoryStore to be passed in
    func positionalRank(from playerDirectory: PlayerDirectoryStore) -> String? {
        return playerDirectory.positionalRank(for: self.playerID)
    }
    
    /// Get the player's numeric positional ranking
    /// Requires PlayerDirectoryStore to be passed in
    func numericPositionalRank(from playerDirectory: PlayerDirectoryStore) -> Int? {
        return playerDirectory.numericPositionalRank(for: self.playerID)
    }
}