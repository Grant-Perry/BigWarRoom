//
//  SmartRefreshManager.swift
//  BigWarRoom
//
//  Smart refresh logic - determines optimal refresh intervals based on:
//  - Day of week (Tue/Wed = minimal refresh)
//  - Live game status (games playing = fast refresh)
//  - Kickoff times (pre-emptive speed up near kickoffs)
//

import Foundation
import SwiftUI

/// Manages smart refresh intervals based on NFL game schedule and day of week
@MainActor
@Observable
final class SmartRefreshManager {
    
    // MARK: - Singleton
    static let shared = SmartRefreshManager()
    
    // MARK: - Dependencies
    private let nflGameDataService: NFLGameDataService
    
    // MARK: - State
    private(set) var currentRefreshInterval: TimeInterval = TimeInterval(AppConstants.MatchupRefresh)
    private(set) var shouldShowCountdownTimer: Bool = true
    private(set) var refreshReason: String = "Default"
    private(set) var hasLiveGames: Bool = false
    
    // MARK: - Constants
    private let fastRefreshInterval: TimeInterval = TimeInterval(AppConstants.MatchupRefresh) // 15s for live games
    private let mediumRefreshInterval: TimeInterval = 60.0  // 1 minute for games starting soon
    private let slowRefreshInterval: TimeInterval = 900.0   // 15 minutes for games scheduled today
    private let dormantRefreshInterval: TimeInterval = 3600.0 // 1 hour for no-game days
    
    // MARK: - Init
    private init() {
        self.nflGameDataService = NFLGameDataService.shared
        // Calculate initial state
        Task { @MainActor in
            calculateOptimalRefresh()
        }
    }
    
    // For testing/injection
    init(nflGameDataService: NFLGameDataService) {
        self.nflGameDataService = nflGameDataService
    }
    
    // MARK: - Public API
    
    /// Calculates the optimal refresh interval and whether to show timer
    func calculateOptimalRefresh() {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        
        // Check if it's a "no-game" day (Tuesday = 3, Wednesday = 4)
        if isNoGameDay(weekday: weekday, date: now) {
            currentRefreshInterval = dormantRefreshInterval
            shouldShowCountdownTimer = false
            hasLiveGames = false
            refreshReason = "No games today (Tue/Wed)"
            DebugPrint(mode: .globalRefresh, "🔋 SMART REFRESH: No-game day - 1 hour interval, timer hidden")
            return
        }
        
        // Check live game status from NFLGameDataService
        let gameStatus = determineGameStatus()
        
        switch gameStatus {
        case .liveGamesPlaying:
            currentRefreshInterval = fastRefreshInterval
            shouldShowCountdownTimer = true
            hasLiveGames = true
            refreshReason = "Live games in progress"
            DebugPrint(mode: .globalRefresh, "🔥 SMART REFRESH: Live games - \(Int(fastRefreshInterval))s interval")
            
        case .gamesStartingSoon:
            currentRefreshInterval = mediumRefreshInterval
            shouldShowCountdownTimer = true
            hasLiveGames = false
            refreshReason = "Games starting soon"
            DebugPrint(mode: .globalRefresh, "⏰ SMART REFRESH: Games starting soon - 1 min interval")
            
        case .gamesScheduledToday:
            currentRefreshInterval = slowRefreshInterval
            shouldShowCountdownTimer = true
            hasLiveGames = false
            refreshReason = "Games scheduled today"
            DebugPrint(mode: .globalRefresh, "📅 SMART REFRESH: Games scheduled - 15 min interval")
            
        case .allGamesFinished:
            currentRefreshInterval = dormantRefreshInterval
            shouldShowCountdownTimer = false
            hasLiveGames = false
            refreshReason = "All games finished"
            DebugPrint(mode: .globalRefresh, "✅ SMART REFRESH: All games finished - 1 hour interval, timer hidden")
            
        case .noGamesToday:
            currentRefreshInterval = dormantRefreshInterval
            shouldShowCountdownTimer = false
            hasLiveGames = false
            refreshReason = "No games today"
            DebugPrint(mode: .globalRefresh, "😴 SMART REFRESH: No games today - 1 hour interval, timer hidden")
        }
    }
    
