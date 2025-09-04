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
        // Subscribe to game data updates
        gameDataService.$gameData
            .map { gameData in
                gameData[team.uppercased()]
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
}