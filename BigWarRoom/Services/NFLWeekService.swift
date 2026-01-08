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
    
    
    // MARK: -> Observable Properties (Available to all ViewModels)
    var currentWeek: Int
    var currentYear: String = "2025"
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
        
        // Start with NFL fiscal year fallback (will be updated by Sleeper API)
        currentYear = String(NFLWeekCalculator.getCurrentSeasonYear())
        
        // 🔥 FIX: Use a smarter default - calculate based on date instead of defaulting to 1
        currentWeek = NFLWeekCalculator.calculateCurrentWeek()
        
        DebugPrint(mode: .weekCheck, "📅 NFLWeekService.init: Initialized with calculated week \(currentWeek), year \(currentYear), waiting for Sleeper API...")
        
        // Fetch real data immediately - Sleeper API is SSOT
        Task {
            await fetchCurrentNFLWeek()
            setupPeriodicUpdates()
        }
    }
    
    // MARK: -> Static Helper
    /// Simple fallback calculation (no Tuesday/Wednesday logic - trust Sleeper API instead)
    private static func calculateCurrentWeek() -> Int {
        // Use NFLWeekCalculator to get the actual current week instead of defaulting to 1
        return NFLWeekCalculator.calculateCurrentWeek()
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
        // 🔋 BATTERY FIX: Skip if app is not active
        guard AppLifecycleManager.shared.isActive else {
            return
        }
        
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
                // 🔋 BATTERY FIX: Only update if app is active
                if AppLifecycleManager.shared.isActive {
                    await self?.fetchCurrentNFLWeek()
                }
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}