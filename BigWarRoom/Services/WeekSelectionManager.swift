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
/// - Always initializes to current NFL week (waits for real API data)
/// - When changed, propagates to ALL subscribers
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
    
    /// Whether we're still waiting for the real NFL week to be fetched
    var isWaitingForRealWeek: Bool = true
    
    // MARK: - Dependencies - inject instead of using singletons
    private let nflWeekService: NFLWeekService
    
    // Use @ObservationIgnored for internal subscription management
    @ObservationIgnored private var weekUpdateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(nflWeekService: NFLWeekService) {
        self.nflWeekService = nflWeekService
        
        // Start with current NFL week (even if it's the default 1)
        self.selectedWeek = nflWeekService.currentWeek
        
        // Set up subscriptions to get the REAL week when it's fetched
        setupNFLWeekSubscription()
        
        // Trigger immediate fetch if NFL service hasn't loaded yet
        Task {
            if nflWeekService.lastUpdated == nil {
//                print("🗓️ WeekSelectionManager: NFLWeekService hasn't loaded yet, triggering fetch...")
                await nflWeekService.refresh()
            }
        }
        
//        print("🗓️ WeekSelectionManager: Initialized to Week \(selectedWeek)")
    }
    
    deinit {
        weekUpdateTask?.cancel()
    }
    
    // MARK: - Public Interface
    
    /// Change the selected week (typically called by Mission Control)
    /// This will propagate to ALL subscribers across the app
    func selectWeek(_ week: Int) {
        guard week != selectedWeek else { return }
        
//        print("🗓️ WeekSelectionManager: Changing week from \(selectedWeek) to \(week)")
        
        selectedWeek = week
        lastChanged = Date()
        isWaitingForRealWeek = false // User has made an explicit selection
        
        // Post notification for backward compatibility
        NotificationCenter.default.post(name: .weekSelectionChanged, object: nil)
    }
    
    /// Reset to current NFL week (useful for "Current Week" button)
    func resetToCurrentWeek() {
        let currentWeek = nflWeekService.currentWeek
//        print("🗓️ WeekSelectionManager: Resetting to current NFL week \(currentWeek)")
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
    
    /// Subscribe to NFL week service for season transitions and initial real week
    private func setupNFLWeekSubscription() {
        weekUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                
                let newNFLWeek = self.nflWeekService.currentWeek
                
                // Check if NFL week has changed
                if self.isWaitingForRealWeek && newNFLWeek != 1 {
//                    print("🗓️ WeekSelectionManager: First real NFL week received, updating from \(self.selectedWeek) to \(newNFLWeek)")
                    await MainActor.run {
                        self.selectedWeek = newNFLWeek
                        self.isWaitingForRealWeek = false
                        self.lastChanged = Date()
                    }
                }
                
                // If user was viewing current week and NFL advances, update selection
                else if self.selectedWeek == newNFLWeek - 1 && !self.isWaitingForRealWeek {
//                    print("🗓️ WeekSelectionManager: Auto-advancing to new current week \(newNFLWeek)")
                    await MainActor.run {
                        self.selectedWeek = newNFLWeek
                        self.lastChanged = Date()
                    }
                }
                
                // Check if NFL service has loaded for the first time
                if self.isWaitingForRealWeek && 
                   self.nflWeekService.lastUpdated != nil && 
                   self.selectedWeek != self.nflWeekService.currentWeek {
//                    print("🗓️ WeekSelectionManager: NFL service loaded, updating week to \(self.nflWeekService.currentWeek)")
                    await MainActor.run {
                        self.selectedWeek = self.nflWeekService.currentWeek
                        self.isWaitingForRealWeek = false
                        self.lastChanged = Date()
                    }
                }
                
                // Wait before next check
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
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