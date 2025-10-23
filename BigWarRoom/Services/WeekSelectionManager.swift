//
//  WeekSelectionManager.swift
//  BigWarRoom
//
//  🗓️ SINGLE SOURCE OF TRUTH for week selection across the entire app
//  When Mission Control changes the week, it changes EVERYWHERE
//

import Foundation
import Combine

/// **WeekSelectionManager**
/// 
/// The ultimate week manager - Mission Control's week picker controls the entire app
/// 
/// **Key Features:**
/// - Singleton pattern for app-wide access
/// - Always initializes to current NFL week (waits for real API data)
/// - When changed, propagates to ALL subscribers
/// - Mission Control becomes the master controller
@MainActor
final class WeekSelectionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = WeekSelectionManager()
    
    // MARK: - Published Properties
    /// The selected week that drives the ENTIRE app
    /// When Mission Control changes this, it changes everywhere
    @Published var selectedWeek: Int
    
    /// Track when the week was last changed (for debugging/logging)
    @Published var lastChanged: Date = Date()
    
    /// Whether we're still waiting for the real NFL week to be fetched
    @Published var isWaitingForRealWeek: Bool = true
    
    // MARK: - Dependencies
    private let nflWeekService = NFLWeekService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
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
    
    // MARK: - Public Interface
    
    /// Change the selected week (typically called by Mission Control)
    /// This will propagate to ALL subscribers across the app
    func selectWeek(_ week: Int) {
        guard week != selectedWeek else { return }
        
//        print("🗓️ WeekSelectionManager: Changing week from \(selectedWeek) to \(week)")
        
        selectedWeek = week
        lastChanged = Date()
        isWaitingForRealWeek = false // User has made an explicit selection
        
        // Force objectWillChange notification to ensure all subscribers update
        objectWillChange.send()
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
        nflWeekService.$currentWeek
            .removeDuplicates()
            .sink { [weak self] newNFLWeek in
                guard let self = self else { return }
                
//                print("🗓️ WeekSelectionManager: NFL week updated to \(newNFLWeek)")
                
                // If we're still waiting for the real week (first load), update to it
                if self.isWaitingForRealWeek && newNFLWeek != 1 {
//                    print("🗓️ WeekSelectionManager: First real NFL week received, updating from \(self.selectedWeek) to \(newNFLWeek)")
                    self.selectedWeek = newNFLWeek
                    self.isWaitingForRealWeek = false
                    self.lastChanged = Date()
                    return
                }
                
                // If user was viewing current week and NFL advances, update selection
                // This handles week transitions automatically
                if self.selectedWeek == newNFLWeek - 1 && !self.isWaitingForRealWeek {
//                    print("🗓️ WeekSelectionManager: Auto-advancing to new current week \(newNFLWeek)")
                    self.selectedWeek = newNFLWeek
                    self.lastChanged = Date()
                }
            }
            .store(in: &cancellables)
            
        // Also watch for when NFL service finishes loading
        nflWeekService.$lastUpdated
            .compactMap { $0 }
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // If we're still waiting and the real week is different, update
                if self.isWaitingForRealWeek && self.selectedWeek != self.nflWeekService.currentWeek {
//                    print("🗓️ WeekSelectionManager: NFL service loaded, updating week to \(self.nflWeekService.currentWeek)")
                    self.selectedWeek = self.nflWeekService.currentWeek
                    self.isWaitingForRealWeek = false
                    self.lastChanged = Date()
                }
            }
            .store(in: &cancellables)
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