    /// Call this after any manual refresh (PTR) to recalculate
    func scheduleNextRefresh() {
        calculateOptimalRefresh()
    }
    
    // MARK: - Private Helpers
    
    private enum GameStatus {
        case liveGamesPlaying
        case gamesStartingSoon
        case gamesScheduledToday
        case allGamesFinished
        case noGamesToday
    }
    
    /// Determines if today is a "no-game" day
    private func isNoGameDay(weekday: Int, date: Date) -> Bool {
        // Tuesday = 3, Wednesday = 4 in Calendar
        // These are typically no-game days EXCEPT:
        // - Black Friday (Friday after Thanksgiving)
        // - Playoff Saturdays (late December/January)
        
        switch weekday {
        case 3, 4: // Tuesday, Wednesday
            return true
            
        case 6: // Friday
            // Check if it's Black Friday (4th Thursday of November + 1 day)
            if isBlackFriday(date: date) {
                return false // Black Friday HAS games
            }
            // Regular Friday - might have games, check schedule
            return !hasGamesToday()
            
        case 7: // Saturday
            // Playoff Saturdays have games (typically weeks 15-18 and playoffs)
            // Regular season Saturdays typically don't until late
            if isPlayoffPeriod(date: date) {
                return false // Playoff period HAS Saturday games
            }
            return !hasGamesToday()
            
        default:
            // Sunday (1), Monday (2), Thursday (5) - game days
            return false
        }
    }
    
    /// Check if date is Black Friday
    private func isBlackFriday(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.component(.weekday, from: date)
        
        // Black Friday is the Friday (weekday 6) after Thanksgiving
        // Thanksgiving is 4th Thursday of November
        // So Black Friday is between Nov 23-29 and is a Friday
        return month == 11 && weekday == 6 && day >= 23 && day <= 29
    }
    
    /// Check if we're in playoff period (late December through February)
    private func isPlayoffPeriod(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Playoff period: mid-December through early February
        // Week 15+ typically starts mid-December
        if month == 12 && day >= 14 {
            return true
        }
        if month == 1 || month == 2 {
            return true
        }
        return false
    }
    
    /// Check if there are any games scheduled today
    private func hasGamesToday() -> Bool {
        let games = Array(nflGameDataService.gameData.values)
        guard !games.isEmpty else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return games.first(where: { game in
            guard let gameDate = game.startDate else { return false }
            return calendar.isDate(gameDate, inSameDayAs: today)
        }) != nil
    }
    
    /// Determines current game status from NFL game data
    private func determineGameStatus() -> GameStatus {
        let games = Array(nflGameDataService.gameData.values)
        
        // No games loaded
        guard !games.isEmpty else {
            return .noGamesToday
        }
        
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        // Filter to today's games only
        let todaysGames = games.filter { game in
            guard let gameDate = game.startDate else { return false }
            return calendar.isDate(gameDate, inSameDayAs: today)
        }
        
        guard !todaysGames.isEmpty else {
            return .noGamesToday
        }
        
        // Check for live games using the isLive property or gameStatus
        let liveGames = todaysGames.filter { game in
            game.isLive || game.gameStatus.lowercased().contains("in") || 
            game.gameStatus.lowercased().contains("1st") || 
            game.gameStatus.lowercased().contains("2nd") || 
            game.gameStatus.lowercased().contains("3rd") || 
            game.gameStatus.lowercased().contains("4th") ||
            game.gameStatus.lowercased().contains("ot") ||
            game.gameStatus.lowercased() == "halftime"
        }
        
        if !liveGames.isEmpty {
            return .liveGamesPlaying
        }
        
        // Check for games starting soon (within 30 minutes)
        let soonGames = todaysGames.filter { game in
            guard let gameDate = game.startDate else { return false }
            let timeUntilGame = gameDate.timeIntervalSince(now)
            return timeUntilGame > 0 && timeUntilGame <= 1800 // 30 minutes
        }
        
        if !soonGames.isEmpty {
            return .gamesStartingSoon
        }
        
        // Check for games scheduled later today
        let upcomingGames = todaysGames.filter { game in
            guard let gameDate = game.startDate else { return false }
            return gameDate > now
        }
        
        if !upcomingGames.isEmpty {
            return .gamesScheduledToday
        }
        
        // All games must be finished
        return .allGamesFinished
    }
}
