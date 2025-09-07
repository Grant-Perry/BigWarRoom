//
//  NFLGameMatchupViewModel.swift
//  BigWarRoom
//
//  View model for displaying real NFL game matchup data
//
// MARK: -> NFL Game Matchup View Model

import SwiftUI
import Combine

class NFLGameMatchupViewModel: ObservableObject {
    @Published var gameInfo: NFLGameInfo?
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let gameDataService = NFLGameDataService.shared
    
    /// Configure the view model for a specific team
    func configure(for team: String, week: Int, year: Int = 2024) {
        print("🔧 NFLGameMatchupViewModel: Configuring for team '\(team)'")
        
        // Subscribe to game data updates with team normalization
        gameDataService.$gameData
            .map { [weak self] gameData in
                let normalizedTeam = self?.normalizeTeamAbbreviation(team.uppercased()) ?? team.uppercased()
                let gameInfo = gameData[normalizedTeam]
                print("🔧 NFLGameMatchupViewModel: '\(team)' -> '\(normalizedTeam)' | Found: \(gameInfo != nil)")
                return gameInfo
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.gameInfo, on: self)
            .store(in: &cancellables)
        
        // Subscribe to loading state
        gameDataService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Fetch initial data if not available
        if gameDataService.gameData.isEmpty {
            gameDataService.fetchGameData(forWeek: week, year: year)
        }
    }
    
    /// Refresh game data
    func refresh(week: Int, year: Int = 2024) {
        gameDataService.fetchGameData(forWeek: week, year: year, forceRefresh: true)
    }
    
    /// Normalize team abbreviations to match ESPN's NFL API
    private func normalizeTeamAbbreviation(_ team: String) -> String {
        switch team.uppercased() {
        case "WAS":
            print("🔧 NFLGameMatchupViewModel: NORMALIZING WAS -> WSH")
            return "WSH"  // ESPN uses WSH for Washington
        default:
            return team.uppercased()
        }
    }
}