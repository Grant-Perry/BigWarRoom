//
//  OPRKService.swift
//  BigWarRoom
//
//  Service for managing OPRK (Opponent Rank) data from ESPN
//

import Foundation
import SwiftUI

/// **OPRK Service**
///
/// Manages opponent rank data for defenses, providing matchup advantage assessments
@MainActor
final class OPRKService {
    static let shared = OPRKService()
    
    // MARK: - Cached OPRK Data
    
    /// Cached OPRK data by team and position
    /// Format: [TeamAbbrev: [Position: OPRK_Rank]]
    /// Example: ["BUF": ["QB": 5, "RB": 12, "WR": 8, "TE": 15]]
    private var oprkCache: [String: [String: Int]] = [:]
    
    /// Timestamp of last OPRK update
    private var lastUpdateTime: Date?
    
    /// Cache expiration (refresh every hour)
    private let cacheExpiration: TimeInterval = 3600
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Update OPRK data from ESPN league response
    /// - Parameter espnLeague: ESPN league data containing positional ratings
    func updateOPRKData(from espnLeague: ESPNLeague) {
        debugPrint(mode: .oprk, "Checking ESPN league response...")
        debugPrint(mode: .oprk, "positionAgainstOpponent property exists? \(espnLeague.positionAgainstOpponent != nil)")
        
        guard let positionalRatingsResponse = espnLeague.positionAgainstOpponent else {
            debugPrint(mode: .oprk, "⚠️ No positionAgainstOpponent object in ESPN response")
            debugPrint(mode: .oprk, "⚠️ This likely means the API call is missing view=mPositionalRatings parameter")
            return
        }
        
        debugPrint(mode: .oprk, "positionAgainstOpponent decoded successfully")
        debugPrint(mode: .oprk, "positionalRatings property is nil? \(positionalRatingsResponse.positionalRatings == nil)")
        
        guard let ratingsData = positionalRatingsResponse.positionalRatings else {
            debugPrint(mode: .oprk, "⚠️ positionAgainstOpponent object exists but positionalRatings is nil")
            debugPrint(mode: .oprk, "⚠️ This likely means the JSON structure doesn't match our model")
            return
        }
        
        debugPrint(mode: .oprk, "✅ Found positional ratings data with \(ratingsData.count) positions")
        
        var newCache: [String: [String: Int]] = [:]
        
        // ESPN position IDs to position strings
        let positionMap: [String: String] = [
            "1": "QB",   // Quarterback
            "2": "RB",   // Running Back  
            "3": "WR",   // Wide Receiver
            "4": "TE",   // Tight End
            "5": "K",    // Kicker
            "16": "D/ST" // Defense/Special Teams
        ]
        
        // Process each position's ratings
        for (positionId, positionRatings) in ratingsData {
            guard let position = positionMap[positionId] else {
                debugPrint(mode: .oprk, "⚠️ Unknown position ID: \(positionId)")
                continue
            }
            
            // Get the ratingsByOpponent data
            guard let teamRatings = positionRatings.ratingsByOpponent else {
                debugPrint(mode: .oprk, "⚠️ No ratingsByOpponent for position \(position)")
                continue
            }
            
            debugPrint(mode: .oprk, "Processing position \(position) with \(teamRatings.count) teams")
            
            // Process each team's rating for this position
            for (teamIdString, rating) in teamRatings {
                guard let teamId = Int(teamIdString),
                      let teamAbbrev = ESPNTeamMap.teamIdToAbbreviation[teamId] else {
                    continue
                }
                
                // Initialize team's position ratings if needed
                if newCache[teamAbbrev] == nil {
                    newCache[teamAbbrev] = [:]
                }
                
                // Store the OPRK rank
                newCache[teamAbbrev]?[position] = rating.rank
            }
        }
        
        // Update cache
        oprkCache = newCache
        lastUpdateTime = Date()
        
        debugPrint(mode: .oprk, "✅ Updated rankings for \(newCache.count) teams across \(positionMap.count) positions")
        
        // Debug: Show sample of what was stored
        if let miaData = newCache["MIA"] {
            debugPrint(mode: .oprk, "Cache Sample - MIA: \(miaData)")
        }
        if let bufData = newCache["BUF"] {
            debugPrint(mode: .oprk, "Cache Sample - BUF: \(bufData)")
        }
    }
    
