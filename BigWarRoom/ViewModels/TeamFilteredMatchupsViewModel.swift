//
//  TeamFilteredMatchupsViewModel.swift
//  BigWarRoom
//
//  ViewModel for filtering matchups by NFL team selection
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for team-filtered matchups from Schedule tap
@MainActor
@Observable
final class TeamFilteredMatchupsViewModel {
    
    // MARK: - Observable Properties
    var filteredMatchups: [UnifiedMatchup] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    /// The ScheduleGame object is the source of truth
    var gameData: ScheduleGame?
    
    /// Explicit ready state - true when both matchups and team codes are available
    var isReadyToFilter: Bool = false

    private var lastFilteredAwayTeam: String = ""
    private var lastFilteredHomeTeam: String = ""
    
    // MARK: - Dependencies
    private let matchupsHubViewModel: MatchupsHubViewModel
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Teams display string (e.g., "WSH vs GB")
    var teamsDisplayString: String {
        guard let game = gameData else { return "" }
        return "\(game.awayTeam) vs \(game.homeTeam)"
    }
    
    /// Header title for filtered view
    var headerTitle: String {
        return "MATCHUPS FOR \(teamsDisplayString)"
    }
    
    /// Check if we have any matchups
    var hasMatchups: Bool {
        return !filteredMatchups.isEmpty
    }
    
    /// Show loading state - simplified logic
    var shouldShowLoadingState: Bool {
        guard let game = gameData else { return false }

        let normalizedAway = normalizeTeamCode(game.awayTeam)
        let normalizedHome = normalizeTeamCode(game.homeTeam)
        let filterIsForCurrentSelection = (lastFilteredAwayTeam == normalizedAway && lastFilteredHomeTeam == normalizedHome)

        return isLoading || !filterIsForCurrentSelection
    }
    
    // MARK: - Initialization
    
    init(matchupsHubViewModel: MatchupsHubViewModel) {
        self.matchupsHubViewModel = matchupsHubViewModel
        setupObservation()
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    // MARK: - Public Methods
    
    /// Filter matchups by selected NFL teams using ScheduleGame object
    func filterMatchups(for game: ScheduleGame) {
        logInfo("Filtering requested for game ID: \(game.id)", category: "TeamFilter")
        logDebug("isReadyToFilter: \(isReadyToFilter), Hub matchups: \(matchupsHubViewModel.myMatchups.count)", category: "TeamFilter")

        // Clear filtered matchups to force empty state while loading
        filteredMatchups = []

        // Use the game object to set the state
        self.gameData = game

        // Reset last filtered to force loading state for new selection
        lastFilteredAwayTeam = ""
        lastFilteredHomeTeam = ""

        // Explicitly set loading state
        isLoading = true

        logDebug("Set loading state - isLoading: \(isLoading)", category: "TeamFilter")

        // The observation task will handle filtering when conditions are met
    }
    
    /// Refresh the filtered data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        // Refresh the main hub data first
        await matchupsHubViewModel.manualRefresh()
        
        // The observation task will handle re-filtering when matchups update
    }
    
    // MARK: - Private Methods
    
    /// Setup @Observable observation to watch for changes
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedMatchupsReady = false
            var lastObservedGameData: ScheduleGame? = nil
            var lastObservedMatchupsCount = 0
            
