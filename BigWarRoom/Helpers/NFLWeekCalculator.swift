//
//  NFLWeekCalculator.swift
//  BigWarRoom
//
//  Centralized NFL week calculation using Sleeper API for REAL accuracy
//

import Foundation

/// Utility for calculating current NFL week and integrating with game data
struct NFLWeekCalculator {
    
    /// Get current NFL week from WeekSelectionManager (SSOT for user-selected week)
    /// This returns what the USER wants to view, not necessarily the current NFL week
    static func getCurrentWeek() -> Int {
        // 🔥 FIX: Use WeekSelectionManager as SSOT, not NFLWeekService
        return WeekSelectionManager.shared.selectedWeek
    }
    
    /// Calculate current NFL week based on calendar date (fallback when API unavailable)
    static func calculateCurrentWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let year = getCurrentSeasonYear()
        
        // Known season start dates
        let seasonStartDate: Date
        if year == 2025 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 4))!
        } else if year == 2024 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        } else {
            // Fallback: find first Thursday of September
            var startDate = calendar.date(from: DateComponents(year: year, month: 9, day: 1))!
            while calendar.component(.weekday, from: startDate) != 5 { // Thursday = 5
                startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            }
            seasonStartDate = startDate
        }
        
        // Calculate weeks since season start
        let daysSinceStart = calendar.dateComponents([.day], from: seasonStartDate, to: now).day ?? 0
        let weeksSinceStart = daysSinceStart / 7
        
        // NFL regular season is 18 weeks (Week 1 through Week 18)
        // Playoffs would be after Week 18
        let calculatedWeek = min(max(weeksSinceStart + 1, 1), 18)
        
        DebugPrint(mode: .weekCheck, "📅 NFLWeekCalculator.calculateCurrentWeek: Calculated week \(calculatedWeek) based on date")
        
        return calculatedWeek
    }
    
    /// Setup real NFL game data for the calculated current week
    static func setupCurrentWeekGameData(gameDataService: NFLGameDataService) {
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentSeasonYear()
        
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