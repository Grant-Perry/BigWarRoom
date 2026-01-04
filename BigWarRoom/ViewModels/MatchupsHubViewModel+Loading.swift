//
//  MatchupsHubViewModel+Loading.swift
//  BigWarRoom
//
//  Main loading logic for MatchupsHubViewModel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading Operations
extension MatchupsHubViewModel {
    
    /// Main loading function - Load all matchups across all connected leagues
    internal func performLoadAllMatchups() async {
        guard !isLoading else { 
            DebugPrint(mode: .matchupLoading, "performLoadAllMatchups called - ALREADY LOADING, ignoring")
            return 
        }
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups STARTING")
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Loading from data store..."
            loadingProgress = 0.0
        }
        
        // 🚀 NEW: Check for cached data first
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentYear()
        
        if let cachedData = MatchupCacheManager.shared.loadCachedData(week: currentWeek, year: currentYear) {
            DebugPrint(mode: .matchupLoading, "⚡ CACHE HIT: Loading \(cachedData.snapshots.count) matchups from cache!")
            await loadMatchupsFromCache(cachedData)
            return
        }
        
        DebugPrint(mode: .matchupLoading, "📦 CACHE MISS: Fetching fresh data...")
        
        do {
            // Step 1: Fetch available leagues - 10% progress
            await updateProgress(0.10, message: "Loading available leagues...", sessionId: "STORE")
            
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                return
            }
            
            // Step 2: Convert to LeagueDescriptor and warm the store - 30% progress
            await updateProgress(0.30, message: "Warming data store...", sessionId: "STORE")
            
            let leagueDescriptors = availableLeagues.map { league in
                LeagueDescriptor(
                    id: league.id,
                    name: league.league.name,
                    platform: league.source,
                    avatarURL: nil
                )
            }
            
            await matchupDataStore.warmLeagues(leagueDescriptors, week: currentWeek)
            
            // Step 3: Hydrate each matchup lazily - 40% -> 90% progress
            await updateProgress(0.40, message: "Loading matchups...", sessionId: "STORE")
            
            var loadedMatchups: [UnifiedMatchup] = []
            var loadedSnapshots: [MatchupSnapshot] = []  // 🚀 NEW: Collect snapshots for caching
            let totalLeagues = availableLeagues.count
            var processedLeagues = 0
            
            for league in availableLeagues {
                // Calculate base progress for this league
                let baseProgress = 0.40 + (Double(processedLeagues) / Double(totalLeagues)) * 0.45
                
                // Show we're starting this league (no sub-progress, just clear milestone)
                await updateProgress(baseProgress, message: "Loading \(league.league.name)...", sessionId: "STORE")
                
                // Create snapshot ID
                let snapshotID = MatchupSnapshot.ID(
                    leagueID: league.id,
                    matchupID: "\(league.id)_\(currentWeek)",
                    platform: league.source,
                    week: currentWeek
                )
                
                // Hydrate matchup directly (no timeout)
                do {
                    let snapshot = try await self.matchupDataStore.hydrateMatchup(snapshotID)
                    
                    // 🚀 NEW: Save snapshot for caching
                    loadedSnapshots.append(snapshot)
                    
                    // 🔥 SINGLE CONVERSION POINT: Snapshot → UnifiedMatchup
                    let unifiedMatchup = convertSnapshotToUnifiedMatchup(snapshot, league: league)
                    loadedMatchups.append(unifiedMatchup)
                    
                } catch {
                    DebugPrint(mode: .matchupLoading, "❌ Failed to hydrate \(league.league.name): \(error) - trying elimination fallback")
                    
                    // Try playoff elimination fallback
                    if let eliminatedMatchup = await tryEliminatedMatchupFallback(league: league, week: currentWeek) {
                        loadedMatchups.append(eliminatedMatchup)
                        DebugPrint(mode: .matchupLoading, "✅ Created eliminated matchup for \(league.league.name)")
                    } else {
                        DebugPrint(mode: .matchupLoading, "❌ No eliminated fallback available for \(league.league.name)")
                    }
                }
                
                // 🔥 CRITICAL: Always increment, even if hydration failed
                processedLeagues += 1
                let progress = 0.40 + (Double(processedLeagues) / Double(totalLeagues)) * 0.45
                await updateProgress(progress, message: "Loaded \(processedLeagues) of \(totalLeagues) leagues", sessionId: "STORE")
            }
            
