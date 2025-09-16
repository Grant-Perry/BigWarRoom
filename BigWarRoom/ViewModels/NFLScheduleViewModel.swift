//
//  NFLScheduleViewModel.swift
//  BigWarRoom
//
//  NFL Schedule data management with stunning visual presentation
//
// MARK: -> NFL Schedule ViewModel

import SwiftUI
import Foundation
import Combine

@MainActor
final class NFLScheduleViewModel: ObservableObject {
    @Published var games: [ScheduleGame] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWeek: Int
    @Published var selectedGame: ScheduleGame?
    @Published var showingGameDetail = false
    
    private var cancellables = Set<AnyCancellable>()
    private let gameDataService = NFLGameDataService.shared
    private let weekService = NFLWeekService.shared
    
    init() {
        self.selectedWeek = weekService.currentWeek
        
        // Subscribe to game data updates
        gameDataService.$gameData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gameData in
                self?.processGameData(gameData)
            }
            .store(in: &cancellables)
        
        // Subscribe to loading state
        gameDataService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Subscribe to error messages
        gameDataService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Initial data load
        refreshSchedule()
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
            
            // DEBUG: Print game info to see what we're getting
            print("🏈 Schedule Game: \(gameInfo.awayTeam) @ \(gameInfo.homeTeam) - Status: \(gameInfo.gameStatus) - Scores: \(gameInfo.awayScore)-\(gameInfo.homeScore)")
        }
        
        // Sort by game time, live games first, then by start date
        games = processedGames.sorted { first, second in
            if first.isLive && !second.isLive { return true }
            if !first.isLive && second.isLive { return false }
            
            // If both are final games, sort by start date
            if first.gameStatus.lowercased().contains("final") && second.gameStatus.lowercased().contains("final") {
                guard let firstDate = first.startDate, let secondDate = second.startDate else {
                    return first.gameStatus < second.gameStatus
                }
                return firstDate < secondDate
            }
            
            // Sort by start date
            guard let firstDate = first.startDate,
                  let secondDate = second.startDate else {
                return first.gameStatus < second.gameStatus
            }
            
            return firstDate < secondDate
        }
        
        print("🏈 Total games processed: \(games.count)")
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
        
        // DEBUG: Print the day name to see what we're getting
        print("🏈 Game day for \(awayTeam)@\(homeTeam): \(dayName)")
        
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
        // Handle formats like "2nd Quarter", "Q2 14:32", etc.
        let components = time.components(separatedBy: " ")
        
        for component in components {
            if component.lowercased().contains("1st") || component.contains("1") {
                return extractTimeWithQuarter("Q1", from: components)
            } else if component.lowercased().contains("2nd") || component.contains("2") {
                return extractTimeWithQuarter("Q2", from: components)
            } else if component.lowercased().contains("3rd") || component.contains("3") {
                return extractTimeWithQuarter("Q3", from: components)
            } else if component.lowercased().contains("4th") || component.contains("4") {
                return extractTimeWithQuarter("Q4", from: components)
            } else if component.lowercased().contains("ot") {
                return "OT"
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