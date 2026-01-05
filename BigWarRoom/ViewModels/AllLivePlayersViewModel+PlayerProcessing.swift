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

                    // 🔥 FIX: Set activity time properly for Recent Activity sort
                    let activityTime: Date?
                    if abs(freshDelta) > 0.01 {
                        // Score changed - mark as active NOW
                        activityTime = Date()
                    } else if let prevTime = previousActivityTime {
                        // No change - keep previous time
                        activityTime = prevTime
                    } else if calculatedScore > 0 {
                        // 🔥 NEW: First time seeing this player and they have points - use now
                        // This ensures players with scores show up in Recent Activity sort
                        activityTime = Date()
                    } else {
                        // No score yet
                        activityTime = nil
                    }

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

                // 🔥 FIX: Set activity time properly for Recent Activity sort
                let activityTime: Date?
                if abs(freshDelta) > 0.01 {
                    // Score changed - mark as active NOW
                    activityTime = Date()
                } else if let prevTime = previousActivityTime {
                    // No change - keep previous time
                    activityTime = prevTime
                } else if calculatedScore > 0 {
                    // 🔥 NEW: First time seeing this player and they have points - use now
                    // This ensures players with scores show up in Recent Activity sort
                    activityTime = Date()
                } else {
                    // No score yet
                    activityTime = nil
                }

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

    // MARK: - Build Player Data with Statistics (🔥 DRY: Uses PlayerStatisticsService)
    internal func buildPlayerData(from allPlayerEntries: [LivePlayerEntry]) async {
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        
        // 🚨 GAME ALERTS: Process game alerts for highest scoring play
        // 🚫 DISABLED 2024: Game alerts functionality temporarily disabled due to performance concerns
        // TO RE-ENABLE: Uncomment the line below and ensure GameAlertsManager is active
        // processGameAlerts(from: allPlayerEntries)
        
        // 🔥 DRY: Use PlayerStatisticsService for all calculations
        topScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        scoreRange = topScore - bottomScore
        
        // Calculate median using service
        medianScore = PlayerStatisticsService.shared.calculateMedian(from: scores)
        
        // Determine if adaptive scaling should be used
        useAdaptiveScaling = PlayerStatisticsService.shared.shouldUseAdaptiveScaling(
            topScore: topScore,
            medianScore: medianScore
        )
        
        let quartiles = PlayerStatisticsService.shared.calculateQuartiles(from: scores)
        
        // Update players with proper percentages and tiers
        allPlayers = allPlayerEntries.map { entry in
            let percentage = PlayerStatisticsService.shared.calculateScaledPercentage(
                score: entry.currentScore,
                topScore: topScore,
                useAdaptiveScaling: useAdaptiveScaling
            )
            let tier = PlayerStatisticsService.shared.determinePerformanceTier(
                score: entry.currentScore,
                quartiles: quartiles
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
        
        // 🔥 DRY: Use PlayerStatisticsService for calculations
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
        
        let newMedianScore = PlayerStatisticsService.shared.calculateMedian(from: scores)
        if abs(medianScore - newMedianScore) > 0.01 {
            medianScore = newMedianScore
        }
        
        let newAdaptiveScaling = PlayerStatisticsService.shared.shouldUseAdaptiveScaling(
            topScore: topScore,
            medianScore: medianScore
        )
        if useAdaptiveScaling != newAdaptiveScaling {
            useAdaptiveScaling = newAdaptiveScaling
        }
        
        let quartiles = PlayerStatisticsService.shared.calculateQuartiles(from: scores)
        
        // Update players silently with fresh score data
        let updatedPlayers = allPlayerEntries.map { entry in
            let percentage = PlayerStatisticsService.shared.calculateScaledPercentage(
                score: entry.currentScore,
                topScore: topScore,
                useAdaptiveScaling: useAdaptiveScaling
            )
            let tier = PlayerStatisticsService.shared.determinePerformanceTier(
                score: entry.currentScore,
                quartiles: quartiles
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
    
    // 🔥 NEW: Silent filter application (called during background updates) - 🔥 DRY: Uses Services
    private func applySilentPositionFilter() {
        guard !allPlayers.isEmpty else {
            filteredPlayers = []
            return
        }

        var players = allPlayers
        
        // If searching, handle two different flows (SAME AS MAIN FILTER)
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

        // 🔥 DRY: Use PlayerSortingService for silent sorting
        filteredPlayers = PlayerSortingService.shared.sortPlayers(
            updatedPlayers,
            by: sortingMethod,
            highToLow: sortHighToLow
        )
    }
    
    // MARK: - REMOVED: sortPlayersSilently and all helper methods moved to PlayerSortingService
    // MARK: - REMOVED: All statistical calculation methods moved to PlayerStatisticsService
    // MARK: - REMOVED: Silent sorting/filtering moved to use services
}