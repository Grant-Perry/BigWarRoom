//
//  SeasonYearManager.swift
//  BigWarRoom
//
//  🗓️ SINGLE SOURCE OF TRUTH for season year selection across the entire app
//  When year changes, it changes EVERYWHERE
//

import Foundation
import Observation

/// **SeasonYearManager**
/// 
/// The ultimate year manager - controls current season year for the entire app
/// 
/// **Key Features:**
/// - @Observable pattern for app-wide access
/// - Defaults to current NFL season year (2025)
/// - When changed, propagates to ALL subscribers
/// - Integrates with WeekPickerView for unified season/week control
@Observable
@MainActor
final class SeasonYearManager {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: SeasonYearManager?
    
    static var shared: SeasonYearManager {
        if let existing = _shared {
            return existing
        }
        let instance = SeasonYearManager()
        _shared = instance
        return instance
    }
    
    static func setSharedInstance(_ instance: SeasonYearManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties
    /// The selected year that drives the ENTIRE app
    /// When user changes this, it changes everywhere
    var selectedYear: String
    
    /// Track when the year was last changed (for debugging/logging)
    var lastChanged: Date = Date()
    
    /// Available years for picker - Use @ObservationIgnored for constants
    @ObservationIgnored let availableYears = ["2024", "2025", "2026"]
    
    // MARK: - Initialization
    init() {
        // 🔥 FIXED: Default to current NFL season (2025)
        // Check if user has a saved preference, otherwise use 2025
        let savedYear = AppConstants.ESPNLeagueYear
        self.selectedYear = (savedYear == "2024") ? "2025" : savedYear
        
        // Ensure AppConstants matches
        if AppConstants.ESPNLeagueYear != self.selectedYear {
            AppConstants.ESPNLeagueYear = self.selectedYear
        }
    }
    
    // MARK: - Public Interface
    
    /// Change the selected year (typically called by WeekPickerView)
    /// This will propagate to ALL subscribers across the app
    func selectYear(_ year: String) {
        guard year != selectedYear, availableYears.contains(year) else { return }
        
        selectedYear = year
        lastChanged = Date()
        
        // Update AppConstants ESPNLeagueYear for backward compatibility
        AppConstants.ESPNLeagueYear = year
    }
    
    /// Get the current year as Int for API calls
    var selectedYearInt: Int {
        return Int(selectedYear) ?? 2024
    }
    
    /// Check if we're viewing the current calendar year
    var isCurrentCalendarYear: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return selectedYearInt == currentYear
    }
    
    /// Get ESPN token for current selected year
    var currentESPNToken: String {
        return AppConstants.getPrimaryESPNToken(for: selectedYear)
    }
    
    /// Get alternate ESPN token for current selected year
    var alternateESPNToken: String {
        return AppConstants.getAlternateESPNToken(for: selectedYear)
    }
}

// MARK: - Convenience Extensions

extension SeasonYearManager {
    /// Get year display text for UI
    var yearDisplayText: String {
        return "\(selectedYear) Season"
    }
    
    /// Check if a specific year is valid/available
    func isValidYear(_ year: String) -> Bool {
        return availableYears.contains(year)
    }
    
    /// Get the next available year (for future seasons)
    var nextYear: String? {
        guard let currentIndex = availableYears.firstIndex(of: selectedYear),
              currentIndex < availableYears.count - 1 else { return nil }
        return availableYears[currentIndex + 1]
    }
    
    /// Get the previous available year
    var previousYear: String? {
        guard let currentIndex = availableYears.firstIndex(of: selectedYear),
              currentIndex > 0 else { return nil }
        return availableYears[currentIndex - 1]
    }
}