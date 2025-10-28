//
//  AllLivePlayersViewModel+PlayerProcessing.swift
//  BigWarRoom
//
//  🔥 FOCUSED: Player extraction, score calculations, and data building
//

import Foundation
import Combine

extension AllLivePlayersViewModel {
    // MARK: - Player Extraction from Single Matchup
    internal func extractPlayersFromSingleMatchup(_ matchup: UnifiedMatchup) -> [LivePlayerEntry] {
        var players: [LivePlayerEntry] = []
        
        print("🔥 EXTRACT MATCHUP: \(matchup.league.league.name) (\(matchup.league.source.rawValue))")

        // Regular matchups - extract from MY team only
        if let fantasyMatchup = matchup.fantasyMatchup {
            print("🔥 EXTRACT: Regular matchup found")
            if let myTeam = matchup.myTeam {
                let myStarters = myTeam.roster.filter { $0.isStarter }
                print("🔥 EXTRACT: Found \(myStarters.count) starters in myTeam")
                for player in myStarters {
                    let calculatedScore = getCalculatedPlayerScore(for: player, in: matchup)
                    
                    // 🔥 NEW: Track activity for recent sort
                    let existingPlayer = allPlayers.first { $0.player.id == player.id }
                    let previousScore = existingPlayer?.currentScore
                    let activityTime = (previousScore != nil && abs(calculatedScore - (previousScore ?? 0.0)) > 0.01) ? Date() : existingPlayer?.lastActivityTime
                    
                    print("🔥 EXTRACT: Adding \(player.fullName) with score \(calculatedScore)")
                    
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
                        performanceTier: .average, // Calculated later
                        lastActivityTime: activityTime,
                        previousScore: previousScore
                    ))
                }
            } else {
                print("🔥 EXTRACT: No myTeam found in regular matchup")
            }
        }

        // Chopped leagues - extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            print("🔥 EXTRACT: Chopped league found")
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }
            print("🔥 EXTRACT: Found \(myTeamStarters.count) starters in chopped team")

            for player in myTeamStarters {
                let calculatedScore = getCalculatedPlayerScore(for: player, in: matchup)
                
                // 🔥 NEW: Track activity for recent sort
                let existingPlayer = allPlayers.first { $0.player.id == player.id }
                let previousScore = existingPlayer?.currentScore
                let activityTime = (previousScore != nil && abs(calculatedScore - (previousScore ?? 0.0)) > 0.01) ? Date() : existingPlayer?.lastActivityTime
                
                print("🔥 EXTRACT: Adding chopped \(player.fullName) with score \(calculatedScore)")
                
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
                    performanceTier: .average, // Calculated later
                    lastActivityTime: activityTime,
                    previousScore: previousScore
                ))
            }
        }
        
        print("🔥 EXTRACT RESULT: Extracted \(players.count) players from matchup")
        return players
    }
    
    // MARK: - Score Calculation
    private func getCalculatedPlayerScore(for player: FantasyPlayer, in matchup: UnifiedMatchup) -> Double {
        // 🔥 CRITICAL FIX: Use SharedStatsService directly for live stats instead of cached providers
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = AppConstants.currentSeasonYear
        
        print("🔥 SCORE CALC: \(player.fullName) - Week: \(currentWeek), Year: \(currentYear)")
        
        // 🔥 NEW APPROACH: Get fresh stats directly from SharedStatsService
        if let sleeperID = player.sleeperID {
            // Get cached stats from SharedStatsService (which loads from live API)
            if let playerStats = SharedStatsService.shared.getCachedPlayerStats(
                playerID: sleeperID, 
                week: currentWeek, 
                year: currentYear
            ) {
                print("🔥 SCORE CALC: Found fresh stats from SharedStatsService for \(player.fullName)")
                
                // Calculate fantasy points using proper scoring settings
                let calculatedScore = calculateFantasyPoints(from: playerStats, for: matchup)
                print("🔥 SCORE CALC: \(player.fullName) calculated score: \(calculatedScore) pts")
                return calculatedScore
                
            } else {
                print("🔥 SCORE CALC: No stats found in SharedStatsService for \(player.fullName) (ID: \(sleeperID))")
                
                // Try to trigger a fresh stats load if needed
                if !SharedStatsService.shared.hasCache(week: currentWeek, year: currentYear) {
                    print("🔥 SCORE CALC: SharedStatsService has no cache for week \(currentWeek) - triggering load")
                    Task {
                        do {
                            let _ = try await SharedStatsService.shared.loadWeekStats(week: currentWeek, year: currentYear)
                            print("🔥 SCORE CALC: Successfully loaded fresh stats for week \(currentWeek)")
                        } catch {
                            print("🔥 SCORE CALC ERROR: Failed to load fresh stats: \(error)")
                        }
                    }
                }
            }
        } else {
            print("🔥 SCORE CALC: No sleeperID for \(player.fullName)")
        }
        
        // 🔥 FALLBACK 1: Try the old cached provider method for ESPN leagues
        if let cachedProvider = matchupsHubViewModel.getCachedProvider(
            for: matchup.league, 
            week: currentWeek, 
            year: currentYear
        ) {
            print("🔥 SCORE CALC: Found cached provider for \(matchup.league.source.rawValue)")
            
            // For ESPN leagues, get fresh score from the cached matchup data
            if matchup.league.source == .espn {
                print("🔥 SCORE CALC: ESPN league - checking myTeam roster")
                if let myTeam = matchup.myTeam,
                   let freshPlayer = myTeam.roster.first(where: { $0.id == player.id }) {
                    let freshScore = freshPlayer.currentPoints ?? 0.0
                    print("🔥 SCORE CALC: \(player.fullName) ESPN fresh score: \(freshScore) pts")
                    return freshScore
                }
            }
            
            // For Sleeper leagues, use calculated score from provider
            if matchup.league.source == .sleeper && cachedProvider.hasPlayerScores() {
                let calculatedScore = cachedProvider.getPlayerScore(playerId: player.id)
                print("🔥 SCORE CALC: \(player.fullName) Sleeper provider score: \(calculatedScore) pts")
                return calculatedScore
            }
        }
        
        // 🔥 FALLBACK 2: Use the player's cached score
        let fallbackScore = player.currentPoints ?? 0.0
        print("🔥 SCORE CALC: \(player.fullName) using fallback score: \(fallbackScore) pts")
        return fallbackScore
    }
    
    // 🔥 NEW: Calculate fantasy points from raw stats using league scoring settings
    private func calculateFantasyPoints(from stats: [String: Double], for matchup: UnifiedMatchup) -> Double {
        // Get scoring settings based on league type
        let scoringSettings = getScoringSettings(for: matchup)
        
        var totalPoints = 0.0
        
        // Apply scoring rules to stats
        for (statKey, statValue) in stats {
            if let pointsPerStat = scoringSettings[statKey] {
                let points = statValue * pointsPerStat
                totalPoints += points
            }
        }
        
        return totalPoints
    }
    
    // 🔥 NEW: Get scoring settings for a league
    private func getScoringSettings(for matchup: UnifiedMatchup) -> [String: Double] {
        // For now, use standard PPR scoring
        // TODO: Get league-specific scoring settings from the league configuration
        return getStandardPPRScoring()
    }
    
    // 🔥 NEW: Standard PPR scoring settings
    private func getStandardPPRScoring() -> [String: Double] {
        return [
            // Passing
            "pass_yd": 0.04,      // 1 point per 25 passing yards
            "pass_td": 4.0,       // 4 points per passing TD
            "pass_int": -1.0,     // -1 point per interception
            "pass_2pt": 2.0,      // 2 points per 2-point conversion
            
            // Rushing
            "rush_yd": 0.1,       // 1 point per 10 rushing yards
            "rush_td": 6.0,       // 6 points per rushing TD
            "rush_2pt": 2.0,      // 2 points per 2-point conversion
            
            // Receiving
            "rec": 1.0,           // 1 point per reception (PPR)
            "rec_yd": 0.1,        // 1 point per 10 receiving yards
            "rec_td": 6.0,        // 6 points per receiving TD
            "rec_2pt": 2.0,       // 2 points per 2-point conversion
            
            // Kicking
            "fgm": 3.0,           // 3 points per field goal made
            "fgm_0_19": 3.0,      // 3 points for 0-19 yard FG
            "fgm_20_29": 3.0,     // 3 points for 20-29 yard FG
            "fgm_30_39": 3.0,     // 3 points for 30-39 yard FG
            "fgm_40_49": 4.0,     // 4 points for 40-49 yard FG
            "fgm_50p": 5.0,       // 5 points for 50+ yard FG
            "xpm": 1.0,           // 1 point per extra point made
            
            // Defense/Special Teams
            "def_td": 6.0,        // 6 points per defensive TD
            "def_int": 2.0,       // 2 points per interception
            "def_fr": 2.0,        // 2 points per fumble recovery
            "def_sack": 1.0,      // 1 point per sack
            "def_safe": 2.0,      // 2 points per safety
            "def_pa": 0.0,        // Points allowed (varies by league)
            "def_yds_allowed": 0.0, // Yards allowed (varies by league)
            
            // Fumbles (negative points)
            "fum_lost": -1.0,     // -1 point per fumble lost
            
            // Common alternative stat names
            "pts_ppr": 1.0,       // Direct PPR points (if provided)
            "pts_std": 1.0,       // Direct standard points (if provided)
            "pts_half_ppr": 1.0   // Direct half-PPR points (if provided)
        ]
    }
    
    // MARK: - Build Player Data with Statistics
    internal func buildPlayerData(from allPlayerEntries: [LivePlayerEntry]) async {
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // 🚨 GAME ALERTS: Process game alerts for highest scoring play
        // 🚫 DISABLED 2024: Game alerts functionality temporarily disabled due to performance concerns
        // TO RE-ENABLE: Uncomment the line below and ensure GameAlertsManager is active
        // processGameAlerts(from: allPlayerEntries)
        
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
                performanceTier: tier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.previousScore
            )
        }
        
        // Apply current filters
        applyPositionFilter()
    }
    
    // MARK: - Surgical Data Update (Silent Background Updates)
    internal func updatePlayerDataSurgically() async {
//        print("🔄 SURGICAL UPDATE DEBUG: Starting surgical update")
        let allPlayerEntries = extractAllPlayers()
        guard !allPlayerEntries.isEmpty else { 
//            print("🔄 SURGICAL UPDATE DEBUG: No player entries found")
            return 
        }
        
//        print("🔄 SURGICAL UPDATE DEBUG: Extracted \(allPlayerEntries.count) player entries")
        
        // Log a few sample scores for comparison
        let samplePlayers = Array(allPlayerEntries.prefix(3))
        for player in samplePlayers {
//            print("🔄 SURGICAL UPDATE DEBUG: Sample - \(player.playerName): \(player.currentScore) pts")
        }
        
        // 🔥 FIX: Update data silently but NOTIFY SwiftUI of changes
        await updatePlayerDataSilently(from: allPlayerEntries)
        lastUpdateTime = Date()
        
//        print("🔄 SURGICAL UPDATE DEBUG: Updated lastUpdateTime to \(lastUpdateTime)")
        
        // 🔥 REMOVED: Don't send objectWillChange during surgical updates - causes excessive rebuilds
        // Only the @Published properties changing should trigger updates
        // objectWillChange.send()
//        print("🔄 SURGICAL UPDATE DEBUG: Sent objectWillChange notification")
    }
    
    // 🔥 FIXED: Changed from private to internal so DataLoading extension can access it
    internal func updatePlayerDataSilently(from allPlayerEntries: [LivePlayerEntry]) async {
        print("🔥 SILENT UPDATE START: Processing \(allPlayerEntries.count) player entries")
        
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // Debug: Show score distribution
        let topScores = Array(scores.prefix(5))
        print("🔥 SILENT UPDATE SCORES: Top 5 scores = \(topScores)")
        
        // Update statistics silently
        let newTopScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        let newScoreRange = newTopScore - bottomScore
        
        // 🔥 FIX: Only update if values actually changed to minimize UI churn
        if abs(topScore - newTopScore) > 0.01 {
            print("🔥 SILENT UPDATE: Updating topScore from \(topScore) to \(newTopScore)")
            topScore = newTopScore
        }
        if abs(scoreRange - newScoreRange) > 0.01 {
            scoreRange = newScoreRange
        }
        
        if !scores.isEmpty {
            let mid = scores.count / 2
            let newMedianScore = scores.count % 2 == 0 ?
                (scores[mid - 1] + scores[mid]) / 2 :
                scores[mid]
            
            if abs(medianScore - newMedianScore) > 0.01 {
                medianScore = newMedianScore
            }
        }
        
        let newAdaptiveScaling = topScore > (medianScore * 3)
        if useAdaptiveScaling != newAdaptiveScaling {
            useAdaptiveScaling = newAdaptiveScaling
        }
        
        let quartiles = calculateQuartiles(from: scores)
        
        // Update players silently with fresh score data
        let updatedPlayers = allPlayerEntries.map { entry in
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
                performanceTier: tier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.previousScore
            )
        }
        
        // Debug: Show before/after player counts
        print("🔥 SILENT UPDATE: Updating allPlayers from \(allPlayers.count) to \(updatedPlayers.count) players")
        
        // 🔥 CRITICAL FIX: Update allPlayers with fresh data
        let oldPlayerCount = allPlayers.count
        allPlayers = updatedPlayers
        print("🔥 SILENT UPDATE: allPlayers updated (was \(oldPlayerCount), now \(allPlayers.count))")
        
        // 🔥 CRITICAL FIX: Use the regular filter method instead of silent to trigger UI updates
        let oldFilteredCount = filteredPlayers.count
        applyPositionFilter()
        print("🔥 SILENT UPDATE: filteredPlayers updated (was \(oldFilteredCount), now \(filteredPlayers.count))")
        
        print("🔥 SILENT UPDATE COMPLETE")
    }
    
    // 🔥 NEW: Silent filter application (called during background updates)
    private func applySilentPositionFilter() {
        guard !allPlayers.isEmpty else {
            filteredPlayers = []
            return
        }

        var players = allPlayers
        
        // If searching, handle two different flows (SAME AS MAIN FILTER)
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
                        performanceTier: .average,
                        lastActivityTime: nil, // 🔥 NEW: No activity for search results
                        previousScore: nil // 🔥 NEW: No previous score for search results
                    )
                }
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
                performanceTier: tier,
                lastActivityTime: entry.lastActivityTime,
                previousScore: entry.previousScore
            )
        }

        // Apply sorting silently
        filteredPlayers = sortPlayersSilently(updatedPlayers)
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
                
        case .recent:
            // Sort by most recent activity first, then by score as secondary sort
            sortedPlayers = players.sorted { player1, player2 in
                let time1 = player1.lastActivityTime ?? Date.distantPast
                let time2 = player2.lastActivityTime ?? Date.distantPast
                
                if time1 != time2 {
                    return time1 > time2 // Most recent first
                }
                
                // Secondary sort by score
                return player1.currentScore > player2.currentScore
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