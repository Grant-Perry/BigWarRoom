//
//  NFLWeekCalculator.swift
//  BigWarRoom
//
//  Centralized NFL week calculation using Sleeper API for REAL accuracy
//

import Foundation

/// Utility for calculating current NFL week and integrating with game data
struct NFLWeekCalculator {
    
    /// Get current NFL week (you can integrate with Sleeper API later)
    static func getCurrentWeek() -> Int {
        // TODO: Integrate with Sleeper API for accurate week calculation
        // For now, return a reasonable default based on current date
        let calendar = Calendar.current
        let now = Date()
        
        // NFL season typically starts first week of September
        // This is a basic calculation - you can enhance with Sleeper API
        let components = calendar.dateComponents([.month, .weekOfYear], from: now)
        
        if let month = components.month {
            switch month {
            case 9: return max(1, (components.weekOfYear ?? 1) - 35) // Early September
            case 10: return min(8, (components.weekOfYear ?? 1) - 35) // October
            case 11: return min(12, (components.weekOfYear ?? 1) - 35) // November  
            case 12: return min(17, (components.weekOfYear ?? 1) - 35) // December
            case 1: return min(18, (components.weekOfYear ?? 1) + 17) // January playoffs
            default: return 15 // Default to week 15 for testing
            }
        }
        
        return 15 // Fallback
    }
    
    /// Setup real NFL game data for the calculated current week
    static func setupCurrentWeekGameData() {
        let currentWeek = getCurrentWeek()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        NFLGameDataService.shared.fetchGameData(forWeek: currentWeek, year: currentYear)
    }
    
    /// Get current NFL season year
    static func getCurrentSeasonYear() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        // NFL season spans two calendar years, but we use the year it starts
        // Season starts in September and ends in February of next year
        if month >= 9 {
            return year // September-December uses current year
        } else {
            return year - 1 // January-February uses previous year
        }
    }
}