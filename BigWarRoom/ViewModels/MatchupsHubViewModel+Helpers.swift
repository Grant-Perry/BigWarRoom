//
//  MatchupsHubViewModel+Helpers.swift
//  BigWarRoom
//
//  Helper methods and utilities for MatchupsHubViewModel
//

import Foundation

// MARK: - Helper Methods
extension MatchupsHubViewModel {
    
    /// Get selected week (SSOT from WeekSelectionManager)
    /// This ensures refresh uses the user's selected week, not always current week
    internal func getCurrentWeek() -> Int {
        return WeekSelectionManager.shared.selectedWeek
    }
    
    /// Get current year as string
    internal func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
    }
}