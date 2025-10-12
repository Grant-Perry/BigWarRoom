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
            // print("🔥 LOADING: Already loading, ignoring duplicate request")
            return 
        }
        
        let loadingSessionId = UUID().uuidString.prefix(8)
        // print("🔥 LOADING SESSION \(loadingSessionId): Starting new loading session")
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Discovering leagues..."
            loadingProgress = 0.0
            loadedLeagueCount = 0
        }
        
        do {
            // Step 0: Fetch NFL game data for live detection - 5% progress
            await updateProgress(0.05, message: "Loading NFL data...", sessionId: String(loadingSessionId))
            await fetchNFLGameData()
            
            // Step 1: Load all available leagues - 10% progress
            await updateProgress(0.10, message: "Loading available leagues...", sessionId: String(loadingSessionId))
            
            // 🔥 FIX: Use dynamic Sleeper credentials instead of hardcoded AppConstants.GpSleeperID
            let sleeperUserID = SleeperCredentialsManager.shared.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
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
            await loadMatchupsFromAllLeagues(availableLeagues, sessionId: String(loadingSessionId))
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load leagues: \(error.localizedDescription)"
                isLoading = false
            }
        }
        
        // print("🔥 LOADING SESSION \(loadingSessionId): Completed loading session")
    }
    
    /// 🔥 NEW: Bulletproof progress update that forces UI refresh
    private func updateProgress(_ progress: Double, message: String, sessionId: String) async {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        // print("🔥 SESSION \(sessionId): Setting progress to \(clampedProgress) (\(Int(clampedProgress * 100))%)")
        
        await MainActor.run {
            // Update all progress-related properties at once
            self.loadingProgress = clampedProgress
            self.currentLoadingLeague = message
            
            // print("🔥 SESSION \(sessionId): UI properties updated - progress=\(self.loadingProgress), message='\(self.currentLoadingLeague)'")
        }
    }
    
    /// Load matchups from all leagues with progressive updates
    internal func loadMatchupsFromAllLeagues(_ leagues: [UnifiedLeagueManager.LeagueWrapper], sessionId: String) async {
        // Initialize loading states - 15% progress
        await updateProgress(0.15, message: "Initializing leagues...", sessionId: sessionId)
        
        // print("🔥 SESSION \(sessionId): Starting to load \(leagues.count) leagues")
        
        await MainActor.run {
            for league in leagues {
                loadingStates[league.id] = LeagueLoadingState(
                    name: league.league.name,
                    status: .pending,
                    progress: 0.0
                )
                // print("🔥 SESSION \(sessionId): Initialized league: \(league.league.name)")
            }
        }
        
        // 🔥 PROGRESS RANGE: 20% -> 90% for league loading
        let totalLeagues = leagues.count
        var processedLeagues = 0
        
        // print("🔥 SESSION \(sessionId): About to start withTaskGroup for \(totalLeagues) leagues")
        
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: (UnifiedMatchup?, String).self) { group in
            // print("🔥 SESSION \(sessionId): Inside withTaskGroup, adding tasks...")
            
            for league in leagues {
                // print("🔥 SESSION \(sessionId): Adding task for league: \(league.league.name)")
                group.addTask {
                    // print("🔥 SESSION \(sessionId): Starting task for league: \(league.league.name)")
                    let matchup = await self.loadSingleLeagueMatchup(league)
                    // print("🔥 SESSION \(sessionId): Finished task for league: \(league.league.name), matchup: \(matchup != nil ? "SUCCESS" : "FAILED")")
                    return (matchup, league.id)
                }
            }
            
            var loadedMatchups: [UnifiedMatchup] = []
            
            // print("🔥 SESSION \(sessionId): About to iterate through task group results...")
            
            for await (matchup, leagueID) in group {
                processedLeagues += 1
                // print("🔥 SESSION \(sessionId): Processed league \(processedLeagues)/\(totalLeagues), matchup: \(matchup != nil ? "SUCCESS" : "FAILED")")
                
                if let matchup = matchup {
                    await MainActor.run {
                        loadedMatchups.append(matchup)
                        self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
                    }
                    // print("🔥 SESSION \(sessionId): Added matchup to collection, total: \(loadedMatchups.count)")
                }
                
                // 🔥 BULLETPROOF PROGRESS: Linear interpolation from 20% to 90%
                let progressPercent = 0.20 + (Double(processedLeagues) / Double(totalLeagues)) * 0.70
                // print("🔥 SESSION \(sessionId): Updating progress to \(progressPercent) (\(Int(progressPercent * 100))%)")
                await updateProgress(
                    progressPercent, 
                    message: "Loaded \(processedLeagues) of \(totalLeagues) leagues...",
                    sessionId: sessionId
                )
                
                await MainActor.run {
                    self.loadedLeagueCount = processedLeagues
                }
            }
            
            // print("🔥 SESSION \(sessionId): Finished processing all league tasks")
        }
        
        // print("🔥 SESSION \(sessionId): Exited withTaskGroup, proceeding to finalization...")
        
        // 🔥 FINAL STEPS: 90% -> 100%
        // print("🔥 SESSION \(sessionId): Starting finalization at 95%...")
        await updateProgress(0.95, message: "Finalizing matchups...", sessionId: sessionId)
        
        // Brief pause to show near completion
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        
        // print("🔥 SESSION \(sessionId): Setting progress to 100%...")
        await updateProgress(1.0, message: "Complete!", sessionId: sessionId)
        
        // Brief pause to show 100% completion
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        
        // Finalize loading
        // print("🔥 SESSION \(sessionId): Calling finalizeLoading()...")
        await finalizeLoading()
        
        // print("🔥 SESSION \(sessionId): Completely finished loading process")
    }
    
    /// Load matchup for a single league using isolated LeagueMatchupProvider
    internal func loadSingleLeagueMatchup(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentYear()
        let leagueKey = "\(league.id)_\(currentWeek)_\(currentYear)"
        
        // 🔥 FIX: Bulletproof race condition prevention with lock
        loadingLock.lock()
        if currentlyLoadingLeagues.contains(leagueKey) {
            loadingLock.unlock()
            // print("🔥 SINGLE LEAGUE: Already loading \(league.league.name), skipping")
            return nil
        }
        currentlyLoadingLeagues.insert(leagueKey)
        loadingLock.unlock()
        
        defer { 
            loadingLock.lock()
            currentlyLoadingLeagues.remove(leagueKey)
            loadingLock.unlock()
            // print("🔥 SINGLE LEAGUE: Finished loading \(league.league.name)")
        }
        
        // Update individual league progress
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.1)
        
        do {
            // print("🔥 SINGLE LEAGUE: Creating provider for \(league.league.name)")
            
            // 🔥 NEW APPROACH: Create isolated provider for this league
            let provider = LeagueMatchupProvider(
                league: league, 
                week: currentWeek,  // Use the actual week
                year: currentYear
            )
            
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.3)
            
            // print("🔥 SINGLE LEAGUE: Identifying team ID for \(league.league.name)")
            
            // Step 1: Identify user's team ID
            guard let myTeamID = await provider.identifyMyTeamID() else {
                // print("🔥 SINGLE LEAGUE: Failed to identify team ID for \(league.league.name)")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            // print("🔥 SINGLE LEAGUE: Found team ID '\(myTeamID)' for \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.6)
            
            // Step 2: Fetch matchups using isolated provider
            // print("🔥 SINGLE LEAGUE: Fetching matchups for \(league.league.name)")
            let matchups = try await provider.fetchMatchups()
            // print("🔥 SINGLE LEAGUE: Fetched \(matchups.count) matchups for \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
            
            // 🔥 NEW: Cache the fully-loaded provider for later use
            await MainActor.run {
                self.cacheProvider(provider, for: league, week: currentWeek, year: currentYear)
            }
            
            // Step 3: Check for Chopped league
            if league.source == .sleeper && matchups.isEmpty {
                // print("🔥 SINGLE LEAGUE: Detected Chopped league: \(league.league.name)")
                return await handleChoppedLeague(league: league, myTeamID: myTeamID)
            }
            
            // Step 4: Handle regular leagues
            // print("🔥 SINGLE LEAGUE: Processing regular league: \(league.league.name)")
            return await handleRegularLeague(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider)
            
        } catch {
            print("🔥 SINGLE LEAGUE: Error loading \(league.league.name): \(error)")
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
    }
    
    /// Handle regular league processing
    private func handleRegularLeague(
        league: UnifiedLeagueManager.LeagueWrapper, 
        matchups: [FantasyMatchup], 
        myTeamID: String, 
        provider: LeagueMatchupProvider
    ) async -> UnifiedMatchup? {
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.9)
        
        if matchups.isEmpty {
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
                myTeamRanking: nil,
                myIdentifiedTeamID: myTeamID
            )
            
            await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
            return unifiedMatchup
        } else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
    }
    
    /// Finalize the loading process
    private func finalizeLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority (live games first, then by league importance)
            self.myMatchups.sort { $0.priority > $1.priority }
        }
    }
    
    // MARK: - Loading State Management
    
    /// Update loading state message
    internal func updateLoadingState(_ message: String) async {
        await MainActor.run {
            currentLoadingLeague = message
        }
    }
    
    /// Update individual league loading state
    internal func updateLeagueLoadingState(_ leagueID: String, status: LoadingStatus, progress: Double) async {
        await MainActor.run {
            loadingStates[leagueID]?.status = status
            loadingStates[leagueID]?.progress = progress
        }
    }
    
    /// Fetch NFL game data for live detection
    private func fetchNFLGameData() async {
        let currentWeek = NFLWeekService.shared.currentWeek
        let currentYear = Calendar.current.component(.year, from: Date())
        NFLGameDataService.shared.fetchGameData(forWeek: currentWeek, year: currentYear)
    }
}