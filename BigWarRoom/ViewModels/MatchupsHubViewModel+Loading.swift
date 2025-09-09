//
//  MatchupsHubViewModel+Loading.swift
//  BigWarRoom
//
//  Main loading logic for MatchupsHubViewModel
//

import Foundation
import SwiftUI

// MARK: - Loading Operations
extension MatchupsHubViewModel {
    
    /// Main loading function - Load all matchups across all connected leagues
    internal func performLoadAllMatchups() async {
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
            // Step 0: Fetch NFL game data for live detection
            await fetchNFLGameData()
            
            // Step 1: Load all available leagues
            await updateLoadingState("Loading available leagues...")
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: AppConstants.GpSleeperID,
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
            await loadMatchupsFromAllLeagues(availableLeagues)
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load leagues: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Load matchups from all leagues with progressive updates
    internal func loadMatchupsFromAllLeagues(_ leagues: [UnifiedLeagueManager.LeagueWrapper]) async {
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
        await finalizeLoading()
    }
    
    /// Load matchup for a single league using isolated LeagueMatchupProvider
    internal func loadSingleLeagueMatchup(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(getCurrentWeek())_\(getCurrentYear())"
        
        // 🔥 FIX: Bulletproof race condition prevention with lock
        loadingLock.lock()
        if currentlyLoadingLeagues.contains(leagueKey) {
            loadingLock.unlock()
            // x Print("⚠️ LOADING: Already loading league \(league.league.name), skipping duplicate request")
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
                // x Print("❌ IDENTIFICATION FAILED: Could not find my team in league \(league.league.name)")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            // x Print("🎯 PROVIDER: Identified myTeamID = '\(myTeamID)' for \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.4)
            
            // Step 2: Fetch matchups using isolated provider
            let matchups = try await provider.fetchMatchups()
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.7)
            
            // Step 3: Check for Chopped league
            if league.source == .sleeper && matchups.isEmpty {
                return await handleChoppedLeague(league: league, myTeamID: myTeamID)
            }
            
            // Step 4: Handle regular leagues
            return await handleRegularLeague(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider)
            
        } catch {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            // x Print("❌ LOADING: Failed to load league \(league.league.name): \(error)")
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
        // x Print("🏈 REGULAR: Processing regular league: \(league.league.name)")
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
        
        if matchups.isEmpty {
            // x Print("⚠️ EMPTY MATCHUPS: No matchups found for \(league.league.name) week \(getCurrentWeek())")
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
            // x Print("✅ Created regular matchup for \(league.league.name): \(myMatchup.homeTeam.ownerName) vs \(myMatchup.awayTeam.ownerName)")
            return unifiedMatchup
        } else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            // x Print("❌ REGULAR: No matchup found for team ID '\(myTeamID)' in \(league.league.name)")
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
