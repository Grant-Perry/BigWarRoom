//
//  SleeperProjectionsService.swift
//  BigWarRoom
//
//  💊 Fetches weekly player projections from Sleeper API
//  Endpoint: GET /v1/projections/nfl/{season_type}/{season}/{week}
//  Returns: pts_ppr, pts_half_ppr, pts_std + raw stat projections
//  🔥 NO SINGLETON - Instance-based for proper memory management
//

import Foundation

@MainActor
@Observable
final class SleeperProjectionsService {
    // 🔥 REMOVED: static let shared = SleeperProjectionsService()
    
    // MARK: - Cache
    
    /// Cache key: "week_year_seasonType"
    @ObservationIgnored private var projectionsCache: [String: [String: SleeperProjection]] = [:]
    
    /// Last fetch time for each cache key
    @ObservationIgnored private var lastFetchTime: [String: Date] = [:]
    
    /// Cache duration: 1 hour (projections don't change frequently)
    private let cacheDuration: TimeInterval = 3600
    
    // MARK: - Initialization
    
    init() {
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: New instance created")
    }
    
    deinit {
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: Instance deallocated (cache freed) ✅")
    }
    
    // MARK: - Models
    
    struct SleeperProjection: Codable {
        // Pre-calculated fantasy points
        let pts_ppr: Double?
        let pts_half_ppr: Double?
        let pts_std: Double?
        
        // Raw stat projections
        let pass_yd: Double?
        let pass_td: Double?
        let pass_int: Double?
        let rush_yd: Double?
        let rush_td: Double?
        let rec: Double?
        let rec_yd: Double?
        let rec_td: Double?
        let fum_lost: Double?
        let gp: Double?  // Games played projection
        
        // Note: playerID comes from the dictionary key, not the value
        // Note: week/season/seasonType are in the URL, not the response
    }
    
    // MARK: - Public API
    
    /// Fetch projections for a specific week
    /// - Parameters:
    ///   - week: NFL week number
    ///   - year: Season year (e.g., "2024")
    ///   - seasonType: "regular" or "post"
    ///   - forceRefresh: Bypass cache and fetch fresh data
    /// - Returns: Dictionary of playerID -> SleeperProjection
    func fetchProjections(
        week: Int,
        year: String,
        seasonType: String = "regular",
        forceRefresh: Bool = false
    ) async throws -> [String: SleeperProjection] {
        let cacheKey = "\(week)_\(year)_\(seasonType)"
        
        // Check cache first
        if !forceRefresh,
           let cached = projectionsCache[cacheKey],
           let lastFetch = lastFetchTime[cacheKey],
           Date().timeIntervalSince(lastFetch) < cacheDuration {
            DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: Using cached data for week \(week) \(year)")
            return cached
        }
        
        // Fetch from API
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: Fetching from Sleeper API for week \(week) \(year)")
        
        let urlString = "https://api.sleeper.app/v1/projections/nfl/\(seasonType)/\(year)/\(week)"
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: Invalid URL")
            throw ProjectionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: Invalid HTTP response")
            throw ProjectionError.invalidResponse
        }
        
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: HTTP \(httpResponse.statusCode)")
            
            // Try to decode error message
            if let errorString = String(data: data, encoding: .utf8) {
                DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: Response: \(errorString)")
            }
            
            throw ProjectionError.httpError(httpResponse.statusCode)
        }
        
        DebugPrint(mode: .sleeperAPI, "📊 PROJECTIONS: Response size: \(data.count) bytes")
        
        // Parse response - it's a dictionary of playerID -> projection data
        let decoder = JSONDecoder()
        
        let projectionsDict: [String: SleeperProjection]
        do {
            projectionsDict = try decoder.decode([String: SleeperProjection].self, from: data)
        } catch {
            DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: Decoding error - \(error.localizedDescription)")
            
            // Try to see what we got
            if let jsonString = String(data: data, encoding: .utf8) {
                DebugPrint(mode: .sleeperAPI, "❌ PROJECTIONS: Raw response (first 1000 chars): \(String(jsonString.prefix(1000)))")
            }
            
            throw ProjectionError.decodingError(error)
        }
        
        DebugPrint(mode: .sleeperAPI, "✅ PROJECTIONS: Fetched \(projectionsDict.count) player projections")
        
        // Cache the results
        projectionsCache[cacheKey] = projectionsDict
        lastFetchTime[cacheKey] = Date()
        
        return projectionsDict
    }
    
    /// Get projection for a specific player
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - year: Season year
    ///   - seasonType: "regular" or "post"
    /// - Returns: SleeperProjection if available
    func getProjection(
        for playerID: String,
        week: Int,
        year: String,
        seasonType: String = "regular"
    ) async throws -> SleeperProjection? {
        let projections = try await fetchProjections(
            week: week,
            year: year,
            seasonType: seasonType
        )
        return projections[playerID]
    }
    
    /// Get projected points for a player in a specific scoring format
    /// - Parameters:
    ///   - playerID: Sleeper player ID
    ///   - week: NFL week number
    ///   - year: Season year
    ///   - scoringFormat: "ppr", "half_ppr", or "std"
    /// - Returns: Projected points or nil
    func getProjectedPoints(
        for playerID: String,
        week: Int,
        year: String,
        scoringFormat: String = "ppr"
    ) async throws -> Double? {
        guard let projection = try await getProjection(
            for: playerID,
            week: week,
            year: year
        ) else {
            return nil
        }
        
        switch scoringFormat.lowercased() {
        case "ppr":
            return projection.pts_ppr
        case "half_ppr", "half":
            return projection.pts_half_ppr
        case "std", "standard":
            return projection.pts_std
        default:
            return projection.pts_ppr // Default to PPR
        }
    }
    
    /// Clear all cached projections
    func clearCache() {
        projectionsCache.removeAll()
        lastFetchTime.removeAll()
        DebugPrint(mode: .sleeperAPI, "🗑️ PROJECTIONS: Cache cleared")
    }
    
    /// Clear cache for a specific week
    func clearCache(for week: Int, year: String, seasonType: String = "regular") {
        let cacheKey = "\(week)_\(year)_\(seasonType)"
        projectionsCache.removeValue(forKey: cacheKey)
        lastFetchTime.removeValue(forKey: cacheKey)
        DebugPrint(mode: .sleeperAPI, "🗑️ PROJECTIONS: Cache cleared for week \(week) \(year)")
    }
    
    // MARK: - Errors
    
    enum ProjectionError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid projections API URL"
            case .invalidResponse:
                return "Invalid response from projections API"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .decodingError(let error):
                return "Failed to decode projections: \(error.localizedDescription)"
            }
        }
    }
}