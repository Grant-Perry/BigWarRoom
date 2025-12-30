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
        // Use NFLWeekService for accurate week calculation
        return NFLWeekService.shared.currentWeek
    }
    
    /// Setup real NFL game data for the calculated current week
    static func setupCurrentWeekGameData(gameDataService: NFLGameDataService) {
        let currentWeek = getCurrentWeek()
        let currentYear = Calendar.current.component(.year, from: Date())
        
        gameDataService.fetchGameData(forWeek: currentWeek, year: currentYear)
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