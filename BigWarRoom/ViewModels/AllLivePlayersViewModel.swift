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
    var showActiveOnly: Bool = true // 🔥 DEFAULT: Show only active players on initial load
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
    
    // 🔥 FIXED: Track last processed update time to prevent duplicate processing
    internal var lastProcessedMatchupUpdate = Date.distantPast
    
    // 🔥 PHASE 3: Replace Combine subscriptions with observation task
    private var observationTask: Task<Void, Never>?
    
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
        // setupObservation()  // 🔥 DISABLED: Creates race condition with 15-second timer, causes throttle to block all API calls
        setupAutoRefresh()
    }
    
    // MARK: - Cleanup
    @MainActor
    deinit {
        debounceTask?.cancel()
        observationTask?.cancel()
        refreshTimer?.invalidate()
    }
    
    // 🔥 PHASE 3: Replace Combine subscription with @Observable observation
    private func setupObservation() {
        DebugPrint(mode: .liveUpdates, "👀 OBSERVATION SETUP: Setting up @Observable-based observation")
        
        observationTask = Task { @MainActor in
            // Observe changes to MatchupsHubViewModel
            var lastObservedUpdate = Date.distantPast
            
            while !Task.isCancelled {
                // Check if MatchupsHubViewModel's lastUpdateTime changed
                let currentUpdateTime = matchupsHubViewModel.lastUpdateTime
                
                if currentUpdateTime > lastObservedUpdate && currentUpdateTime > lastProcessedMatchupUpdate {
                    DebugPrint(mode: .liveUpdates, "🎯 OBSERVATION TRIGGERED: MatchupsHub lastUpdateTime = \(currentUpdateTime)")
                    
                    // Only process if we have initial data
                    guard !allPlayers.isEmpty else {
                        DebugPrint(mode: .liveUpdates, "🚫 OBSERVATION BLOCKED: No initial data yet (allPlayers.count = \(allPlayers.count))")
                        lastObservedUpdate = currentUpdateTime
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                    
                    DebugPrint(mode: .liveUpdates, "▶️ OBSERVATION PROCESSING: Starting live update for \(currentUpdateTime)")
                    lastProcessedMatchupUpdate = currentUpdateTime
                    lastObservedUpdate = currentUpdateTime
                    
                    await performLiveUpdate()
                }
                
                // Small delay to prevent excessive polling
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    // 🔥 NEW: Setup auto-refresh timer
    private func setupAutoRefresh() {
        // 🔥 DISABLED: MatchupsHubViewModel already has a 15-second auto-refresh timer
        // Having both timers causes a race condition where they block each other
        // Instead, we observe MatchupsHub changes via setupObservation() which is already in place
        // print("🔥 AUTO-REFRESH DISABLED: AllLivePlayersViewModel will observe MatchupsHub changes instead")
    }
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