//
//  AllLivePlayersViewModel+PlayerProcessing.swift
//  BigWarRoom
//
//  🔥 FOCUSED: Player extraction, score calculations, and data building
//

import Foundation

extension AllLivePlayersViewModel {
    // MARK: - Player Extraction from Single Matchup
    internal func extractPlayersFromSingleMatchup(_ matchup: UnifiedMatchup) -> [LivePlayerEntry] {
        var players: [LivePlayerEntry] = []

        // Regular matchups - extract from MY team only
        if let fantasyMatchup = matchup.fantasyMatchup {
            if let myTeam = matchup.myTeam {
                let myStarters = myTeam.roster.filter { $0.isStarter }
                for player in myStarters {
                    let calculatedScore = getCalculatedPlayerScore(for: player, in: matchup)
                    
                    players.append(LivePlayerEntry(
                        id: "\(matchup.id)_my_\(player.id)",
                        player: player,
                        leagueName: matchup.league.league.name,
                        leagueSource: matchup.league.source.rawValue,
                        currentScore: calculatedScore,
                        projectedScore: player.projectedPoints ?? 0.0,
                        isStarter: player.isStarter,
                        percentageOfTop: 0.0, // Calculated later
                        matchup: matchup,
                        performanceTier: .average // Calculated later
                    ))
                }
            }
        }

        // Chopped leagues - extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }

            for player in myTeamStarters {
                let calculatedScore = getCalculatedPlayerScore(for: player, in: matchup)
                
                players.append(LivePlayerEntry(
                    id: "\(matchup.id)_chopped_\(player.id)",
                    player: player,
                    leagueName: matchup.league.league.name,
                    leagueSource: matchup.league.source.rawValue,
                    currentScore: calculatedScore,
                    projectedScore: player.projectedPoints ?? 0.0,
                    isStarter: player.isStarter,
                    percentageOfTop: 0.0, // Calculated later
                    matchup: matchup,
                    performanceTier: .average // Calculated later
                ))
            }
        }
        
