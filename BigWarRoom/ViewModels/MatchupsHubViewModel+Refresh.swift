//
//  MatchupsHubViewModel+Refresh.swift
//  BigWarRoom
//
//  Auto-refresh and manual refresh logic for MatchupsHubViewModel
//

import Foundation
import SwiftUI

// MARK: - Refresh Operations
extension MatchupsHubViewModel {
    
    // MARK: - Auto Refresh Setup
    internal func setupAutoRefresh() {
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
            await performLoadAllMatchups()
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
                
                await refreshSingleMatchup(matchup)
            }
        }
        
        await MainActor.run {
            self.lastUpdateTime = Date()
        }
    }
    
    /// Refresh a single matchup
    private func refreshSingleMatchup(_ matchup: UnifiedMatchup) async {
        // 🔥 NEW APPROACH: Create fresh provider for refresh
        let provider = LeagueMatchupProvider(
            league: matchup.league,
            week: getCurrentWeek(),
            year: getCurrentYear()
        )
        
        // Get user's team ID
        guard let myTeamID = await provider.identifyMyTeamID() else {
            // x Print("⚠️ REFRESH: Could not identify team for \(matchup.league.league.name)")
            return
        }
        
        if matchup.isChoppedLeague {
            await refreshChoppedMatchup(matchup, myTeamID: myTeamID, provider: provider)
        } else {
            await refreshRegularMatchup(matchup, myTeamID: myTeamID, provider: provider)
        }
    }
    
    /// Refresh chopped league matchup
    private func refreshChoppedMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider) async {
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
                        myTeamRanking: myTeamRanking,
                        myIdentifiedTeamID: myTeamID
                    )
                }
            }
        }
    }
    
    /// Refresh regular matchup
    private func refreshRegularMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider) async {
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
                            lastUpdated: Date(),
                            myTeamRanking: nil,
                            myIdentifiedTeamID: myTeamID
                        )
                    }
                }
            }
        } catch {
            // x Print("⚠️ REFRESH: Failed to refresh \(matchup.league.league.name): \(error)")
        }
    }
    
    // MARK: - Manual Refresh
    
    /// Manual refresh trigger - BACKGROUND REFRESH (no loading screen)
    internal func performManualRefresh() async {
        // 🔥 FIX: Don't show loading screen for manual refresh - keep user on Mission Control
        guard !isLoading else { return }
        
        // Clear loading guards before starting fresh refresh
        loadingLock.lock()
        currentlyLoadingLeagues.removeAll()
        loadingLock.unlock()
        
        // BACKGROUND REFRESH: Update data without showing loading screen
        await refreshMatchupsInBackground()
    }
    
    /// Background refresh that doesn't disrupt the UI
    private func refreshMatchupsInBackground() async {
        await MainActor.run {
            // Only update timestamp, don't change isLoading or show loading screen
            lastUpdateTime = Date()
        }
        
        do {
            // Step 0: Refresh NFL game data for live detection
            let currentWeek = NFLWeekService.shared.currentWeek
            let currentYear = Calendar.current.component(.year, from: Date())
            NFLGameDataService.shared.fetchGameData(forWeek: currentWeek, year: currentYear, forceRefresh: true)
            
            // Step 1: Refresh available leagues quietly
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: AppConstants.GpSleeperID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            guard !availableLeagues.isEmpty else { return }
            
            // Step 2: Refresh all league data in parallel
            await loadMatchupsFromAllLeaguesBackground(availableLeagues)
            
        } catch {
            // x Print("⚠️ BACKGROUND REFRESH: Failed to refresh leagues: \(error)")
        }
    }
    
    /// Background version of loadMatchupsFromAllLeagues that doesn't update loading UI
    private func loadMatchupsFromAllLeaguesBackground(_ leagues: [UnifiedLeagueManager.LeagueWrapper]) async {
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: UnifiedMatchup?.self) { group in
            for league in leagues {
                group.addTask {
                    await self.loadSingleLeagueMatchupBackground(league)
                }
            }
            
            var refreshedMatchups: [UnifiedMatchup] = []
            
            for await matchup in group {
                if let matchup = matchup {
                    refreshedMatchups.append(matchup)
                }
            }
            
            // Update the UI with fresh data
            await MainActor.run {
                self.myMatchups = refreshedMatchups.sorted { $0.priority > $1.priority }
                self.lastUpdateTime = Date()
            }
        }
    }
    
    /// Background version that doesn't update loading states
    private func loadSingleLeagueMatchupBackground(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(getCurrentWeek())_\(getCurrentYear())"
        
        // Race condition prevention
        loadingLock.lock()
        if currentlyLoadingLeagues.contains(leagueKey) {
            loadingLock.unlock()
            return nil
        }
        currentlyLoadingLeagues.insert(leagueKey)
        loadingLock.unlock()
        
        defer { 
            loadingLock.lock()
            currentlyLoadingLeagues.remove(leagueKey)
            loadingLock.unlock()
        }
        
        do {
            // Create isolated provider for this league (no UI updates)
            let provider = LeagueMatchupProvider(
                league: league, 
                week: getCurrentWeek(), 
                year: getCurrentYear()
            )
            
            // Step 1: Identify user's team ID
            guard let myTeamID = await provider.identifyMyTeamID() else {
                return nil
            }
            
            // Step 2: Fetch matchups using isolated provider
            let matchups = try await provider.fetchMatchups()
            
            // Step 3: Check for Chopped league
            if league.source == .sleeper && matchups.isEmpty {
                return await handleChoppedLeagueBackground(league: league, myTeamID: myTeamID)
            }
            
            // Step 4: Handle regular leagues
            return await handleRegularLeagueBackground(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider)
            
        } catch {
            return nil
        }
    }
    
    /// Background chopped league handling
    private func handleChoppedLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        // Create chopped summary using proper Sleeper data
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: getCurrentWeek()) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped",
                    league: league,
                    fantasyMatchup: nil,
                    choppedSummary: choppedSummary,
                    lastUpdated: Date(),
                    myTeamRanking: myTeamRanking,
                    myIdentifiedTeamID: myTeamID
                )
                
                return unifiedMatchup
            }
        }
        return nil
    }
    
    /// Background regular league handling
    private func handleRegularLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, matchups: [FantasyMatchup], myTeamID: String, provider: LeagueMatchupProvider) async -> UnifiedMatchup? {
        if matchups.isEmpty {
            return nil
        }
        
        // Find user's matchup using provider
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
            
            return unifiedMatchup
        } else {
            return nil
        }
    }
}
