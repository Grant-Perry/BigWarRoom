//
//  PlayerStatsCache.swift
//  BigWarRoom
//
//  Shared cache for player weekly stats to avoid redundant API calls
//

import Foundation

/// **PlayerStatsCache**
/// 
/// Singleton cache that stores weekly player stats loaded during chopped league processing
/// so they can be accessed by player cards without making duplicate API calls
@MainActor
class PlayerStatsCache {
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: PlayerStatsCache?
    
    static var shared: PlayerStatsCache {
        if let existing = _shared {
            return existing
        }
        let instance = PlayerStatsCache()
        _shared = instance
        return instance
    }
    
    static func setSharedInstance(_ instance: PlayerStatsCache) {
        _shared = instance
    }
    
    private var weeklyStats: [Int: [String: [String: Double]]] = [:]
    
    init() {}

    /// Update cached stats for a specific week
    func updateWeeklyStats(_ stats: [String: [String: Double]], for week: Int) {
        weeklyStats[week] = stats
    }
    
    /// Get cached stats for a specific week
    func getWeeklyStats(for week: Int) -> [String: [String: Double]]? {
        return weeklyStats[week]
    }
    
    /// Get stats for a specific player in a specific week
    func getPlayerStats(playerID: String, week: Int) -> [String: Double]? {
        return weeklyStats[week]?[playerID]
    }
    
    /// Clear cache (useful for memory management)
    func clearCache() {
        weeklyStats.removeAll()
    }
    
    /// Clear cache for a specific week
    func clearWeekCache(for week: Int) {
        weeklyStats.removeValue(forKey: week)
    }
}