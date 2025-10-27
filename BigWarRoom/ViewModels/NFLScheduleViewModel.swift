//
//  NFLScheduleViewModel.swift
//  BigWarRoom
//
//  NFL Schedule data management with stunning visual presentation
//
// MARK: -> NFL Schedule ViewModel

import SwiftUI
import Foundation
import Observation

@MainActor
@Observable
final class NFLScheduleViewModel {
    var games: [ScheduleGame] = []
    var isLoading = false
    var errorMessage: String?
    var selectedWeek: Int
    var selectedGame: ScheduleGame?
    var showingGameDetail = false
    var selectedGameId: String? // For NavigationLink selection
    
    private let gameDataService = NFLGameDataService.shared
    private let weekService = NFLWeekService.shared
    private var observationTask: Task<Void, Never>?
    
    init() {
        self.selectedWeek = weekService.currentWeek
        setupObservation()
        
        // Initial data load
        refreshSchedule()
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedGameData: [String: NFLGameInfo] = [:]
            var lastObservedIsLoading = false
            var lastObservedErrorMessage: String? = nil
            
            while !Task.isCancelled {
                let currentGameData = gameDataService.gameData
                let currentIsLoading = gameDataService.isLoading
                let currentErrorMessage = gameDataService.errorMessage
                
                // Check for game data changes
                if currentGameData != lastObservedGameData {
                    processGameData(currentGameData)
                    lastObservedGameData = currentGameData
                }
                
                // Check for loading state changes
                if currentIsLoading != lastObservedIsLoading {
                    isLoading = currentIsLoading
                    lastObservedIsLoading = currentIsLoading
                }
                
                // Check for error message changes
                if currentErrorMessage != lastObservedErrorMessage {
                    errorMessage = currentErrorMessage
                    lastObservedErrorMessage = currentErrorMessage
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            }
        }
    }
    
    /// Refresh schedule data for current week
    func refreshSchedule() {
        gameDataService.fetchGameData(forWeek: selectedWeek, forceRefresh: true)
    }
    
    /// Change selected week and refresh data
    func selectWeek(_ week: Int) {
        selectedWeek = week
        refreshSchedule()
    }
    
    /// Process raw game data into schedule format
    private func processGameData(_ gameData: [String: NFLGameInfo]) {
        var processedGames: [ScheduleGame] = []
        var seenGames = Set<String>()
        
        for (_, gameInfo) in gameData {
            let gameKey = "\(gameInfo.awayTeam)@\(gameInfo.homeTeam)"
            let reverseKey = "\(gameInfo.homeTeam)@\(gameInfo.awayTeam)"
            
            // Avoid duplicates
            guard !seenGames.contains(gameKey) && !seenGames.contains(reverseKey) else { continue }
            seenGames.insert(gameKey)
            
            let scheduleGame = ScheduleGame(
                id: gameKey,
                awayTeam: gameInfo.awayTeam,
                homeTeam: gameInfo.homeTeam,
                awayScore: gameInfo.awayScore,
                homeScore: gameInfo.homeScore,
                gameStatus: gameInfo.gameStatus,
                gameTime: gameInfo.gameTime,
                startDate: gameInfo.startDate,
                isLive: gameInfo.isLive
            )
            
            processedGames.append(scheduleGame)
        }
        
        // STABLE SORT: Keep existing games in their current positions when possible
        let existingGameOrder = games.map { $0.id }
        
        // Sort by STABLE criteria - primarily by start date, not live status
        let sortedGames = processedGames.sorted { first, second in
            // First, try to maintain existing order for stability
            let firstIndex = existingGameOrder.firstIndex(of: first.id) ?? Int.max
            let secondIndex = existingGameOrder.firstIndex(of: second.id) ?? Int.max
            
            // If both games existed before, keep their original order
            if firstIndex != Int.max && secondIndex != Int.max {
                return firstIndex < secondIndex
            }
            
            // For new games or mixed cases, sort by start date only
            guard let firstDate = first.startDate,
                  let secondDate = second.startDate else {
                return first.gameStatus < second.gameStatus
            }
            
            return firstDate < secondDate
        }
        
        // Only update if there are actual changes to prevent unnecessary reordering
        let newGameIds = Set(sortedGames.map { $0.id })
        let existingGameIds = Set(games.map { $0.id })
        
        if newGameIds != existingGameIds || games.isEmpty {
            games = sortedGames
        } else {
            // Update game data but preserve order
            games = games.compactMap { existingGame in
                processedGames.first { $0.id == existingGame.id }
            }
        }
    }
    