            // 🚀 NEW: Save snapshots to cache
            if !loadedSnapshots.isEmpty {
                MatchupCacheManager.shared.saveCachedData(loadedSnapshots, week: currentWeek, year: currentYear)
            }
            
            // Update UI with loaded matchups
            await MainActor.run {
                self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
            }
            
            // 🔥 NEW: Explicit progress milestones to ensure smooth completion
            await updateProgress(0.90, message: "Finalizing data...", sessionId: "STORE")
            try? await Task.sleep(for: .milliseconds(100)) // Brief pause for UI
            
            await updateProgress(0.95, message: "Almost ready...", sessionId: "STORE")
            try? await Task.sleep(for: .milliseconds(100))
            
            // Finalize - 100% progress
            await updateProgress(1.0, message: "Complete!", sessionId: "STORE")
            await finalizeLoading()
            
        }
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups COMPLETE - \(myMatchups.count) matchups")
    }
    
    /// 🚀 NEW: Load matchups from cache (instant!)
    private func loadMatchupsFromCache(_ cachedData: CachedMatchupData) async {
        await updateProgress(0.20, message: "Loading from cache...", sessionId: "CACHE")
        
        // Get available leagues to create wrappers
        let sleeperUserID = sleeperCredentials.getUserIdentifier()
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: sleeperUserID,
            season: cachedData.year
        )
        
        // 🔥 CRITICAL: Warm the store with league descriptors so refresh() can work
        let currentWeek = getCurrentWeek()
        let leagueDescriptors = unifiedLeagueManager.allLeagues.map { league in
            LeagueDescriptor(
                id: league.id,
                name: league.league.name,
                platform: league.source,
                avatarURL: nil
            )
        }
        await matchupDataStore.warmLeagues(leagueDescriptors, week: currentWeek)
        
        await updateProgress(0.50, message: "Building matchups from cache...", sessionId: "CACHE")
        
        var loadedMatchups: [UnifiedMatchup] = []
        
        // Convert cached snapshots back to MatchupSnapshots
        for cachedSnapshot in cachedData.snapshots {
            guard let snapshot = cachedSnapshot.toMatchupSnapshot() else {
                DebugPrint(mode: .matchupLoading, "⚠️ Failed to convert cached snapshot")
                continue
            }
            
            // 🔥 CRITICAL: Pre-populate the store cache with this snapshot
            // This ensures refresh() can find and update it later
            let key = MatchupDataStore.LeagueKey(
                leagueID: snapshot.id.leagueID,
                platform: snapshot.id.platform,
                seasonYear: cachedData.year,
                week: snapshot.id.week
            )
            
            await matchupDataStore.cacheSnapshot(snapshot, for: key)
            
            // Find the corresponding league wrapper
            if let league = unifiedLeagueManager.allLeagues.first(where: { $0.id == snapshot.league.id }) {
                let unifiedMatchup = convertSnapshotToUnifiedMatchup(snapshot, league: league)
                loadedMatchups.append(unifiedMatchup)
            }
        }
        
        await updateProgress(0.90, message: "Finalizing cached data...", sessionId: "CACHE")
        
        await MainActor.run {
            self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
        }
        
        await updateProgress(1.0, message: "Loaded from cache!", sessionId: "CACHE")
        await finalizeCacheLoading()
        
        DebugPrint(mode: .matchupLoading, "⚡ CACHE: Loaded \(myMatchups.count) matchups from cache + warmed store!")
    }
    
    /// 🔥 NEW: Bulletproof progress update that forces UI refresh
    private func updateProgress(_ progress: Double, message: String, sessionId: String) async {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        await MainActor.run {
            self.loadingProgress = clampedProgress
            self.currentLoadingLeague = message
        }
    }
    
    /// Finalize the loading process
    private func finalizeLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority
            self.myMatchups.sort { $0.priority > $1.priority }
        }
        
        // 💊 RX: Check optimization status for all matchups after loading
        await refreshAllOptimizationStatuses()
    }
    
    /// 🚀 NEW: Finalize cache loading WITHOUT setting lastUpdateTime
    /// This allows immediate refresh after loading from cache
    private func finalizeCacheLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            // 🔥 DON'T set lastUpdateTime here - let the first refresh set it
            
            // Sort final matchups by priority
            self.myMatchups.sort { $0.priority > $1.priority }
        }
        
        // 💊 RX: Check optimization status for all matchups after loading
        await refreshAllOptimizationStatuses()
    }
    
    /// Fetch NFL game data for live detection
    private func fetchNFLGameData() async {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = Calendar.current.component(.year, from: Date())
        
        DebugPrint(mode: .weekCheck, "📅 MatchupsHub: Fetching NFL game data for user-selected week \(selectedWeek)")
        
        gameDataService.fetchGameData(forWeek: selectedWeek, year: currentYear)
    }
    
    // MARK: - 🔥 SINGLE SOURCE OF TRUTH: Snapshot → UnifiedMatchup Conversion
    
    /// Convert MatchupSnapshot to UnifiedMatchup (SINGLE conversion point for SSOT)
    /// This is the ONLY place where we convert from domain model (snapshot) to view model (UnifiedMatchup)
    internal func convertSnapshotToUnifiedMatchup(_ snapshot: MatchupSnapshot, league: UnifiedLeagueManager.LeagueWrapper) -> UnifiedMatchup {
        // 🔥 PHASE 2.5: Use DataConversionService for conversion
        let fantasyMatchup = DataConversionService.shared.convertSnapshotToFantasyMatchup(
            snapshot,
            year: getCurrentYear()
        )
        
        return UnifiedMatchup(
            id: snapshot.id.matchupID,
            league: league,
            fantasyMatchup: fantasyMatchup,
            choppedSummary: nil,  // TODO: Handle chopped leagues
            lastUpdated: snapshot.lastUpdated,
            myTeamRanking: nil,  // TODO: Handle chopped ranking
            myIdentifiedTeamID: snapshot.myTeam.info.teamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: nil,  // TODO: Handle horizontal scrolling
            gameDataService: gameDataService
        )
    }
    
    // MARK: - Playoff Elimination Handling
    
    /// Handle playoff elimination - create a special matchup showing the eliminated team
    private func handlePlayoffEliminationMatchup(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> UnifiedMatchup? {
        
        DebugPrint(mode: .matchupLoading, "🏆 Creating eliminated playoff matchup for \(league.league.name)")
        
        let myTeam = await fetchEliminatedTeamRoster(
            league: league,
            myTeamID: myTeamID,
            week: week
        )
        
        guard let eliminatedTeam = myTeam else {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated team roster")
            return nil
        }
        
        DebugPrint(mode: .matchupLoading, "   ✅ Successfully fetched eliminated team roster: \(eliminatedTeam.name) with score \(eliminatedTeam.currentScore ?? 0.0)")
        
        let placeholderOpponent = FantasyTeam(
            id: "eliminated_placeholder",
            name: "Dreams Deferred",
            ownerName: "Dreams Deferred",
            record: nil,
            avatar: nil,
            currentScore: 0.0,
            projectedScore: 0.0,
            roster: [],
            rosterID: 0,
            faabTotal: nil,
            faabUsed: nil
        )
        
        let eliminatedMatchup = FantasyMatchup(
            id: "\(league.league.leagueID)_eliminated_\(week)_\(myTeamID)",
            leagueID: league.league.leagueID,
            week: week,
            year: getCurrentYear(),
            homeTeam: eliminatedTeam,
            awayTeam: placeholderOpponent,
            status: .complete,
            winProbability: 0.0,
            startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            sleeperMatchups: nil
        )
        
        let unifiedMatchup = UnifiedMatchup(
            id: "\(league.id)_eliminated_\(week)",
            league: league,
            fantasyMatchup: eliminatedMatchup,
            choppedSummary: nil,
            lastUpdated: Date(),
            myTeamRanking: nil,
            myIdentifiedTeamID: myTeamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: [eliminatedMatchup],
            gameDataService: gameDataService
        )
        
        DebugPrint(mode: .matchupLoading, "   ✅ Created eliminated playoff matchup for \(league.league.name) Week \(week)")
        return unifiedMatchup
    }
    
    /// Fetch roster data for an eliminated team
    private func fetchEliminatedTeamRoster(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        // 🔥 PHASE 2: Delegate to TeamRosterFetchService
        return await teamRosterFetchService.fetchEliminatedTeamRoster(
            league: league,
            myTeamID: myTeamID,
            week: week
        )
    }
    
    // MARK: - Update League Loading State Helper
    
    /// Update individual league loading state (stub for store-based approach)
    internal func updateLeagueLoadingState(_ leagueID: String, status: LoadingStatus, progress: Double) async {
        await MainActor.run {
            loadingStates[leagueID]?.status = status
            loadingStates[leagueID]?.progress = progress
        }
    }
    
    // MARK: - Eliminated Matchup Fallback
    
    /// Try to create an eliminated matchup when store hydration fails
    private func tryEliminatedMatchupFallback(league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> UnifiedMatchup? {
        // Step 1: Check if this is a chopped league (using service)
        if await choppedLeagueService.isSleeperChoppedLeagueResolved(league) {
            DebugPrint(mode: .matchupLoading, "🪓 Detected chopped league: \(league.league.name)")
            
            // Try to get my team ID (using service)
            guard let myTeamID = await teamIdentificationService.identifyMyTeamID(for: league) else {
                DebugPrint(mode: .matchupLoading, "❌ Could not identify team ID for chopped league")
                return nil
            }
            
            // Call chopped league handler
            return await handleChoppedLeague(league: league, myTeamID: myTeamID)
        }
        
        // Step 2: Check if this is a playoff elimination scenario using service
        if playoffEliminationService.isPlayoffWeek(league: league, week: week) {
            DebugPrint(mode: .matchupLoading, "🏆 Detected playoff week: \(league.league.name)")
            
            // Try to get my team ID (using service)
            guard let myTeamID = await teamIdentificationService.identifyMyTeamID(for: league) else {
                DebugPrint(mode: .matchupLoading, "❌ Could not identify team ID for playoff league")
                return nil
            }
            
            // Check if I'm eliminated from playoffs using service
            if await playoffEliminationService.shouldHideEliminatedPlayoffLeague(league: league, week: week, myTeamID: myTeamID) {
                // User has PE toggle OFF - don't show this league
                DebugPrint(mode: .matchupLoading, "❌ Playoff eliminated and toggle OFF - hiding league")
                return nil
            }
            
            // Check if I'm in winners bracket using service
            let isInWinnersBracket: Bool
            switch league.source {
            case .espn:
                isInWinnersBracket = await playoffEliminationService.isESPNTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
            case .sleeper:
                isInWinnersBracket = await playoffEliminationService.isSleeperTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
            }
            
            if !isInWinnersBracket && UserDefaults.standard.showEliminatedPlayoffLeagues {
                DebugPrint(mode: .matchupLoading, "✅ Playoff eliminated but toggle ON - creating eliminated matchup")
                return await handlePlayoffEliminationMatchup(league: league, myTeamID: myTeamID, week: week)
            }
        }
        
        return nil
    }
}