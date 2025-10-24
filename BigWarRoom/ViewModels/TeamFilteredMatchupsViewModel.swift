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
    
    /// The ScheduleGame object is the source of truth
    @Published var gameData: ScheduleGame?
    
    /// Explicit ready state - true when both matchups and team codes are available
    @Published var isReadyToFilter: Bool = false

    private var lastFilteredAwayTeam: String = ""
    private var lastFilteredHomeTeam: String = ""
    
    // MARK: - Dependencies
    private let matchupsHubViewModel: MatchupsHubViewModel
    private var cancellables = Set<AnyCancellable>()
    
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
        setupCombineChaining()
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

        // IMPORTANT: Don't call performFiltering() here - let the Combine pipeline handle it
        // This prevents the double-call race condition
    }
    
    /// Refresh the filtered data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        // Refresh the main hub data first
        await matchupsHubViewModel.manualRefresh()
        
        // No need to set isLoading to false here, the Combine pipeline will
        // handle it once the matchupsHubViewModel.myMatchups publisher emits
        // a new value and performFiltering() is called.
    }
    
    // MARK: - Private Methods
    
    /// Setup Combine pipeline to watch matchups readiness
    private func setupCombineChaining() {
        // Create a publisher that emits when matchups are available
        let readyStatePublisher = matchupsHubViewModel.$myMatchups
            .map { !$0.isEmpty }
            .map { hasMatchups in
                logDebug("Matchups loaded: \(hasMatchups), Ready: \(hasMatchups)", category: "TeamFilter")
                return hasMatchups
            }
            .removeDuplicates()
        
        // Update isReadyToFilter state
        readyStatePublisher
            .assign(to: &$isReadyToFilter)
        
        // Trigger filtering whenever the selected game changes AND the data is ready
        // Add a small delay to ensure gameData is fully set before filtering
        Publishers.CombineLatest(
            readyStatePublisher,
            $gameData
        )
        .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
        .sink { [weak self] isReady, game in
            guard let self = self, isReady, let game = game else { 
                logDebug("Filter skipped - Ready: \(isReady), Game: \(game?.id ?? "nil")", category: "TeamFilter")
                return 
            }
            
            logDebug("Executing filter: Game data ready: \(game.id)", category: "TeamFilter")
            self.performFiltering()
            self.isLoading = false
            logDebug("Filter complete: Cleared loading states", category: "TeamFilter")
        }
        .store(in: &cancellables)
        
        // Also watch for changes in the actual matchups data (for refreshes)
        matchupsHubViewModel.$myMatchups
            .filter { [weak self] _ in
                // Only refilter if we have a game selected and are ready
                guard let self = self else { return false }
                return self.gameData != nil && self.isReadyToFilter
            }
            .sink { [weak self] _ in
                logDebug("Matchups updated: Refiltering...", category: "TeamFilter")
                self?.performFiltering()
            }
            .store(in: &cancellables)
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