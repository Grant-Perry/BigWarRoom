//
//  TeamFilteredMatchupsViewModel.swift
//  BigWarRoom
//
//  ViewModel for filtering matchups by NFL team selection
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for team-filtered matchups from Schedule tap
@MainActor
final class TeamFilteredMatchupsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var filteredMatchups: [UnifiedMatchup] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedAwayTeam: String = ""
    @Published var selectedHomeTeam: String = ""
    
    // MARK: - Dependencies
    private let matchupsHubViewModel: MatchupsHubViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Teams display string (e.g., "WSH vs GB")
    var teamsDisplayString: String {
        return "\(selectedAwayTeam) vs \(selectedHomeTeam)"
    }
    
    /// Header title for filtered view
    var headerTitle: String {
        return "MATCHUPS FOR \(teamsDisplayString)"
    }
    
    /// Check if we have any matchups
    var hasMatchups: Bool {
        return !filteredMatchups.isEmpty
    }
    
    // MARK: - Initialization
    
    init(matchupsHubViewModel: MatchupsHubViewModel) {
        self.matchupsHubViewModel = matchupsHubViewModel
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Filter matchups by selected NFL teams
    func filterMatchups(awayTeam: String, homeTeam: String) {
        selectedAwayTeam = awayTeam
        selectedHomeTeam = homeTeam
        performFiltering()
    }
    
    /// Refresh the filtered data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        // Refresh the main hub data first
        await matchupsHubViewModel.manualRefresh()
        
        // Then refilter
        performFiltering()
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for changes in main hub data
    private func setupObservers() {
        // Watch for changes in main matchups data
        matchupsHubViewModel.$myMatchups
            .sink { [weak self] _ in
                self?.performFiltering()
            }
            .store(in: &cancellables)
    }
    
    /// Perform the actual filtering logic
    private func performFiltering() {
        guard !selectedAwayTeam.isEmpty && !selectedHomeTeam.isEmpty else {
            filteredMatchups = []
            return
        }
        
        let targetTeams = Set([selectedAwayTeam.uppercased(), selectedHomeTeam.uppercased()])
        
        filteredMatchups = matchupsHubViewModel.myMatchups.filter { matchup in
            hasPlayersFromTeams(in: matchup, teams: targetTeams)
        }
    }
    
    /// Check if a matchup has players from the specified NFL teams
    private func hasPlayersFromTeams(in matchup: UnifiedMatchup, teams: Set<String>) -> Bool {
        // Get all players from the matchup (both starters and bench)
        var allPlayers: [FantasyPlayer] = []
        
        // Add my team's players
        if let myTeam = matchup.myTeam {
            allPlayers.append(contentsOf: myTeam.roster)
        }
        
        // For regular matchups, also check opponent's players
        if !matchup.isChoppedLeague, let opponentTeam = matchup.opponentTeam {
            allPlayers.append(contentsOf: opponentTeam.roster)
        }
        
        // Check if any player is from the target NFL teams
        return allPlayers.contains { player in
            guard let playerTeam = player.team?.uppercased() else { return false }
            return teams.contains(playerTeam)
        }
    }
    
    // MARK: - Delegation Methods (Pass-through to main ViewModel)
    
    /// Get sorted matchups (reuse main ViewModel logic)
    func sortedMatchups(sortByWinning: Bool) -> [UnifiedMatchup] {
        if sortByWinning {
            return filteredMatchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 > score2
            }
        } else {
            return filteredMatchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 < score2
            }
        }
    }
    
    /// Get winning status for matchup (delegate to main ViewModel)
    func getWinningStatusForMatchup(_ matchup: UnifiedMatchup) -> Bool {
        return matchupsHubViewModel.getWinningStatusForMatchup(matchup)
    }
    
    /// Get score color for matchup (delegate to main ViewModel)
    func getScoreColorForMatchup(_ matchup: UnifiedMatchup) -> Color {
        return matchupsHubViewModel.getScoreColorForMatchup(matchup)
    }
    
    /// Count of live matchups
    func liveMatchupsCount() -> Int {
        return matchupsHubViewModel.liveMatchupsCount(from: filteredMatchups)
    }
    
    /// Count of winning matchups
    func winningMatchupsCount() -> Int {
        return matchupsHubViewModel.winningMatchupsCount(from: filteredMatchups)
    }
    
    /// Format relative time (delegate to main ViewModel)
    func timeAgo(_ date: Date) -> String {
        return matchupsHubViewModel.timeAgo(date)
    }
}