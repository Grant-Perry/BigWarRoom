//
//  MatchupsHubViewModel.swift
//  BigWarRoom
//
//  The command center for all your fantasy battles across leagues
//

import Foundation
import Combine
import SwiftUI

/// Main MatchupsHub ViewModel - focuses on core state management and coordination
@MainActor
final class MatchupsHubViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var myMatchups: [UnifiedMatchup] = []
    @Published var isLoading: Bool = false
    @Published var currentLoadingLeague: String = ""
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var autoRefreshEnabled: Bool = true
    
    // MARK: - Loading State Management
    @Published var loadingStates: [String: LeagueLoadingState] = [:]
    internal var totalLeagueCount: Int = 0
    internal var loadedLeagueCount: Int = 0
    
    // MARK: - Dependencies
    internal let unifiedLeagueManager = UnifiedLeagueManager()
    internal let sleeperCredentials = SleeperCredentialsManager.shared
    internal var refreshTimer: Timer?
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Loading Guards
    internal var currentlyLoadingLeagues = Set<String>()
    internal let loadingLock = NSLock()
    internal let maxConcurrentLoads = 3
    
    // MARK: - Initialization
    init() {
        setupAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Load all matchups across all connected leagues
    func loadAllMatchups() async {
        await performLoadAllMatchups()
    }
    
    /// Load matchups for a specific week
    func loadMatchupsForWeek(_ week: Int) async {
        await performLoadMatchupsForWeek(week)
    }
    
    /// Manual refresh trigger - BACKGROUND REFRESH (no loading screen)
    func manualRefresh() async {
        await performManualRefresh()
    }
    
    /// Toggle auto refresh
    func toggleAutoRefresh() {
        autoRefreshEnabled.toggle()
        setupAutoRefresh()
    }
}

// MARK: - Supporting Models

/// Unified matchup model combining all league types
struct UnifiedMatchup: Identifiable {
    let id: String
    let league: UnifiedLeagueManager.LeagueWrapper
    let fantasyMatchup: FantasyMatchup?
    let choppedSummary: ChoppedWeekSummary?
    let lastUpdated: Date
    let myTeamRanking: FantasyTeamRanking? // For Chopped leagues
    let myIdentifiedTeamID: String? // 🔥 NEW: Store the correctly identified team ID
    private let authenticatedUsername: String
    
    init(id: String, league: UnifiedLeagueManager.LeagueWrapper, fantasyMatchup: FantasyMatchup?, choppedSummary: ChoppedWeekSummary?, lastUpdated: Date, myTeamRanking: FantasyTeamRanking? = nil, myIdentifiedTeamID: String? = nil) {
        self.id = id
        self.league = league
        self.fantasyMatchup = fantasyMatchup
        self.choppedSummary = choppedSummary
        self.lastUpdated = lastUpdated
        self.myTeamRanking = myTeamRanking
        self.myIdentifiedTeamID = myIdentifiedTeamID // 🔥 NEW: Store the team ID
        self.authenticatedUsername = SleeperCredentialsManager.shared.currentUsername
    }
    
    /// Create a configured FantasyViewModel for this matchup
    /// This ensures the detail view knows which team is the user's team
    @MainActor
    func createConfiguredFantasyViewModel() -> FantasyViewModel {
        let viewModel = FantasyViewModel()
        
        // Set up the league context
        if let myTeamId = myTeam?.id {
            viewModel.selectLeague(league, myTeamID: myTeamId)
        } else {
            viewModel.selectLeague(league)
        }
        
        // If we have matchup data, set it directly to avoid refetching
        if let matchup = fantasyMatchup {
            viewModel.matchups = [matchup]
        }
        
        // If we have chopped data, set it
        if let chopped = choppedSummary {
            viewModel.currentChoppedSummary = chopped
            viewModel.detectedAsChoppedLeague = true
        }
        
        // FIXED: Use selected week from WeekSelectionManager (NOT current NFL week)
        // This ensures detail views show data for the week selected in Mission Control
        // viewModel.selectedWeek = NFLWeekService.shared.currentWeek // OLD - WRONG!
        // The FantasyViewModel now automatically uses WeekSelectionManager.shared.selectedWeek
        
        // Disable auto-refresh to prevent conflicts with Mission Control's refresh
        viewModel.setMatchupsHubControl(true)
        
        return viewModel
    }
    
