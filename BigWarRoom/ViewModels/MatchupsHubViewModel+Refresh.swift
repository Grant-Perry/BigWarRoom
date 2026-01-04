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
        
        guard autoRefreshEnabled else {
            DebugPrint(mode: .globalRefresh, "⏸️ AUTO REFRESH: Disabled by user setting")
            return
        }
        
        // 🔥 SMART REFRESH: Calculate optimal interval based on game status
        SmartRefreshManager.shared.calculateOptimalRefresh()
        let interval = SmartRefreshManager.shared.currentRefreshInterval
        
        DebugPrint(mode: .globalRefresh, "⏱️ AUTO REFRESH: Setting up timer with \(Int(interval))s interval, hasLiveGames=\(SmartRefreshManager.shared.hasLiveGames)")
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let isActive = await AppLifecycleManager.shared.isActive
                DebugPrint(mode: .globalRefresh, "⏰ TIMER FIRED: isLoading=\(self.isLoading), isActive=\(isActive)")
                
                if isActive && !self.isLoading {
                    SmartRefreshManager.shared.calculateOptimalRefresh()
                    DebugPrint(mode: .globalRefresh, "🚀 CALLING refreshMatchups()")
                    await self.refreshMatchups()
                    
                    let newInterval = SmartRefreshManager.shared.currentRefreshInterval
                    if abs(newInterval - interval) > 1.0 {
                        DebugPrint(mode: .globalRefresh, "🔄 RESCHEDULING: Interval changed from \(Int(interval))s to \(Int(newInterval))s")
                        self.setupAutoRefresh()
                    }
                } else {
                    DebugPrint(mode: .globalRefresh, "⏭️ TIMER SKIPPED: App inactive or already loading")
                }
            }
        }
        
        DebugPrint(mode: .globalRefresh, "✅ AUTO REFRESH: Timer scheduled successfully")
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
            DebugPrint(mode: .globalRefresh, "🔄 REFRESH: No matchups loaded, performing full load")
            await performLoadAllMatchups()
            return
        }
        
        DebugPrint(mode: .globalRefresh, "🔄 REFRESH MATCHUPS: Starting refresh for \(myMatchups.count) matchups")
        
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
        
        DebugPrint(mode: .globalRefresh, "🔄 REFRESH: Re-hydrating \(myMatchups.count) matchups from store")
        
        for matchup in myMatchups {
            let leagueID = matchup.league.id
            let currentWeek = getCurrentWeek()
            let snapshotID = MatchupSnapshot.ID(
                leagueID: leagueID,
                matchupID: "\(leagueID)_\(currentWeek)",
                platform: matchup.league.source,
                week: currentWeek
            )
            
            DebugPrint(mode: .globalRefresh, "   🔄 Refreshing \(matchup.league.league.name)...")
            
            do {
                let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
                let refreshed = convertSnapshotToUnifiedMatchup(snapshot, league: matchup.league)
                refreshedMatchups.append(refreshed)
                
                DebugPrint(mode: .globalRefresh, "   ✅ Refreshed \(matchup.league.league.name) - new score: \(snapshot.myTeam.score.actual)")
            } catch {
                DebugPrint(mode: .globalRefresh, "   ⚠️ Failed to refresh \(matchup.league.league.name): \(error)")
                // Keep old matchup if refresh fails
                refreshedMatchups.append(matchup)
            }
        }
        
        DebugPrint(mode: .globalRefresh, "🔄 REFRESH: Updating UI with \(refreshedMatchups.count) refreshed matchups")
        
        // Step 3: Update UI with refreshed data
        await MainActor.run {
            self.myMatchups = refreshedMatchups.sorted { $0.priority > $1.priority }
            self.lastUpdateTime = Date()
            self.isUpdating = false
            
            DebugPrint(mode: .globalRefresh, "✅ REFRESH: UI updated, myMatchups now has \(self.myMatchups.count) matchups")
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
        
        // 🚀 NEW: Clear matchup cache to force fresh fetch
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentYear()
        MatchupCacheManager.shared.clearCache(week: currentWeek, year: currentYear)
        
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