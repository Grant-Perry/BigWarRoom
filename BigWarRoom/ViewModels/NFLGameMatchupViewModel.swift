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

    func configure(for team: String, week: Int, year: Int = 2024) {
        gameDataService.$gameData
            .map { [weak self] gameData in
                let normalizedTeam = self?.normalizeTeamAbbreviation(team.uppercased()) ?? team.uppercased()
                let gameInfo = gameData[normalizedTeam]
                return gameInfo
            }
            .removeDuplicates { oldInfo, newInfo in
                guard let oldInfo, let newInfo else { return oldInfo == nil && newInfo == nil }
                return oldInfo.matchupString == newInfo.matchupString &&
                    oldInfo.formattedGameTime == newInfo.formattedGameTime &&
                    oldInfo.scoreString == newInfo.scoreString &&
                    oldInfo.isLive == newInfo.isLive
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.gameInfo, on: self)
            .store(in: &cancellables)
        gameDataService.$isLoading
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        if gameDataService.gameData.isEmpty {
            gameDataService.fetchGameData(forWeek: week, year: year)
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