//
//  SharedStatsService.swift
//  BigWarRoom
//
//  🔥 SOLUTION: Centralized stats loading to eliminate redundant API calls
//  Instead of each league calling the same stats API, we call it ONCE and share the results
//

import Foundation
import Combine

/// **SharedStatsService**
/// 
/// Singleton service that loads weekly NFL stats once and shares them across all leagues.
/// This eliminates the redundant API calls that were causing 10+ second loading delays.
@MainActor
final class SharedStatsService: ObservableObject {
    static let shared = SharedStatsService()
    
    // MARK: - State
    @Published private(set) var isLoading = false
    @Published private(set) var lastLoadTime: Date?
    @Published private(set) var currentWeek: Int = 7
    @Published private(set) var currentYear: String = "2025"
    
    // MARK: - Cached Data
    private var weeklyStatsCache: [String: [String: [String: Double]]] = [:]  // [week_year: [playerID: stats]]
    private var loadingTasks: [String: Task<[String: [String: Double]], Error>] = [:]
    
    private init() {
        // Subscribe to week changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weekDidChange(_:)),
            name: .weekSelectionChanged,
            object: nil
        )
    }
    
    // MARK: - Public Interface
    
    /// Load stats for the current week/year if not already cached
    /// Returns immediately if already loaded, otherwise loads from API
    func loadCurrentWeekStats() async throws -> [String: [String: Double]] {
        let week = WeekSelectionManager.shared.selectedWeek
        let year = SeasonYearManager.shared.selectedYear
        
        return try await loadWeekStats(week: week, year: year)
    }
    
    /// Load stats for a specific week/year
    /// Uses caching to avoid redundant API calls
    func loadWeekStats(week: Int, year: String) async throws -> [String: [String: Double]] {
        let cacheKey = "\(week)_\(year)"
        
        // Return cached data if available
        if let cachedStats = weeklyStatsCache[cacheKey] {
            return cachedStats
        }
        
        // Check if we're already loading this week
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
            
            // Also update PlayerStatsCache for backward compatibility
            await PlayerStatsCache.shared.updateWeeklyStats(stats, for: week)
            
            return stats
            
        } catch {
            loadingTasks.removeValue(forKey: cacheKey)
            throw error
        }
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
        let newWeek = WeekSelectionManager.shared.selectedWeek
        let newYear = SeasonYearManager.shared.selectedYear
        
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