//
//  MatchupsHubViewModel.swift
//  BigWarRoom
//
//  The command center for all your fantasy battles across leagues
//

import Foundation
import SwiftUI
import Observation

/// Main MatchupsHub ViewModel - focuses on core state management and coordination
@MainActor
@Observable
final class MatchupsHubViewModel {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: MatchupsHubViewModel?
    
    static var shared: MatchupsHubViewModel {
        if let existing = _shared {
            return existing
        }
        fatalError("MatchupsHubViewModel.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: MatchupsHubViewModel) {
        _shared = instance
    }
    
    // MARK: - 🔥 PHASE 3: @Observable State Properties (no @Published needed)
    var myMatchups: [UnifiedMatchup] = []
    var isLoading = false
    var isUpdating = false // 🔥 NEW: Track live update state for Siri animation
    var lastUpdateTime = Date()
    var autoRefreshEnabled = true

    // MARK: - Just Me Mode State (Persistent across refreshes)
    var microModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "MatchupsHub_MicroModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "MatchupsHub_MicroModeEnabled")
        }
    }
    var expandedCardId: String? = nil
    var justMeModeBannerVisible = false // Keep this false - no banner needed
    
    // MARK: - 💊 RX Optimization Status Tracking
    var lineupOptimizationStatus: [String: Bool] = [:] // matchupID -> isOptimized

    // MARK: - Loading State Management
    var loadingStates: [String: LeagueLoadingState] = [:]
    var errorMessage: String? = nil
    var currentLoadingLeague: String = ""
    var loadingProgress: Double = 0.0
    internal var totalLeagueCount: Int = 0
    internal var loadedLeagueCount: Int = 0
    
    // 🔥 NEW: Cache loaded LeagueMatchupProvider instances for score consistency
    internal var cachedProviders: [String: LeagueMatchupProvider] = [:]
    
    // MARK: - Dependencies - Injected instead of .shared (PHASE 3 DI COMPLETE)
    private let espnCredentials: ESPNCredentialsManager
    internal let sleeperCredentials: SleeperCredentialsManager
    internal let unifiedLeagueManager: UnifiedLeagueManager
    internal var refreshTimer: Timer?
    
    // 🔥 PHASE 3 DI: New dependencies
    private let playerDirectory: PlayerDirectoryStore
    private let gameStatusService: GameStatusService
    private let sharedStatsService: SharedStatsService
    
    // 🔥 PHASE 3: Replace Combine with observation task
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Loading Guards
    // 🔥 FIXED: Remove NSLock - using actor isolation instead
    internal var currentlyLoadingLeagues = Set<String>()
    internal let maxConcurrentLoads = 3
    
    // 🔥 NEW: Actor for thread-safe loading guard (internal, not private)
    internal actor LoadingGuard {
        private var loadingKeys = Set<String>()
        
        func shouldLoad(key: String) -> Bool {
            if loadingKeys.contains(key) {
                return false
            }
            loadingKeys.insert(key)
            return true
        }
        
        func completeLoad(key: String) {
            loadingKeys.remove(key)
        }
    }
    
    internal let loadingGuard = LoadingGuard()
    
    // MARK: - Initialization with Dependency Injection (PHASE 3 DI COMPLETE)
    init(
        espnCredentials: ESPNCredentialsManager,
        sleeperCredentials: SleeperCredentialsManager,
        playerDirectory: PlayerDirectoryStore,
        gameStatusService: GameStatusService,
        sharedStatsService: SharedStatsService
    ) {
        self.espnCredentials = espnCredentials
        self.sleeperCredentials = sleeperCredentials
        self.playerDirectory = playerDirectory
        self.gameStatusService = gameStatusService
        self.sharedStatsService = sharedStatsService
        
        // 🔥 PHASE 3 DI: Create UnifiedLeagueManager with proper dependency injection
        // We need to create API clients here - this is a bit complex but proper
        let sleeperAPIClient = SleeperAPIClient()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCredentials)
        
        self.unifiedLeagueManager = UnifiedLeagueManager(
            sleeperClient: sleeperAPIClient,
            espnClient: espnAPIClient,
            espnCredentials: espnCredentials
        )
        
        setupAutoRefresh()
        setupCredentialObservation()
    }
    
    // MARK: - 🔥 PHASE 3: Replace Combine subscription with @Observable observation
    private func setupCredentialObservation() {
        DebugPrint(mode: .viewModelLifecycle, "Setting up @Observable-based credential monitoring")
        
        observationTask = Task { @MainActor in
            var lastSleeperCredentials = sleeperCredentials.hasValidCredentials
            var lastSleeperUsername = sleeperCredentials.currentUsername
            
            while !Task.isCancelled {
                // Check if Sleeper credentials changed
                let currentSleeperCredentials = sleeperCredentials.hasValidCredentials
                let currentSleeperUsername = sleeperCredentials.currentUsername
                
                if currentSleeperCredentials != lastSleeperCredentials {
                    DebugPrint(mode: .viewModelLifecycle, "Sleeper credentials changed - refreshing leagues...")
                    await manualRefresh()
                    lastSleeperCredentials = currentSleeperCredentials
                }
                
                if currentSleeperUsername != lastSleeperUsername {
                    DebugPrint(mode: .viewModelLifecycle, "Sleeper username changed to '\(currentSleeperUsername)' - refreshing leagues...")
                    await manualRefresh()
                    lastSleeperUsername = currentSleeperUsername
                }
                
                // Small delay to prevent excessive polling
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    deinit {
        // Swift 6: `deinit` is nonisolated, but this type is `@MainActor`.
        // Use assumeIsolated to safely touch main-actor state during teardown.
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            observationTask?.cancel()
        }
    }
    
    // MARK: - Public Interface
    
    /// Load all matchups across all connected leagues
    func loadAllMatchups() async {
        DebugPrint(mode: .matchupLoading, "MatchupsHubViewModel.loadAllMatchups() called from LoadingScreen")
        await performLoadAllMatchups()
    }
    
    /// Load matchups for a specific week
    func loadMatchupsForWeek(_ week: Int) async {
        DebugPrint(mode: .matchupLoading, "MatchupsHubViewModel.loadMatchupsForWeek(\(week)) called")
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
        // 🔥 FIXED: Separate eliminated chopped leagues from active matchups
        var activeMatchups: [UnifiedMatchup] = []
        var eliminatedMatchups: [UnifiedMatchup] = []
        
        for matchup in myMatchups {
            if matchup.isMyManagerEliminated {
                eliminatedMatchups.append(matchup) // Eliminated - goes to end
            } else {
                activeMatchups.append(matchup) // Active - participates in sorting
            }
        }
        
        // 🔥 NEW: Separate winning and losing matchups for proper secondary sorting
        var winningMatchups: [UnifiedMatchup] = []
        var losingMatchups: [UnifiedMatchup] = []
        
        for matchup in activeMatchups {
            let isWinning = getWinningStatusForMatchup(matchup)
            if isWinning {
                winningMatchups.append(matchup)
            } else {
                losingMatchups.append(matchup)
            }
        }
        
        // Sort winning matchups by MY score descending (highest scores first)
        let sortedWinningMatchups = winningMatchups.sorted { matchup1, matchup2 in
            let myScore1 = getMyScore(for: matchup1)
            let myScore2 = getMyScore(for: matchup2)
            return myScore1 > myScore2 // My highest scores first
        }
        
        // Sort losing matchups by MY score descending (highest scores first)
        let sortedLosingMatchups = losingMatchups.sorted { matchup1, matchup2 in
            let myScore1 = getMyScore(for: matchup1)
            let myScore2 = getMyScore(for: matchup2)
            return myScore1 > myScore2 // My highest scores first
        }
        
        // 🔥 NEW: Combine based on primary sort preference
        let sortedActiveMatchups: [UnifiedMatchup]
        if sortByWinning {
            // Winning sort: Show winning matchups first (highest scores), then losing matchups (highest scores)
            sortedActiveMatchups = sortedWinningMatchups + sortedLosingMatchups
        } else {
            // Losing sort: Show losing matchups first (highest scores), then winning matchups (highest scores)
            sortedActiveMatchups = sortedLosingMatchups + sortedWinningMatchups
        }
        
        // 🔥 ALWAYS append eliminated matchups at the end (no sorting)
        return sortedActiveMatchups + eliminatedMatchups
    }
    
    /// 🔥 NEW: Get my score for any matchup type
    private func getMyScore(for matchup: UnifiedMatchup) -> Double {
        if matchup.isChoppedLeague {
            // For chopped leagues: Use my current score
            return matchup.myTeam?.currentScore ?? 0.0
        } else {
            // For regular leagues: Use my current score
            return matchup.myTeam?.currentScore ?? 0.0
        }
    }
    
    /// 🔥 NEW: Calculate unified performance margin for any matchup type
    private func getPerformanceMargin(for matchup: UnifiedMatchup) -> Double {
        if matchup.isChoppedLeague {
            // Chopped leagues: Use safety margin (points above/below elimination line)
            guard let ranking = matchup.myTeamRanking else { return 0.0 }
            return ranking.pointsFromSafety
        } else {
            // Regular leagues: Use score differential vs opponent
            guard let myScore = matchup.myTeam?.currentScore,
                  let opponentScore = matchup.opponentTeam?.currentScore else { return 0.0 }
            return myScore - opponentScore
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
                // 🔥 MODEL-BASED CP: Use isInActiveGame for lightweight live detection
                player.isInActiveGame
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
    
    /// 🔥 SIMPLE CHOPPED LOGIC: Get winning status for a matchup - not in last place = winning
    func getWinningStatusForMatchup(_ matchup: UnifiedMatchup) -> Bool {
        if matchup.isChoppedLeague {
            // 🔥 SIMPLE CHOPPED LOGIC: Win if NOT in chopping block (last place or bottom 2)
            guard let ranking = matchup.myTeamRanking,
                  let choppedSummary = matchup.choppedSummary else {
                return false
            }
            
            // If I'm already eliminated from this league, it's definitely a loss
            if matchup.isMyManagerEliminated {
                return false
            }
            
            let totalTeams = choppedSummary.rankings.count
            let myRank = ranking.rank
            
            // 🔥 SIMPLE RULE:
            // - 32+ player leagues: Bottom 2 get chopped = ranks (totalTeams-1) and totalTeams are losing
            // - All other leagues: Bottom 1 gets chopped = rank totalTeams is losing
            if totalTeams >= 32 {
                // Bottom 2 positions are losing (last 2 places)
                return myRank <= (totalTeams - 2)
            } else {
                // Bottom 1 position is losing (last place)
                return myRank < totalTeams
            }
            
        } else {
            // Regular matchup logic - simple score comparison
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
    
    /// Format relative time
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // 🔥 NEW: Get cached LeagueMatchupProvider for consistent scoring
    func getCachedProvider(for league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String) -> LeagueMatchupProvider? {
        let cacheKey = "\(league.id)_\(week)_\(year)"
        return cachedProviders[cacheKey]
    }
    
    // 🔥 NEW: Store provider in cache after loading
    internal func cacheProvider(_ provider: LeagueMatchupProvider, for league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String) {
        let cacheKey = "\(league.id)_\(week)_\(year)"
        cachedProviders[cacheKey] = provider
//        print("🔥 CACHE: Stored provider for \(league.league.name) (key: \(cacheKey))")
    }
}

/// Unified matchup model combining all league types
struct UnifiedMatchup: Identifiable, Hashable {
    // MARK: - Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UnifiedMatchup, rhs: UnifiedMatchup) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Properties
    let id: String
    let league: UnifiedLeagueManager.LeagueWrapper
    let fantasyMatchup: FantasyMatchup?
    let choppedSummary: ChoppedWeekSummary?
    let lastUpdated: Date
    let myTeamRanking: FantasyTeamRanking? // For Chopped leagues
    let myIdentifiedTeamID: String? // 🔥 NEW: Store the correctly identified team ID
    private let authenticatedUsername: String
    let allLeagueMatchups: [FantasyMatchup]? // 🔥 NEW: All matchups in this league for horizontal scrolling
    
    init(id: String, league: UnifiedLeagueManager.LeagueWrapper, fantasyMatchup: FantasyMatchup?, choppedSummary: ChoppedWeekSummary?, lastUpdated: Date, myTeamRanking: FantasyTeamRanking? = nil, myIdentifiedTeamID: String? = nil, authenticatedUsername: String, allLeagueMatchups: [FantasyMatchup]? = nil) {
        self.id = id
        self.league = league
        self.fantasyMatchup = fantasyMatchup
        self.choppedSummary = choppedSummary
        self.lastUpdated = lastUpdated
        self.myTeamRanking = myTeamRanking
        self.myIdentifiedTeamID = myIdentifiedTeamID
        self.authenticatedUsername = authenticatedUsername
        self.allLeagueMatchups = allLeagueMatchups
    }
    
    /// Create a configured FantasyViewModel for this matchup
    /// This ensures the detail view knows which team is the user's team
    @MainActor
    func createConfiguredFantasyViewModel() -> FantasyViewModel {
        // 🔥 FIXED: Create NEW instance instead of using shared to prevent conflicts
        let viewModel = FantasyViewModel()
        
        // Set up the league context
        if let myTeamId = myTeam?.id {
            viewModel.selectLeague(league, myTeamID: myTeamId)
        } else {
            viewModel.selectLeague(league)
        }
        
        // If we have chopped data, set it
        if let chopped = choppedSummary {
            viewModel.currentChoppedSummary = chopped
            viewModel.detectedAsChoppedLeague = true
        }
        
        // Disable auto-refresh to prevent conflicts with Mission Control's refresh
        viewModel.setMatchupsHubControl(true)
        
        return viewModel
    }
    
    /// Is this a Chopped league?
    var isChoppedLeague: Bool {
        // Source of truth: Mission Control treats a matchup as "chopped" only if we actually built chopped data.
        // This prevents mis-classification if league settings are missing or inconsistent.
        return choppedSummary != nil
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
        // Check for playoff elimination first (opponent name check)
        if let opponentName = opponentTeam?.name, opponentName == "Eliminated from Playoffs" {
            DebugPrint(mode: .matchupLoading, limit: 10, "✅ PLAYOFF ELIMINATION DETECTED for \(league.league.name)")
            return true
        }
        
        // Check chopped leagues
        if isChoppedLeague {
            return checkChoppedElimination()
        }

        return false
    }
    
    // MARK: - Private Elimination Checks
    
    /// Check if eliminated from a chopped league
    private func checkChoppedElimination() -> Bool {
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
            _ = (myTeam.currentScore ?? 0.0) == 0.0
            _ = myTeam.roster.isEmpty
            
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
    
    /// Get projected score for my team (async)
    func getMyTeamProjectedScore() async -> Double {
        let projections = await ProjectedPointsManager.shared.getProjectedMatchupScores(for: self)
        return projections.myTeam
    }
    
    /// Get projected score for opponent team (async)
    func getOpponentProjectedScore() async -> Double {
        let projections = await ProjectedPointsManager.shared.getProjectedMatchupScores(for: self)
        return projections.opponent
    }
    
    /// Get both projected scores at once (more efficient)
    func getProjectedScores() async -> (myTeam: Double, opponent: Double) {
        return await ProjectedPointsManager.shared.getProjectedMatchupScores(for: self)
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