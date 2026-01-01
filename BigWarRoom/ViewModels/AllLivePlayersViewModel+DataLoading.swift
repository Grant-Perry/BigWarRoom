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
    private var lastLoadTime: Date? {
        get { UserDefaults.standard.object(forKey: "AllLivePlayers_LastLoadTime") as? Date }
        set { 
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: "AllLivePlayers_LastLoadTime")
            } else {
                UserDefaults.standard.removeObject(forKey: "AllLivePlayers_LastLoadTime")
            }
        }
    }
    
    // MARK: - Main Data Loading
    internal func performDataLoad() async {
        await fetchFreshData()
    }
    
    // MARK: - Fresh Data Fetching (Shows Loading)
    private func fetchFreshData() async {
        dataState = .loading
        isLoading = true
        errorMessage = nil

        async let statsTask: Void = loadPlayerStats(forceRefresh: false)
        async let matchupsTask: Void = matchupsHubViewModel.refreshMatchups()
        
        _ = await matchupsTask
        
        let playerEntries = extractAllPlayers()
        await buildPlayerData(from: playerEntries)
        
        await notifyPlayerWatchService(with: playerEntries)

        _ = await statsTask
        
        lastLoadTime = Date()
        dataState = allPlayers.isEmpty ? .empty : .loaded
        isLoading = false
        
        if !hasAppliedInitialActiveOnlyDefault {
            hasAppliedInitialActiveOnlyDefault = true
            if !hasAnyLiveGames {
                DebugPrint(mode: .liveUpdates, "📅 SMART DEFAULT: No live games detected - setting Active Only to NO")
                showActiveOnly = false
                applyPositionFilter()
            } else {
                DebugPrint(mode: .liveUpdates, "🏈 SMART DEFAULT: Live games detected - keeping Active Only YES")
            }
        }
    }
    
    // MARK: - Player Stats Loading
    internal func loadPlayerStats(forceRefresh: Bool = false) async {
        guard !Task.isCancelled else { return }

        await MainActor.run {
            self.statsLoaded = false
        }

        let currentYear = AppConstants.currentSeasonYear
        let selectedWeek = weekSelectionManager.selectedWeek
        
        if AppConstants.debug {
        }

        do {
            let freshStats = try await sharedStatsService.loadWeekStats(
                week: selectedWeek, 
                year: currentYear, 
                forceRefresh: forceRefresh
            )
            
            if AppConstants.debug {
            }
            
            if AppConstants.debug {
                let sampleStats = Array(freshStats.prefix(3))
                for (playerId, stats) in sampleStats {
                    let fantasyPoints = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                }
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = freshStats
                self.statsLoaded = true
                if AppConstants.debug {
                }
            }
            
        } catch {
            if AppConstants.debug {
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.statsLoaded = true
            }
        }
    }
    
    // MARK: - Manual Refresh
    internal func performManualRefresh() async {
        lastLoadTime = nil
        await performDataLoad()
    }
    
    // MARK: - Background Updates (Silent)
    func performLiveUpdate() async {
        isUpdating = true
        
        DebugPrint(mode: .liveUpdates, "🔥 LIVE UPDATE START: Beginning live update process...")
        DebugPrint(mode: .liveUpdates, "Selected week = \(WeekSelectionManager.shared.selectedWeek)")
        let startTime = Date()
        
        DebugPrint(mode: .liveUpdates, "🔥 Forcing fresh stats reload to bypass cache")
        await loadPlayerStats(forceRefresh: true)
        
        DebugPrint(mode: .liveUpdates, "🌐 Calling MatchupsHub to fetch fresh scores from APIs...")
        await matchupsHubViewModel.refreshMatchups()
        DebugPrint(mode: .liveUpdates, "✅ API refresh complete - extracting updated player data")
        
        if AppConstants.debug {
            if let firstMatchup = matchupsHubViewModel.myMatchups.first {
                if let fantasyMatchup = firstMatchup.fantasyMatchup {
                    DebugPrint(mode: .liveUpdates, "First matchup - Week: \(fantasyMatchup.week), Status: \(fantasyMatchup.status)")
                }
            }
        }
        
        let freshPlayerEntries = extractAllPlayers()
        guard !freshPlayerEntries.isEmpty else {
            DebugPrint(mode: .liveUpdates, "❌ LIVE UPDATE ERROR: No fresh player entries found after extraction")
            DebugPrint(mode: .liveUpdates, "matchupsHubViewModel.myMatchups.count = \(matchupsHubViewModel.myMatchups.count)")
            isUpdating = false
            return
        }
        
        DebugPrint(mode: .liveUpdates, "Extracted \(freshPlayerEntries.count) players")
        
        if AppConstants.debug {
            let sampleBefore = Array(allPlayers.prefix(3))
            for player in sampleBefore {
                DebugPrint(mode: .liveUpdates, limit: 3, "BEFORE UPDATE: \(player.playerName) = \(player.currentScore) pts")
            }
        }
        
        await updatePlayerDataSilently(from: freshPlayerEntries)
        
        if AppConstants.debug {
            let sampleAfter = Array(allPlayers.prefix(3))
            for player in sampleAfter {
                DebugPrint(mode: .liveUpdates, limit: 3, "AFTER UPDATE: \(player.playerName) = \(player.currentScore) pts")
            }
            
            let filteredSample = Array(filteredPlayers.prefix(3))
            for player in filteredSample {
                DebugPrint(mode: .liveUpdates, limit: 3, "FILTERED RESULT: \(player.playerName) = \(player.currentScore) pts")
            }
        }
        
        await notifyPlayerWatchService(with: freshPlayerEntries)
        
        let oldTime = lastUpdateTime
        lastUpdateTime = Date()
        
        DebugPrint(mode: .liveUpdates, "✅ LIVE UPDATE COMPLETE: Updated lastUpdateTime from \(oldTime) to \(lastUpdateTime)")
        DebugPrint(mode: .liveUpdates, "LIVE UPDATE STATS: allPlayers.count = \(allPlayers.count), filteredPlayers.count = \(filteredPlayers.count)")
        
        let elapsed = Date().timeIntervalSince(startTime)
        DebugPrint(mode: .liveUpdates, "Completed in \(String(format: "%.2f", elapsed))s")
        
        isUpdating = false
        
        DebugPrint(mode: .liveUpdates, limit: 1, "@Observable: Property changes will automatically trigger UI updates")
    }

    // MARK: - Snapshot Processing (no API calls)
    internal func processCurrentSnapshot() async {
        guard isDataLoaded else { return }
        isUpdating = true

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
        NotificationCenter.default.addObserver(
            forName: .weekSelectionChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let newWeek = self.weekSelectionManager.selectedWeek

            self.debounceTask?.cancel()
            self.debounceTask = Task { @MainActor in
                let wasSearching = self.isSearching
                let searchText = self.searchText
                let showRosteredOnly = self.showRosteredOnly
                let preservedNFLPlayers = self.allNFLPlayers
                
                self.statsLoaded = false
                self.playerStats = [:]
                
                if !(self.allPlayers.isEmpty) {
                    await self.loadPlayerStats(forceRefresh: true)
                }
                
                if wasSearching {
                    self.isSearching = wasSearching
                    self.searchText = searchText
                    self.showRosteredOnly = showRosteredOnly
                    self.allNFLPlayers = preservedNFLPlayers
                    
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
        await loadPlayerStats(forceRefresh: true)
    }

    func loadStatsIfNeeded() {
        guard !statsLoaded else { return }
        Task { await loadPlayerStats(forceRefresh: false) }
    }
    
    // MARK: - PlayerWatchService Integration
    
    private func notifyPlayerWatchService(with playerEntries: [LivePlayerEntry]) async {
        // Views that use AllLivePlayersViewModel should also inject PlayerWatchService
        // and call updateWatchedPlayerScores() when needed.
    }
    
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