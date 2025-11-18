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
        
        // Start with simple fallback (don't try to be smart about Tuesday/Wednesday)
        currentYear = String(Calendar.current.component(.year, from: Date()))
        currentWeek = 1 // Default fallback if API hasn't loaded yet
        
        DebugPrint(mode: .weekCheck, "📅 NFLWeekService.init: Initialized with fallback week \(currentWeek), waiting for Sleeper API...")
        
        // Fetch real data immediately - Sleeper API is SSOT
        Task {
            await fetchCurrentNFLWeek()
            setupPeriodicUpdates()
        }
    }
    
    // MARK: -> Static Helper
    /// Simple fallback calculation (no Tuesday/Wednesday logic - trust Sleeper API instead)
    private static func calculateCurrentWeek() -> Int {
        // Just return a safe default - we'll get the real week from Sleeper API
        return 1
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
            
            DebugPrint(mode: .weekCheck, "📅 NFLWeekService.fetchCurrentNFLWeek: API returned week \(nflState.displayWeek), season \(nflState.leagueSeason), type \(nflState.seasonType)")
            
            // Update properties - @Observable will automatically notify observers
            currentWeek = nflState.displayWeek
            currentYear = nflState.leagueSeason
            seasonType = nflState.seasonType
            lastUpdated = Date()
            
            DebugPrint(mode: .weekCheck, "📅 NFLWeekService.fetchCurrentNFLWeek: Updated currentWeek to \(currentWeek)")
            
        } catch {
            DebugPrint(mode: .weekCheck, "📅 NFLWeekService.fetchCurrentNFLWeek: Error fetching NFL state - \(error.localizedDescription)")
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