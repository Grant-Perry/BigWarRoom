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
        
        // 🔥 SMART REFRESH: Calculate optimal interval based on game status
        SmartRefreshManager.shared.calculateOptimalRefresh()
        let interval = SmartRefreshManager.shared.currentRefreshInterval
        
        DebugPrint(mode: .globalRefresh, "⏱️ AUTO REFRESH: Setting up with \(Int(interval))s interval")
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // 🔋 BATTERY FIX: Only refresh if app is active
                if await AppLifecycleManager.shared.isActive && !self.isLoading {
                    // Recalculate optimal interval each refresh cycle
                    SmartRefreshManager.shared.calculateOptimalRefresh()
                    await self.refreshMatchups()
                    
                    // Reschedule with new interval if it changed
                    let newInterval = SmartRefreshManager.shared.currentRefreshInterval
                    if abs(newInterval - interval) > 1.0 {
                        self.setupAutoRefresh() // Reschedule with new interval
                    }
                }
            }
        }
    }
    
    /// Refresh existing matchups without full reload
    /// 🔥 REFACTORED: Now uses MatchupDataStore for efficient refresh
    internal func refreshMatchups() async {
        // 🔋 BATTERY FIX: Skip refresh if app is not active
        guard AppLifecycleManager.shared.isActive || myMatchups.isEmpty else {
            DebugPrint(mode: .globalRefresh, "REFRESH SKIPPED: App is not active (backgrounded)")
            return
        }
        
        guard !myMatchups.isEmpty && !isLoading else {
            // If no matchups loaded yet, do a full load
            await performLoadAllMatchups()
            return
        }
        
        // 🔥 NEW: Set updating flag for Siri animation  
        isUpdating = true
        
        // 🔥 LIGHT THROTTLING: Prevent rapid duplicate calls (3 seconds minimum)
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        guard timeSinceLastUpdate >= 3.0 else {
            DebugPrint(mode: .globalRefresh, "REFRESH THROTTLED: Only \(String(format: "%.1f", timeSinceLastUpdate))s since last update (min: 3s)")
            isUpdating = false
            return
        }
        
        DebugPrint(mode: .globalRefresh, "🔄 REFRESH: Using MatchupDataStore with force refresh")
        
        // Step 1: Force refresh via store (invalidates cache)
        await matchupDataStore.refresh(league: nil, force: true)
        
        // Step 2: Re-hydrate all current matchups from refreshed store cache
        var refreshedMatchups: [UnifiedMatchup] = []
        
        for matchup in myMatchups {
            let snapshotID = MatchupSnapshot.ID(
                leagueID: matchup.league.league.leagueID,
                matchupID: matchup.id,
                platform: matchup.league.source,
                week: getCurrentWeek()
            )
            
            do {
                let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
                let refreshed = convertSnapshotToUnifiedMatchup(snapshot, league: matchup.league)
                refreshedMatchups.append(refreshed)
            } catch {
                DebugPrint(mode: .globalRefresh, "⚠️ Failed to refresh \(matchup.league.league.name): \(error)")
                // Keep old matchup if refresh fails
                refreshedMatchups.append(matchup)
            }
        }
        
        // Step 3: Update UI with refreshed data
        await MainActor.run {
            self.myMatchups = refreshedMatchups.sorted { $0.priority > $1.priority }
            self.lastUpdateTime = Date()
            self.isUpdating = false
        }
        
        DebugPrint(mode: .globalRefresh, "✅ REFRESH: Complete via store")
    }
    
    /// Manual refresh trigger (PTR) - Does FULL refresh like app startup
    /// 🔥 REFACTORED: Now uses MatchupDataStore
    internal func performManualRefresh() async {
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
            isUpdating = false
            return
        }
        
        DebugPrint(mode: .globalRefresh, "🔄 MANUAL REFRESH (PTR): Starting FULL refresh via store")
        
        // 🔥 PRESERVE Just Me Mode state during refresh
        let wasMicroModeEnabled = microModeEnabled
        let preservedExpandedCardId = expandedCardId
        let wasBannerVisible = justMeModeBannerVisible
        
        // 🔥 FULL REFRESH: Force refresh all leagues via store, then reload
        await matchupDataStore.refresh(league: nil, force: true)
        await performLoadAllMatchups()
        
        // 🔥 RESTORE Just Me Mode state after refresh
        await MainActor.run {
            microModeEnabled = wasMicroModeEnabled
            expandedCardId = preservedExpandedCardId
            justMeModeBannerVisible = wasBannerVisible
        }
        
        // 🔥 SMART REFRESH: Recalculate optimal interval after manual refresh
        SmartRefreshManager.shared.scheduleNextRefresh()
        setupAutoRefresh()
        
        // 🔥 Clear updating flag when complete
        isUpdating = false
        
        DebugPrint(mode: .globalRefresh, "✅ MANUAL REFRESH (PTR): Complete")
    }
}

// MARK: - DEPRECATED: All old refresh methods replaced by MatchupDataStore
/*
    private func refreshSingleMatchup(_ matchup: UnifiedMatchup, forWeek week: Int) async {}
    private func refreshChoppedMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider, week: Int) async {}
    private func refreshRegularMatchup(_ matchup: UnifiedMatchup, myTeamID: String, provider: LeagueMatchupProvider, week: Int) async {}
    private func refreshMatchupsInBackground() async {}
    private func loadMatchupsFromAllLeaguesBackground(_ leagues: [UnifiedLeagueManager.LeagueWrapper], forWeek week: Int) async {}
    private func loadSingleLeagueMatchupBackground(_ league: UnifiedLeagueManager.LeagueWrapper, forWeek week: Int) async -> UnifiedMatchup? {}
    private func handleChoppedLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> UnifiedMatchup? {}
    private func handleRegularLeagueBackground(league: UnifiedLeagueManager.LeagueWrapper, matchups: [FantasyMatchup], myTeamID: String, provider: LeagueMatchupProvider, week: Int) async -> UnifiedMatchup? {}
    private func createSleeperChoppedSummary(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> ChoppedWeekSummary? {}
    private func findMyTeamInChoppedLeaderboard(_ summary: ChoppedWeekSummary, leagueID: String) async -> FantasyTeamRanking? {}
*/