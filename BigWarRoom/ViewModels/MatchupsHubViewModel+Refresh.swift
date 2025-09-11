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
    /// 🔥 FIXED: Uses selected week instead of current week
    private func refreshMatchups() async {
        guard !myMatchups.isEmpty && !isLoading else {
            await performLoadAllMatchups()
            return
        }
        
        // Get the currently selected week from WeekSelectionManager
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
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
                
                await refreshSingleMatchup(matchup, forWeek: selectedWeek)
            }
        }
        
        await MainActor.run {
            self.lastUpdateTime = Date()
        }
    }
    
    /// Refresh a single matchup for a specific week
    /// 🔥 FIXED: Now takes week parameter to use selected week
    private func refreshSingleMatchup(_ matchup: UnifiedMatchup, forWeek week: Int) async {
        // Create fresh provider for refresh with the correct week
        let provider = LeagueMatchupProvider(
            league: matchup.league,
            week: week,  // 🔥 FIXED: Use selected week instead of current week
            year: getCurrentYear()
        )
        
        // Get user's team ID
        guard let myTeamID = await provider.identifyMyTeamID() else {
            // x Print("⚠️ REFRESH: Could not identify team for \(matchup.league.league.name)")
            return
        }
        
        if matchup.isChoppedLeague {
            await refreshChoppedMatchup(matchup, myTeamID: myTeamID, provider: provider, week: week)
        } else {
            await refreshRegularMatchup(matchup, myTeamID: myTeamID, provider: provider, week: week)
        }
    }
    
    /// Refresh chopped league matchup for specific week
    private func refreshChoppedMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider, week: Int) async {
        if let choppedSummary = await createSleeperChoppedSummary(league: matchup.league, myTeamID: myTeamID, week: week),
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
    
    /// Refresh regular matchup for specific week
    private func refreshRegularMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider, week: Int) async {
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
            // x Print("⚠️ REFRESH: Failed to refresh \(matchup.league.league.name) Week \(week): \(error)")
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
    /// 🔥 FIXED: Uses selected week instead of current week
    private func refreshMatchupsInBackground() async {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        await MainActor.run {
            // Only update timestamp, don't change isLoading or show loading screen
            lastUpdateTime = Date()
        }
        
        do {
            // Step 0: Refresh NFL game data for the selected week (not just current)
            let currentYear = Calendar.current.component(.year, from: Date())
            NFLGameDataService.shared.fetchGameData(forWeek: selectedWeek, year: currentYear, forceRefresh: true)
            
            // Step 1: Refresh available leagues quietly
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: AppConstants.GpSleeperID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            guard !availableLeagues.isEmpty else { return }
            
            // Step 2: Refresh all league data for selected week
            await loadMatchupsFromAllLeaguesBackground(availableLeagues, forWeek: selectedWeek)
            
        } catch {
            // x Print("⚠️ BACKGROUND REFRESH: Failed to refresh leagues: \(error)")
        }
    }
    
    /// Background version of loadMatchupsFromAllLeagues for specific week
    private func loadMatchupsFromAllLeaguesBackground(_ leagues: [UnifiedLeagueManager.LeagueWrapper], forWeek week: Int) async {
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: UnifiedMatchup?.self) { group in
            for league in leagues {
                group.addTask {
                    await self.loadSingleLeagueMatchupBackground(league, forWeek: week)
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
    
    /// Background version for specific week
    private func loadSingleLeagueMatchupBackground(_ league: UnifiedLeagueManager.LeagueWrapper, forWeek week: Int) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(week)_\(getCurrentYear())"
        
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
            // Create isolated provider for this league with specific week
            let provider = LeagueMatchupProvider(
                league: league, 
                week: week,  // 🔥 FIXED: Use specific week
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
                return await handleChoppedLeagueBackground(league: league, myTeamID: myTeamID, week: week)
            }
            
            // Step 4: Handle regular leagues
            return await handleRegularLeagueBackground(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider, week: week)
            
        } catch {
            return nil
        }
    }
    
    /// Background chopped league handling for specific week
    private func handleChoppedLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> UnifiedMatchup? {
        // Create chopped summary using proper Sleeper data for specific week
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: week) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped_\(week)",
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
    
    /// Background regular league handling for specific week
    private func handleRegularLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, matchups: [FantasyMatchup], myTeamID: String, provider: LeagueMatchupProvider, week: Int) async -> UnifiedMatchup? {
        if matchups.isEmpty {
            return nil
        }
        
        // Find user's matchup using provider
        if let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) {
            let unifiedMatchup = UnifiedMatchup(
                id: "\(league.id)_\(myMatchup.id)_\(week)",
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