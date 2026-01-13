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
        } else if year == 2026 {
            // 2026 season will start (estimated first Thursday of September)
            seasonStartDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 4))!
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
        
        // 🔥 FIX: If we're BEFORE the season starts, return Week 1 as fallback
        guard daysSinceStart >= 0 else {
            DebugPrint(mode: .weekCheck, "📅 NFLWeekCalculator: Current date is BEFORE season start, defaulting to Week 1")
            return 1
        }
        
        let weeksSinceStart = daysSinceStart / 7
        
        // 🔥 FIX: Allow weeks > 18 for playoffs (don't cap at 18)
        // Playoffs are weeks 19-23:
        // Week 19 = Wild Card
        // Week 20 = Divisional
        // Week 21 = Conference Championship
        // Week 22 = Pro Bowl
        // Week 23 = Super Bowl
        let calculatedWeek = weeksSinceStart + 1
        
        DebugPrint(mode: .weekCheck, "📅 NFLWeekCalculator.calculateCurrentWeek: Days since \(year) season start: \(daysSinceStart), Calculated week: \(calculatedWeek)")
        
        // Cap at Week 23 (Super Bowl is the last possible week)
        return min(calculatedWeek, 23)
    }
    
    /// Setup real NFL game data for the calculated current week
    static func setupCurrentWeekGameData(gameDataService: NFLGameDataService) {
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentSeasonYear()
        
        gameDataService.fetchGameData(forWeek: currentWeek, year: currentYear)
    }
    
    /// Get current NFL season year
    /// Returns the year the season STARTED (not the calendar year)
    static func getCurrentSeasonYear() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        // NFL season spans two calendar years, but we use the year it starts
        // Season starts in September and ends in February of next year
        // Examples:
        // - January 2026 → 2025 season (playoffs)
        // - September 2025 → 2025 season (regular season starts)
        // - August 2025 → 2025 season (preseason)
        if month >= 3 { // March through December = current year's season
            return year
        } else { // January-February = previous year's season (playoffs)
            return year - 1
        }
    }
}