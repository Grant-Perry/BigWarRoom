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
        print("🔥 ACTIVE FILTER: Setting showActiveOnly to \(showActive)")
        showActiveOnly = showActive
        triggerAnimationReset()
        
        // Clear live game cache when changing active filter
        clearLiveGameCache()
        
        // Apply filter instantly - no loading state
        applyPositionFilter()
        
        // Load game data in background if needed
        if showActive && NFLGameDataService.shared.gameData.isEmpty {
            Task { @MainActor in
                print("🔄 BACKGROUND: Loading game data for future filtering")
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
        print("🔄 Loading all NFL players for search...")
        
        // Use PlayerDirectoryStore instead of the old approach
        let playerStore = PlayerDirectoryStore.shared
        
        // Check if we need to refresh the player directory
        if playerStore.needsRefresh {
            print("🔄 Player directory needs refresh - fetching from API...")
            await playerStore.refreshPlayers()
        }
        
        let playersData = playerStore.players
        print("📊 PlayerDirectoryStore has \(playersData.count) total players")
        
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
            print("✅ Loaded \(nflPlayers.count) NFL players for search")
            
            // Debug: Look for Ja'Marr Chase specifically
            let jamarrPlayers = nflPlayers.filter { player in
                player.fullName.lowercased().contains("marr") && player.fullName.lowercased().contains("chase")
            }
            print("🏈 Found \(jamarrPlayers.count) players with 'marr' and 'chase' in name:")
            for player in jamarrPlayers.prefix(3) {
                print("   - \(player.fullName) (ID: \(player.playerID))")
            }
            
            // Test our matching logic on Ja'Marr
            if let jamarrPlayer = jamarrPlayers.first {
                let testQueries = ["ja", "jamarr", "ja'marr", "marr", "chase"]
                for query in testQueries {
                    let matches = playerNameMatches(jamarrPlayer.fullName, searchQuery: query)
                    print("🧪 Test: '\(query)' matches '\(jamarrPlayer.fullName)' = \(matches)")
                }
            }
        }
    }

    func applySorting() {
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    // MARK: - Core Filtering Logic
    
    internal func applyPositionFilter() {
        print("🔥 FILTERING: Applying filters - Position: \(selectedPosition.rawValue), ActiveOnly: \(showActiveOnly), SortMethod: \(sortingMethod.rawValue), Search: '\(searchText)', RosteredOnly: \(showRosteredOnly)")
        print("🔥 FILTERING: allPlayers.count = \(allPlayers.count)")

        guard !allPlayers.isEmpty else {
            print("🔥 FILTERING: No players to filter")
            filteredPlayers = []
            return
        }

        var players = allPlayers
        print("🔥 FILTERING: Starting with \(players.count) players")
        
        // If searching, handle two different flows
        if isSearching {
            print("🔥 FILTERING: In search mode")
            if showRosteredOnly {
                // ROSTERED ONLY SEARCH: Filter existing league players by search terms
                print("🔥 SEARCH: Searching ROSTERED players for '\(searchText)'")
                
                players = allPlayers.filter { livePlayer in
                    let matches = playerNameMatches(livePlayer.playerName, searchQuery: searchText)
                    if matches {
                        print("🏈 ROSTERED MATCH: '\(searchText)' matches '\(livePlayer.playerName)'")
                    }
                    return matches
                }
                
                print("🔥 SEARCH: Found \(players.count) rostered players matching '\(searchText)'")
                
                // IMPORTANT: Don't apply any other filters when doing rostered search
                // Skip to the final steps to preserve the search results
            } else {
                // FULL NFL SEARCH: Search all NFL players and create search entries
                print("🔥 SEARCH: Searching ALL NFL players for '\(searchText)'")
                
                guard !allNFLPlayers.isEmpty else {
                    // If NFL players not loaded yet, show empty state
                    filteredPlayers = []
                    return
                }
                
                let matchingNFLPlayers = allNFLPlayers.filter { player in
                    let matches = sleeperPlayerMatches(player, searchQuery: searchText)
                    if matches {
                        print("🏈 NFL MATCH: '\(searchText)' matches '\(player.fullName)'")
                    }
                    return matches
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
                
                print("🔥 SEARCH: Found \(players.count) NFL players matching '\(searchText)'")
            }
        } else {
            print("🔥 FILTERING: NOT in search mode - applying normal filters")
            // Apply normal filters when not searching
            
            // Step 1: Position filter
            players = selectedPosition == .all ?
                allPlayers :
                allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }
            
            print("🔥 FILTERING: After position filter (\(selectedPosition.rawValue)) - \(players.count) players")

            // Step 2: Active-only filter (SIMPLIFIED)
            if showActiveOnly {
                print("🔥 FILTERING: Filtering to ACTIVE players only...")
                players = players.filter { player in
                    return isPlayerInLiveGame(player.player)
                }
                print("🔥 FILTERING: After Active Only filter - \(players.count) live players")
            } else {
                print("🔥 FILTERING: Showing ALL players (no active filtering)")
            }
        }
        
        print("🔥 FILTERING: Before quality filter - \(players.count) players")
        
        // Step 3: Basic quality filter - BUT SKIP if doing rostered search to preserve results
        if !(isSearching && showRosteredOnly) {
            let beforeCount = players.count
            players = players.filter { player in
                // Keep players with valid names and reasonable data
                let hasValidName = !player.playerName.trimmingCharacters(in: .whitespaces).isEmpty
                let isNotUnknown = player.player.fullName != "Unknown Player"
                let hasReasonableData = player.currentScore >= 0.0 // Allow 0.0 scores
                
                let passes = hasValidName && isNotUnknown && hasReasonableData
                if !passes {
                    print("🔥 QUALITY FILTER: Rejecting '\(player.playerName)' - hasValidName: \(hasValidName), isNotUnknown: \(isNotUnknown), hasReasonableData: \(hasReasonableData)")
                }
                return passes
            }
            print("🔥 FILTERING: After basic quality filter - \(players.count) players (filtered out \(beforeCount - players.count))")
        }

        guard !players.isEmpty else {
            print("🔥 FILTERING: No valid players after filtering - showing empty state")
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
        print("🔥 FILTERING: Final result - \(filteredPlayers.count) players after sorting")
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