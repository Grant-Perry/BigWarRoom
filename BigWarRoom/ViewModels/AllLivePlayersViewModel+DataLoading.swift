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
    private var dataFreshnessThreshold: TimeInterval { 15.0 } // 15 seconds for live sports
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
    internal func performDataLoad() async {
        let needsDataFetch = allPlayers.isEmpty || 
                           (lastLoadTime == nil) ||
                           (Date().timeIntervalSince(lastLoadTime!) > dataFreshnessThreshold)
        
        if needsDataFetch {
            await fetchFreshData()
        } else {
            await processExistingData()
        }
    }
    
    // MARK: - Fresh Data Fetching (Shows Loading)
    private func fetchFreshData() async {
        dataState = .loading
        isLoading = true
        errorMessage = nil

        do {
            // Load stats if needed
            if !statsLoaded {
                await loadPlayerStats()
            }
            
            // Load matchups
            await matchupsHubViewModel.loadAllMatchups()
            
            // Extract and process players
            let playerEntries = extractAllPlayers()
            await buildPlayerData(from: playerEntries)
            
            // 🔥 NEW: Update PlayerWatchService with initial data
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
    private func processExistingData() async {
        applyPositionFilter() // Instant
        dataState = allPlayers.isEmpty ? .empty : .loaded
        isLoading = false
    }
    
    // MARK: - Player Stats Loading
    internal func loadPlayerStats() async {
        guard !Task.isCancelled else { return }

        let currentYear = AppConstants.currentSeasonYear
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        print("🔄 STATS DEBUG: Loading player stats for week \(selectedWeek), year \(currentYear)")

        do {
            // 🔥 CRITICAL FIX: Use SharedStatsService instead of making redundant API calls
            let freshStats = try await SharedStatsService.shared.loadWeekStats(week: selectedWeek, year: currentYear)
            
            print("🔄 STATS DEBUG: Successfully loaded stats from SharedStatsService for \(freshStats.keys.count) players")
            
            // Log a few sample player scores for debugging
            let sampleStats = Array(freshStats.prefix(3))
            for (playerId, stats) in sampleStats {
                let fantasyPoints = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                print("🔄 STATS DEBUG: Sample - Player \(playerId): \(fantasyPoints) pts")
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = freshStats
                self.statsLoaded = true
                print("🔄 STATS DEBUG: Updated playerStats on main thread with fresh data from SharedStatsService")
            }
            
        } catch {
            print("🔄 STATS DEBUG: Failed to load stats from SharedStatsService: \(error)")
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
        guard isDataLoaded else { 
            print("🔥 LIVE UPDATE BLOCKED: Data not loaded yet")
            return 
        }
        
        // 🔥 NEW: Set updating flag for animation
        isUpdating = true
        
        print("🔥 LIVE UPDATE START: Beginning live update process...")
        print("🔥 LIVE UPDATE: Selected week = \(WeekSelectionManager.shared.selectedWeek)")
        let startTime = Date()
        
        // 🔥 CRITICAL: Clear player stats cache to force fresh fetch
        print("🔥 LIVE UPDATE: Clearing player stats cache for fresh data")
        await PlayerStatsCache.shared.clearCache()
        
        // 🔥 NOTE: DO NOT call performManualRefresh() here!
        // This method is called BY the observation system AFTER MatchupsHub has already refreshed
        // Calling refresh here would create a race condition
        print("🔥 LIVE UPDATE: Extracting players from already-refreshed MatchupsHub data")
        
        // Debug: Show week info from first matchup
        if let firstMatchup = matchupsHubViewModel.myMatchups.first {
            if let fantasyMatchup = firstMatchup.fantasyMatchup {
                print(
                   "🔥 LIVE UPDATE: First matchup - Week: \(fantasyMatchup.week), Status: \(fantasyMatchup.status)"
                )
            }
        }
        
        // 🔥 FIXED: Extract from already-refreshed matchup data 
        let freshPlayerEntries = extractAllPlayers()
        guard !freshPlayerEntries.isEmpty else {
            print("🔥 LIVE UPDATE ERROR: No fresh player entries found after extraction")
            print("🔥 LIVE UPDATE: matchupsHubViewModel.myMatchups.count = \(matchupsHubViewModel.myMatchups.count)")
            isUpdating = false // 🔥 Clear updating flag on error
            return
        }
        
        print("🔥 LIVE UPDATE DEBUG: Extracted \(freshPlayerEntries.count) players")
        
        // Debug: Show sample scores before update
        let sampleBefore = Array(allPlayers.prefix(3))
        for player in sampleBefore {
            print("🔥 BEFORE UPDATE: \(player.playerName) = \(player.currentScore) pts")
        }
        
        // Update player data with fresh scores from matchups
        await updatePlayerDataSilently(from: freshPlayerEntries)
        
        // Debug: Show sample scores after update
        let sampleAfter = Array(allPlayers.prefix(3))
        for player in sampleAfter {
            print("🔥 AFTER UPDATE: \(player.playerName) = \(player.currentScore) pts")
        }
        
        // Debug: Show filtered players
        let filteredSample = Array(filteredPlayers.prefix(3))
        for player in filteredSample {
            print("🔥 FILTERED RESULT: \(player.playerName) = \(player.currentScore) pts")
        }
        
        // 🔥 NEW: Update PlayerWatchService with fresh data
        await notifyPlayerWatchService(with: freshPlayerEntries)
        
        // 🔥 CRITICAL: Update timestamp to trigger view updates
        let oldTime = lastUpdateTime
        lastUpdateTime = Date()
        
        print("🔥 LIVE UPDATE COMPLETE: Updated lastUpdateTime from \(oldTime) to \(lastUpdateTime)")
        print("🔥 LIVE UPDATE STATS: allPlayers.count = \(allPlayers.count), filteredPlayers.count = \(filteredPlayers.count)")
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ LIVE UPDATE: Completed in \(String(format: "%.2f", elapsed))s")
        
        // 🔥 NEW: Clear updating flag when complete
        isUpdating = false
        
        // 🔥 PHASE 3: @Observable handles change notifications automatically
        // No need for objectWillChange.send() anymore
        print("🔥 @OBSERVABLE: Property changes will automatically trigger UI updates")
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
            let newWeek = WeekSelectionManager.shared.selectedWeek
            self?.debounceTask?.cancel()
            self?.debounceTask = Task { @MainActor in
                // PRESERVE SEARCH STATE: Don't clear search data during week changes
                let wasSearching = self?.isSearching ?? false
                let searchText = self?.searchText ?? ""
                let showRosteredOnly = self?.showRosteredOnly ?? false
                let preservedNFLPlayers = self?.allNFLPlayers ?? []
                
                // Reset stats for new week
                self?.statsLoaded = false
                self?.playerStats = [:]
                
                // Reload stats for new week if we have players
                if !(self?.allPlayers.isEmpty ?? true) {
                    await self?.loadPlayerStats()
                }
                
                // RESTORE SEARCH STATE: Put search state back after week change
                if wasSearching {
                    self?.isSearching = wasSearching
                    self?.searchText = searchText
                    self?.showRosteredOnly = showRosteredOnly
                    self?.allNFLPlayers = preservedNFLPlayers
                    
                    // Reapply search filters for new week
                    self?.applyPositionFilter()
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
    
    // MARK: - Extract All Players from Matchups
    internal func extractAllPlayers() -> [LivePlayerEntry] {
        var allPlayerEntries: [LivePlayerEntry] = []
        
        for matchup in matchupsHubViewModel.myMatchups {
            let playersFromMatchup = extractPlayersFromSingleMatchup(matchup)
            allPlayerEntries.append(contentsOf: playersFromMatchup)
        }
        
        return allPlayerEntries
    }
    
    // MARK: - PlayerWatchService Integration
    
    /// Notify PlayerWatchService of updated player data
    private func notifyPlayerWatchService(with playerEntries: [LivePlayerEntry]) async {
        print("🔥 WATCH SERVICE UPDATE: Converting \(playerEntries.count) players for PlayerWatchService")
        
        // Convert LivePlayerEntry to OpponentPlayer format
        let opponentPlayers = playerEntries.map { entry in
            OpponentPlayer(
                id: UUID().uuidString,
                player: entry.player,
                isStarter: entry.isStarter,
                currentScore: entry.currentScore,
                projectedScore: entry.projectedScore,
                threatLevel: convertThreatLevel(entry.performanceTier),
                matchupAdvantage: .neutral,
                percentageOfOpponentTotal: entry.percentageOfTop * 100.0
            )
        }
        
        // Update PlayerWatchService on main actor
        await MainActor.run {
            PlayerWatchService.shared.updateWatchedPlayerScores(opponentPlayers)
        }
        
        print("🔥 WATCH SERVICE UPDATE: Updated PlayerWatchService with \(opponentPlayers.count) players")
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
