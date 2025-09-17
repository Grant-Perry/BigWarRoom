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
    
    // MARK: - UI Business Logic (Moved from View)
    
    /// Sort matchups by winning/losing status
    func sortedMatchups(sortByWinning: Bool) -> [UnifiedMatchup] {
        if sortByWinning {
            return myMatchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 > score2
            }
        } else {
            return myMatchups.sorted { matchup1, matchup2 in
                let score1 = matchup1.myTeam?.currentScore ?? 0
                let score2 = matchup2.myTeam?.currentScore ?? 0
                return score1 < score2
            }
        }
    }
    
    /// Count of live matchups
    func liveMatchupsCount(from matchups: [UnifiedMatchup]) -> Int {
        return matchups.filter { matchup in
            if matchup.isChoppedLeague {
                return false
            }
            
            guard let myTeam = matchup.myTeam else { return false }
            let starters = myTeam.roster.filter { $0.isStarter }
            return starters.contains { player in
                isPlayerInLiveGame(player)
            }
        }.count
    }
    
    /// Count of connected leagues
    var connectedLeaguesCount: Int {
        Set(myMatchups.map { $0.league.id }).count
    }
    
    /// Count of winning matchups
    func winningMatchupsCount(from matchups: [UnifiedMatchup]) -> Int {
        return matchups.filter { getWinningStatusForMatchup($0) }.count
    }
    
    /// Get winning status for a matchup
    func getWinningStatusForMatchup(_ matchup: UnifiedMatchup) -> Bool {
        if matchup.isChoppedLeague {
            guard let teamRanking = matchup.myTeamRanking else { return false }
            return teamRanking.eliminationStatus == .champion || teamRanking.eliminationStatus == .safe
        } else {
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return false
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            
            return myScore > opponentScore
        }
    }
    
    /// Get score color for a matchup
    func getScoreColorForMatchup(_ matchup: UnifiedMatchup) -> Color {
        if matchup.isChoppedLeague {
            guard let ranking = matchup.myTeamRanking else { return .white }
            
            switch ranking.eliminationStatus {
            case .champion, .safe:
                return .gpGreen
            case .warning:
                return .gpYellow
            case .danger:
                return .orange
            case .critical, .eliminated:
                return .gpRedPink
            }
        } else {
            guard let myTeam = matchup.myTeam,
                  let opponentTeam = matchup.opponentTeam else {
                return .white
            }
            
            let myScore = myTeam.currentScore ?? 0
            let opponentScore = opponentTeam.currentScore ?? 0
            
            let isWinning = myScore > opponentScore
            return isWinning ? .gpGreen : .gpRedPink
        }
    }
    
    /// Check if player is in live game
    private func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        guard let gameStatus = player.gameStatus else { return false }
        let timeString = gameStatus.timeString.lowercased()
        
        let quarterPatterns = ["1st ", "2nd ", "3rd ", "4th ", "ot ", "overtime"]
        for pattern in quarterPatterns {
            if timeString.contains(pattern) && timeString.contains(":") {
                return true
            }
        }
        
        let liveStatusIndicators = ["live", "halftime", "half", "end 1st", "end 2nd", "end 3rd", "end 4th"]
        return liveStatusIndicators.contains { timeString.contains($0) }
    }
    
    /// Format relative time
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

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
        // Use shared instance instead of creating new ones
        let viewModel = FantasyViewModel.shared
        
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
        // 🔥 FIXED: Use the definitive source from SleeperLeagueSettings
        return league.isChoppedLeague
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
    
    // 🔥 NEW: Check if MY manager is eliminated from a chopped league
    var isMyManagerEliminated: Bool {
        // Only applies to chopped leagues
        guard isChoppedLeague else { 
//            print("❌ Not a chopped league, returning false")
            return false 
        }
        
//        print("🔍 ELIMINATION CHECK for league: \(league.league.name)")
        
        // 🔥 CRITICAL FIX: Check if my team has 0 players and 0 score (most reliable for eliminated teams)
        // This is the most reliable indicator of elimination in chopped leagues
        if let myTeam = myTeam {
//            print("   - My team name: '\(myTeam.ownerName)'")
//            print("   - My team ID: '\(myTeam.id)'")
//            print("   - My current score: \(myTeam.currentScore ?? 0.0)")
            
            // Method 1: Check if I have 0 players and 0 score (most reliable for eliminated teams)
            let hasZeroScore = (myTeam.currentScore ?? 0.0) == 0.0
            let isEmpty = myTeam.roster.isEmpty
            
//            print("   - Has zero score: \(hasZeroScore)")
//            print("   - Roster is empty: \(isEmpty)")
            
            // 🔥 NEW APPROACH: Check the elimination history first for definitive answer
            if let choppedSummary = choppedSummary {
//                print("   - Elimination history count: \(choppedSummary.eliminationHistory.count)")
                
                // Check if I'm in THIS league's elimination history
                let isInThisLeagueGraveyard = choppedSummary.eliminationHistory.contains { elimination in
                    let nameMatch = elimination.eliminatedTeam.team.ownerName.lowercased() == myTeam.ownerName.lowercased()
                    let idMatch = elimination.eliminatedTeam.team.id == myTeam.id
//                    print("     - Checking graveyard: '\(elimination.eliminatedTeam.team.ownerName)' vs '\(myTeam.ownerName)' (name: \(nameMatch), id: \(idMatch))")
                    return nameMatch || idMatch
                }
                
                if isInThisLeagueGraveyard {
//                    print("✅ ELIMINATED: Found in THIS league's graveyard!")
                    return true
                }
                
                // Method 2: Check if my ranking shows eliminated status
                if let ranking = myTeamRanking {
//                    print("   - My ranking status: \(ranking.eliminationStatus)")
//                    print("   - My ranking isEliminated: \(ranking.isEliminated)")
                    if ranking.isEliminated {
//                        print("✅ ELIMINATED: Ranking shows eliminated!")
                        return true
                    }
                }
                
                // Method 3: Check if I'm not in the active rankings (meaning I was filtered out as eliminated)
                let amInActiveRankings = choppedSummary.rankings.contains { ranking in
                    ranking.team.ownerName.lowercased() == myTeam.ownerName.lowercased() ||
                    ranking.team.id == myTeam.id
                }
                
//                print("   - Am I in active rankings: \(amInActiveRankings)")
                
                if !amInActiveRankings {
//                    print("✅ ELIMINATED: Not found in active rankings!")
                    return true
                }
            }
        }
        
//        print("❌ ELIMINATION CHECK: Not eliminated from this league")
        return false
    }
    
    // 🔥 NEW: Get the week I was eliminated (if applicable)
    var myEliminationWeek: Int? {
        guard isMyManagerEliminated else { return nil }
        
        // Check elimination history first (most reliable)
        if let choppedSummary = choppedSummary,
           let myTeam = myTeam {
            let elimination = choppedSummary.eliminationHistory.first { elimination in
                elimination.eliminatedTeam.team.ownerName.lowercased() == myTeam.ownerName.lowercased() ||
                elimination.eliminatedTeam.team.id == myTeam.id
            }
            return elimination?.week
        }
        
        // Fallback to weeks alive from ranking
        if let ranking = myTeamRanking, ranking.isEliminated {
            return ranking.weeksAlive
        }
        
        return nil
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
