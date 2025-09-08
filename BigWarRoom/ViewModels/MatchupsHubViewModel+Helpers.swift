//
//  MatchupsHubViewModel+Helpers.swift
//  BigWarRoom
//
//  Helper methods and utilities for MatchupsHubViewModel
//

import Foundation

// MARK: - Helper Methods
extension MatchupsHubViewModel {
    
    /// Get current NFL week
    internal func getCurrentWeek() -> Int {
        return NFLWeekService.shared.currentWeek
    }
    
    /// Get current year as string
    internal func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
    }
}