    /// Is this a Chopped league?
    var isChoppedLeague: Bool {
        return league.source == .sleeper && choppedSummary != nil && fantasyMatchup == nil
    }
    
    /// Display priority for sorting (higher = shown first)
    var priority: Int {
        var basePriority = 0
        
        // Live games get highest priority (for regular matchups)
        if fantasyMatchup?.status == .live {
            basePriority += 100
        }
        
        // Chopped leagues get higher priority
        if isChoppedLeague {
            basePriority += 50
        }
        
        // Platform preference (can be customized)
        switch league.source {
        case .espn:
            basePriority += 20
        case .sleeper:
            basePriority += 30
        }
        
        return basePriority
    }
    
    /// My team in this matchup (FIXED to use reliable ID-based matching)
    var myTeam: FantasyTeam? {
        // For Chopped leagues, get team from myTeamRanking
        if isChoppedLeague, let ranking = myTeamRanking {
            return ranking.team
        }
        
        // For regular matchups - use the stored team ID for reliable matching
        guard let matchup = fantasyMatchup, let myID = myIdentifiedTeamID else {
            return nil
        }
        
        // Match by the reliable team ID that was correctly identified during loading
        if matchup.homeTeam.id == myID {
            return matchup.homeTeam
        }
        if matchup.awayTeam.id == myID {
            return matchup.awayTeam
        }
        
        return nil
    }
    
    /// Opponent team in this matchup (FIXED to use reliable ID-based matching)
    var opponentTeam: FantasyTeam? {
        // Chopped leagues have NO opponent - everyone vs everyone
        if isChoppedLeague {
            return nil
        }
        
        guard let matchup = fantasyMatchup, let myID = myIdentifiedTeamID else { 
            return nil 
        }
        
        // Return the team that's NOT my team (using reliable ID matching)
        if matchup.homeTeam.id == myID {
            return matchup.awayTeam
        } else if matchup.awayTeam.id == myID {
            return matchup.homeTeam
        }
        
        return nil
    }
    
    /// Current score difference (nil for Chopped leagues)
    var scoreDifferential: Double? {
        // Chopped leagues don't have score differentials
        if isChoppedLeague {
            return nil
        }
        
        guard let myScore = myTeam?.currentScore,
              let opponentScore = opponentTeam?.currentScore else { return nil }
        return myScore - opponentScore
    }
    
    /// Win probability for my team (nil for Chopped leagues)
    var myWinProbability: Double? {
        // Chopped leagues don't have win probabilities against opponents
        if isChoppedLeague {
            return nil
        }
        
        guard let matchup = fantasyMatchup, let myTeam = myTeam else { return nil }
        
        // If I'm the home team, use the existing win probability
        if matchup.homeTeam.id == myTeam.id {
            return matchup.winProbability
        } else {
            // If I'm the away team, return 1 - home team win probability
            return matchup.winProbability.map { 1.0 - $0 }
        }
    }
    
    /// Single source of truth for matchup live status
    var isLive: Bool {
        // Chopped leagues are never "live" in this context
        if isChoppedLeague {
            return false
        }
        
        // Check if any starter on either team is in a live game
        if let myTeam = myTeam, myTeam.roster.filter({ $0.isStarter && $0.isLive }).count > 0 {
            return true
        }
        
        if let opponentTeam = opponentTeam, opponentTeam.roster.filter({ $0.isStarter && $0.isLive }).count > 0 {
            return true
        }
        
        return false
    }
}

/// Individual league loading state
struct LeagueLoadingState {
    let name: String
    var status: LoadingStatus
    var progress: Double
}

/// Loading status enum
enum LoadingStatus {
    case pending
    case loading
    case completed
    case failed
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .loading: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .loading: return "⚡"
        case .completed: return "✅"
        case .failed: return "❌"
        }
    }
}