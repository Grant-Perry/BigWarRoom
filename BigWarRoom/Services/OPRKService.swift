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
@Observable
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
    
    init() {}
    
    // MARK: - Public Interface
    
    /// Update OPRK data from ESPN league response
    /// - Parameter espnLeague: ESPN league data containing positional ratings
    func updateOPRKData(from espnLeague: ESPNLeague) {
        guard let positionalRatingsResponse = espnLeague.positionAgainstOpponent,
              let ratingsData = positionalRatingsResponse.positionalRatings else {
            return
        }
        
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
            guard let position = positionMap[positionId],
                  let teamRatings = positionRatings.ratingsByOpponent else {
                continue
            }
            
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
    }
    
    /// Get OPRK rank for a specific team and position
    /// - Parameters:
    ///   - team: NFL team abbreviation (e.g., "BUF", "KC")
    ///   - position: Position string (e.g., "QB", "RB", "WR", "TE")
    /// - Returns: OPRK rank (1-32) where 1 = toughest defense, 32 = easiest defense
    func getOPRK(forTeam team: String, position: String) -> Int? {
        let normalizedTeam = team.uppercased()
        
        let normalizedPosition: String
        switch position.uppercased() {
        case "QB": normalizedPosition = "QB"
        case "RB": normalizedPosition = "RB"
        case "WR": normalizedPosition = "WR"
        case "TE": normalizedPosition = "TE"
        case "DST", "D/ST", "DEF": normalizedPosition = "D/ST"
        default: return nil
        }
        
        return oprkCache[normalizedTeam]?[normalizedPosition]
    }
    
    /// Get matchup advantage based on OPRK
    /// - Parameters:
    ///   - team: Opposing team abbreviation
    ///   - position: Player's position
    /// - Returns: MatchupAdvantage enum
    func getMatchupAdvantage(forOpponent team: String, position: String) -> MatchupAdvantage {
        let normalizedTeam = team.uppercased()
        
        guard let oprk = getOPRK(forTeam: normalizedTeam, position: position) else {
            return .neutral
        }
        
        switch oprk {
        case 1...8:    return .difficult
        case 9...16:   return .neutral
        case 17...24:  return .favorable
        case 25...32:  return .elite
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
    
    /// Clear OPRK cache
    func clearCache() {
        oprkCache.removeAll()
        lastUpdateTime = nil
    }
}