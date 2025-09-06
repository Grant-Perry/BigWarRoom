//
//  MatchupsHubViewModel.swift
//  BigWarRoom
//
//  The command center for all your fantasy battles across leagues
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MatchupsHubViewModel: ObservableObject {
    
    // MARK: -> Published Properties
    @Published var myMatchups: [UnifiedMatchup] = []
    @Published var isLoading: Bool = false
    @Published var currentLoadingLeague: String = ""
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    @Published var autoRefreshEnabled: Bool = true
    
    // MARK: -> Loading State Management
    @Published var loadingStates: [String: LeagueLoadingState] = [:]
    private var totalLeagueCount: Int = 0
    private var loadedLeagueCount: Int = 0
    
    // MARK: -> Dependencies
    private let unifiedLeagueManager = UnifiedLeagueManager()
    private let sleeperCredentials = SleeperCredentialsManager.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: -> Loading Guards
    private var currentlyLoadingLeagues = Set<String>()
    private let loadingLock = NSLock()
    private let maxConcurrentLoads = 3
    
    // MARK: -> Initialization
    init() {
        setupAutoRefresh()
        
    }
    
    deinit {
        refreshTimer?.invalidate()
        
    }
    
    // MARK: -> Sleeper User Identification
    
    
    // MARK: -> Main Loading Function
    /// Load all matchups across all connected leagues
    func loadAllMatchups() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Discovering leagues..."
            loadingProgress = 0.0
            loadedLeagueCount = 0
        }
        
        do {
            // Step 1: Load all available leagues
            await updateLoadingState("Loading available leagues...")
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: AppConstants.GpSleeperID,
                season: String(Calendar.current.component(.year, from: Date()))
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            totalLeagueCount = availableLeagues.count
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                return
            }
            
            // Step 2: Load matchups for each league in parallel
            await loadMatchupsFromAllLeagues(availableLeagues)
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load leagues: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Load matchups from all leagues with progressive updates
    private func loadMatchupsFromAllLeagues(_ leagues: [UnifiedLeagueManager.LeagueWrapper]) async {
        // Initialize loading states
        await MainActor.run {
            for league in leagues {
                loadingStates[league.id] = LeagueLoadingState(
                    name: league.league.name,
                    status: .pending,
                    progress: 0.0
                )
            }
        }
        
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: UnifiedMatchup?.self) { group in
            for league in leagues {
                group.addTask {
                    await self.loadSingleLeagueMatchup(league)
                }
            }
            
            var loadedMatchups: [UnifiedMatchup] = []
            
            for await matchup in group {
                if let matchup = matchup {
                    await MainActor.run {
                        loadedMatchups.append(matchup)
                        self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
                        
                        self.loadedLeagueCount += 1
                        self.loadingProgress = Double(self.loadedLeagueCount) / Double(self.totalLeagueCount)
                    }
                }
            }
        }
        
        // Finalize loading
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority (live games first, then by league importance)
            self.myMatchups.sort { $0.priority > $1.priority }
        }
    }
    
    /// Load matchup for a single league using isolated LeagueMatchupProvider
    /// 🔥 NO MORE SHARED STATE - each league gets its own provider instance!
    private func loadSingleLeagueMatchup(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(getCurrentWeek())_\(getCurrentYear())"
        
        // 🔥 FIX: Bulletproof race condition prevention with lock
        loadingLock.lock()
        if currentlyLoadingLeagues.contains(leagueKey) {
            loadingLock.unlock()
            print("⚠️ LOADING: Already loading league \(league.league.name), skipping duplicate request")
            return nil
        }
        currentlyLoadingLeagues.insert(leagueKey)
        loadingLock.unlock()
        
        defer { 
            loadingLock.lock()
            currentlyLoadingLeagues.remove(leagueKey)
            loadingLock.unlock()
        }
        
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.1)
        await updateLoadingState("Loading \(league.league.name)...")
        
        do {
            // 🔥 NEW APPROACH: Create isolated provider for this league
            let provider = LeagueMatchupProvider(
                league: league, 
                week: getCurrentWeek(), 
                year: getCurrentYear()
            )
            
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.2)
            
            // Step 1: Identify user's team ID
            guard let myTeamID = await provider.identifyMyTeamID() else {
                print("❌ IDENTIFICATION FAILED: Could not find my team in league \(league.league.name)")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            print("🎯 PROVIDER: Identified myTeamID = '\(myTeamID)' for \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.4)
            
            // Step 2: Fetch matchups using isolated provider
            let matchups = try await provider.fetchMatchups()
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.7)
            
            // Step 3: Check if this is a Chopped league
            if provider.isChoppedLeague() {
                print("🔥 CHOPPED: Processing chopped league: \(league.league.name)")
                
                if let choppedSummary = await provider.getChoppedSummary(),
                   let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                    
                    let unifiedMatchup = UnifiedMatchup(
                        id: "\(league.id)_chopped",
                        league: league,
                        fantasyMatchup: nil,
                        choppedSummary: choppedSummary,
                        lastUpdated: Date(),
                        myTeamRanking: myTeamRanking
                    )
                    
                    await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                    print("✅ Created Chopped league entry for \(league.league.name): \(myTeamRanking.team.ownerName) ranked \(myTeamRanking.rank)")
                    return unifiedMatchup
                } else {
                    print("❌ CHOPPED: Failed to create chopped summary for \(league.league.name)")
                    await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                    return nil
                }
            }
            
            // Step 4: Handle regular leagues
            print("🏈 REGULAR: Processing regular league: \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
            
            if matchups.isEmpty {
                print("⚠️ EMPTY MATCHUPS: No matchups found for \(league.league.name) week \(getCurrentWeek())")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            // Step 5: Find user's matchup using provider
            if let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) {
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_\(myMatchup.id)",
                    league: league,
                    fantasyMatchup: myMatchup,
                    choppedSummary: nil,
                    lastUpdated: Date(),
                    myTeamRanking: nil
                )
                
                await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                print("✅ Created regular matchup for \(league.league.name): \(myMatchup.homeTeam.ownerName) vs \(myMatchup.awayTeam.ownerName)")
                return unifiedMatchup
            } else {
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                print("❌ REGULAR: No matchup found for team ID '\(myTeamID)' in \(league.league.name)")
                return nil
            }
            
        } catch {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            print("❌ LOADING: Failed to load league \(league.league.name): \(error)")
            return nil
        }
    }
    
    /// Find the authenticated user's team in the Chopped leaderboard using proper Sleeper user identification
    private func findMyTeamInChoppedLeaderboard(_ choppedSummary: ChoppedWeekSummary, leagueID: String) async -> FantasyTeamRanking? {
        // Strategy 1: For Sleeper leagues, use roster ID matching
        if let userRosterID = await getCurrentUserRosterID(leagueID: leagueID) {
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.rosterID == userRosterID
            }
            
            if let myRanking = myRanking {
                print("🎯 CHOPPED: Found MY team by roster ID \(userRosterID): \(myRanking.team.ownerName) (\(myRanking.eliminationStatus.displayName))")
                return myRanking
            }
        }
        
        // Strategy 2: Fallback to username matching
        let authenticatedUsername = sleeperCredentials.currentUsername
        if !authenticatedUsername.isEmpty {
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.ownerName.lowercased() == authenticatedUsername.lowercased()
            }
            
            if let myRanking = myRanking {
                print("🎯 CHOPPED: Found MY team by username '\(authenticatedUsername)': \(myRanking.team.ownerName) (\(myRanking.eliminationStatus.displayName))")
                return myRanking
            }
        }
        
        // Strategy 3: Match by "Gp" (specific fallback)
        let gpRanking = choppedSummary.rankings.first { ranking in
            ranking.team.ownerName.lowercased().contains("gp")
        }
        
        if let gpRanking = gpRanking {
            print("🎯 CHOPPED: Found MY team by 'Gp' match: \(gpRanking.team.ownerName) (\(gpRanking.eliminationStatus.displayName))")
            return gpRanking
        }
        
        print("⚠️ CHOPPED: Could not identify user team in league \(leagueID)")
        print("   Available teams: \(choppedSummary.rankings.map { $0.team.ownerName }.joined(separator: ", "))")
        
        // Return first team as fallback
        return choppedSummary.rankings.first
    }
    
    /// Get the current user's roster ID in a Sleeper league (helper for Chopped leagues)
    private func getCurrentUserRosterID(leagueID: String) async -> Int? {
        guard !sleeperCredentials.currentUserID.isEmpty else {
            print("❌ SLEEPER: No user ID available for roster identification")
            return nil
        }
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            let userRoster = rosters.first { $0.ownerID == sleeperCredentials.currentUserID }
            
            if let userRoster = userRoster {
                print("🎯 SLEEPER: Found user roster ID \(userRoster.rosterID) for user \(sleeperCredentials.currentUserID)")
                return userRoster.rosterID
            } else {
                print("⚠️ SLEEPER: No roster found for user \(sleeperCredentials.currentUserID) in league \(leagueID)")
                return nil
            }
        } catch {
            print("❌ SLEEPER: Failed to fetch rosters for league \(leagueID): \(error)")
            return nil
        }
    }
    
    /// Update loading state message
    private func updateLoadingState(_ message: String) async {
        await MainActor.run {
            currentLoadingLeague = message
        }
    }
    
    /// Update individual league loading state
    private func updateLeagueLoadingState(_ leagueID: String, status: LoadingStatus, progress: Double) async {
        await MainActor.run {
            loadingStates[leagueID]?.status = status
            loadingStates[leagueID]?.progress = progress
        }
    }
    
    // MARK: -> Auto Refresh
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        guard autoRefreshEnabled else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !self.isLoading {
                    await self.refreshMatchups()
                }
            }
        }
    }
    
    /// Refresh existing matchups without full reload
    /// 🔥 UPDATED: Uses isolated providers to prevent race conditions
    private func refreshMatchups() async {
        guard !myMatchups.isEmpty && !isLoading else {
            await loadAllMatchups()
            return
        }
        
        // Limit concurrent refreshes
        let maxConcurrentRefresh = 2
        var activeRefreshes = 0
        
        for matchup in myMatchups {
            guard activeRefreshes < maxConcurrentRefresh else { break }
            guard !currentlyLoadingLeagues.contains(matchup.league.id) else { continue }
            
            activeRefreshes += 1
            currentlyLoadingLeagues.insert(matchup.league.id)
            
            Task {
                defer { 
                    currentlyLoadingLeagues.remove(matchup.league.id)
                    activeRefreshes -= 1
                }
                
                // 🔥 NEW APPROACH: Create fresh provider for refresh
                let provider = LeagueMatchupProvider(
                    league: matchup.league,
                    week: getCurrentWeek(),
                    year: getCurrentYear()
                )
                
                // Get user's team ID
                guard let myTeamID = await provider.identifyMyTeamID() else {
                    print("⚠️ REFRESH: Could not identify team for \(matchup.league.league.name)")
                    return
                }
                
                if matchup.isChoppedLeague {
                    // Refresh Chopped league data
                    if let choppedSummary = await provider.getChoppedSummary(),
                       let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: matchup.league.league.leagueID) {
                        
                        await MainActor.run {
                            if let index = self.myMatchups.firstIndex(where: { $0.id == matchup.id }) {
                                self.myMatchups[index] = UnifiedMatchup(
                                    id: matchup.id,
                                    league: matchup.league,
                                    fantasyMatchup: nil,
                                    choppedSummary: choppedSummary,
                                    lastUpdated: Date(),
                                    myTeamRanking: myTeamRanking
                                )
                            }
                        }
                    }
                } else {
                    // Refresh regular matchup data
                    do {
                        let matchups = try await provider.fetchMatchups()
                        
                        if let updatedMatchup = provider.findMyMatchup(myTeamID: myTeamID) {
                            await MainActor.run {
                                if let index = self.myMatchups.firstIndex(where: { $0.id == matchup.id }) {
                                    self.myMatchups[index] = UnifiedMatchup(
                                        id: matchup.id,
                                        league: matchup.league,
                                        fantasyMatchup: updatedMatchup,
                                        choppedSummary: nil,
                                        lastUpdated: Date()
                                    )
                                }
                            }
                        }
                    } catch {
                        print("⚠️ REFRESH: Failed to refresh \(matchup.league.league.name): \(error)")
                    }
                }
            }
        }
        
        await MainActor.run {
            self.lastUpdateTime = Date()
        }
    }
    
    /// Toggle auto refresh
    func toggleAutoRefresh() {
        autoRefreshEnabled.toggle()
        setupAutoRefresh()
    }
    
    /// Manual refresh trigger
    func manualRefresh() async {
        // 🔥 FIX: Clear loading guards before starting fresh
        loadingLock.lock()
        currentlyLoadingLeagues.removeAll()
        loadingLock.unlock()
        
        await loadAllMatchups()
    }
    
    // MARK: -> Helper Methods
    
    /// Get current NFL week
    private func getCurrentWeek() -> Int {
        return NFLWeekService.shared.currentWeek
    }
    
    /// Get current year
    private func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
    }
}

