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
        print("🔥 DATA FETCH: Fetching new data from APIs")
        
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
        print("🔥 DATA PROCESSING: Using existing fresh data")
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

        guard let url = URL(string: urlString) else {
            await MainActor.run { self.statsLoaded = true }
            return
        }

        do {
            let request = URLRequest(url: url, timeoutInterval: 10.0)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return }

            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)

            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.playerStats = statsData
                self.statsLoaded = true
                self.objectWillChange.send()
            }
        } catch {
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.statsLoaded = true
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Manual Refresh
    internal func performManualRefresh() async {
        print("🔄 MANUAL REFRESH: User initiated refresh - showing loading")
        lastLoadTime = nil // Force fresh fetch
        await performDataLoad()
    }
    
    // MARK: - Background Updates (Silent)
    func performLiveUpdate() async {
        guard isDataLoaded else { return }
        print("🔄 BACKGROUND UPDATE: Silently refreshing player scores")
        await updatePlayerDataSurgically()
    }
    
    // MARK: - Week Changes Subscription
    internal func subscribeToWeekChanges() {
        weekSubscription = WeekSelectionManager.shared.$selectedWeek
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newWeek in
                self?.debounceTask?.cancel()
                self?.debounceTask = Task { @MainActor in
                    self?.statsLoaded = false
                    self?.playerStats = [:]
                    
                    if !(self?.allPlayers.isEmpty ?? true) {
                        await self?.loadPlayerStats()
                    }
                }
            }
    }
    
    // MARK: - Force Methods (For Compatibility)
    func forceLoadAllPlayers() async {
        print("🔥 FORCE: Force loading all players (bypassing cache)")
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