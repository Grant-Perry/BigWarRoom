//
//  NFLGameMatchupViewModel.swift
//  BigWarRoom
//
//  View model for displaying real NFL game matchup data
//
// MARK: -> NFL Game Matchup View Model

import SwiftUI
import Observation

@MainActor
@Observable
final class NFLGameMatchupViewModel {
    var gameInfo: NFLGameInfo?
    var isLoading = false
    
    // 🔥 INJECT dependency instead of using .shared
    private let gameDataService: NFLGameDataService
    private var observationTask: Task<Void, Never>?

    // 🔥 DEPENDENCY INJECTION: Accept gameDataService via init
    init(gameDataService: NFLGameDataService) {
        self.gameDataService = gameDataService
        setupObservation()
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    private func setupObservation() {
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                let currentGameData = gameDataService.gameData
                let currentIsLoading = gameDataService.isLoading
                
                if currentIsLoading != isLoading {
                    isLoading = currentIsLoading
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    func configure(for team: String, week: Int, year: Int = 2024) {
        let normalizedTeam = normalizeTeamAbbreviation(team.uppercased())
        gameInfo = gameDataService.gameData[normalizedTeam]
        
        if gameDataService.gameData.isEmpty {
            gameDataService.fetchGameData(forWeek: week, year: year)
        }
        
        // Update observation to track this specific team's game info
        observationTask?.cancel()
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                let currentGameData = gameDataService.gameData
                let currentIsLoading = gameDataService.isLoading
                let newGameInfo = currentGameData[normalizedTeam]
                
                if currentIsLoading != isLoading {
                    isLoading = currentIsLoading
                }
                
                // Only update if game info actually changed
                if let oldInfo = gameInfo, let newInfo = newGameInfo {
                    if oldInfo.matchupString != newInfo.matchupString ||
                       oldInfo.formattedGameTime != newInfo.formattedGameTime ||
                       oldInfo.scoreString != newInfo.scoreString ||
                       oldInfo.isLive != newInfo.isLive {
                        gameInfo = newInfo
                    }
                } else if gameInfo != newGameInfo {
                    gameInfo = newGameInfo
                }
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    func refresh(week: Int, year: Int = 2024) {
        gameDataService.fetchGameData(forWeek: week, year: year, forceRefresh: true)
    }

    private func normalizeTeamAbbreviation(_ team: String) -> String {
        switch team.uppercased() {
        case "WAS": return "WSH"
        default: return team.uppercased()
        }
    }
}