    /// Get OPRK rank for a specific team and position
    /// - Parameters:
    ///   - team: NFL team abbreviation (e.g., "BUF", "KC")
    ///   - position: Position string (e.g., "QB", "RB", "WR", "TE")
    /// - Returns: OPRK rank (1-32) where 1 = toughest defense, 32 = easiest defense
    func getOPRK(forTeam team: String, position: String) -> Int? {
        // Normalize team abbreviation (already uppercased)
        let normalizedTeam = team.uppercased()
        
        // Normalize position (handle variations)
        let normalizedPosition: String
        switch position.uppercased() {
        case "QB": normalizedPosition = "QB"
        case "RB": normalizedPosition = "RB"
        case "WR": normalizedPosition = "WR"
        case "TE": normalizedPosition = "TE"
        case "DST", "D/ST", "DEF": normalizedPosition = "D/ST"
        default: return nil
        }
        
        let result = oprkCache[normalizedTeam]?[normalizedPosition]
        debugPrint(mode: .oprk, "Lookup: team=\(normalizedTeam), position=\(normalizedPosition) → rank=\(result ?? -1)")
        
        return result
    }
    
    /// Get matchup advantage based on OPRK
    /// - Parameters:
    ///   - team: Opposing team abbreviation
    ///   - position: Player's position
    /// - Returns: MatchupAdvantage enum
    func getMatchupAdvantage(forOpponent team: String, position: String) -> MatchupAdvantage {
        // Normalize team name first
        let normalizedTeam = team.uppercased()
        
        guard let oprk = getOPRK(forTeam: normalizedTeam, position: position) else {
            return .neutral
        }
        
        // Map OPRK rank to matchup advantage
        // Lower OPRK = tougher defense = worse matchup
        // Higher OPRK = weaker defense = better matchup
        switch oprk {
        case 1...8:    return .difficult  // Top 8 defenses (ranks 1-8)
        case 9...16:   return .neutral    // Middle tier defenses (ranks 9-16)
        case 17...24:  return .favorable  // Easier matchups (ranks 17-24)
        case 25...32:  return .elite      // Easiest matchups (ranks 25-32)
        default:       return .neutral
        }
    }
    
    /// Check if OPRK cache is stale and needs refresh
    var needsRefresh: Bool {
        guard let lastUpdate = lastUpdateTime else {
            return true
        }
        
        return Date().timeIntervalSince(lastUpdate) > cacheExpiration
    }
    
    /// Clear OPRK cache (useful for testing or manual refresh)
    func clearCache() {
        oprkCache.removeAll()
        lastUpdateTime = nil
        debugPrint(mode: .oprk, "🗑️ Cache cleared")
    }
    
    /// Get all OPRK data for debugging
    func debugPrintOPRK() {
        debugPrint(mode: .oprk, "📊 Cache Status:")
        debugPrint(mode: .oprk, "  - Teams: \(oprkCache.count)")
        debugPrint(mode: .oprk, "  - Last Update: \(lastUpdateTime?.description ?? "Never")")
        debugPrint(mode: .oprk, "  - Needs Refresh: \(needsRefresh)")
        
        for (team, positions) in oprkCache.sorted(by: { $0.key < $1.key }) {
            debugPrint(mode: .oprk, "  - \(team): QB=\(positions["QB"] ?? 0), RB=\(positions["RB"] ?? 0), WR=\(positions["WR"] ?? 0), TE=\(positions["TE"] ?? 0)")
        }
    }
}

