//
//  SharedStatsService.swift
//  BigWarRoom
//
//  🔥 SOLUTION: Centralized stats loading to eliminate redundant API calls
//  Instead of each league calling the same stats API, we call it ONCE and share the results
//

import Foundation
import Observation

/// **SharedStatsService**
/// 
/// Service that loads weekly NFL stats once and shares them across all leagues.
/// This eliminates the redundant API calls that were causing 10+ second loading delays.
@Observable
@MainActor
final class SharedStatsService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: SharedStatsService?
    
    static var shared: SharedStatsService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default dependencies
        let nflWeekService = NFLWeekService(apiClient: SleeperAPIClient())
        let weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService)
        let seasonYearManager = SeasonYearManager()
        let playerStatsCache = PlayerStatsCache()
        let instance = SharedStatsService(
            weekSelectionManager: weekSelectionManager,
            seasonYearManager: seasonYearManager,
            playerStatsCache: playerStatsCache
        )
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: SharedStatsService) {
        _shared = instance
    }
    
    // MARK: - Observable State
    private(set) var isLoading = false
    private(set) var lastLoadTime: Date?
    private(set) var currentWeek: Int = 7
    private(set) var currentYear: String = "2025"
    
    // MARK: - Cached Data - Use @ObservationIgnored for internal caches
    @ObservationIgnored private var weeklyStatsCache: [String: [String: [String: Double]]] = [:]  // [week_year: [playerID: stats]]
    @ObservationIgnored private var loadingTasks: [String: Task<[String: [String: Double]], Error>] = [:]
    
    // Dependencies - inject instead of using singletons
    private let weekSelectionManager: WeekSelectionManager
    private let seasonYearManager: SeasonYearManager
    private let playerStatsCache: PlayerStatsCache
    
    init(weekSelectionManager: WeekSelectionManager, 
         seasonYearManager: SeasonYearManager,
         playerStatsCache: PlayerStatsCache) {
        self.weekSelectionManager = weekSelectionManager
        self.seasonYearManager = seasonYearManager
        self.playerStatsCache = playerStatsCache
        
        // Subscribe to week changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weekDidChange(_:)),
            name: .weekSelectionChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    /// Load stats for the current week/year if not already cached
    /// Returns immediately if already loaded, otherwise loads from API
    func loadCurrentWeekStats() async throws -> [String: [String: Double]] {
        let week = weekSelectionManager.selectedWeek
        let year = seasonYearManager.selectedYear
        
        return try await loadWeekStats(week: week, year: year)
    }
    
    /// Load stats for a specific week/year
    /// Uses caching to avoid redundant API calls UNLESS forceRefresh is true
    func loadWeekStats(week: Int, year: String, forceRefresh: Bool = false) async throws -> [String: [String: Double]] {
        let cacheKey = "\(week)_\(year)"
        
        // 🔥 WOODY'S FIX: Skip cache if forceRefresh is true
        if !forceRefresh, let cachedStats = weeklyStatsCache[cacheKey] {
            if AppConstants.debug {
                print("🔍 SharedStatsService: Returning cached stats for \(cacheKey)")
            }
            return cachedStats
        }
        
        // 🔥 WOODY'S FIX: Cancel existing task if we're force refreshing
        if forceRefresh {
            loadingTasks[cacheKey]?.cancel()
            loadingTasks.removeValue(forKey: cacheKey)
            weeklyStatsCache.removeValue(forKey: cacheKey)
            if AppConstants.debug {
                print("🔥 SharedStatsService: Force refresh - cleared cache for \(cacheKey)")
            }
        }
        
        // Check if we're already loading this week (and not force refreshing)
        if let existingTask = loadingTasks[cacheKey] {
            return try await existingTask.value
        }
        
        // Start new loading task
        let loadingTask = Task<[String: [String: Double]], Error> {
            try await fetchWeekStats(week: week, year: year)
        }
        
        loadingTasks[cacheKey] = loadingTask
        
        do {
            let stats = try await loadingTask.value
            
            // Cache the results
            weeklyStatsCache[cacheKey] = stats
            loadingTasks.removeValue(forKey: cacheKey)
            lastLoadTime = Date()
            
            if AppConstants.debug {
                print("✅ SharedStatsService: Cached fresh stats for \(cacheKey) - \(stats.count) players")
            }
            
            // Also update PlayerStatsCache for backward compatibility
            await playerStatsCache.updateWeeklyStats(stats, for: week)
            
            return stats
            
        } catch {
            loadingTasks.removeValue(forKey: cacheKey)
            throw error
        }
    }

    /// 🔥 WOODY'S FIX: Add dedicated force refresh method
    func forceRefreshWeekStats(week: Int, year: String) async throws -> [String: [String: Double]] {
        return try await loadWeekStats(week: week, year: year, forceRefresh: true)
    }
    
    /// Load stats for the current week/year with optional force refresh
    func loadCurrentWeekStats(forceRefresh: Bool = false) async throws -> [String: [String: Double]] {
        let week = weekSelectionManager.selectedWeek
        let year = seasonYearManager.selectedYear
        
        return try await loadWeekStats(week: week, year: year, forceRefresh: forceRefresh)
    }
    
    /// Get cached stats for a specific week without loading
    func getCachedWeekStats(week: Int, year: String) -> [String: [String: Double]]? {
        let cacheKey = "\(week)_\(year)"
        return weeklyStatsCache[cacheKey]
    }
    
    /// Get cached stats for a specific player
    func getCachedPlayerStats(playerID: String, week: Int, year: String) -> [String: Double]? {
        let cacheKey = "\(week)_\(year)"
        return weeklyStatsCache[cacheKey]?[playerID]
    }
    
    /// Check if stats are cached for a specific week
    func hasCache(week: Int, year: String) -> Bool {
        let cacheKey = "\(week)_\(year)"
        return weeklyStatsCache[cacheKey] != nil
    }
    
    /// Clear all cached stats (useful for memory management)
    func clearCache() {
        weeklyStatsCache.removeAll()
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }
    
    /// Clear cache for a specific week
    func clearCache(week: Int, year: String) {
        let cacheKey = "\(week)_\(year)"
        weeklyStatsCache.removeValue(forKey: cacheKey)
        loadingTasks[cacheKey]?.cancel()
        loadingTasks.removeValue(forKey: cacheKey)
    }
    
    // MARK: - Private Implementation
    
    /// Fetch stats from Sleeper API
    private func fetchWeekStats(week: Int, year: String) async throws -> [String: [String: Double]] {
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(year)/\(week)") else {
            throw StatsError.invalidURL
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    throw StatsError.httpError(httpResponse.statusCode)
                }
            }
            
            // Decode the stats data
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            return statsData
            
        } catch let decodingError as DecodingError {
            throw StatsError.decodingError(decodingError)
        } catch {
            throw StatsError.networkError(error)
        }
    }
    
    // MARK: - Week Change Handling
    
    @objc private func weekDidChange(_ notification: Notification) {
        let newWeek = weekSelectionManager.selectedWeek
        let newYear = seasonYearManager.selectedYear
        
        if newWeek != currentWeek || newYear != currentYear {
            currentWeek = newWeek
            currentYear = newYear

            // Preload stats for the new week
            Task {
                do {
                    let _ = try await loadWeekStats(week: newWeek, year: newYear)
                } catch {
                    // Silent error handling
                }
            }
        }
    }
}

// MARK: - Error Types

enum StatsError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case networkError(Error)
    case decodingError(DecodingError)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid stats API URL"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let weekSelectionChanged = Notification.Name("weekSelectionChanged")
}