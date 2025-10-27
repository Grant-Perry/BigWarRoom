//
//  NFLWeekService.swift
//  BigWarRoom
//
//  Centralized service to fetch and share current NFL week across the app
//

import Foundation
import Observation

@Observable
@MainActor
final class NFLWeekService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: NFLWeekService?
    
    static var shared: NFLWeekService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default SleeperAPIClient
        let instance = NFLWeekService(apiClient: SleeperAPIClient())
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: NFLWeekService) {
        _shared = instance
    }
    
    // MARK: -> Observable Properties (Available to all ViewModels)
    var currentWeek: Int
    var currentYear: String = "2024"
    var seasonType: String = "regular" // "pre", "regular", "post"
    var isLoading: Bool = false
    var lastUpdated: Date?
    
    // MARK: -> Private Properties - Use @ObservationIgnored for internal state
    @ObservationIgnored private let updateInterval: TimeInterval = 300 // 5 minutes
    @ObservationIgnored private var updateTimer: Timer?
    
    // Dependencies - inject instead of using .shared
    private let apiClient: SleeperAPIClient
    
    init(apiClient: SleeperAPIClient) {
        self.apiClient = apiClient
        
        // Start with reasonable defaults - calculate approximate current week
        currentYear = String(Calendar.current.component(.year, from: Date()))
        currentWeek = Self.calculateApproximateCurrentWeek()
        
        // Fetch real data immediately
        Task {
            await fetchCurrentNFLWeek()
            setupPeriodicUpdates()
        }
    }
    
    // MARK: -> Static Helper
    /// Calculate approximate current NFL week based on calendar date
    /// This provides a better starting point than hardcoded 1
    private static func calculateApproximateCurrentWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        // NFL season typically starts first Thursday of September
        // For 2024, let's assume it started around September 5th
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Rough approximation - NFL season starts early September
        guard let seasonStart = dateFormatter.date(from: "\(calendar.component(.year, from: now))-09-05") else {
            return 1
        }
        
        let daysSinceStart = calendar.dateComponents([.day], from: seasonStart, to: now).day ?? 0
        let weeksSinceStart = max(1, (daysSinceStart / 7) + 1)
        
        // Cap at reasonable bounds
        return min(18, max(1, weeksSinceStart))
    }
    
    // MARK: -> Public Methods
    
    /// Manually refresh NFL week data
    func refresh() async {
        await fetchCurrentNFLWeek()
    }
    
    /// Get current week with debug override (but still use REAL week by default)
    func getCurrentWeek(debugWeek: Int? = nil) -> Int {
        if let debugWeek = debugWeek, AppConstants.debug {
            return debugWeek
        }
        // ALWAYS return the real current week (even in debug mode unless explicitly overridden)
        return currentWeek
    }
    
    // MARK: -> Private Methods
    
    /// Fetch current NFL week from Sleeper API
    private func fetchCurrentNFLWeek() async {
        isLoading = true
        
        do {
            let nflState = try await apiClient.fetchNFLState()
            
            // Update properties - @Observable will automatically notify observers
            currentWeek = nflState.displayWeek
            currentYear = nflState.leagueSeason
            seasonType = nflState.seasonType
            lastUpdated = Date()
            
        } catch {
            // Keep existing values on error
        }
        
        isLoading = false
    }
    
    /// Setup periodic updates every 5 minutes
    private func setupPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchCurrentNFLWeek()
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}