// MARK: -> Supporting Models

/// Unified matchup model combining all league types
struct UnifiedMatchup: Identifiable {
    let id: String
    let league: UnifiedLeagueManager.LeagueWrapper
    let fantasyMatchup: FantasyMatchup?
    let choppedSummary: ChoppedWeekSummary?
    let lastUpdated: Date
    let myTeamRanking: FantasyTeamRanking? // For Chopped leagues
    private let authenticatedUsername: String
    
    init(id: String, league: UnifiedLeagueManager.LeagueWrapper, fantasyMatchup: FantasyMatchup?, choppedSummary: ChoppedWeekSummary?, lastUpdated: Date, myTeamRanking: FantasyTeamRanking? = nil) {
        self.id = id
        self.league = league
        self.fantasyMatchup = fantasyMatchup
        self.choppedSummary = choppedSummary
        self.lastUpdated = lastUpdated
        self.myTeamRanking = myTeamRanking
        self.authenticatedUsername = SleeperCredentialsManager.shared.currentUsername
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
    
    /// My team in this matchup (properly identified by authenticated username)
    var myTeam: FantasyTeam? {
        // For Chopped leagues, get team from myTeamRanking
        if isChoppedLeague, let ranking = myTeamRanking {
            return ranking.team
        }
        
        // For regular matchups
        guard let matchup = fantasyMatchup else { return nil }
        
        // For Sleeper leagues, match by authenticated username
        if league.source == .sleeper && !authenticatedUsername.isEmpty {
            if matchup.homeTeam.ownerName.lowercased() == authenticatedUsername.lowercased() {
                return matchup.homeTeam
            }
            if matchup.awayTeam.ownerName.lowercased() == authenticatedUsername.lowercased() {
                return matchup.awayTeam
            }
        }
        
        // Fallback for ESPN or unidentified users
        return matchup.homeTeam
    }
    
    /// Opponent team in this matchup (nil for Chopped leagues since there's no opponent)
    var opponentTeam: FantasyTeam? {
        // Chopped leagues have NO opponent - everyone vs everyone
        if isChoppedLeague {
            return nil
        }
        
        guard let matchup = fantasyMatchup, let myTeam = myTeam else { return nil }
        
        // Return the team that's NOT my team
        if matchup.homeTeam.id == myTeam.id {
            return matchup.awayTeam
        } else {
            return matchup.homeTeam
        }
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