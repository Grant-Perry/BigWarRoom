//
//  AllLivePlayersViewModel.swift
//  BigWarRoom
//
//  🔥 REFACTORED: Core coordination only - all functionality moved to focused extensions
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AllLivePlayersViewModel: ObservableObject {
    // MARK: - Shared Instance
    static let shared = AllLivePlayersViewModel()
    
    // MARK: - Published Properties (Core State Only)
    @Published var allPlayers: [LivePlayerEntry] = []
    @Published var filteredPlayers: [LivePlayerEntry] = []
    @Published var selectedPosition: PlayerPosition = .all
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataState: DataLoadingState = .initial
    
    // MARK: - UI State
    @Published var sortHighToLow = true
    @Published var sortingMethod: SortingMethod = .position
    @Published var showActiveOnly: Bool = false
    @Published var shouldResetAnimations = false
    @Published var sortChangeID = UUID()
    @Published var lastUpdateTime = Date()
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var showRosteredOnly: Bool = false // Changed to checkbox approach
    @Published var allNFLPlayers: [SleeperPlayer] = [] // For All Players search
    
    // MARK: - Computed Statistics
    @Published var topScore: Double = 0.0
    @Published var medianScore: Double = 0.0
    @Published var scoreRange: Double = 0.0
    @Published var useAdaptiveScaling: Bool = false
    @Published var positionTopScore: Double = 0.0
    
    // MARK: - Player Stats
    @Published var playerStats: [String: [String: Double]] = [:]
    @Published var statsLoaded: Bool = false
    
    // MARK: - Dependencies
    let matchupsHubViewModel = MatchupsHubViewModel.shared
    
    // MARK: - Internal State (not published)
    internal var weekSubscription: AnyCancellable?
    internal var matchupsSubscription: AnyCancellable?
    internal var debounceTask: Task<Void, Never>?
    internal var isBatchingUpdates = false
    
    // 🔥 FIXED: Track last processed update time to prevent duplicate processing
    internal var lastProcessedMatchupUpdate = Date.distantPast
    
    // MARK: - Private Init
    private init() {
        subscribeToWeekChanges()
        subscribeToMatchupsUpdates()
    }
    
    // MARK: - Cleanup
    deinit {
        debounceTask?.cancel()
        weekSubscription?.cancel()
        matchupsSubscription?.cancel()
    }
    
    // 🔥 FIXED: Subscribe to MatchupsHubViewModel updates with duplicate prevention
    private func subscribeToMatchupsUpdates() {
        print("🔥 SUBSCRIPTION SETUP: Setting up matchups subscription")
        matchupsSubscription = matchupsHubViewModel.$lastUpdateTime
            .removeDuplicates()
            .debounce(for: .milliseconds(750), scheduler: DispatchQueue.main) 
            .sink { [weak self] updateTime in
                guard let self = self else { 
                    print("🔥 SUBSCRIPTION ERROR: Self is nil")
                    return 
                }
                
                print("🔥 SUBSCRIPTION TRIGGERED: MatchupsHub lastUpdateTime = \(updateTime)")
                
                // 🔥 CRITICAL FIX: Prevent duplicate processing of same update
                guard updateTime > self.lastProcessedMatchupUpdate else {
                    print("🔥 SUBSCRIPTION BLOCKED: Duplicate update from \(updateTime), last processed: \(self.lastProcessedMatchupUpdate)")
                    return
                }
                
                // Only process if we have initial data
                guard !self.allPlayers.isEmpty else { 
                    print("🔥 SUBSCRIPTION BLOCKED: No initial data yet (allPlayers.count = \(self.allPlayers.count))")
                    return 
                }
                
                print("🔥 SUBSCRIPTION PROCESSING: Starting live update for \(updateTime)")
                self.lastProcessedMatchupUpdate = updateTime
                
                Task { @MainActor in
                    await self.performLiveUpdate()
                }
            }
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
        await performManualRefresh()
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