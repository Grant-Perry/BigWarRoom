//
//  BettingOddsCacheManager.swift
//  BigWarRoom
//
//  Manages both in-memory and persistent disk caching for betting odds
//

import Foundation

@MainActor
final class BettingOddsCacheManager {
    
    // MARK: - Cache Storage
    
    // In-memory caches
    private var playerOddsCache: [String: (PlayerBettingOdds?, Date)] = [:]
    private var gameOddsCache: [String: ([String: GameBettingOdds], Date)] = [:]
    
    // Cache expiration settings
    private let playerOddsCacheExpiration: TimeInterval = 3600 // 1 hour
    
    private var gameOddsCacheExpiration: TimeInterval {
        let minutes = UserDefaults.standard.double(forKey: "OddsRefreshInterval")
        let finalMinutes = minutes > 0 ? minutes : 15.0
        return finalMinutes * 60.0
    }
    
    // Persistent cache keys
    private static let lastGameOddsFetchKey = "BettingOdds_LastGameOddsFetch"
    
    // MARK: - Player Odds Caching
    
    func getCachedPlayerOdds(cacheKey: String) -> PlayerBettingOdds? {
        guard let (cachedOdds, timestamp) = playerOddsCache[cacheKey],
              Date().timeIntervalSince(timestamp) < playerOddsCacheExpiration,
              let odds = cachedOdds else {
            return nil
        }
        return odds
    }
    
    func cachePlayerOdds(_ odds: PlayerBettingOdds?, cacheKey: String) {
        if let odds = odds {
            playerOddsCache[cacheKey] = (odds, Date())
        } else {
            // Cache nil with shorter expiration for retry
            playerOddsCache[cacheKey] = (nil, Date().addingTimeInterval(-300))
        }
    }
    
    // MARK: - Game Odds Caching (In-Memory)
    
    func getCachedGameOdds(cacheKey: String) -> [String: GameBettingOdds]? {
        let expirationInterval = gameOddsCacheExpiration
        
        if let (cached, timestamp) = gameOddsCache[cacheKey],
           Date().timeIntervalSince(timestamp) < expirationInterval {
            return cached
        }
        return nil
    }
    
    func cacheGameOdds(_ odds: [String: GameBettingOdds], cacheKey: String, timestamp: Date) {
        gameOddsCache[cacheKey] = (odds, timestamp)
    }
    
    // MARK: - Game Odds Caching (Persistent)
    
    /// Check if persistent cache is still valid
    func isGameOddsCacheValid() -> (isValid: Bool, lastFetchDate: Date?, timeSinceLastFetch: TimeInterval?) {
        let expirationInterval = gameOddsCacheExpiration
        
        if let lastFetchDate = UserDefaults.standard.object(forKey: Self.lastGameOddsFetchKey) as? Date {
            let timeSinceLastFetch = Date().timeIntervalSince(lastFetchDate)
            let isValid = timeSinceLastFetch < expirationInterval
            return (isValid, lastFetchDate, timeSinceLastFetch)
        }
        
        return (false, nil, nil)
    }
    
    /// Save game odds to persistent file
    func persistGameOdds(_ odds: [String: GameBettingOdds], cacheKey: String) {
        let fileURL = getOddsCacheFileURL(cacheKey: cacheKey)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(odds)
            try data.write(to: fileURL)
            let sizeKB = Double(data.count) / 1024.0
            DebugPrint(mode: .bracketTimer, "💾 [ODDS FILE CACHE] Saved \(odds.count) games to disk (\(String(format: "%.1f", sizeKB)) KB)")
        } catch {
            DebugPrint(mode: .bracketTimer, "❌ [ODDS FILE CACHE] Failed to save: \(error)")
        }
    }
    
    /// Load game odds from persistent file
    func loadPersistedGameOdds(cacheKey: String) -> [String: GameBettingOdds]? {
        let fileURL = getOddsCacheFileURL(cacheKey: cacheKey)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            DebugPrint(mode: .bracketTimer, "📂 [ODDS FILE CACHE] No file found for key: \(cacheKey)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let odds = try decoder.decode([String: GameBettingOdds].self, from: data)
            DebugPrint(mode: .bracketTimer, "📂 [ODDS FILE CACHE] Loaded \(odds.count) games from disk")
            return odds
        } catch {
            DebugPrint(mode: .bracketTimer, "❌ [ODDS FILE CACHE] Failed to load: \(error)")
            return nil
        }
    }
    
    /// Update the persistent timestamp for game odds fetch
    func updateGameOddsFetchTimestamp() {
        UserDefaults.standard.set(Date(), forKey: Self.lastGameOddsFetchKey)
    }
    
    /// Clear all game odds cache (memory + disk + timestamp)
    func clearGameOddsCache() {
        gameOddsCache.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.lastGameOddsFetchKey)
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let oddsFiles = files.filter { $0.lastPathComponent.hasPrefix("odds_") }
            for file in oddsFiles {
                try FileManager.default.removeItem(at: file)
            }
            DebugPrint(mode: .bettingOdds, "🗑️ [ODDS REFRESH] Cleared \(oddsFiles.count) persisted odds files")
        } catch {
            DebugPrint(mode: .bettingOdds, "⚠️ [ODDS REFRESH] Failed to clear files: \(error)")
        }
        
        DebugPrint(mode: .bettingOdds, "🔄 [ODDS REFRESH] Manual cache clear - next fetch will be fresh")
    }
    
    // MARK: - Private Helpers
    
    private func getOddsCacheFileURL(cacheKey: String) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("odds_\(cacheKey).json")
    }
}