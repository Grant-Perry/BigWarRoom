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
        let urlString = "https://api.sleeper.app/v1/stats/nfl/regular/\(currentYear)/\(selectedWeek)"
        
        print("🔄 STATS DEBUG: Loading player stats from \(urlString)")

        guard let url = URL(string: urlString) else {
            print("🔄 STATS DEBUG: Invalid URL, marking stats as loaded")
            await MainActor.run { self.statsLoaded = true }
            return
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 10.0)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            print("🔄 STATS DEBUG: Successfully loaded stats for \(statsData.keys.count) players")
            
            // Log a few sample player scores for debugging
            let sampleStats = Array(statsData.prefix(3))
            for (playerId, stats) in sampleStats {
                let fantasyPoints = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                print("🔄 STATS DEBUG: Sample - Player \(playerId): \(fantasyPoints) pts")
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = statsData
                self.statsLoaded = true
                print("🔄 STATS DEBUG: Updated playerStats on main thread")
                
                // 🔥 CRITICAL FIX: Don't trigger objectWillChange here
                // Let the natural property change handle it to avoid duplicate updates
            }
        } catch {
            print("🔄 STATS DEBUG: Failed to load stats: \(error)")
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
        
        print("🔥 LIVE UPDATE START: Beginning live update process...")
        let startTime = Date()
        
        // 🔥 CRITICAL FIX: Refresh matchups FIRST to get fresh scores
        await matchupsHubViewModel.performManualRefresh()
        print("🔥 LIVE UPDATE: Refreshed matchup data")
        
        // 🔥 FIXED: Now extract from refreshed matchup data 
        let freshPlayerEntries = extractAllPlayers()
        guard !freshPlayerEntries.isEmpty else {
            print("🔥 LIVE UPDATE ERROR: No fresh player entries found")
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
        
        // 🔥 CRITICAL: Update timestamp to trigger view updates
        let oldTime = lastUpdateTime
        lastUpdateTime = Date()
        
        print("🔥 LIVE UPDATE COMPLETE: Updated lastUpdateTime from \(oldTime) to \(lastUpdateTime)")
        print("🔥 LIVE UPDATE STATS: allPlayers.count = \(allPlayers.count), filteredPlayers.count = \(filteredPlayers.count)")
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ LIVE UPDATE: Completed in \(String(format: "%.2f", elapsed))s")
        
        // 🔥 FORCE UI UPDATE: Manually trigger objectWillChange as backup
        objectWillChange.send()
        print("🔥 SENT OBJECT WILL CHANGE")
    }
    
    // MARK: - Week Changes Subscription
    internal func subscribeToWeekChanges() {
        weekSubscription = WeekSelectionManager.shared.$selectedWeek
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newWeek in
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
}