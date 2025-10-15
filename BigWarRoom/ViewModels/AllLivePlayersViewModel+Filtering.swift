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
    
    func applySorting() {
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    // MARK: - Core Filtering Logic
    
    internal func applyPositionFilter() {
        print("🔥 FILTERING: Applying filters - Position: \(selectedPosition.rawValue), ActiveOnly: \(showActiveOnly)")

        guard !allPlayers.isEmpty else {
            print("🔥 FILTERING: No players to filter")
            filteredPlayers = []
            return
        }

        // Step 1: Position filter
        let positionFiltered = selectedPosition == .all ?
            allPlayers :
            allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }
        
        print("🔥 FILTERING: After position filter - \(positionFiltered.count) players")

        // Step 2: Active-only filter
        var players = positionFiltered
        if showActiveOnly {
            print("🔥 FILTERING: Applying Active Only filter...")
            players = positionFiltered.filter { player in
                return isPlayerInLiveGame(player.player)
            }
            print("🔥 FILTERING: After Active Only filter - \(players.count) live players")
        }
        
        // Step 3: Filter out empty cards for name sorting (fixes the empty card issue)
        if sortingMethod == .name {
            players = players.filter { $0.currentScore > 0.0 }
            print("🔥 FILTERING: Filtered out empty cards for name sort - \(players.count) players remaining")
        }

        guard !players.isEmpty else {
            print("🔥 FILTERING: No players after filtering - showing empty state")
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
}