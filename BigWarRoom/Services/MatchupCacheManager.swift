//
//  MatchupCacheManager.swift
//  BigWarRoom
//
//  Week-based caching for matchup structure data (NOT scores)
//  Speeds up app loading by caching league lists, rosters, and matchup pairings
//

import Foundation
import Observation

/// Manages week-based caching of matchup structure data
/// DOES NOT cache scores - those are always fetched fresh for live updates
@Observable
@MainActor
final class MatchupCacheManager {
    
    // MARK: - Singleton (hybrid pattern for backward compatibility)
    private static var _shared: MatchupCacheManager?
    
    static var shared: MatchupCacheManager {
        if let existing = _shared {
            return existing
        }
        let instance = MatchupCacheManager()
        _shared = instance
        return instance
    }
    
    static func setSharedInstance(_ instance: MatchupCacheManager) {
        _shared = instance
    }
    
    // MARK: - Observable State
    private(set) var lastCachedWeek: Int?
    private(set) var lastCachedYear: String?
    private(set) var lastCacheDate: Date?
    private(set) var cacheSize: Int64 = 0
    
    // MARK: - Cache Settings
    
    /// Check if caching is enabled (UserDefaults toggle)
    var isCacheEnabled: Bool {
        // Default to TRUE if never set
        if UserDefaults.standard.object(forKey: "MatchupCacheEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "MatchupCacheEnabled")
    }
    
    /// Toggle cache on/off
    func setCacheEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "MatchupCacheEnabled")
        
        if !enabled {
            // If disabling cache, clear it
            clearAllCache()
        }
    }
    
    // MARK: - Cache Key Generation
    
    /// Generate cache key for a specific week/year
    func getCacheKey(week: Int, year: String) -> String {
        return "matchups_week\(week)_\(year)"
    }
    
    /// Get file URL for cached data
    private func getCacheFileURL(week: Int, year: String) -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheKey = getCacheKey(week: week, year: year)
        return documentsURL.appendingPathComponent("\(cacheKey).json")
    }
    
    // MARK: - Cache Operations
    
    /// Check if we have cached data for a specific week
    func hasCachedData(week: Int, year: String) -> Bool {
        guard isCacheEnabled else { return false }
        
        let fileURL = getCacheFileURL(week: week, year: year)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Load cached matchup structure data
    func loadCachedData(week: Int, year: String) -> CachedMatchupData? {
        guard isCacheEnabled else {
            DebugPrint(mode: .matchupLoading, "🚫 Cache disabled - skipping cache load")
            return nil
        }
        
        guard hasCachedData(week: week, year: year) else {
            DebugPrint(mode: .matchupLoading, "📦 No cache found for week \(week), year \(year)")
            return nil
        }
        
        let fileURL = getCacheFileURL(week: week, year: year)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cachedData = try JSONDecoder().decode(CachedMatchupData.self, from: data)
            
            // Update observable state
            lastCachedWeek = week
            lastCachedYear = year
            lastCacheDate = cachedData.cacheDate
            updateCacheSize()
            
            DebugPrint(mode: .matchupLoading, "✅ Cache HIT for week \(week), year \(year) - loaded \(cachedData.snapshots.count) snapshots")
            DebugPrint(mode: .matchupLoading, "   Cache date: \(cachedData.cacheDate)")
            
            return cachedData
            
        } catch {
            DebugPrint(mode: .matchupLoading, "❌ Failed to load cache: \(error)")
            return nil
        }
    }
    
    /// Save matchup structure data to cache
    func saveCachedData(_ snapshots: [MatchupSnapshot], week: Int, year: String) {
        guard isCacheEnabled else {
            DebugPrint(mode: .matchupLoading, "🚫 Cache disabled - skipping cache save")
            return
        }
        
        // Convert snapshots to cacheable format
        let cachedSnapshots = snapshots.map { CachedMatchupSnapshot(from: $0) }
        
        let cachedData = CachedMatchupData(
            week: week,
            year: year,
            cacheDate: Date(),
            snapshots: cachedSnapshots
        )
        
        let fileURL = getCacheFileURL(week: week, year: year)
        
        do {
            let data = try JSONEncoder().encode(cachedData)
            try data.write(to: fileURL)
            
            // Update observable state
            lastCachedWeek = week
            lastCachedYear = year
            lastCacheDate = Date()
            updateCacheSize()
            
            let sizeKB = Double(data.count) / 1024.0
            DebugPrint(mode: .matchupLoading, "💾 Cached \(snapshots.count) snapshots for week \(week), year \(year) (\(String(format: "%.1f", sizeKB)) KB)")
            
        } catch {
            DebugPrint(mode: .matchupLoading, "❌ Failed to save cache: \(error)")
        }
    }
    
    /// Clear cache for a specific week
    func clearCache(week: Int, year: String) {
        let fileURL = getCacheFileURL(week: week, year: year)
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                DebugPrint(mode: .matchupLoading, "🗑️ Cleared cache for week \(week), year \(year)")
            }
        } catch {
            DebugPrint(mode: .matchupLoading, "❌ Failed to clear cache: \(error)")
        }
        
        updateCacheSize()
    }
    
    /// Clear ALL cached data
    func clearAllCache() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            let cacheFiles = files.filter { $0.lastPathComponent.hasPrefix("matchups_week") }
            
            for file in cacheFiles {
                try FileManager.default.removeItem(at: file)
            }
            
            DebugPrint(mode: .matchupLoading, "🗑️ Cleared ALL cache (\(cacheFiles.count) files)")
            
            // Reset state
            lastCachedWeek = nil
            lastCachedYear = nil
            lastCacheDate = nil
            cacheSize = 0
            
        } catch {
            DebugPrint(mode: .matchupLoading, "❌ Failed to clear all cache: \(error)")
        }
    }
    
    /// Calculate total cache size
    private func updateCacheSize() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey])
            let cacheFiles = files.filter { $0.lastPathComponent.hasPrefix("matchups_week") }
            
            var totalSize: Int64 = 0
            for file in cacheFiles {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
            
            cacheSize = totalSize
            
        } catch {
            // Silent failure
        }
    }
    
    // MARK: - Cache Info
    
    /// Get human-readable cache info
    func getCacheInfo() -> String? {
        guard let week = lastCachedWeek,
              let year = lastCachedYear,
              let date = lastCacheDate else {
            return nil
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let timeAgo = formatter.localizedString(for: date, relativeTo: Date())
        
        return "Week \(week), \(year) • \(timeAgo)"
    }
    
    /// Get cache size in MB
    func getCacheSizeString() -> String {
        let sizeMB = Double(cacheSize) / 1024.0 / 1024.0
        if sizeMB < 0.1 {
            let sizeKB = Double(cacheSize) / 1024.0
            return String(format: "%.1f KB", sizeKB)
        }
        return String(format: "%.1f MB", sizeMB)
    }
}

