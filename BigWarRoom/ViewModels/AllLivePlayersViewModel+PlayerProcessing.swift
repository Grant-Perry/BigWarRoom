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

        // 🔥 DEBUG: Log what type of matchup we're processing
        DebugPrint(mode: .liveUpdate2, "🔍 Processing matchup: \(matchup.league.league.name)")
        DebugPrint(mode: .liveUpdate2, "  - Has fantasyMatchup: \(matchup.fantasyMatchup != nil)")
        DebugPrint(mode: .liveUpdate2, "  - Has myTeamRanking: \(matchup.myTeamRanking != nil)")

        // 🔥 RESPECT USER SETTINGS: Skip eliminated playoff matchups if setting is off
        if matchup.isMyManagerEliminated {
            let showEliminatedPlayoffs = UserDefaults.standard.showEliminatedPlayoffLeagues
            if !showEliminatedPlayoffs {
                DebugPrint(mode: .liveUpdate2, "⏭️ SKIPPING: Eliminated playoff matchup (setting is OFF)")
                return []
            } else {
                DebugPrint(mode: .liveUpdate2, "✅ INCLUDING: Eliminated playoff matchup (setting is ON)")
            }
        }

        // Regular matchups - extract from MY team only
        if matchup.fantasyMatchup != nil {
            DebugPrint(mode: .liveUpdate2, "📊 REGULAR LEAGUE: \(matchup.league.league.name)")
            if let myTeam = matchup.myTeam {
                let myStarters = myTeam.roster.filter { $0.isStarter }
                DebugPrint(mode: .liveUpdate2, "  - Found \(myStarters.count) starters")
                for player in myStarters {
                    let calculatedScore = player.currentPoints ?? 0.0

                    // 💥 FIX: Use player.id + matchup.id for card-unique lookup
                    let existingPlayer = allPlayers.first { $0.player.id == player.id && $0.matchup.id == matchup.id }
                    let oldCurrent = existingPlayer?.currentScore ?? calculatedScore
                    let previousActivityTime = existingPlayer?.lastActivityTime
                    let priorDelta = existingPlayer?.accumulatedDelta ?? 0.0
                    let freshDelta = calculatedScore - oldCurrent
                    let newAccumulatedDelta = abs(freshDelta) > 0.01 ? (priorDelta + freshDelta) : priorDelta

                    let activityTime = (abs(freshDelta) > 0.01) ? Date() : previousActivityTime

                    // 🔥 MODEL-BASED: No lookups needed! Data already on player model ✅
                    // Injury status and jersey number are already populated during player creation
                    
                    var normPosition = player.position.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if normPosition == "DST" || normPosition == "D/ST" || normPosition == "DEFENSE" {
                        normPosition = "DEF"
                    }

                    // Patch the player copy for LivePlayerEntry:
                    let normalizedPlayer = FantasyPlayer(
                        id: player.id,
                        sleeperID: player.sleeperID,
                        espnID: player.espnID,
                        firstName: player.firstName,
                        lastName: player.lastName,
                        position: normPosition, // USE NORMALIZED POSITION!
                        team: player.team,
                        jerseyNumber: player.jerseyNumber,
                        currentPoints: player.currentPoints,
                        projectedPoints: player.projectedPoints,
                        gameStatus: player.gameStatus,
                        isStarter: player.isStarter,
                        lineupSlot: player.lineupSlot,
                        injuryStatus: player.injuryStatus
                    )

                    players.append(LivePlayerEntry(
                        id: "\(matchup.id)_my_\(player.id)",
                        player: normalizedPlayer, // <--- PATCHED
                        leagueName: matchup.league.league.name,
                        leagueSource: matchup.league.source.rawValue,
                        currentScore: calculatedScore,
                        projectedScore: player.projectedPoints ?? 0.0,
                        isStarter: player.isStarter,
                        percentageOfTop: 0.0, // Calculated later
                        matchup: matchup,
                        performanceTier: .average, // Calculated later
                        lastActivityTime: activityTime,
                        previousScore: oldCurrent,
                        accumulatedDelta: newAccumulatedDelta
                    ))
                }
            }
        }

        // Chopped leagues - extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            DebugPrint(mode: .liveUpdate2, "🏆 CHOPPED LEAGUE: \(matchup.league.league.name)")
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }
            DebugPrint(mode: .liveUpdate2, "  - Total roster: \(myTeamRanking.team.roster.count) players")
            DebugPrint(mode: .liveUpdate2, "  - Starters found: \(myTeamStarters.count) starters")
            
            // 🔥 FILTER OUT ELIMINATED TEAMS: Skip chopped leagues where you have no real players
            let validPlayers = myTeamStarters.filter { player in
                // Consider a player "valid" if they have a real name and non-empty, non-FLEX position
                let hasValidName = !player.fullName.trimmingCharacters(in: .whitespaces).isEmpty
                let positionTrimmed = player.position.trimmingCharacters(in: .whitespaces)
                let hasValidPosition = !positionTrimmed.isEmpty && positionTrimmed != "FLEX"
                return hasValidName || hasValidPosition
            }
            
            // If no valid players, you've been chopped - skip this league entirely
            if validPlayers.isEmpty {
                DebugPrint(mode: .liveUpdate2, "  ❌ SKIPPING: No valid players found - you've been eliminated from this league")
                return players // Skip processing this chopped league
            }
            
            DebugPrint(mode: .liveUpdate2, "  ✅ Found \(validPlayers.count) valid players (you're still alive!)")
            
            for player in validPlayers {
                DebugPrint(mode: .liveUpdate2, "    - PlayerID: '\(player.id)'")
                DebugPrint(mode: .liveUpdate2, "    - SleeperID: '\(player.sleeperID ?? "nil")'") 
                DebugPrint(mode: .liveUpdate2, "    - ESPNID: '\(player.espnID ?? "nil")'")

                let calculatedScore = player.currentPoints ?? 0.0

                // 💥 FIX: Use player.id + matchup.id for card-unique lookup
                let existingPlayer = allPlayers.first { $0.player.id == player.id && $0.matchup.id == matchup.id }
                let oldCurrent = existingPlayer?.currentScore ?? calculatedScore
                let previousActivityTime = existingPlayer?.lastActivityTime
                let priorDelta = existingPlayer?.accumulatedDelta ?? 0.0
                let freshDelta = calculatedScore - oldCurrent
                let newAccumulatedDelta = abs(freshDelta) > 0.01 ? (priorDelta + freshDelta) : priorDelta

                let activityTime = (abs(freshDelta) > 0.01) ? Date() : previousActivityTime

                // 🔥 MODEL-BASED: No lookups needed! Data already on player model ✅
                // Injury status and jersey number are already populated during player creation
                
                var normPosition = player.position.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if normPosition == "DST" || normPosition == "D/ST" || normPosition == "DEFENSE" {
                    normPosition = "DEF"
                }
                let normalizedPlayer = FantasyPlayer(
                    id: player.id,
                    sleeperID: player.sleeperID,
                    espnID: player.espnID,
                    firstName: player.firstName,
                    lastName: player.lastName,
                    position: normPosition,
                    team: player.team,
                    jerseyNumber: player.jerseyNumber,
                    currentPoints: player.currentPoints,
                    projectedPoints: player.projectedPoints,
                    gameStatus: player.gameStatus,
                    isStarter: player.isStarter,
                    lineupSlot: player.lineupSlot,
                    injuryStatus: player.injuryStatus
                )
                players.append(LivePlayerEntry(
                    id: "\(matchup.id)_chopped_\(player.id)",
                    player: normalizedPlayer,
                    leagueName: matchup.league.league.name,
                    leagueSource: matchup.league.source.rawValue,
                    currentScore: calculatedScore,
                    projectedScore: player.projectedPoints ?? 0.0,
                    isStarter: player.isStarter,
                    percentageOfTop: 0.0, // Calculated later
                    matchup: matchup,
                    performanceTier: .average, // Calculated later
                    lastActivityTime: activityTime,
                    previousScore: oldCurrent,
                    accumulatedDelta: newAccumulatedDelta
                ))
            }
        }
        
        DebugPrint(mode: .liveUpdate2, "✅ Extracted \(players.count) total players from \(matchup.league.league.name)")
        return players
    }

    // MARK: - Diagnostic Instrument: Extract All Players
    internal func extractAllPlayers() -> [LivePlayerEntry] {
        let matchupsCount = matchupsHubViewModel.myMatchups.count
        let matchupIDs = matchupsHubViewModel.myMatchups.map { $0.id }
        var allPlayers: [LivePlayerEntry] = []

        // 💣 INSTRUMENTATION: Only do when debug enabled, minimal perf hit.
        if AppConstants.debug {
            DebugPrint(mode: .liveUpdate2, "[extractAllPlayers] matchupsCount = \(matchupsCount), matchupIDs: \(matchupIDs)")
        }

        // Only run extraction if we believe all matchups are loaded!
        if matchupsCount < expectedLeagueCount() {
            if AppConstants.debug {
                DebugPrint(
                    mode: .liveUpdate2,
                    "[extractAllPlayers] 🚨 ABORTED - only \(matchupsCount) matchups (expecting \(expectedLeagueCount())). Skipping total/allPlayers extraction for this cycle."
                )
            }
            return [] // <- Don't extract partial, avoids total flip
        }

        for matchup in matchupsHubViewModel.myMatchups {
            let playersForMatchup = extractPlayersFromSingleMatchup(matchup)
            allPlayers.append(contentsOf: playersForMatchup)
        }

        if AppConstants.debug {
            let prefs = allPlayers
                .map { "\($0.playerName) (\($0.leagueName)): \($0.currentScoreString)" }
                .joined(separator: ", ")
            DebugPrint(mode: .liveUpdate2, "[extractAllPlayers] Extracted \(allPlayers.count) players: \(prefs)")
        }

        return allPlayers
    }

    // 🧠 Helper to define what "complete" means; adjust logic if needed
    internal func expectedLeagueCount() -> Int {
        // Could be static, or could read from a config/service; adjust to your use-case
        // This is just a placeholder, REPLACE with actual expected count logic!
        return matchupsHubViewModel.connectedLeaguesCount
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
                previousScore: entry.previousScore,
                accumulatedDelta: entry.accumulatedDelta // 🔥 Add this everywhere!
            )
        }
        
        // Apply current filters
        applyPositionFilter()
    }
    
    // MARK: - Surgical Data Update (Silent Background Updates)
    internal func updatePlayerDataSurgically() async {
        let allPlayerEntries = extractAllPlayers()
        guard !allPlayerEntries.isEmpty else { 
            return 
        }
        
        // 🔥 FIX: Update data silently but NOTIFY SwiftUI of changes
        await updatePlayerDataSilently(from: allPlayerEntries)
        lastUpdateTime = Date()
    }
    
    // 🔥 FIXED: Changed from private to internal so DataLoading extension can access it
    internal func updatePlayerDataSilently(from allPlayerEntries: [LivePlayerEntry]) async {
        if AppConstants.debug {
            DebugPrint(mode: .liveUpdate2, "[updatePlayerDataSilently] Called with \(allPlayerEntries.count) players")
            let list = allPlayerEntries
                .map { "\($0.playerName) (\($0.leagueName)): \($0.currentScoreString)" }
                .joined(separator: ", ")
            DebugPrint(mode: .liveUpdate2, "[updatePlayerDataSilently] Player list: \(list)")
        }

        // You can optionally block updating if your extractor returned an empty set due to the gating above:
        guard !allPlayerEntries.isEmpty else {
            if AppConstants.debug {
                DebugPrint(mode: .liveUpdate2, "[updatePlayerDataSilently] SKIPPED: No players (partial or incomplete extraction)")
            }
            return
        }

        DebugPrint(mode: .liveUpdate2, "🔥 SILENT UPDATE START: Processing \(allPlayerEntries.count) player entries")
        
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // Debug: Show score distribution
        let topScores = Array(scores.prefix(5))
        DebugPrint(mode: .liveUpdate2, "🔥 SILENT UPDATE SCORES: Top 5 scores = \(topScores)")
        
        // Update statistics silently
        let newTopScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        let newScoreRange = newTopScore - bottomScore
        
        // 🔥 FIX: Only update if values actually changed to minimize UI churn
        if abs(topScore - newTopScore) > 0.01 {
            DebugPrint(mode: .liveUpdate2, "🔥 SILENT UPDATE: Updating topScore from \(topScore) to \(newTopScore)")
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
                previousScore: entry.previousScore,
                accumulatedDelta: entry.accumulatedDelta // 🔥 Add this everywhere!
            )
        }
        
        // Debug: Show before/after player counts
        DebugPrint(mode: .liveUpdates, "🔄 SILENT UPDATE: Updating allPlayers from \(allPlayers.count) to \(updatedPlayers.count) players")
        
        // 🔥 CRITICAL FIX: Update allPlayers with fresh data
        let oldPlayerCount = allPlayers.count
        allPlayers = updatedPlayers
        DebugPrint(mode: .liveUpdates, "✏️ allPlayers updated (was \(oldPlayerCount), now \(allPlayers.count))")
        
        // 🔥 CRITICAL FIX: Use the regular filter method instead of silent to trigger UI updates
        let oldFilteredCount = filteredPlayers.count
        applyPositionFilter()
        DebugPrint(mode: .liveUpdates, "🔍 filteredPlayers updated (was \(oldFilteredCount), now \(filteredPlayers.count))")
        
        // Auto-recovery: if data is loaded and filters produced no results, relax filters
        if isDataLoaded && !allPlayers.isEmpty && filteredPlayers.isEmpty {
            DebugPrint(mode: .liveUpdates, "🛟 AUTO-RECOVERY: No results with current filters. Falling back to All / No Active Only.")
            showActiveOnly = false
            selectedPosition = .all
            applyPositionFilter()
        }

        DebugPrint(mode: .liveUpdates, "✅ SILENT UPDATE COMPLETE")
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
                        lineupSlot: nil,
                        injuryStatus: sleeperPlayer.injuryStatus  // 🔥 MODEL-BASED: From SleeperPlayer
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
                        lastActivityTime: nil,
                        previousScore: nil,
                        accumulatedDelta: 0.0 // Zero for searched cards
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
                    // 🔥 MODEL-BASED CP: Use isInActiveGame for lightweight live detection
                    return player.player.isInActiveGame
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
                previousScore: entry.previousScore,
                accumulatedDelta: entry.accumulatedDelta // 🔥 Add this everywhere!
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