//
//  AllLivePlayersViewModel.swift
//  BigWarRoom
//
//  🔥 REFACTORED: Core coordination only - all functionality moved to focused extensions
//  🔥 NO SINGLETON - Use dependency injection
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class AllLivePlayersViewModel {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: AllLivePlayersViewModel?
    
    static var shared: AllLivePlayersViewModel {
        if let existing = _shared {
            return existing
        }
        fatalError("AllLivePlayersViewModel.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: AllLivePlayersViewModel) {
        _shared = instance
    }
    
    // MARK: - 🔥 PHASE 3: @Observable State Properties (no @Published needed)
    var allPlayers: [LivePlayerEntry] = []
    var filteredPlayers: [LivePlayerEntry] = []
    var selectedPosition: PlayerPosition = .all
    var isLoading = false
    var isUpdating = false // 🔥 NEW: Track live update state for animation
    var errorMessage: String?
    var dataState: DataLoadingState = .initial
    
    // MARK: - UI State
    var sortHighToLow = true
    var sortingMethod: SortingMethod = .score
    var showActiveOnly: Bool = true // 🔥 SMART DEFAULT: Will be set to false if no live games on initial load
    var hasAppliedInitialActiveOnlyDefault = false // 🔥 Track if we've applied smart default
    var shouldResetAnimations = false
    var sortChangeID = UUID()
    var lastUpdateTime = Date()
    var searchText: String = ""
    var isSearching: Bool = false
    var showRosteredOnly: Bool = false // Changed to checkbox approach
    var allNFLPlayers: [SleeperPlayer] = [] // For All Players search
    
    // MARK: - Computed Statistics
    var topScore: Double = 0.0
    var medianScore: Double = 0.0
    var scoreRange: Double = 0.0
    var useAdaptiveScaling: Bool = false
    var positionTopScore: Double = 0.0
    
    // MARK: - Player Stats
    var playerStats: [String: [String: Double]] = [:]
    var statsLoaded: Bool = false
    
    // 🔥 PHASE 2.5: Accept dependencies instead of hardcoded .shared
    let matchupsHubViewModel: MatchupsHubViewModel
    internal let playerDirectory: PlayerDirectoryStore
    internal let gameStatusService: GameStatusService
    internal let sharedStatsService: SharedStatsService
    internal let weekSelectionManager: WeekSelectionManager
    
    // MARK: - Internal State (not published)
    internal var debounceTask: Task<Void, Never>?
    internal var isBatchingUpdates = false
    
    /// 🔥 REMOVED: No longer needed - using proper observation
    // internal var lastProcessedMatchupUpdate = Date.distantPast
    
    /// 🔥 REMOVED: Polling observation task - replaced with reactive observation
    // private var observationTask: Task<Void, Never>?
    
    // 🔥 NEW: Auto-refresh timer for live player data (every 15 seconds during games)
    internal var refreshTimer: Timer?
    var autoRefreshEnabled = true
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    @MainActor
    init(
        matchupsHubViewModel: MatchupsHubViewModel,
        playerDirectory: PlayerDirectoryStore,
        gameStatusService: GameStatusService,
        sharedStatsService: SharedStatsService,
        weekSelectionManager: WeekSelectionManager
    ) {
        self.matchupsHubViewModel = matchupsHubViewModel
        self.playerDirectory = playerDirectory
        self.gameStatusService = gameStatusService
        self.sharedStatsService = sharedStatsService
        self.weekSelectionManager = weekSelectionManager
        // 🔥 REMOVED: No more timers or polling
        // setupAutoRefresh()
        // setupObservation()
    }
    
    // MARK: - Cleanup
    @MainActor
    deinit {
        debounceTask?.cancel()
        // 🔥 REMOVED: No more polling to clean up
        // observationTask?.cancel()
        // refreshTimer?.invalidate()
    }
    
    /// 🔥 REMOVED: Polling observation - now using proper @Observable reactivity
    // private func setupObservation() { ... }
    
    /// 🔥 REMOVED: Auto-refresh timer - MatchupsHub handles refresh cycle
    // private func setupAutoRefresh() { ... }
}

// MARK: - Core Enums and Types
extension AllLivePlayersViewModel {
    enum DataLoadingState {
        case initial
        case loading
        case loaded
        case empty
        case error(String)
    }
    
    enum PlayerPosition: String, CaseIterable, Identifiable {
        case all = "All"
        case qb = "QB"
        case rb = "RB"
        case wr = "WR"
        case te = "TE"
        case k = "K"
        case def = "DEF"

        var id: String { rawValue }
        var displayName: String { rawValue }
    }
    
    enum SortingMethod: String, CaseIterable, Identifiable {
        case position = "Position"
        case score = "Score"
        case name = "Name"
        case team = "Team"
        case recent = "Recent Activity" // 🔥 NEW: Recent Activity sort

        var id: String { rawValue }
        var displayName: String { rawValue }
    }
    
    struct LivePlayerEntry: Identifiable {
        let id: String
        let player: FantasyPlayer
        let leagueName: String
        let leagueSource: String
        let currentScore: Double
        let projectedScore: Double
        let isStarter: Bool
        let percentageOfTop: Double
        let matchup: UnifiedMatchup
        let performanceTier: PerformanceTier
        
        // 🔥 NEW: Activity tracking for recent sort
        var lastActivityTime: Date?
        var previousScore: Double?
        var accumulatedDelta: Double    // Sticky delta for pill, survives refreshes
        
        // 🔥 REMOVED: These are now on FantasyPlayer model itself!
        // Access via: playerEntry.player.injuryStatus
        // Access via: playerEntry.player.jerseyNumber

        var scoreBarWidth: Double {
            let minBarWidth: Double = 0.08
            let scalableWidth: Double = 0.92
            return minBarWidth + (percentageOfTop * scalableWidth)
        }

        var position: String { player.position }
        var teamName: String { player.team ?? "" }
        var playerName: String { player.fullName }
        var currentScoreString: String { String(format: "%.2f", currentScore) }
        
        // 🔥 NEW: Check if player had recent activity
        var hasRecentActivity: Bool {
            guard let activityTime = lastActivityTime else { return false }
            return Date().timeIntervalSince(activityTime) < 300 // 5 minutes
        }
        
        // 🔥 NEW: Check if score changed (for activity tracking)
        var scoreChanged: Bool {
            guard let previous = previousScore else { return false }
            return abs(currentScore - previous) > 0.01 // Account for floating point precision
        }
    }
    
    enum PerformanceTier: String, CaseIterable {
        case elite = "Elite"
        case good = "Good"
        case average = "Average"
        case struggling = "Struggling"

        var color: Color {
            switch self {
            case .elite: return .gpGreen
            case .good: return .blue
            case .average: return .orange
            case .struggling: return .red
            }
        }
    }
}

// MARK: - Core Coordination Methods
extension AllLivePlayersViewModel {
    /// Main entry point for loading data
    func loadAllPlayers() async {
        await performDataLoad()
    }
    
    /// Main entry point for refreshing data
    func refresh() async {
        // 🔥 NO THROTTLING: Always fetch fresh data from APIs
        DebugPrint(mode: .liveUpdates, "🔄 AUTO-REFRESH: Performing background live update")
        await performLiveUpdate()
    }
    
    /// Main entry point for filter changes
    func setPositionFilter(_ position: PlayerPosition) {
        selectedPosition = position
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    /// Main entry point for sort changes
    func setSortingMethod(_ method: SortingMethod) {
        sortingMethod = method
        triggerAnimationReset()
        applyPositionFilter()
    }
}

// MARK: - Delta Management
extension AllLivePlayersViewModel {
    /// Resets all player previousScore to current score, clearing all per-player deltas
    func resetAllPlayerDeltas() {
        // Update allPlayers with previousScore set to currentScore
        allPlayers = allPlayers.map { entry in
            LivePlayerEntry(
                id: entry.id,
                player: entry.player,
                leagueName: entry.leagueName,
                leagueSource: entry.leagueSource,
                currentScore: entry.currentScore,
                projectedScore: entry.projectedScore,
                isStarter: entry.isStarter,
                percentageOfTop: entry.percentageOfTop,
                matchup: entry.matchup,
                performanceTier: entry.performanceTier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.currentScore,
                accumulatedDelta: 0.0
            )
        }
        
        // Also update filteredPlayers
        filteredPlayers = filteredPlayers.map { entry in
            LivePlayerEntry(
                id: entry.id,
                player: entry.player,
                leagueName: entry.leagueName,
                leagueSource: entry.leagueSource,
                currentScore: entry.currentScore,
                projectedScore: entry.projectedScore,
                isStarter: entry.isStarter,
                percentageOfTop: entry.percentageOfTop,
                matchup: entry.matchup,
                performanceTier: entry.performanceTier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.currentScore,
                accumulatedDelta: 0.0
            )
        }
    }
}

// MARK: - State Helpers
extension AllLivePlayersViewModel {
    var isInitialState: Bool {
        if case .initial = dataState { return true }
        return false
    }
    
    var isDataLoaded: Bool {
        if case .loaded = dataState { return true }
        return false
    }
    
    var hasNoLeagues: Bool {
        // Only consider it "no leagues" if we've finished loading and still have nothing
        // Don't show "no leagues" during initial loading
        let isCurrentlyLoading = {
            switch dataState {
            case .loading:
                return true
            default:
                return false
            }
        }()
        
        return !matchupsHubViewModel.isLoading && matchupsHubViewModel.myMatchups.isEmpty && !isCurrentlyLoading
    }
    
    var hasLeaguesButNoPlayers: Bool {
        !matchupsHubViewModel.myMatchups.isEmpty && filteredPlayers.isEmpty && !isDataLoaded
    }
    
    var connectedLeaguesCount: Int {
        matchupsHubViewModel.myMatchups.count
    }
}

// MARK: - Business Logic Helpers  
extension AllLivePlayersViewModel {
    var firstAvailableManager: ManagerInfo? {
        for matchup in matchupsHubViewModel.myMatchups {
            if let myTeam = matchup.myTeam {
                let isWinning = determineIfWinning(matchup: matchup, team: myTeam)
                return ManagerInfo(
                    name: myTeam.ownerName,
                    score: myTeam.currentScore ?? 0.0,
                    avatarURL: myTeam.avatarURL,
                    scoreColor: isWinning ? .green : .red
                )
            }
        }
        return nil
    }
    
    private func determineIfWinning(matchup: UnifiedMatchup, team: FantasyTeam) -> Bool {
        if matchup.isChoppedLeague { return true }
        guard let opponent = matchup.opponentTeam else { return true }
        return (team.currentScore ?? 0.0) > (opponent.currentScore ?? 0.0)
    }
    
    var sortDirectionText: String {
        switch sortingMethod {
        case .position: return sortHighToLow ? "QB to K" : "K to QB"
        case .score: return sortHighToLow ? "Highest" : "Lowest"
        case .name: return sortHighToLow ? "A to Z" : "Z to A"
        case .team: return sortHighToLow ? "A to Z" : "Z to A"
        case .recent: return "Most Recent"
        }
    }
}