    /// Show game detail with fantasy players
    func showGameDetail(for game: ScheduleGame) {
        selectedGame = game
        showingGameDetail = true
    }
}

// MARK: -> Schedule Game Model
struct ScheduleGame: Identifiable, Hashable {
    let id: String
    let awayTeam: String
    let homeTeam: String
    let awayScore: Int
    let homeScore: Int
    let gameStatus: String
    let gameTime: String
    let startDate: Date?
    let isLive: Bool
    
    /// Formatted day name for display
    var dayName: String {
        guard let date = startDate else { return "TBD" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        let dayName = formatter.string(from: date)
        
        return dayName
    }
    
    /// Formatted start time
    var startTime: String {
        guard let date = startDate else { return gameTime }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    /// Display time based on game status
    var displayTime: String {
        switch gameStatus.lowercased() {
        case "pre", "pregame":
            return startTime
        case "in", "live":
            // Parse the game time for quarter and clock
            if gameTime.contains("Quarter") || gameTime.contains("Q") {
                return parseGameTime(gameTime)
            }
            return "LIVE"
        case "post", "final":
            // Always show FINAL for completed games, regardless of score
            return "FINAL"
        default:
            if gameTime.contains("Final") || gameTime.contains("FINAL") {
                return "FINAL"
            }
            return startTime
        }
    }
    
    /// Parse ESPN game time format
    private func parseGameTime(_ time: String) -> String {
        // 🔥 FIXED: Handle ESPN formats like "15:00 - 4th Quarter", "2:30 - 3rd Quarter"
        let lowercaseTime = time.lowercased()
        
        var quarterDisplay = ""
        var timeDisplay = ""
        
        // 🔥 FIXED: Look for quarter information in the full string first
        if lowercaseTime.contains("1st quarter") || lowercaseTime.contains("1st qtr") {
            quarterDisplay = "Q1"
        } else if lowercaseTime.contains("2nd quarter") || lowercaseTime.contains("2nd qtr") {
            quarterDisplay = "Q2"
        } else if lowercaseTime.contains("3rd quarter") || lowercaseTime.contains("3rd qtr") {
            quarterDisplay = "Q3"
        } else if lowercaseTime.contains("4th quarter") || lowercaseTime.contains("4th qtr") {
            quarterDisplay = "Q4"
        } else if lowercaseTime.contains("1st") {
            quarterDisplay = "Q1"
        } else if lowercaseTime.contains("2nd") {
            quarterDisplay = "Q2"
        } else if lowercaseTime.contains("3rd") {
            quarterDisplay = "Q3"
        } else if lowercaseTime.contains("4th") {
            quarterDisplay = "Q4"
        } else if lowercaseTime.contains("ot") || lowercaseTime.contains("overtime") {
            quarterDisplay = "OT"
        } else if lowercaseTime.contains("halftime") || lowercaseTime.contains("half") {
            return "HALFTIME"
        } else if lowercaseTime.contains("final") {
            return "FINAL"
        } else {
            return "LIVE"
        }
        
        // 🔥 FIXED: Extract time component from beginning of string (before the dash)
        if let dashIndex = time.firstIndex(of: "-") {
            let timeString = String(time[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            if timeString.contains(":") {
                timeDisplay = timeString
            }
        } else {
            // Fallback: look for time component in any part of the string
            let components = time.components(separatedBy: " ")
            if let timeComponent = components.first(where: { $0.contains(":") }) {
                timeDisplay = timeComponent
            }
        }
        
        // Return formatted quarter and time
        if !quarterDisplay.isEmpty {
            if !timeDisplay.isEmpty {
                return "\(quarterDisplay) \(timeDisplay)"
            } else {
                return quarterDisplay
            }
        }
        
        return "LIVE"
    }
    
    private func extractTimeWithQuarter(_ quarter: String, from components: [String]) -> String {
        // Look for time component
        let timeComponent = components.first { $0.contains(":") }
        return timeComponent != nil ? "\(quarter) \(timeComponent!)" : quarter
    }
    
    /// Score display for live/final games
    var scoreDisplay: String {
        return "\(awayScore) - \(homeScore)"
    }
    
    /// Status color for UI
    var statusColor: Color {
        switch gameStatus.lowercased() {
        case "in", "live": return .red
        case "pre", "pregame": return .orange
        case "post", "final": return .gray
        default: return .orange
        }
    }
}