//
//  SeasonYearManager.swift
//  BigWarRoom
//
//  🗓️ SINGLE SOURCE OF TRUTH for season year selection across the entire app
//  When year changes, it changes EVERYWHERE
//

import Foundation
import Combine

/// **SeasonYearManager**
/// 
/// The ultimate year manager - controls current season year for the entire app
/// 
/// **Key Features:**
/// - Singleton pattern for app-wide access
/// - Defaults to current ESPN league year from AppConstants
/// - When changed, propagates to ALL subscribers
/// - Integrates with WeekPickerView for unified season/week control
@MainActor
final class SeasonYearManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SeasonYearManager()
    
    // MARK: - Published Properties
    /// The selected year that drives the ENTIRE app
    /// When user changes this, it changes everywhere
    @Published var selectedYear: String
    
    /// Track when the year was last changed (for debugging/logging)
    @Published var lastChanged: Date = Date()
    
    /// Available years for picker
    let availableYears = ["2024", "2025", "2026"]
    
    // MARK: - Initialization
    private init() {
        // Start with current ESPN league year from AppConstants
        self.selectedYear = AppConstants.ESPNLeagueYear
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
        
        // Force objectWillChange notification to ensure all subscribers update
        objectWillChange.send()
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