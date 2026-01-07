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
    
    /// Available years for picker
    /// 🔥 FIX: Expand to match WeekPickerView's year range (2015 to current+1)
    static func getAvailableYears() -> [String] {
        let currentNFLYear = NFLWeekCalculator.getCurrentSeasonYear()
        let maxYear = currentNFLYear + 1
        return (2015...maxYear).map { String($0) }
    }
    
    var availableYears: [String] {
        return Self.getAvailableYears()
    }
    
    // MARK: - Initialization
    init() {
        // 🔥 FIXED: Use existing baseline - respect saved year or calculate current NFL season
        let savedYear = AppConstants.ESPNLeagueYear
        let currentNFLYear = String(NFLWeekCalculator.getCurrentSeasonYear())
        let available = Self.getAvailableYears()
        
        // Use saved year if valid, otherwise use calculated NFL season year
        if available.contains(savedYear) {
            self.selectedYear = savedYear
        } else {
            self.selectedYear = currentNFLYear
        }
        
        // Ensure AppConstants matches
        if AppConstants.ESPNLeagueYear != self.selectedYear {
            AppConstants.ESPNLeagueYear = self.selectedYear
        }
    }
    
    // MARK: - Public Interface
    
    /// Change the selected year (typically called by WeekPickerView)
    /// This will propagate to ALL subscribers across the app
    func selectYear(_ year: String) {
        DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Attempting to select year '\(year)'")
        DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Current year: '\(selectedYear)'")
        DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Available years: \(availableYears.joined(separator: ", "))")
        
        guard year != selectedYear, availableYears.contains(year) else {
            DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Guard failed - year==selectedYear: \(year == selectedYear), contains: \(availableYears.contains(year))")
            return
        }
        
        DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Guard passed, changing year from '\(selectedYear)' to '\(year)'")
        
        selectedYear = year
        lastChanged = Date()
        
        // Update AppConstants ESPNLeagueYear for backward compatibility
        AppConstants.ESPNLeagueYear = year
        
        DebugPrint(mode: .weekCheck, "📅 SeasonYearManager.selectYear: Year changed successfully to '\(selectedYear)', AppConstants: '\(AppConstants.ESPNLeagueYear)'")
    }
    
    /// Get the current year as Int for API calls
    var selectedYearInt: Int {
        return Int(selectedYear) ?? 2025
    }
    
    /// Check if we're viewing the current calendar year
    var isCurrentCalendarYear: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return selectedYearInt == currentYear
    }
    
    /// Check if we're viewing the current NFL season year (uses fiscal year logic)
    var isCurrentNFLSeasonYear: Bool {
        let currentNFLYear = NFLWeekCalculator.getCurrentSeasonYear()
        return selectedYearInt == currentNFLYear
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