            while !Task.isCancelled {
                let hasMatchups = !matchupsHubViewModel.myMatchups.isEmpty
                let currentGameData = gameData
                let currentMatchupsCount = matchupsHubViewModel.myMatchups.count
                
                // Update ready state
                if hasMatchups != isReadyToFilter {
                    isReadyToFilter = hasMatchups
                    logDebug("Matchups loaded: \(hasMatchups), Ready: \(hasMatchups)", category: "TeamFilter")
                }
                
                // Check if conditions changed for filtering
                let readyChanged = hasMatchups != lastObservedMatchupsReady
                let gameChanged = (currentGameData?.id != lastObservedGameData?.id)
                let matchupsCountChanged = currentMatchupsCount != lastObservedMatchupsCount
                
                if (readyChanged || gameChanged) && hasMatchups && currentGameData != nil {
                    logDebug("Executing filter: Game data ready: \(currentGameData?.id ?? "nil")", category: "TeamFilter")
                    
                    // Small delay to ensure state is settled
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    performFiltering()
                    isLoading = false
                    logDebug("Filter complete: Cleared loading states", category: "TeamFilter")
                }
                
                // Also refilter if matchups data changed (for refreshes)
                if matchupsCountChanged && hasMatchups && currentGameData != nil && isReadyToFilter {
                    logDebug("Matchups updated: Refiltering...", category: "TeamFilter")
                    performFiltering()
                }
                
                lastObservedMatchupsReady = hasMatchups
                lastObservedGameData = currentGameData
                lastObservedMatchupsCount = currentMatchupsCount
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    /// Perform the actual filtering logic
    private func performFiltering() {
        logDebug("Perform filtering start: gameData exists: \(gameData != nil)", category: "TeamFilter")

        guard let game = gameData else {
            logDebug("No game data to filter with", category: "TeamFilter")
            filteredMatchups = []
            return
        }

        guard isReadyToFilter else {
            logDebug("Not ready to filter yet", category: "TeamFilter")
            return
        }

        // Use the team codes from the gameData object
        let normalizedAway = normalizeTeamCode(game.awayTeam)
        let normalizedHome = normalizeTeamCode(game.homeTeam)
        let targetTeams = Set([normalizedAway, normalizedHome])

        logDebug("Filtering for normalized teams: \(targetTeams)", category: "TeamFilter")
        logDebug("Available matchups: \(matchupsHubViewModel.myMatchups.count)", category: "TeamFilter")

        var foundMatchups: [UnifiedMatchup] = []

        for matchup in matchupsHubViewModel.myMatchups {
            let hasPlayers = hasPlayersFromTeams(in: matchup, teams: targetTeams)

            if hasPlayers {
                foundMatchups.append(matchup)
            }
        }

        filteredMatchups = foundMatchups
        lastFilteredAwayTeam = normalizedAway
        lastFilteredHomeTeam = normalizedHome

        logInfo("Found \(foundMatchups.count) matching matchups for game \(game.id)", category: "TeamFilter")
    }
    
    /// Check if a matchup has players from the specified NFL teams
    private func hasPlayersFromTeams(in matchup: UnifiedMatchup, teams: Set<String>) -> Bool {
        // Only get players from YOUR team's roster - not opponent's
        guard let myTeam = matchup.myTeam else {
            return false
        }

        let myPlayers = myTeam.roster

        // Check if any of YOUR players are on the target NFL teams
        let hasMatchingPlayers = myPlayers.contains { player in
            guard let rawTeam = player.team?.uppercased() else {
                return false
            }

            let playerTeam = normalizeTeamCode(rawTeam)
            return teams.contains(playerTeam)
        }

        return hasMatchingPlayers
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
    
    /// 🔧 Normalize NFL team codes across data sources to canonical forms
    private func normalizeTeamCode(_ code: String) -> String {
        let upper = code.uppercased()
        let map: [String: String] = [
            // Commanders
            "WSH": "WSH", "WAS": "WSH",
            // Jaguars
            "JAX": "JAX", "JAC": "JAX",
            // Raiders
            "LV": "LV", "LVR": "LV", "OAK": "LV",
            // Rams
            "LAR": "LAR", "LA": "LAR", "STL": "LAR",
            // Chargers
            "LAC": "LAC", "SD": "LAC",
            // Patriots
            "NE": "NE", "NWE": "NE",
            // Packers
            "GB": "GB", "GNB": "GB",
            // 49ers
            "SF": "SF", "SFO": "SF",
            // Saints
            "NO": "NO", "NOR": "NO",
            // Buccaneers
            "TB": "TB", "TBB": "TB",
            // Chiefs
            "KC": "KC", "KCC": "KC"
            // The rest map to themselves by default
        ]
        return map[upper] ?? upper
    }
    
    /// 🔥 Clear filter state to prevent stale data on next sheet open
    func clearFilterState() {
        logInfo("Clearing filter state", category: "TeamFilter")
        filteredMatchups = []
        gameData = nil
        isLoading = false
        lastFilteredAwayTeam = ""
        lastFilteredHomeTeam = ""
    }
}