        return players
    }
    
    // MARK: - Score Calculation
    private func getCalculatedPlayerScore(for player: FantasyPlayer, in matchup: UnifiedMatchup) -> Double {
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = AppConstants.currentSeasonYear
        
        if let cachedProvider = matchupsHubViewModel.getCachedProvider(
            for: matchup.league, 
            week: currentWeek, 
            year: currentYear
        ) {
            // ESPN leagues - get fresh score from cached matchup
            if matchup.league.source == .espn {
                if let myTeam = matchup.myTeam,
                   let freshPlayer = myTeam.roster.first(where: { $0.id == player.id }) {
                    return freshPlayer.currentPoints ?? 0.0
                }
            }
            
            // Sleeper leagues - use calculated score from provider
            if matchup.league.source == .sleeper && cachedProvider.hasPlayerScores() {
                return cachedProvider.getPlayerScore(playerId: player.id)
            }
        }
        
        // Fallback to cached score
        return player.currentPoints ?? 0.0
    }
    
    // MARK: - Build Player Data with Statistics
    internal func buildPlayerData(from allPlayerEntries: [LivePlayerEntry]) async {
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // Calculate overall statistics
        topScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        scoreRange = topScore - bottomScore
        
        // Calculate median
        if !scores.isEmpty {
            let mid = scores.count / 2
            medianScore = scores.count % 2 == 0 ?
                (scores[mid - 1] + scores[mid]) / 2 :
                scores[mid]
        }
        
        // Use adaptive scaling for extreme distributions
        useAdaptiveScaling = topScore > (medianScore * 3)
        let quartiles = calculateQuartiles(from: scores)
        
        // Update players with proper percentages and tiers
        allPlayers = allPlayerEntries.map { entry in
            let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: topScore)
            let tier = determinePerformanceTier(score: entry.currentScore, quartiles: quartiles)
            
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
        
        // Apply current filters
        applyPositionFilter()
    }
    
    // MARK: - Surgical Data Update (Silent Background Updates)
    internal func updatePlayerDataSurgically() async {
        print("🔇 SILENT UPDATE: Starting surgical data update - NO UI state changes")
        
        let allPlayerEntries = extractAllPlayers()
        guard !allPlayerEntries.isEmpty else { return }
        
        // 🔥 FIX: Update data silently without triggering any UI state changes
        await updatePlayerDataSilently(from: allPlayerEntries)
        lastUpdateTime = Date()
    }
    
    // 🔥 NEW: Truly silent update that doesn't trigger UI changes
    private func updatePlayerDataSilently(from allPlayerEntries: [LivePlayerEntry]) async {
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // Update statistics silently
        topScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        scoreRange = topScore - bottomScore
        
        if !scores.isEmpty {
            let mid = scores.count / 2
            medianScore = scores.count % 2 == 0 ?
                (scores[mid - 1] + scores[mid]) / 2 :
                scores[mid]
        }
        
        useAdaptiveScaling = topScore > (medianScore * 3)
        let quartiles = calculateQuartiles(from: scores)
        
        // Update players silently
        allPlayers = allPlayerEntries.map { entry in
            let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: topScore)
            let tier = determinePerformanceTier(score: entry.currentScore, quartiles: quartiles)
            
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
        
        // 🔥 FIX: Apply filters silently without triggering state changes
        applySilentPositionFilter()
        
        print("🔇 SILENT UPDATE: Completed without any loading state changes")
    }
    
    // 🔥 NEW: Silent filter application (called during background updates)
    private func applySilentPositionFilter() {
        print("🔇 SILENT FILTER: Applying filters without UI state changes - Search: '\(searchText)', RosteredOnly: \(showRosteredOnly)")
        
        guard !allPlayers.isEmpty else {
            filteredPlayers = []
            return
        }

        var players = allPlayers
        
        // If searching, handle two different flows (SAME AS MAIN FILTER)
        if isSearching {
            if showRosteredOnly {
                // ROSTERED ONLY SEARCH: Filter existing league players by search terms
                print("🔇 SILENT: Searching ROSTERED players for '\(searchText)'")
                
                players = allPlayers.filter { livePlayer in
                    let matches = playerNameMatches(livePlayer.playerName, searchQuery: searchText)
                    if matches {
                        print("🔇 ROSTERED MATCH: '\(searchText)' matches '\(livePlayer.playerName)'")
                    }
                    return matches
                }
                
                print("🔇 SILENT: Found \(players.count) rostered players matching '\(searchText)'")
                
                // IMPORTANT: Don't apply any other filters when doing rostered search
                // Skip to the final steps to preserve the search results
            } else {
                // FULL NFL SEARCH: Search all NFL players and create search entries
                print("🔇 SILENT: Searching ALL NFL players for '\(searchText)'")
                
                guard !allNFLPlayers.isEmpty else {
                    filteredPlayers = []
                    return
                }
                
                let matchingNFLPlayers = allNFLPlayers.filter { player in
                    let matches = sleeperPlayerMatches(player, searchQuery: searchText)
                    if matches {
                        print("🔇 NFL MATCH: '\(searchText)' matches '\(player.fullName)'")
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
                
                print("🔇 SILENT: Found \(players.count) NFL players matching '\(searchText)'")
            }
        } else {
            // Apply normal filters when not searching
            
            // Apply position filter
            players = selectedPosition == .all ?
                allPlayers :
                allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }

            // Apply active-only filter
            if showActiveOnly {
                players = players.filter { player in
                    return isPlayerInLiveGame(player.player)
                }
            }
        }
        
        // Basic quality filter - BUT SKIP if doing rostered search to preserve results
        if !(isSearching && showRosteredOnly) {
            players = players.filter { player in
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

        // Calculate position-specific statistics
        let positionScores = players.map { $0.currentScore }.sorted(by: >)
        positionTopScore = positionScores.first ?? 1.0
        let positionQuartiles = calculateQuartiles(from: positionScores)

        // Update players with position-relative percentages and tiers
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

        // Apply sorting silently
        filteredPlayers = sortPlayersSilently(updatedPlayers)
        print("🔇 SILENT FILTER: Completed - \(filteredPlayers.count) players")
    }
    
    // 🔥 NEW: Silent sorting (no UI changes)
    private func sortPlayersSilently(_ players: [LivePlayerEntry]) -> [LivePlayerEntry] {
        // Same sorting logic but without any UI state changes
        let sortedPlayers: [LivePlayerEntry]

        switch sortingMethod {
        case .position:
            sortedPlayers = sortHighToLow ?
                players.sorted { positionPrioritySilent($0.position) < positionPrioritySilent($1.position) } :
                players.sorted { positionPrioritySilent($0.position) > positionPrioritySilent($1.position) }
            
        case .score:
            sortedPlayers = sortHighToLow ?
                players.sorted { $0.currentScore > $1.currentScore } :
                players.sorted { $0.currentScore < $1.currentScore }

        case .name:
            sortedPlayers = sortHighToLow ?
                players.sorted { extractLastNameSilent($0.playerName) < extractLastNameSilent($1.playerName) } :
                players.sorted { extractLastNameSilent($0.playerName) > extractLastNameSilent($1.playerName) }

        case .team:
            sortedPlayers = sortHighToLow ?
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()

                    if team1 != team2 {
                        return team1 < team2
                    }
                    return positionPrioritySilent(player1.position) < positionPrioritySilent(player2.position)
                } :
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()

                    if team1 != team2 {
                        return team1 > team2
                    }
                    return positionPrioritySilent(player1.position) < positionPrioritySilent(player2.position)
                }
        }

        return sortedPlayers
    }
    
    // 🔥 NEW: Helper methods for silent operations
    private func extractLastNameSilent(_ fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }

    private func positionPrioritySilent(_ position: String) -> Int {
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

    // MARK: - NEW: Matching Functions for Silent Updates (copied from Filtering extension)
    
    /// Smart name matching that handles apostrophes properly - SILENT VERSION
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
    
    /// Smart name matching for SleeperPlayer objects - SILENT VERSION
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
    
    // MARK: - Statistical Calculations
    internal func calculateScaledPercentage(score: Double, topScore: Double) -> Double {
        guard topScore > 0 else { return 0.0 }

        if useAdaptiveScaling {
            // Logarithmic scaling for extreme distributions
            let logTop = log(max(topScore, 1.0))
            let logScore = log(max(score, 1.0))
            return logScore / logTop
        } else {
            // Standard linear scaling
            return score / topScore
        }
    }

    internal func calculateQuartiles(from sortedScores: [Double]) -> (q1: Double, q2: Double, q3: Double) {
        guard !sortedScores.isEmpty else { return (0, 0, 0) }

        let count = sortedScores.count
        let q1Index = count / 4
        let q2Index = count / 2
        let q3Index = (3 * count) / 4

        let q1 = q1Index < count ? sortedScores[q1Index] : sortedScores.last!
        let q2 = q2Index < count ? sortedScores[q2Index] : sortedScores.last!
        let q3 = q3Index < count ? sortedScores[q3Index] : sortedScores.last!

        return (q1, q2, q3)
    }

    internal func determinePerformanceTier(score: Double, quartiles: (q1: Double, q2: Double, q3: Double)) -> PerformanceTier {
        if score >= quartiles.q3 {
            return .elite
        } else if score >= quartiles.q2 {
            return .good
        } else if score >= quartiles.q1 {
            return .average
        } else {
            return .struggling
        }
    }

    /// Normalize text for more forgiving search matching
    private func normalizeSearchText(_ text: String) -> String {
        return text.lowercased()
            .replacingOccurrences(of: "'", with: "") // Remove apostrophes
            .replacingOccurrences(of: "'", with: "") // Remove curly apostrophes  
            .replacingOccurrences(of: ".", with: "") // Remove periods
            .replacingOccurrences(of: "-", with: "") // Remove dashes
            .replacingOccurrences(of: " ", with: "")  // Remove spaces for partial matching
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