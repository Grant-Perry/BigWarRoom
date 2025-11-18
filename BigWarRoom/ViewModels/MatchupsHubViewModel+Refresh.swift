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
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(AppConstants.MatchupRefresh), repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !self.isLoading {
                    await self.refreshMatchups()
                }
            }
        }
    }
    
    /// Refresh existing matchups without full reload
    /// 🔥 FIXED: Uses selected week instead of current week
    internal func refreshMatchups() async {
        guard !myMatchups.isEmpty && !isLoading else {
            // 🔥 CRITICAL FIX: Load for selected week, not current week!
            let selectedWeek = WeekSelectionManager.shared.selectedWeek
            if selectedWeek != WeekSelectionManager.shared.currentNFLWeek {
                await performLoadMatchupsForWeek(selectedWeek)
            } else {
                await performLoadAllMatchups()
            }
            return
        }
        
        // 🔥 NEW: Set updating flag for Siri animation  
        isUpdating = true
        
        // 🔥 LIGHT THROTTLING: Prevent rapid duplicate calls (3 seconds minimum)
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        guard timeSinceLastUpdate >= 3.0 else {
            DebugPrint(mode: .globalRefresh, "REFRESH THROTTLED: Only \(String(format: "%.1f", timeSinceLastUpdate))s since last update (min: 3s)")
            isUpdating = false // 🔥 Clear updating flag when throttled
            return
        }
        
        // 🔥 CRITICAL FIX: Clear cached providers to force fresh score data
        cachedProviders.removeAll()
        DebugPrint(mode: .globalRefresh, "Cleared cached providers for fresh scores")
        
        // Get the currently selected week from WeekSelectionManager
        // 🔥 TODO: We'll need to inject WeekSelectionManager too
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        // Refresh all matchups and WAIT for completion before returning
        await withTaskGroup(of: Void.self) { group in
            for matchup in myMatchups {
                let leagueId = matchup.league.id
                group.addTask {
                    // Prevent duplicate loads for the same league (MainActor for isolation)
                    let shouldSkip: Bool = await MainActor.run { () -> Bool in
                        if self.currentlyLoadingLeagues.contains(leagueId) {
                            return true
                        }
                        self.currentlyLoadingLeagues.insert(leagueId)
                        return false
                    }
                    if shouldSkip { return }
                    
                    defer {
                        Task { @MainActor in
                            self.currentlyLoadingLeagues.remove(leagueId)
                        }
                    }
                    
                    await self.refreshSingleMatchup(matchup, forWeek: selectedWeek)
                }
            }
            // Wait for all league refreshes to finish
            await group.waitForAll()
        }
        
        await MainActor.run {
            self.lastUpdateTime = Date()
            // 🔥 Clear updating flag when refresh complete
            self.isUpdating = false
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
                        myIdentifiedTeamID: myTeamID,
                        authenticatedUsername: sleeperCredentials.currentUsername
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
                            myIdentifiedTeamID: myTeamID,
                            authenticatedUsername: sleeperCredentials.currentUsername
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
        guard !isLoading else { 
            DebugPrint(mode: .globalRefresh, "MANUAL REFRESH BLOCKED: Already loading")
            return 
        }
        
        // 🔥 NEW: Set updating flag for Siri animation
        isUpdating = true
        
        // 🔥 LIGHT THROTTLING: Prevent excessive manual refreshes (2 seconds minimum)
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        guard timeSinceLastUpdate >= 2.0 else {
            DebugPrint(mode: .globalRefresh, "MANUAL REFRESH THROTTLED: Only \(String(format: "%.1f", timeSinceLastUpdate))s since last update (min: 2s)")
            isUpdating = false // 🔥 Clear updating flag when throttled
            return
        }
        
        DebugPrint(mode: .globalRefresh, "MANUAL REFRESH START: Proceeding with manual refresh")
        
        // 🔥 PRESERVE Just Me Mode state during refresh
        let wasMicroModeEnabled = microModeEnabled
        let preservedExpandedCardId = expandedCardId
        let wasBannerVisible = justMeModeBannerVisible // NEW: Preserve banner state
        
        // Clear loading guards before starting fresh refresh
        loadingLock.lock()
        currentlyLoadingLeagues.removeAll()
        loadingLock.unlock()
        
        // BACKGROUND REFRESH: Update data without showing loading screen
        await refreshMatchupsInBackground()
        
        // 🔥 RESTORE Just Me Mode state after refresh
        await MainActor.run {
            microModeEnabled = wasMicroModeEnabled
            expandedCardId = preservedExpandedCardId
            justMeModeBannerVisible = wasBannerVisible // NEW: Restore banner state
        }
        
        // 🔥 NEW: Clear updating flag when complete
        isUpdating = false
    }
    
    /// Background refresh that doesn't disrupt the UI
    /// 🔥 FIXED: Preserves UI state during refresh
    private func refreshMatchupsInBackground() async {
        // 🔥 TODO: We'll need to inject WeekSelectionManager too
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        // 🔥 PRESERVE UI state before refresh
        let preservedMicroMode = microModeEnabled
        let preservedExpandedCard = expandedCardId
        let preservedBannerVisible = justMeModeBannerVisible // NEW: Preserve banner
        
        // 🔥 CRITICAL FIX: Clear cached providers to force fresh score data
        let count = cachedProviders.count
        cachedProviders.removeAll()
        DebugPrint(mode: .globalRefresh, "Cleared \(count) cached providers for fresh scores")
        
        await MainActor.run {
            // Only update timestamp, don't change isLoading or show loading screen
            lastUpdateTime = Date()
        }
        
        do {
            // Step 0: Refresh NFL game data for the selected week (not just current)
            let currentYear = Calendar.current.component(.year, from: Date())
            
            DebugPrint(mode: .weekCheck, "📅 MatchupsHub.refreshInBackground: Using user-selected week \(selectedWeek)")
            
            NFLGameDataService.shared.fetchGameData(forWeek: selectedWeek, year: currentYear, forceRefresh: true)
            
            // Step 1: Refresh available leagues quietly
            // 🔥 PHASE 2: Use injected credentials instead of .shared
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            guard !availableLeagues.isEmpty else { return }
            
            // Step 2: Refresh all league data for selected week
            await loadMatchupsFromAllLeaguesBackground(availableLeagues, forWeek: selectedWeek)
            
        } catch {
            // x Print("⚠️ BACKGROUND REFRESH: Failed to refresh leagues: \(error)")
        }
        
        // 🔥 RESTORE UI state after refresh
        await MainActor.run {
            microModeEnabled = preservedMicroMode
            expandedCardId = preservedExpandedCard
            justMeModeBannerVisible = preservedBannerVisible // NEW: Restore banner
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
        
        // 💊 RX: Refresh optimization status after background refresh
        await refreshAllOptimizationStatuses()
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
                    myIdentifiedTeamID: myTeamID,
                    authenticatedUsername: sleeperCredentials.currentUsername
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
                myIdentifiedTeamID: myTeamID,
                authenticatedUsername: sleeperCredentials.currentUsername
            )
            
            return unifiedMatchup
        } else {
            return nil
        }
    }
}