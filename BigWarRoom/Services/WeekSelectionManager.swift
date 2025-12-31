//
//  WeekSelectionManager.swift
//  BigWarRoom
//
//  🗓️ SINGLE SOURCE OF TRUTH for week selection across the entire app
//  When Mission Control changes the week, it changes EVERYWHERE
//

import Foundation
import Observation

/// **WeekSelectionManager**
/// 
/// The ultimate week manager - Mission Control's week picker controls the entire app
/// 
/// **Key Features:**
/// - @Observable pattern for app-wide access
/// - Fetches initial week from Sleeper API ONCE on init, then user control forever
/// - `selectedWeek` = SSOT for the entire app
/// - Mission Control becomes the master controller
@Observable
@MainActor
final class WeekSelectionManager {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: WeekSelectionManager?
    
    static var shared: WeekSelectionManager {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default NFLWeekService
        let nflWeekService = NFLWeekService(apiClient: SleeperAPIClient())
        let instance = WeekSelectionManager(nflWeekService: nflWeekService)
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: WeekSelectionManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties
    
    /// The selected week that drives the ENTIRE app
    /// When Mission Control changes this, it changes everywhere
    var selectedWeek: Int
    
    /// Track when the week was last changed (for debugging/logging)
    var lastChanged: Date = Date()
    
    /// Whether we're still waiting for the real NFL week to be fetched (ONLY on first init)
    var isWaitingForRealWeek: Bool = true
    
    // MARK: - Dependencies - inject instead of using singletons
    private let nflWeekService: NFLWeekService
    
    // MARK: - Initialization
    init(nflWeekService: NFLWeekService) {
        self.nflWeekService = nflWeekService
        
        // Start with current NFL week (even if it's the default 1)
        self.selectedWeek = nflWeekService.currentWeek
        
        DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager.init: Initialized to Week \(selectedWeek) (from NFLWeekService.currentWeek)")
        
        // 🔥 CRITICAL: Fetch the real week from Sleeper API ONCE, then done forever
        Task {
            await fetchInitialWeekFromSleeper()
        }
    }
    
    // MARK: - Public Interface
    
    /// Change the selected week (typically called by Mission Control)
    /// This will propagate to ALL subscribers across the app
    func selectWeek(_ week: Int) {
        guard week != selectedWeek else { return }
        
        DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager.selectWeek: User changed week from \(selectedWeek) to \(week)")
        
        selectedWeek = week
        lastChanged = Date()
        isWaitingForRealWeek = false
        
        // Post notification for backward compatibility
        NotificationCenter.default.post(name: .weekSelectionChanged, object: nil)
    }
    
    /// Reset to current NFL week (useful for "Current Week" button)
    func resetToCurrentWeek() {
        let currentWeek = nflWeekService.currentWeek
        DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager: Resetting to current NFL week \(currentWeek)")
        selectWeek(currentWeek)
    }
    
    /// Check if we're viewing the current NFL week
    var isCurrentWeek: Bool {
        return selectedWeek == nflWeekService.currentWeek
    }
    
    /// Get the current NFL week (for reference, but selectedWeek is the SSOT)
    var currentNFLWeek: Int {
        return nflWeekService.currentWeek
    }
    
    // MARK: - Private Methods
    
    /// Fetch the initial week from Sleeper API ONE TIME ONLY
    private func fetchInitialWeekFromSleeper() async {
        // If NFLWeekService hasn't fetched yet, trigger it
        if nflWeekService.lastUpdated == nil {
            DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager: Fetching initial week from Sleeper API...")
            await nflWeekService.refresh()
        }
        
        let realWeek = nflWeekService.currentWeek
        
        // Only update if we're still on default week 1
        guard isWaitingForRealWeek && realWeek != 1 else {
            DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager: Initial week already set or invalid (realWeek=\(realWeek), waiting=\(isWaitingForRealWeek))")
            return
        }
        
        DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager: ONE-TIME INIT - Setting initial week to \(realWeek) from Sleeper API")
        
        selectedWeek = realWeek
        isWaitingForRealWeek = false
        lastChanged = Date()
        
        DebugPrint(mode: .weekCheck, "📅 WeekSelectionManager: ✅ Initialization complete. Week=\(selectedWeek). Sleeper API will never be consulted again.")
    }
}

// MARK: - Convenience Extensions

extension WeekSelectionManager {
    /// Get week display text for UI
    func weekDisplayText(_ week: Int? = nil) -> String {
        let displayWeek = week ?? selectedWeek
        
        if displayWeek == currentNFLWeek {
            return "WEEK \(displayWeek)"
        } else if displayWeek > 17 {
            return "WEEK \(displayWeek) (PLAYOFFS)"
        } else if displayWeek < currentNFLWeek {
            return "WEEK \(displayWeek) (PAST)"
        } else {
            return "WEEK \(displayWeek) (FUTURE)"
        }
    }
    
    /// Check if a specific week is valid (1-18)
    func isValidWeek(_ week: Int) -> Bool {
        return week >= 1 && week <= 18
    }
}