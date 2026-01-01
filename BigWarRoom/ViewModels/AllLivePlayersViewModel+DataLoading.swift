//
//  AllLivePlayersViewModel+DataLoading.swift
//  BigWarRoom
//
//  🔥 DRY REFACTOR: Now uses AsyncTaskService for consistent async patterns
//  🔥 FOCUSED: Data loading, API calls, and stats management
//

import Foundation
import Combine

extension AllLivePlayersViewModel {
    // 🔥 DRY: Access AsyncTaskService for task management
    private var asyncTaskService: AsyncTaskService {
        AsyncTaskService.shared
    }
    
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

        // 🔥 DRY: Use AsyncTaskService for parallel execution
        await asyncTaskService.runParallel([
            { await self.loadPlayerStats(forceRefresh: false) },
            { await self.matchupsHubViewModel.refreshMatchups() }
        ])
        
        // Extract and process players
        let playerEntries = extractAllPlayers()
        await buildPlayerData(from: playerEntries)
        
        // 🔥 PHASE 3 DI: Update PlayerWatchService with initial data
        await notifyPlayerWatchService(with: playerEntries)
        
        // Update state
        lastLoadTime = Date()
        dataState = allPlayers.isEmpty ? .empty : .loaded
        isLoading = false
        
        // 🔥 SMART DEFAULT: On initial load, check if there are live games
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

        // 🔥 ALWAYS reload stats - reset flag to force fresh fetch
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
                let sampleStats = Array(freshStats.prefix(3))
                for (playerId, stats) in sampleStats {
                    let fantasyPoints = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                }
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = freshStats
                self.statsLoaded = true
            }
            
        } catch {
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
        let startTime = Date()
        
        // 🔥 DRY: Use AsyncTaskService for parallel updates
        await asyncTaskService.runParallel([
            { await self.loadPlayerStats(forceRefresh: true) },
            { await self.matchupsHubViewModel.refreshMatchups() }
        ])
        
        // Extract from freshly-refreshed matchup data
        let freshPlayerEntries = extractAllPlayers()
        guard !freshPlayerEntries.isEmpty else {
            DebugPrint(mode: .liveUpdates, "❌ LIVE UPDATE ERROR: No fresh player entries found")
            isUpdating = false
            return
        }
        
        // Update player data with fresh scores
        await updatePlayerDataSilently(from: freshPlayerEntries)
        
        // Update PlayerWatchService
        await notifyPlayerWatchService(with: freshPlayerEntries)
        
        // Update timestamp
        lastUpdateTime = Date()
        isUpdating = false
        
        let elapsed = Date().timeIntervalSince(startTime)
        DebugPrint(mode: .liveUpdates, "✅ Completed in \(String(format: "%.2f", elapsed))s")
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

            // 🔥 DRY: Use AsyncTaskService for debounced execution
            asyncTaskService.debounce(id: "week_change", delay: 0.35) { @MainActor [weak self] in
                guard let self = self else { return }
                
                // PRESERVE SEARCH STATE
                let wasSearching = self.isSearching
                let searchText = self.searchText
                let showRosteredOnly = self.showRosteredOnly
                let preservedNFLPlayers = self.allNFLPlayers
                
                // Reset stats for new week
                self.statsLoaded = false
                self.playerStats = [:]
                
                // Reload stats if we have players
                if !(self.allPlayers.isEmpty) {
                    await self.loadPlayerStats(forceRefresh: true)
                }
                
                // RESTORE SEARCH STATE
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
        // 🔥 DRY: Use AsyncTaskService for simple task
        asyncTaskService.run {
            await self.loadPlayerStats(forceRefresh: false)
        }
    }
    
    // MARK: - PlayerWatchService Integration
    
    private func notifyPlayerWatchService(with playerEntries: [LivePlayerEntry]) async {
        // 🔥 PHASE 3 DI: PlayerWatchService updates handled by view layer
    }
    
    private func convertThreatLevel(_ tier: PerformanceTier) -> PlayerThreatLevel {
        switch tier {
        case .elite: return .explosive
        case .good: return .dangerous
        case .average: return .moderate
        case .struggling: return .minimal
        }
    }
}