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
        if showActive && NFLGameDataService.shared.gameData.isEmpty {
            Task { @MainActor in
                let currentWeek = NFLWeekCalculator.getCurrentWeek()
                NFLGameDataService.shared.fetchGameData(forWeek: currentWeek, forceRefresh: false)
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
    
    // MARK: - Core Filtering Logic
    
    internal func applyPositionFilter() {
        guard !allPlayers.isEmpty else {
            filteredPlayers = []
            return
        }

        var players = allPlayers
        
        // If searching, handle two different flows
        if isSearching {
            if showRosteredOnly {
                // ROSTERED ONLY SEARCH: Filter existing league players by search terms
                players = allPlayers.filter { livePlayer in
                    return playerNameMatches(livePlayer.playerName, searchQuery: searchText)
                }
                
                // IMPORTANT: Don't apply any other filters when doing rostered search
                // Skip to the final steps to preserve the search results
            } else {
                // FULL NFL SEARCH: Search all NFL players and create search entries
                guard !allNFLPlayers.isEmpty else {
                    // If NFL players not loaded yet, show empty state
                    filteredPlayers = []
                    return
                }
                
                let matchingNFLPlayers = allNFLPlayers.filter { player in
                    return sleeperPlayerMatches(player, searchQuery: searchText)
                }.prefix(50)
                
                // Convert to LivePlayerEntry format for display
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
                        lineupSlot: nil
                    )
                    
                    guard let templateMatchup = allPlayers.first?.matchup else { 
                        return nil 
                    }
                    
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
                        performanceTier: .average
                    )
                }
            }
        } else {
            // Apply normal filters when not searching
            
            // Step 1: Position filter
            players = selectedPosition == .all ?
                allPlayers :
                allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }

            // Step 2: Active-only filter (SIMPLIFIED)
            if showActiveOnly {
                players = players.filter { player in
                    return isPlayerInLiveGame(player.player)
                }
            }
        }
        
        // Step 3: Basic quality filter - BUT SKIP if doing rostered search to preserve results
        if !(isSearching && showRosteredOnly) {
            players = players.filter { player in
                // Keep players with valid names and reasonable data
                let hasValidName = !player.playerName.trimmingCharacters(in: .whitespaces).isEmpty
                let isNotUnknown = player.player.fullName != "Unknown Player"
                let hasReasonableData = player.currentScore >= 0.0 // Allow 0.0 scores
                
                return hasValidName && isNotUnknown && hasReasonableData
            }
        }

        guard !players.isEmpty else {
            filteredPlayers = []
            positionTopScore = 0.0
            return
        }

        // Step 4: Calculate position-specific statistics
        let positionScores = players.map { $0.currentScore }.sorted(by: >)
        positionTopScore = positionScores.first ?? 1.0
        let positionQuartiles = calculateQuartiles(from: positionScores)

        // Step 5: Update players with position-relative percentages and tiers
        let updatedPlayers = players.map { entry in
            let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: positionTopScore)
            let tier = determinePerformanceTier(score: entry.currentScore, quartiles: positionQuartiles)

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
                performanceTier: tier
            )
        }

        // Step 6: Apply sorting
        filteredPlayers = sortPlayers(updatedPlayers)
    }
    
    // MARK: - Sorting Logic
    
    private func sortPlayers(_ players: [LivePlayerEntry]) -> [LivePlayerEntry] {
        let sortedPlayers: [LivePlayerEntry]

        switch sortingMethod {
        case .position:
            sortedPlayers = sortHighToLow ?
                players.sorted { positionPriority($0.position) < positionPriority($1.position) } :
                players.sorted { positionPriority($0.position) > positionPriority($1.position) }
            
        case .score:
            sortedPlayers = sortHighToLow ?
                players.sorted { $0.currentScore > $1.currentScore } :
                players.sorted { $0.currentScore < $1.currentScore }

        case .name:
            // Simplified name sorting - no special handling
            sortedPlayers = sortHighToLow ?
                players.sorted { extractLastName($0.playerName) < extractLastName($1.playerName) } :
                players.sorted { extractLastName($0.playerName) > extractLastName($1.playerName) }

        case .team:
            sortedPlayers = sortHighToLow ?
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()

                    if team1 != team2 {
                        return team1 < team2
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                } :
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()

                    if team1 != team2 {
                        return team1 > team2
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                }
        }

        return sortedPlayers
    }
    
    // MARK: - Sorting Helpers
    
    private func extractLastName(_ fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }

    private func positionPriority(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "RB": return 2
        case "WR": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "DEF", "DST": return 6
        case "K": return 7
        default: return 8
        }
    }
    
    // MARK: - Animation Control
    
    internal func triggerAnimationReset() {
        shouldResetAnimations = true
        sortChangeID = UUID()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldResetAnimations = false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Smart name matching that handles apostrophes properly - FIXED VERSION  
    private func playerNameMatches(_ playerName: String, searchQuery: String) -> Bool {
        // Don't force any capitalization - keep everything lowercase for matching
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let name = playerName.lowercased()
        
        guard !query.isEmpty else { return false }
        
        // Split both query and name by spaces for flexible matching
        let queryTerms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let nameComponents = name.components(separatedBy: .whitespaces)
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.last ?? ""
        
        // For each query term, check if ANY name field contains it
        for queryTerm in queryTerms {
            let termFound = name.contains(queryTerm) || 
                          firstName.contains(queryTerm) || 
                          lastName.contains(queryTerm)
            
            if termFound {
                return true  // If any term matches, player matches
            }
        }
        
        return false
    }
    
    /// Smart name matching for SleeperPlayer objects - FIXED VERSION
    private func sleeperPlayerMatches(_ player: SleeperPlayer, searchQuery: String) -> Bool {
        // Don't force any capitalization - keep everything lowercase for matching
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else { return false }
        
        let fullName = player.fullName.lowercased()
        let shortName = player.shortName.lowercased()  
        let firstName = player.firstName?.lowercased() ?? ""
        let lastName = player.lastName?.lowercased() ?? ""
        
        // Split query by spaces for flexible matching
        let queryTerms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // For each query term, check if ANY name field contains it
        for queryTerm in queryTerms {
            let termFound = fullName.contains(queryTerm) || 
                          shortName.contains(queryTerm) || 
                          firstName.contains(queryTerm) || 
                          lastName.contains(queryTerm)
            
            if termFound {
                return true  // If any term matches, player matches
            }
        }
        
        return false
    }
    
    /// Get all Sleeper IDs of players on my rosters
    private func getMyRosterSleeperIDs() -> Set<String> {
        var ids = Set<String>()
        for matchup in allPlayers {
            if let sleeperID = matchup.player.sleeperID {
                ids.insert(sleeperID)
            }
        }
        return ids
    }
}