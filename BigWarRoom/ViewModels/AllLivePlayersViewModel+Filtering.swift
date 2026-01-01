//
//  AllLivePlayersViewModel+Filtering.swift
//  BigWarRoom
//
//  🔥 FOCUSED: Filtering, sorting, and position logic (instant operations)
//

import Foundation

extension AllLivePlayersViewModel {
    // MARK: - Filter Control Methods (Instant - No Loading States)
    
    func setSortDirection(highToLow: Bool) {
        sortHighToLow = highToLow
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    func toggleSortDirection() {
        sortHighToLow.toggle()
        triggerAnimationReset()
        applyPositionFilter()
    }

    func setShowActiveOnly(_ showActive: Bool) {
        showActiveOnly = showActive
        triggerAnimationReset()
        
        // Clear live game cache when changing active filter
        clearLiveGameCache()
        
        // Apply filter instantly - no loading state
        applyPositionFilter()
        
        // Load game data in background if needed
        if showActive && nflGameDataService.gameData.isEmpty {
            Task { @MainActor in
                // 🔥 CRITICAL FIX: Use WeekSelectionManager.selectedWeek (user's chosen week) instead of getCurrentWeek
                let selectedWeek = weekSelectionManager.selectedWeek
                
                DebugPrint(mode: .weekCheck, "📅 AllLivePlayers: Fetching NFL game data for user-selected week \(selectedWeek)")
                
                nflGameDataService.fetchGameData(forWeek: selectedWeek, forceRefresh: false)
            }
        }
    }
    
    func setSearchText(_ text: String) {
        searchText = text
        isSearching = !text.trimmingCharacters(in: .whitespaces).isEmpty
        
        // Load all NFL players if searching and haven't loaded yet (always load since we always search all)
        if isSearching && allNFLPlayers.isEmpty {
            Task {
                await loadAllNFLPlayers()
            }
        }
        
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    func clearSearch() {
        searchText = ""
        isSearching = false
        showRosteredOnly = false // Reset the filter too
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    func toggleRosteredFilter() {
        showRosteredOnly.toggle()
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    // MARK: - All NFL Players Loading
    private func loadAllNFLPlayers() async {
        // Use PlayerDirectoryStore instead of the old approach
        let playerStore = PlayerDirectoryStore.shared
        
        // Check if we need to refresh the player directory
        if playerStore.needsRefresh {
            await playerStore.refreshPlayers()
        }
        
        let playersData = playerStore.players
        
        let nflPlayers = Array(playersData.values).filter { player in
            let hasValidName = !player.fullName.trimmingCharacters(in: .whitespaces).isEmpty
            let hasPosition = player.position != nil
            return hasPosition && hasValidName
        }.sorted { player1, player2 in
            let rank1 = player1.searchRank ?? 999
            let rank2 = player2.searchRank ?? 999
            return rank1 < rank2
        }
        
        await MainActor.run {
            allNFLPlayers = nflPlayers
        }
    }

    func applySorting() {
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    // MARK: - Core Filtering Logic (🔥 DRY: Uses PlayerFilteringService + PlayerSortingService)
    
    internal func applyPositionFilter() {
        guard !allPlayers.isEmpty else {
            filteredPlayers = []
            return
        }

        var players = allPlayers
        
        // If searching, handle two different flows
        if isSearching {
            if showRosteredOnly {
                // ROSTERED ONLY SEARCH: Use service for filtering
                players = PlayerFilteringService.shared.filterBySearchText(allPlayers, searchText: searchText)
            } else {
                // FULL NFL SEARCH: Search all NFL players and create search entries
                guard !allNFLPlayers.isEmpty else {
                    filteredPlayers = []
                    return
                }
                
                // 🔥 DRY: Use service for Sleeper player search
                let matchingNFLPlayers = PlayerFilteringService.shared.filterSleeperPlayers(
                    allNFLPlayers,
                    searchText: searchText
                ).prefix(50)
                
                // Convert to LivePlayerEntry format for display
                guard let templateMatchup = allPlayers.first?.matchup else {
                    filteredPlayers = []
                    return
                }
                
                players = matchingNFLPlayers.compactMap { sleeperPlayer in
                    let fantasyPlayer = FantasyPlayer(
                        id: sleeperPlayer.playerID,
                        sleeperID: sleeperPlayer.playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "UNKNOWN",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: 0.0,
                        projectedPoints: 0.0,
                        gameStatus: nil,
                        isStarter: false,
                        lineupSlot: nil,
                        injuryStatus: sleeperPlayer.injuryStatus
                    )

                    return LivePlayerEntry(
                        id: "search_all_\(sleeperPlayer.playerID)",
                        player: fantasyPlayer,
                        leagueName: "NFL Search",
                        leagueSource: "Search",
                        currentScore: 0.0,
                        projectedScore: 0.0,
                        isStarter: false,
                        percentageOfTop: 0.0,
                        matchup: templateMatchup,
                        performanceTier: .average,
                        lastActivityTime: nil,
                        previousScore: nil,
                        accumulatedDelta: 0.0
                    )
                }
            }
        } else {
            // 🔥 DRY: Use service for all filtering
            players = PlayerFilteringService.shared.applyFilters(
                to: allPlayers,
                selectedPosition: selectedPosition,
                showActiveOnly: showActiveOnly,
                gameDataService: nflGameDataService
            )
        }

        guard !players.isEmpty else {
            filteredPlayers = []
            positionTopScore = 0.0
            return
        }

        // 🔥 DRY: Use PlayerStatisticsService for calculations
        let positionScores = players.map { $0.currentScore }.sorted(by: >)
        positionTopScore = positionScores.first ?? 1.0
        let positionQuartiles = PlayerStatisticsService.shared.calculateQuartiles(from: positionScores)

        // Update players with position-relative percentages and tiers
        let updatedPlayers = players.map { entry in
            let percentage = PlayerStatisticsService.shared.calculateScaledPercentage(
                score: entry.currentScore,
                topScore: positionTopScore,
                useAdaptiveScaling: useAdaptiveScaling
            )
            let tier = PlayerStatisticsService.shared.determinePerformanceTier(
                score: entry.currentScore,
                quartiles: positionQuartiles
            )

            return LivePlayerEntry(
                id: entry.id,
                player: entry.player,
                leagueName: entry.leagueName,
                leagueSource: entry.leagueSource,
                currentScore: entry.currentScore,
                projectedScore: entry.projectedScore,
                isStarter: entry.isStarter,
                percentageOfTop: percentage,
                matchup: entry.matchup,
                performanceTier: tier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.previousScore,
                accumulatedDelta: entry.accumulatedDelta
            )
        }

        // 🔥 DRY: Use PlayerSortingService for sorting
        filteredPlayers = PlayerSortingService.shared.sortPlayers(
            updatedPlayers,
            by: sortingMethod,
            highToLow: sortHighToLow
        )
    }
    
    // MARK: - REMOVED: All sorting logic moved to PlayerSortingService
    // MARK: - REMOVED: All helper methods moved to PlayerFilteringService
    
    // MARK: - Animation Control
    
    internal func triggerAnimationReset() {
        shouldResetAnimations = true
        sortChangeID = UUID()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldResetAnimations = false
        }
    }
}