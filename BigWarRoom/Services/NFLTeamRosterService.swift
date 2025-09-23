//
//  NFLTeamRosterService.swift
//  BigWarRoom
//
//  🏈 NFL TEAM ROSTER SERVICE 🏈
//  Service to fetch complete NFL team rosters organized by position
//

import Foundation
import SwiftUI

/// **NFLTeamRosterService**
/// 
/// Service that provides full NFL team rosters organized by position groups:
/// - Extends existing PlayerDirectoryStore functionality
/// - Returns players organized by QB, RB, WR, TE, K, DST
/// - Handles depth chart ordering within each position
@MainActor
final class NFLTeamRosterService {
    static let shared = NFLTeamRosterService()
    
    // MARK: - Dependencies
    private let playerDirectory = PlayerDirectoryStore.shared
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Get complete roster for an NFL team organized by position
    /// Returns players in priority order: QB, RB, WR, TE, K, DST
    func getTeamRoster(for teamCode: String) -> NFLTeamRoster {
        let normalizedTeamCode = teamCode.uppercased()
        
        // Get all active players from the team
        let teamPlayers = playerDirectory.players.values.filter { player in
            player.team?.uppercased() == normalizedTeamCode &&
            player.status == "Active" &&
            player.position != nil
        }
        
        // Group by position
        let playersByPosition = Dictionary(grouping: teamPlayers) { player in
            normalizePosition(player.position?.uppercased() ?? "")
        }
        
        // Sort each position group by depth chart order
        var organizedRoster: [String: [SleeperPlayer]] = [:]
        
        for (position, players) in playersByPosition {
            let sortedPlayers = players.sorted { p1, p2 in
                let order1 = p1.depthChartOrder ?? 99
                let order2 = p2.depthChartOrder ?? 99
                
                // If depth chart orders are the same, use searchRank as tiebreaker
                if order1 == order2 {
                    let rank1 = p1.searchRank ?? 999
                    let rank2 = p2.searchRank ?? 999
                    return rank1 < rank2
                }
                
                return order1 < order2
            }
            
            organizedRoster[position] = sortedPlayers
        }
        
        // Create organized roster with specific position ordering
        return NFLTeamRoster(
            teamCode: teamCode,
            quarterbacks: organizedRoster["QB"] ?? [],
            runningBacks: organizedRoster["RB"] ?? [],
            wideReceivers: organizedRoster["WR"] ?? [],
            tightEnds: organizedRoster["TE"] ?? [],
            kickers: organizedRoster["K"] ?? [],
            defense: organizedRoster["DST"] ?? []
        )
    }
    
    /// Get all players from a team as a flat list sorted by position priority: QB, RB, WR, TE, K, DST
    func getTeamPlayersFlat(for teamCode: String) -> [SleeperPlayer] {
        let roster = getTeamRoster(for: teamCode)
        
        // Combine all positions in priority order
        var allPlayers: [SleeperPlayer] = []
        allPlayers.append(contentsOf: roster.quarterbacks)
        allPlayers.append(contentsOf: roster.runningBacks)
        allPlayers.append(contentsOf: roster.wideReceivers)
        allPlayers.append(contentsOf: roster.tightEnds)
        allPlayers.append(contentsOf: roster.kickers)
        allPlayers.append(contentsOf: roster.defense)
        
        return allPlayers
    }
    
    /// Check if the player directory needs to be refreshed
    var needsRefresh: Bool {
        return playerDirectory.needsRefresh
    }
    
    /// Refresh the underlying player directory
    func refreshPlayerDirectory() async {
        await playerDirectory.refreshPlayers()
    }
    
    // MARK: - Private Methods
    
    /// Normalize position names to standard format
    private func normalizePosition(_ position: String) -> String {
        switch position.uppercased() {
        case "DEF", "D/ST": return "DST"
        case "PK": return "K"
        default: return position.uppercased()
        }
    }
}

/// **NFLTeamRoster**
/// 
/// Data model representing a complete NFL team roster organized by position
struct NFLTeamRoster {
    let teamCode: String
    let quarterbacks: [SleeperPlayer]
    let runningBacks: [SleeperPlayer]
    let wideReceivers: [SleeperPlayer]
    let tightEnds: [SleeperPlayer]
    let kickers: [SleeperPlayer]
    let defense: [SleeperPlayer]
    
    /// Get all players as a flat list in position priority order
    var allPlayers: [SleeperPlayer] {
        var players: [SleeperPlayer] = []
        players.append(contentsOf: quarterbacks)
        players.append(contentsOf: runningBacks)
        players.append(contentsOf: wideReceivers)
        players.append(contentsOf: tightEnds)
        players.append(contentsOf: kickers)
        players.append(contentsOf: defense)
        return players
    }
    
    /// Get total number of players
    var totalPlayerCount: Int {
        return quarterbacks.count + runningBacks.count + wideReceivers.count + 
               tightEnds.count + kickers.count + defense.count
    }
    
    /// Check if roster is empty
    var isEmpty: Bool {
        return totalPlayerCount == 0
    }
}

/// Errors for NFL team roster operations
enum NFLTeamRosterError: Error {
    case teamNotFound
    case noPlayersFound
    case playerDirectoryNotLoaded
}