// MARK: - Cached Data Model

/// Container for cached matchup structure data
struct CachedMatchupData: Codable {
    let week: Int
    let year: String
    let cacheDate: Date
    let snapshots: [CachedMatchupSnapshot]
}

/// Simplified snapshot for caching (uses String instead of LeagueSource enum)
struct CachedMatchupSnapshot: Codable {
    let id: CachedMatchupID
    let metadata: MatchupMetadata
    let myTeam: TeamSnapshot
    let opponentTeam: TeamSnapshot
    let league: CachedLeagueDescriptor
    let lastUpdated: Date
    
    struct CachedMatchupID: Codable {
        let leagueID: String
        let matchupID: String
        let platform: String  // 🔥 Use String instead of LeagueSource
        let week: Int
    }
    
    struct MatchupMetadata: Codable {
        let status: String
        let startTime: Date?
        let isPlayoff: Bool
        let isChopped: Bool
        let isEliminated: Bool
    }
}

/// Simplified league descriptor for caching
struct CachedLeagueDescriptor: Codable {
    let id: String
    let name: String
    let platform: String  // 🔥 Use String instead of LeagueSource
    let avatarURL: String?
}

// MARK: - Conversion Extensions

extension CachedMatchupSnapshot {
    /// Convert from MatchupSnapshot to cacheable format
    init(from snapshot: MatchupSnapshot) {
        self.id = CachedMatchupID(
            leagueID: snapshot.id.leagueID,
            matchupID: snapshot.id.matchupID,
            platform: snapshot.id.platform.rawValue,  // Convert enum to String
            week: snapshot.id.week
        )
        self.metadata = MatchupMetadata(
            status: snapshot.metadata.status,
            startTime: snapshot.metadata.startTime,
            isPlayoff: snapshot.metadata.isPlayoff,
            isChopped: snapshot.metadata.isChopped,
            isEliminated: snapshot.metadata.isEliminated
        )
        self.myTeam = snapshot.myTeam
        self.opponentTeam = snapshot.opponentTeam
        self.league = CachedLeagueDescriptor(
            id: snapshot.league.id,
            name: snapshot.league.name,
            platform: snapshot.league.platform.rawValue,  // Convert enum to String
            avatarURL: snapshot.league.avatarURL
        )
        self.lastUpdated = snapshot.lastUpdated
    }
    
    /// Convert back to MatchupSnapshot
    func toMatchupSnapshot() -> MatchupSnapshot? {
        // Convert platform string back to enum
        guard let platformEnum = LeagueSource(rawValue: id.platform) else {
            return nil
        }
        
        return MatchupSnapshot(
            id: MatchupSnapshot.ID(
                leagueID: id.leagueID,
                matchupID: id.matchupID,
                platform: platformEnum,
                week: id.week
            ),
            metadata: MatchupSnapshot.Metadata(
                status: metadata.status,
                startTime: metadata.startTime,
                isPlayoff: metadata.isPlayoff,
                isChopped: metadata.isChopped,
                isEliminated: metadata.isEliminated
            ),
            myTeam: myTeam,
            opponentTeam: opponentTeam,
            league: LeagueDescriptor(
                id: league.id,
                name: league.name,
                platform: platformEnum,
                avatarURL: league.avatarURL
            ),
            lastUpdated: lastUpdated
        )
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    var matchupCacheEnabled: Bool {
        get {
            // Default to TRUE if never set
            if object(forKey: "MatchupCacheEnabled") == nil {
                return true
            }
            return bool(forKey: "MatchupCacheEnabled")
        }
        set {
            set(newValue, forKey: "MatchupCacheEnabled")
        }
    }
}