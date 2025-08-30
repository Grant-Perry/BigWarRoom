//
//  PlayerDirectoryStore.swift
//  BigWarRoom
//
//  Manages the master directory of NFL players from Sleeper API
//
// MARK: -> Player Directory Store

import Foundation
import Combine

@MainActor
final class PlayerDirectoryStore: ObservableObject {
    static let shared = PlayerDirectoryStore()
    
    @Published private(set) var players: [String: SleeperPlayer] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var error: Error?
    
    // NEW: Positional rankings cache
    @Published private(set) var positionalRankings: [String: [String: Int]] = [:] // [position: [playerID: rank]]
    
    private let apiClient = SleeperAPIClient.shared
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "SleeperPlayers"
    private let lastUpdatedKey = "SleeperPlayersLastUpdated"
    
    // Cache duration (24 hours)
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    // MARK: -> Initialization
    
    private init() {
        loadCachedPlayers()
        calculatePositionalRankings()
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
        print("🔄 Refreshing player directory from Sleeper API...")
        isLoading = true
        error = nil
        
        do {
            let fetchedPlayers = try await apiClient.fetchAllPlayers() // Returns [String: SleeperPlayer]
            print("✅ Fetched \(fetchedPlayers.count) players from Sleeper")
            
            players = fetchedPlayers
            lastUpdated = Date()
            
            // Recalculate positional rankings
            calculatePositionalRankings()
            
            // Cache the results
            cachePlayers()
            
            print("🎯 Player directory updated with \(players.count) players")
            
        } catch {
            print("❌ Failed to refresh players: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: -> Positional Rankings Calculation
    
    private func calculatePositionalRankings() {
        print("📊 Calculating NFL team positional rankings...")
        
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
                        print("     \(team) \(position)\(index + 1): \(name) (Depth: \(depthOrder))")
                    }
                }
            }
            
            rankings[position] = positionRankings
            print("   \(position): \(positionRankings.count) players ranked across all teams")
        }
        
        positionalRankings = rankings
        print("✅ NFL team positional rankings calculated for \(rankings.keys.count) positions")
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
    
    private func cachePlayers() {
        do {
            let data = try JSONEncoder().encode(Array(players.values))
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: lastUpdatedKey)
            print("💾 Cached \(players.count) players")
        } catch {
            print("❌ Failed to cache players: \(error)")
        }
    }
    
    private func loadCachedPlayers() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cachedPlayers = try? JSONDecoder().decode([SleeperPlayer].self, from: data) else {
            print("📭 No cached players found")
            return
        }
        
        var playerDict: [String: SleeperPlayer] = [:]
        for player in cachedPlayers {
            playerDict[player.playerID] = player
        }
        
        players = playerDict
        lastUpdated = userDefaults.object(forKey: lastUpdatedKey) as? Date
        
        print("💾 Loaded \(players.count) cached players")
        if let lastUpdated = lastUpdated {
            print("📅 Cache from: \(lastUpdated)")
        }
        
        // Calculate positional rankings for cached data
        calculatePositionalRankings()
    }
}

// MARK: -> Helper Extensions

extension SleeperPlayer {
    /// Get the player's positional ranking (e.g., "RB1", "WR2")
    var positionalRank: String? {
        return PlayerDirectoryStore.shared.positionalRank(for: playerID)
    }
    
    /// Get the player's numeric positional ranking
    var numericPositionalRank: Int? {
        return PlayerDirectoryStore.shared.numericPositionalRank(for: playerID)
    }
}