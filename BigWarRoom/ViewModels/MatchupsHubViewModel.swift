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
    private let fantasyViewModel = FantasyViewModel()
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
        
        // Take control of FantasyViewModel to prevent refresh conflicts
        fantasyViewModel.setMatchupsHubControl(true)
    }
    
    deinit {
        refreshTimer?.invalidate()
        
        // Release control of FantasyViewModel
        fantasyViewModel.setMatchupsHubControl(false)
    }
    
    // MARK: -> Sleeper User Identification
    
    /// Get the current user's roster ID in a Sleeper league
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
    
    /// Load matchup for a single league
    private func loadSingleLeagueMatchup(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(fantasyViewModel.selectedWeek)_\(fantasyViewModel.selectedYear)"
        
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
            // Set the league in fantasy view model
            fantasyViewModel.selectLeague(league)
            
            // 🔥 FIX: Populate name resolution data BEFORE fetching matchups
            if league.source == .sleeper {
                await fantasyViewModel.fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                await updateLeagueLoadingState(league.id, status: .loading, progress: 0.3)
            }
            
            // Now load matchups - this will have proper manager names
            await fantasyViewModel.fetchMatchups()
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.6)
            
            // For Sleeper leagues, wait longer for chopped detection to complete properly
            if league.source == .sleeper {
                // Wait longer for background chopped validation to complete
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await updateLeagueLoadingState(league.id, status: .loading, progress: 0.7)
                
                // Additional check: Wait for detectedAsChoppedLeague to be set if matchups are empty
                var attempts = 0
                while attempts < 5 && fantasyViewModel.matchups.isEmpty && !fantasyViewModel.detectedAsChoppedLeague {
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    attempts += 1
                    print("⏳ WAITING: Attempt \(attempts) - waiting for chopped detection to complete...")
                }
            }
            
            // NOW check if it's chopped using the centralized method
            let isChopped = league.isChoppedLeague
            print("🔍 CHOPPED CHECK RESULT: League \(league.league.name) -> isChopped: \(isChopped)")
            print("   - Final matchups.count: \(fantasyViewModel.matchups.count)")
            
            if isChopped {
                print("🔥 CHOPPED: Processing chopped league: \(league.league.name)")
                
                // Use FantasyViewModel's existing chopped summary creation
                let choppedSummary = await fantasyViewModel.createRealChoppedSummary(
                    leagueID: league.league.leagueID, 
                    week: fantasyViewModel.selectedWeek
                )
                
                if let choppedSummary = choppedSummary,
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
                    print("❌ CHOPPED: Failed to create chopped summary or find my team for \(league.league.name)")
                    // Fall back to regular matchup processing
                }
            }
            
            // For regular leagues (non-Chopped) OR if chopped processing failed
            print("🏈 REGULAR: Processing regular league: \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
            
            // 🔥 FIX: Better error handling for empty matchups
            if fantasyViewModel.matchups.isEmpty {
                print("⚠️ EMPTY MATCHUPS: No matchups found for \(league.league.name) week \(fantasyViewModel.selectedWeek)")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                
                // For ESPN leagues, this might be a valid state (bye week, wrong week, etc.)
                if league.source == .espn {
                    print("🏈 ESPN: Empty matchups might be normal for week \(fantasyViewModel.selectedWeek)")
                }
                return nil
            }
            
            // Find MY matchup using proper identification
            if let myMatchup = await findMyMatchupInLeague(league, matchups: fantasyViewModel.matchups) {
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
                print("❌ REGULAR: No matchup found for user in \(league.league.name)")
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
    
    /// Find the user's matchup in a specific league using proper identification
    private func findMyMatchupInLeague(_ league: UnifiedLeagueManager.LeagueWrapper, matchups: [FantasyMatchup]) async -> FantasyMatchup? {
        
        // For Sleeper leagues, use roster ID matching (most reliable)
        if league.source == .sleeper {
            if let userRosterID = await getCurrentUserRosterID(leagueID: league.league.leagueID) {
                for matchup in matchups {
                    if matchup.homeTeam.rosterID == userRosterID || matchup.awayTeam.rosterID == userRosterID {
                        print("🎯 SLEEPER: Found MY matchup by roster ID \(userRosterID): \(matchup.homeTeam.ownerName) vs \(matchup.awayTeam.ownerName)")
                        return matchup
                    }
                }
            }
            
            // Fallback to username matching for Sleeper
            let authenticatedUsername = sleeperCredentials.currentUsername
            if !authenticatedUsername.isEmpty {
                for matchup in matchups {
                    if matchup.homeTeam.ownerName.lowercased() == authenticatedUsername.lowercased() ||
                       matchup.awayTeam.ownerName.lowercased() == authenticatedUsername.lowercased() {
                        print("🎯 SLEEPER: Found MY matchup by username '\(authenticatedUsername)': \(matchup.homeTeam.ownerName) vs \(matchup.awayTeam.ownerName)")
                        return matchup
                    }
                }
            }
            
            // Last resort: Match by "Gp" pattern
            for matchup in matchups {
                if matchup.homeTeam.ownerName.lowercased().contains("gp") ||
                   matchup.awayTeam.ownerName.lowercased().contains("gp") {
                    print("🎯 SLEEPER: Found MY matchup by 'Gp' pattern: \(matchup.homeTeam.ownerName) vs \(matchup.awayTeam.ownerName)")
                    return matchup
                }
            }
            
            print("⚠️ SLEEPER: Could not identify user matchup in league \(league.league.name)")
            print("   Available teams: \(matchups.flatMap { [$0.homeTeam.ownerName, $0.awayTeam.ownerName] }.joined(separator: ", "))")
        }
        
        // 🔥 FIX: For ESPN leagues, use SWID matching to find MY team!
        if league.source == .espn {
            let myESPNID = AppConstants.GpESPNID
            print("🔍 ESPN: Looking for my SWID '\(myESPNID)' in league \(league.league.name)")
            
            // Get ESPN team ownership data
            let teamOwnership = await getESPNTeamOwnership(leagueID: league.league.leagueID)
            
            // 🔥 DEBUG: Log all matchup roster IDs vs team ownership
            print("🔍 ESPN DEBUG: Matchup roster IDs vs team ownership for \(league.league.name):")
            for (index, matchup) in matchups.enumerated() {
                print("   Matchup \(index + 1): Home=\(matchup.homeTeam.ownerName) (roster:\(matchup.homeTeam.rosterID ?? -1)) vs Away=\(matchup.awayTeam.ownerName) (roster:\(matchup.awayTeam.rosterID ?? -1))")
            }
            print("   Team ownership: \(teamOwnership)")
            
            // Find MY matchup by checking which team I own
            for (index, matchup) in matchups.enumerated() {
                // Check if I own the home team
                if let homeRosterID = matchup.homeTeam.rosterID {
                    print("🔍 ESPN: Checking home team - roster \(homeRosterID), owners: \(teamOwnership[homeRosterID] ?? [])")
                    if let homeOwners = teamOwnership[homeRosterID] {
                        let containsCheck = homeOwners.contains(myESPNID)
                        print("🧪 ESPN: Contains check for home team \(homeRosterID): myESPNID='\(myESPNID)' in \(homeOwners) = \(containsCheck)")
                        
                        if containsCheck {
                            print("🎯 ESPN: Found MY matchup by home team roster ID \(homeRosterID): \(matchup.homeTeam.ownerName) vs \(matchup.awayTeam.ownerName)")
                            return matchup
                        }
                    }
                } else {
                    print("⚠️ ESPN: Home team rosterID is nil for matchup \(index + 1)")
                }
                
                // Check if I own the away team
                if let awayRosterID = matchup.awayTeam.rosterID {
                    print("🔍 ESPN: Checking away team - roster \(awayRosterID), owners: \(teamOwnership[awayRosterID] ?? [])")
                    if let awayOwners = teamOwnership[awayRosterID] {
                        let containsCheck = awayOwners.contains(myESPNID)
                        print("🧪 ESPN: Contains check for away team \(awayRosterID): myESPNID='\(myESPNID)' in \(awayOwners) = \(containsCheck)")
                        
                        if containsCheck {
                            print("🎯 ESPN: Found MY matchup by away team roster ID \(awayRosterID): \(matchup.awayTeam.ownerName) vs \(matchup.homeTeam.ownerName)")
                            return matchup
                        }
                    }
                } else {
                    print("⚠️ ESPN: Away team rosterID is nil for matchup \(index + 1)")
                }
            }
            
            print("⚠️ ESPN: Could not identify user matchup in league \(league.league.name)")
            print("   Available teams: \(matchups.flatMap { [$0.homeTeam.ownerName, $0.awayTeam.ownerName] }.joined(separator: ", "))")
            print("   My SWID: \(myESPNID)")
            print("   Team ownership: \(teamOwnership)")
            
            // Fallback: return first matchup but with warning
            if let firstMatchup = matchups.first {
                print("⚠️ ESPN: Falling back to first matchup: \(firstMatchup.homeTeam.ownerName) vs \(firstMatchup.awayTeam.ownerName)")
                return firstMatchup
            }
        }
        
        return nil
    }
    
    /// Get ESPN team ownership mapping for a specific league
    private func getESPNTeamOwnership(leagueID: String) async -> [Int: [String]] {
        do {
            // Fetch the full ESPN league data to get team ownership
            let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: leagueID)
            
            var ownership: [Int: [String]] = [:]
            
            if let teams = espnLeague.teams {
                for team in teams {
                    ownership[team.id] = team.owners ?? []
                }
                
                print("📋 ESPN: Retrieved team ownership for league \(leagueID):")
                for (teamID, owners) in ownership {
                    print("   Team \(teamID): \(owners)")
                }
            }
            
            return ownership
            
        } catch {
            print("❌ ESPN: Failed to fetch team ownership for league \(leagueID): \(error)")
            return [:]
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
                
                fantasyViewModel.selectLeague(matchup.league)
                
                if matchup.isChoppedLeague {
                    // Refresh Chopped league data using FantasyViewModel's method
                    let choppedSummary = await fantasyViewModel.createRealChoppedSummary(
                        leagueID: matchup.league.league.leagueID,
                        week: fantasyViewModel.selectedWeek
                    )
                    
                    if let choppedSummary = choppedSummary,
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
                    await fantasyViewModel.refreshMatchups()
                    
                    if let updatedMatchup = await findMyMatchupInLeague(matchup.league, matchups: fantasyViewModel.matchups) {
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