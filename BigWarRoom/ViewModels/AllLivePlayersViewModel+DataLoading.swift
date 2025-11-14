//
//  AllLivePlayersViewModel+DataLoading.swift
//  BigWarRoom
//
//  🔥 FOCUSED: Data loading, API calls, and stats management
//

import Foundation
import Combine

extension AllLivePlayersViewModel {
    // MARK: - Data Freshness Constants
    // 🔥 REMOVED CACHING: Always fetch fresh data, no threshold checks
    private var lastLoadTime: Date? {
        get { UserDefaults.standard.object(forKey: "AllLivePlayers_LastLoadTime") as? Date }
        set { 
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: "AllLivePlayers_LastLoadTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "AllLivePlayers_LastLoadTime")
            }
            // 🔥 CRITICAL FIX: Never store massive playerStats in UserDefaults
            // UserDefaults should only contain simple values, not 4MB+ dictionaries
        }
    }
    
    // MARK: - Main Data Loading
    // 🔥 NO CACHE: Always fetch fresh data from APIs
    internal func performDataLoad() async {
        await fetchFreshData()
    }
    
    // MARK: - Fresh Data Fetching (Shows Loading)
    private func fetchFreshData() async {
        dataState = .loading
        isLoading = true
        errorMessage = nil

        do {
            // 🔥 ALWAYS load fresh stats from API
            await loadPlayerStats()
            
            // Load matchups
            await matchupsHubViewModel.loadAllMatchups()
            
            // Extract and process players
            let playerEntries = extractAllPlayers()
            await buildPlayerData(from: playerEntries)
            
            // 🔥 PHASE 3 DI: Update PlayerWatchService with initial data (service passed to extension methods)
            await notifyPlayerWatchService(with: playerEntries)
            
            // Update state
            lastLoadTime = Date()
            dataState = allPlayers.isEmpty ? .empty : .loaded
            isLoading = false
            
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
            dataState = .error(error.localizedDescription)
            isLoading = false
        }
    }
    
    // MARK: - Process Existing Data (No Loading State)
    // 🔥 REMOVED: No longer using cached data - always fetch fresh
    
    // MARK: - Player Stats Loading
    internal func loadPlayerStats() async {
        guard !Task.isCancelled else { return }

        // 🔥 ALWAYS reload stats - reset flag to force fresh fetch
        await MainActor.run {
            self.statsLoaded = false
        }

        let currentYear = AppConstants.currentSeasonYear
        let selectedWeek = weekSelectionManager.selectedWeek
        
        if AppConstants.debug {
            print("🔄 STATS DEBUG: Loading player stats for week \(selectedWeek), year \(currentYear)")
        }

        do {
            // 🔥 PHASE 3 DI: Use injected sharedStatsService
            let freshStats = try await sharedStatsService.loadWeekStats(
                week: selectedWeek, 
                year: currentYear, 
                forceRefresh: true  // 🔥 CRITICAL: Always force fresh data for live updates
            )
            
            if AppConstants.debug {
                print("🔄 STATS DEBUG: Successfully loaded FRESH stats from SharedStatsService for \(freshStats.keys.count) players")
            }
            
            // Log a few sample player scores for debugging
            if AppConstants.debug {
                let sampleStats = Array(freshStats.prefix(3))
                for (playerId, stats) in sampleStats {
                    let fantasyPoints = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                    print("🔄 STATS DEBUG: Sample - Player \(playerId): \(fantasyPoints) pts")
                }
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = freshStats
                self.statsLoaded = true
                if AppConstants.debug {
                    print("🔄 STATS DEBUG: Updated playerStats on main thread with FRESH data from SharedStatsService")
                }
            }
            
        } catch {
            if AppConstants.debug {
                print("🔄 STATS DEBUG: Failed to load stats from SharedStatsService: \(error)")
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.statsLoaded = true
            }
        }
    }
    
    // MARK: - Manual Refresh
    internal func performManualRefresh() async {
        lastLoadTime = nil // Force fresh fetch
        await performDataLoad()
    }
    
    // MARK: - Background Updates (Silent)
    func performLiveUpdate() async {
        // 🔥 WOODY'S FIX: Always fetch fresh data - no guards against redundant calls
        
        // 🔥 NEW: Set updating flag for animation
        isUpdating = true
        
        DebugPrint(mode: .liveUpdates, "🔥 LIVE UPDATE START: Beginning live update process...")
        DebugPrint(mode: .liveUpdates, "Selected week = \(WeekSelectionManager.shared.selectedWeek)")
        let startTime = Date()
        
        // 🔥 WOODY'S FIX: Force refresh stats to bypass cache
        DebugPrint(mode: .liveUpdates, "🔥 Forcing fresh stats reload to bypass cache")
        await loadPlayerStats()  // This now uses forceRefresh: true
        
        // 🔥 CRITICAL FIX: Actually refresh MatchupsHub data from APIs!
        DebugPrint(mode: .liveUpdates, "🌐 Calling MatchupsHub to fetch fresh scores from APIs...")
        await matchupsHubViewModel.refreshMatchups()
        DebugPrint(mode: .liveUpdates, "✅ API refresh complete - extracting updated player data")
        
        // Debug: Show week info from first matchup
        if AppConstants.debug {
            if let firstMatchup = matchupsHubViewModel.myMatchups.first {
                if let fantasyMatchup = firstMatchup.fantasyMatchup {
                    DebugPrint(mode: .liveUpdates, "First matchup - Week: \(fantasyMatchup.week), Status: \(fantasyMatchup.status)")
                }
            }
        }
        
        // Extract from freshly-refreshed matchup data with new API scores
        let freshPlayerEntries = extractAllPlayers()
        guard !freshPlayerEntries.isEmpty else {
            DebugPrint(mode: .liveUpdates, "❌ LIVE UPDATE ERROR: No fresh player entries found after extraction")
            DebugPrint(mode: .liveUpdates, "matchupsHubViewModel.myMatchups.count = \(matchupsHubViewModel.myMatchups.count)")
            isUpdating = false // 🔥 Clear updating flag on error
            return
        }
        
        DebugPrint(mode: .liveUpdates, "Extracted \(freshPlayerEntries.count) players")
        
        // Debug: Show sample scores before update
        if AppConstants.debug {
            let sampleBefore = Array(allPlayers.prefix(3))
            for player in sampleBefore {
                DebugPrint(mode: .liveUpdates, limit: 3, "BEFORE UPDATE: \(player.playerName) = \(player.currentScore) pts")
            }
        }
        
        // Update player data with fresh scores from matchups
        await updatePlayerDataSilently(from: freshPlayerEntries)
        
        // Debug: Show sample scores after update
        if AppConstants.debug {
            let sampleAfter = Array(allPlayers.prefix(3))
            for player in sampleAfter {
                DebugPrint(mode: .liveUpdates, limit: 3, "AFTER UPDATE: \(player.playerName) = \(player.currentScore) pts")
            }
            
            // Debug: Show filtered players
            let filteredSample = Array(filteredPlayers.prefix(3))
            for player in filteredSample {
                DebugPrint(mode: .liveUpdates, limit: 3, "FILTERED RESULT: \(player.playerName) = \(player.currentScore) pts")
            }
        }
        
        // 🔥 NEW: Update PlayerWatchService with fresh data
        await notifyPlayerWatchService(with: freshPlayerEntries)
        
        // 🔥 CRITICAL: Update timestamp to trigger view updates
        let oldTime = lastUpdateTime
        lastUpdateTime = Date()
        
        DebugPrint(mode: .liveUpdates, "✅ LIVE UPDATE COMPLETE: Updated lastUpdateTime from \(oldTime) to \(lastUpdateTime)")
        DebugPrint(mode: .liveUpdates, "LIVE UPDATE STATS: allPlayers.count = \(allPlayers.count), filteredPlayers.count = \(filteredPlayers.count)")
        
        let elapsed = Date().timeIntervalSince(startTime)
        DebugPrint(mode: .liveUpdates, "Completed in \(String(format: "%.2f", elapsed))s")
        
        // 🔥 NEW: Clear updating flag when complete
        isUpdating = false
        
        DebugPrint(mode: .liveUpdates, limit: 1, "@Observable: Property changes will automatically trigger UI updates")
    }

    // MARK: - Snapshot Processing (no API calls)
    /// Process the current snapshot from MatchupsHub without triggering any API refreshes.
    /// Use this when another subsystem (MatchupsHub auto-refresh) is already refreshing scores.
    internal func processCurrentSnapshot() async {
        guard isDataLoaded else { return }
        isUpdating = true

        // Extract players from the existing, most recent MatchupsHub data
        let entries = extractAllPlayers()
        await updatePlayerDataSilently(from: entries)
        await notifyPlayerWatchService(with: entries)

        await MainActor.run {
            lastUpdateTime = Date()
            isUpdating = false
        }
    }
    
    // MARK: - Week Changes Subscription
    internal func subscribeToWeekChanges() {
        // 🔥 PHASE 2.5: @Observable doesn't have Combine publishers
        // We'll use NotificationCenter instead for now
        NotificationCenter.default.addObserver(
            forName: .weekSelectionChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // 🔥 PHASE 3 DI: Use injected weekSelectionManager
            guard let self = self else { return }
            let newWeek = self.weekSelectionManager.selectedWeek

            self.debounceTask?.cancel()
            self.debounceTask = Task { @MainActor in
                // PRESERVE SEARCH STATE: Don't clear search data during week changes
                let wasSearching = self.isSearching
                let searchText = self.searchText
                let showRosteredOnly = self.showRosteredOnly
                let preservedNFLPlayers = self.allNFLPlayers
                
                // Reset stats for new week
                self.statsLoaded = false
                self.playerStats = [:]
                
                // Reload stats for new week if we have players
                if !(self.allPlayers.isEmpty) {
                    await self.loadPlayerStats()
                }
                
                // RESTORE SEARCH STATE: Put search state back after week change
                if wasSearching {
                    self.isSearching = wasSearching
                    self.searchText = searchText
                    self.showRosteredOnly = showRosteredOnly
                    self.allNFLPlayers = preservedNFLPlayers
                    
                    // Reapply search filters for new week
                    self.applyPositionFilter()
                }
            }
        }
    }

    // MARK: - Force Methods (For Compatibility)
    func forceLoadAllPlayers() async {
        lastLoadTime = nil
        await performDataLoad()
    }

    func forceLoadStats() async {
        statsLoaded = false
        await loadPlayerStats()
    }

    func loadStatsIfNeeded() {
        guard !statsLoaded else { return }
        Task { await loadPlayerStats() }
    }
    
    // MARK: - PlayerWatchService Integration
    
    /// Notify PlayerWatchService of updated player data
    /// 🔥 PHASE 3 TODO: This should be injected as a dependency instead of using .shared
    /// For now, we'll skip this update since PlayerWatchService should be updated from views
    private func notifyPlayerWatchService(with playerEntries: [LivePlayerEntry]) async {
        // 🔥 PHASE 3 DI: PlayerWatchService updates are now handled by the view layer
        // that owns the service instance. This prevents coupling between ViewModels.
        // Views that use AllLivePlayersViewModel should also inject PlayerWatchService
        // and call updateWatchedPlayerScores() when needed.
    }
    
    /// Convert performance tier to player threat level
    private func convertThreatLevel(_ tier: PerformanceTier) -> PlayerThreatLevel {
        switch tier {
        case .elite:
            return .explosive
        case .good:
            return .dangerous
        case .average:
            return .moderate
        case .struggling:
            return .minimal
        }
    }
}