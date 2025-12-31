//
//  MatchupsHubViewModel+ChoppedLeagues.swift
//  BigWarRoom
//
//  Chopped league specific logic for MatchupsHubViewModel
//

import Foundation

// MARK: - Chopped League Operations
extension MatchupsHubViewModel {
    
    /// Handle chopped league processing
    internal func handleChoppedLeague(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        // Create chopped summary using proper Sleeper data
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: getCurrentWeek()) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                DebugPrint(
                    mode: .matchupLoading,
                    limit: 20,
                    "🪓 CHOPPED STATUS: \(league.league.name) rosterID=\(String(describing: myTeamRanking.team.rosterID)) rank=\(myTeamRanking.rank) status=\(myTeamRanking.eliminationStatus.rawValue) isEliminated=\(myTeamRanking.isEliminated) showElimToggle=\(UserDefaults.standard.showEliminatedChoppedLeagues)"
                )

                // If the user disabled eliminated chopped leagues, skip loading them entirely.
                if !UserDefaults.standard.showEliminatedChoppedLeagues, myTeamRanking.isEliminated {
                    DebugPrint(mode: .matchupLoading, limit: 20, "🪓 FILTER OUT: \(league.league.name) (chopped eliminated, toggle OFF)")
                    await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                    return nil
                }
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped",
                    league: league,
                    fantasyMatchup: nil,
                    choppedSummary: choppedSummary,
                    lastUpdated: Date(),
                    myTeamRanking: myTeamRanking,
                    myIdentifiedTeamID: myTeamID,
                    authenticatedUsername: sleeperCredentials.currentUsername,
                    allLeagueMatchups: nil,
                    gameDataService: NFLGameDataService.shared
                )
                
                await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                return unifiedMatchup
            }
        }
        
        await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
        return nil
    }
    
    /// Create Chopped league summary for Sleeper leagues with no matchups
    internal func createSleeperChoppedSummary(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> ChoppedWeekSummary? {
        do {
            // Step 1: Fetch REAL matchup data for this week to get actual starter scores
            let matchupData = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: league.league.leagueID, 
                week: week
            )
            
            // Step 2-3: Fetch rosters and users data
            let (rosters, users) = try await fetchRostersAndUsers(for: league.league.leagueID)
            
            // Step 4: Create team mapping and fantasy teams
            let (rosterToOwnerMap, userMap, avatarMap) = createTeamMappings(rosters: rosters, users: users)
            let (activeTeams, eliminatedTeams) = createChoppedFantasyTeams(
                matchupData: matchupData,
                rosters: rosters,
                rosterToOwnerMap: rosterToOwnerMap,
                userMap: userMap,
                avatarMap: avatarMap,
                league: league
            )
            
            // Step 5: Process and rank teams
            return await processChoppedTeamRankings(
                teams: activeTeams,
                eliminatedTeams: eliminatedTeams,
                league: league,
                week: week
            )
            
        } catch {
            return nil
        }
    }
    
    /// Fetch rosters and users data in parallel
    private func fetchRostersAndUsers(for leagueID: String) async throws -> ([SleeperRoster], [SleeperLeagueUser]) {
        async let rosters = SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
        async let users = SleeperAPIClient.shared.fetchUsers(leagueID: leagueID)
        
        let rostersResult = try await rosters
        let usersResult = try await users
        
        return (rostersResult, usersResult)
    }
    
    /// Create team mapping dictionaries
    private func createTeamMappings(rosters: [SleeperRoster], users: [SleeperLeagueUser]) -> ([Int: String], [String: String], [String: URL]) {
        let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.userID, $0.displayName ?? "Team \($0.userID)") })
        
        let avatarMap = Dictionary(uniqueKeysWithValues: users.compactMap { user -> (String, URL)? in
            guard let avatar = user.avatar,
                  let url = URL(string: "https://sleepercdn.com/avatars/\(avatar)") else { return nil }
            return (user.userID, url)
        })
        
        let rosterToOwnerMap = Dictionary(uniqueKeysWithValues: rosters.compactMap { roster -> (Int, String)? in
            guard let ownerID = roster.ownerID else { return nil }
            return (roster.rosterID, ownerID)
        })
        
        return (rosterToOwnerMap, userMap, avatarMap)
    }
    
    /// Create fantasy teams from matchup data
    private func createChoppedFantasyTeams(
        matchupData: [SleeperMatchupResponse],
        rosters: [SleeperRoster],
        rosterToOwnerMap: [Int: String],
        userMap: [String: String],
        avatarMap: [String: URL],
        league: UnifiedLeagueManager.LeagueWrapper
    ) -> (activeTeams: [FantasyTeam], eliminatedTeams: [FantasyTeam]) {
        var activeTeams: [FantasyTeam] = []
        var eliminatedTeams: [FantasyTeam] = [] // Track eliminated teams for graveyard
        let matchupByRosterID = Dictionary(uniqueKeysWithValues: matchupData.map { ($0.rosterID, $0) })

        // 🔥 KEY FIX: Build teams from /rosters so eliminated guillotine teams (often players == [])
        // still get classified correctly even if they don't show in /matchups.
        for roster in rosters {
            let rosterID = roster.rosterID
            let matchup = matchupByRosterID[rosterID]

            let ownerID = roster.ownerID ?? rosterToOwnerMap[rosterID] ?? ""
            let resolvedTeamName = userMap[ownerID] ?? "Team \(rosterID)"
            let avatarURL = avatarMap[ownerID]

            // Guillotine elimination signal (most reliable): roster has no players and/or no owner.
            let hasAnyPlayers = (roster.playerIDs?.isEmpty == false)
            let hasOwner = !ownerID.isEmpty

            // Week-specific activity signal: only active teams have starters for this week.
            let hasAnyStarters = (matchup?.starters?.isEmpty == false)

            // Week score (0 if eliminated / no matchup entry)
            let realTeamScore = matchup?.points ?? 0.0
            let projectedScore = matchup?.projectedPoints ?? (realTeamScore * 1.05)

            let starterRoster: [FantasyPlayer] = {
                guard let matchup else { return [] }
                return createStarterRoster(from: matchup, realTeamScore: realTeamScore, leagueID: league.league.leagueID)
            }()

            let fantasyTeam = FantasyTeam(
                id: String(rosterID),
                name: resolvedTeamName,
                ownerName: resolvedTeamName,
                record: nil,
                avatar: avatarURL?.absoluteString,
                currentScore: realTeamScore,
                projectedScore: projectedScore,
                roster: starterRoster,
                rosterID: rosterID,
                faabTotal: nil,
                faabUsed: nil
            )

            // Active = has owner + has players + has a playable lineup for the selected week.
            if hasOwner && hasAnyPlayers && hasAnyStarters && !starterRoster.isEmpty {
                activeTeams.append(fantasyTeam)
            } else {
                eliminatedTeams.append(fantasyTeam)
            }
        }

        return (activeTeams, eliminatedTeams)
    }
    
    /// Create starter roster from Sleeper matchup data for All Live Players integration
    private func createStarterRoster(from matchup: SleeperMatchupResponse, realTeamScore: Double, leagueID: String) -> [FantasyPlayer] {
        guard let starters = matchup.starters, !starters.isEmpty else {
            return []
        }
        
        // Create FantasyPlayer objects from starter player IDs
        let starterPlayers = starters.compactMap { playerID -> FantasyPlayer? in
            // Get player info from PlayerDirectoryStore
            let playerInfo = PlayerDirectoryStore.shared.player(for: playerID)
            
            // Calculate REAL individual player points using actual stats
            let actualPlayerScore = calculateRealPlayerScore(playerID: playerID, leagueID: leagueID)
            
            let player = FantasyPlayer(
                id: playerID,
                sleeperID: playerID,
                espnID: playerInfo?.espnID,
                firstName: playerInfo?.firstName,
                lastName: playerInfo?.lastName,
                position: playerInfo?.position ?? "FLEX",
                team: playerInfo?.team,
                jerseyNumber: playerInfo?.number?.description,
                currentPoints: actualPlayerScore, // REAL score, not fake average!
                projectedPoints: actualPlayerScore * 1.05,
                gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: playerInfo?.team),
                isStarter: true, // Mark as starter so they show in All Live Players!
                lineupSlot: playerInfo?.position,
                injuryStatus: playerInfo?.injuryStatus  // 🔥 MODEL-BASED: From player data
            )
            
            return player
        }
        
        return starterPlayers
    }
    
    /// Calculate real individual player score using Sleeper stats and league scoring settings
    private func calculateRealPlayerScore(playerID: String, leagueID: String) -> Double {
        // 🔥 FIX: Use SharedStatsService instead of AllLivePlayersViewModel's cache
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = SeasonYearManager.shared.selectedYear
        
        // Get player stats from SharedStatsService (same source as LeagueMatchupProvider)
        guard let playerStats = SharedStatsService.shared.getCachedPlayerStats(
            playerID: playerID,
            week: currentWeek,
            year: currentYear
        ), !playerStats.isEmpty else {
            return 0.0
        }
        
        // Get league scoring settings (use default if not available)
        let scoringSettings = getLeagueScoringSettings(leagueID: leagueID) ?? getDefaultScoringSettings()
        
        // Calculate score using Sleeper scoring logic
        var totalScore = 0.0
        for (statKey, statValue) in playerStats {
            if let scoring = scoringSettings[statKey] as? Double {
                let points = statValue * scoring
                totalScore += points
            }
        }
        
        return totalScore
    }
    
    /// Get league-specific scoring settings
    private func getLeagueScoringSettings(leagueID: String) -> [String: Any]? {
        // This would ideally fetch from cache or API
        // For now, return nil to fall back to defaults
        return nil
    }
    
    /// Get default Sleeper scoring settings
    private func getDefaultScoringSettings() -> [String: Double] {
        return [
            // Passing
            "pass_yd": 0.04,      // 1 point per 25 passing yards
            "pass_td": 4.0,       // 4 points per passing TD
            "pass_int": -1.0,     // -1 point per interception
            
            // Rushing
            "rush_yd": 0.1,       // 1 point per 10 rushing yards
            "rush_td": 6.0,       // 6 points per rushing TD
            
            // Receiving
            "rec": 1.0,           // 1 point per reception (PPR)
            "rec_yd": 0.1,        // 1 point per 10 receiving yards
            "rec_td": 6.0,        // 6 points per receiving TD
            
            // Kicking
            "fgm": 3.0,           // 3 points per field goal made
            "xpm": 1.0,           // 1 point per extra point made
            
            // Defense
            "def_td": 6.0,        // 6 points per defensive TD
            "def_int": 2.0,       // 2 points per interception
            "def_fr": 2.0,        // 2 points per fumble recovery
            "def_sack": 1.0,      // 1 point per sack
            "def_safe": 2.0,      // 2 points per safety
            
            // Fumbles
            "fum_lost": -1.0,     // -1 point per fumble lost
        ]
    }
    
    /// Process team rankings and create final summary
    private func processChoppedTeamRankings(
        teams: [FantasyTeam],
        eliminatedTeams: [FantasyTeam],
        league: UnifiedLeagueManager.LeagueWrapper,
        week: Int
    ) async -> ChoppedWeekSummary {
        // Sort teams by REAL scores (highest to lowest) - ONLY ACTIVE TEAMS
        let sortedTeams = teams.sorted { team1, team2 in
            let score1 = team1.currentScore ?? 0.0
            let score2 = team2.currentScore ?? 0.0
            return score1 > score2
        }
        
        // Dynamic elimination count based on league size - ONLY ACTIVE TEAMS
        let totalActiveTeams = sortedTeams.count
        let eliminationCount = totalActiveTeams >= 18 ? 2 : 1
        
        // Create team rankings with proper elimination zones - ONLY ACTIVE TEAMS
        let teamRankings = createTeamRankings(sortedTeams: sortedTeams, eliminationCount: eliminationCount, totalTeams: totalActiveTeams, week: week)
        
        // Calculate summary stats
        let (avgScore, highScore, lowScore) = calculateSummaryStats(teamRankings: teamRankings)
        
        // Get "death row" teams for this week (bottom N teams FROM ACTIVE TEAMS)
        let eliminatedThisWeek = Array(teamRankings.suffix(eliminationCount))
        
        // CREATE GRAVEYARD: Convert already-eliminated teams (no starters) to EliminationEvents
        let graveyardEvents = eliminatedTeams.enumerated().map { index, team in
            
            let eliminatedRanking = FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: team.currentScore ?? 0.0,
                rank: totalActiveTeams + index + 1, // Rank them after active teams
                eliminationStatus: .eliminated,
                isEliminated: true,
                survivalProbability: 0.0,
                pointsFromSafety: 0.0,
                weeksAlive: week - 1 // Assume eliminated last week
            )
            
            return EliminationEvent(
                id: "eliminated_\(team.id)",
                week: week - 1, // Assume eliminated last week
                eliminatedTeam: eliminatedRanking,
                eliminationScore: team.currentScore ?? 0.0,
                margin: 0.0,
                dramaMeter: 0.5,
                lastWords: "Left with no players to field...",
                timestamp: Date()
            )
        }
        
        logChoppedSummary(totalTeams: totalActiveTeams, eliminationCount: eliminationCount, eliminatedTeams: eliminatedThisWeek, highScore: highScore, lowScore: lowScore, avgScore: avgScore, leagueName: league.league.name)
        
        return ChoppedWeekSummary(
            id: "chopped_real_\(league.league.leagueID)_\(week)",
            week: week,
            rankings: teamRankings, // Only active teams
            eliminatedTeam: eliminatedThisWeek.first, // Primary "death row" team for UI
            cutoffScore: lowScore,
            isComplete: true, // Real data means it's complete
            totalSurvivors: teamRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: graveyardEvents // NOW INCLUDES TEAMS WITH NO PLAYERS
        )
    }
    
    /// Create team rankings with elimination status
    private func createTeamRankings(sortedTeams: [FantasyTeam], eliminationCount: Int, totalTeams: Int, week: Int) -> [FantasyTeamRanking] {
        return sortedTeams.enumerated().map { (index, team) -> FantasyTeamRanking in
            let rank = index + 1
            let teamScore = team.currentScore ?? 0.0
            
            // DEATH ROW CALCULATION: Bottom N teams based on elimination count
            let isInEliminationZone = rank > (totalTeams - eliminationCount)
            
            let status: EliminationStatus
            if rank == 1 {
                status = .champion
            } else if isInEliminationZone {
                status = .critical // DEATH ROW
            } else if rank > (totalTeams * 3 / 4) {
                status = .danger
            } else if rank > (totalTeams / 2) {
                status = .warning
            } else {
                status = .safe
            }
            
            // 🔥 HYBRID LOGIC: Strategic delta based on your situation
            let safetyMargin: Double
            
            if isInEliminationZone {
                // IN ELIMINATION ZONE: Show distance to next person above (negative = need to catch up)
                if index > 0 {
                    let nextPersonAbove = sortedTeams[index - 1]
                    let nextPersonScore = nextPersonAbove.currentScore ?? 0.0
                    safetyMargin = teamScore - nextPersonScore // Negative = points needed to catch them
                } else {
                    // Shouldn't happen (elimination zone but first place), but fallback
                    safetyMargin = 0.0
                }
            } else {
                // SAFE ZONE: Show distance from elimination cutoff line (positive = your buffer)
                let eliminationCutoffTeams = sortedTeams.suffix(eliminationCount)
                let cutoffScore = eliminationCutoffTeams.first?.currentScore ?? 0.0
                safetyMargin = teamScore - cutoffScore // Positive = buffer above elimination
            }
            
            return FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: teamScore,
                rank: rank,
                eliminationStatus: status,
                isEliminated: false, // Don't mark as eliminated yet - let Death Row show them first
                survivalProbability: isInEliminationZone ? 0.0 : max(0.0, min(1.0, Double(totalTeams - rank) / Double(totalTeams))),
                pointsFromSafety: safetyMargin,
                weeksAlive: week
            )
        }
    }
    
    /// Calculate summary statistics
    private func calculateSummaryStats(teamRankings: [FantasyTeamRanking]) -> (avgScore: Double, highScore: Double, lowScore: Double) {
        let allScores = teamRankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        return (avgScore, highScore, lowScore)
    }
    
    /// Log chopped summary details
    private func logChoppedSummary(totalTeams: Int, eliminationCount: Int, eliminatedTeams: [FantasyTeamRanking], highScore: Double, lowScore: Double, avgScore: Double, leagueName: String) {
        // Summary logging can be enabled if needed for debugging
    }
    
    /// Find the authenticated user's team in the Chopped leaderboard using proper Sleeper user identification
    internal func findMyTeamInChoppedLeaderboard(_ choppedSummary: ChoppedWeekSummary, leagueID: String) async -> FantasyTeamRanking? {
        // ✅ Only accept definitive roster-ID matching.
        // Fuzzy fallbacks here will incorrectly "find" you in every chopped league.
        guard let userRosterID = await getCurrentUserRosterID(leagueID: leagueID) else {
            return nil
        }

        if let myRanking = choppedSummary.rankings.first(where: { $0.team.rosterID == userRosterID }) {
            return myRanking
        }

        if let eliminatedRanking = choppedSummary.eliminationHistory.first(where: { $0.eliminatedTeam.team.rosterID == userRosterID }) {
            return eliminatedRanking.eliminatedTeam
        }

        return nil
    }
    
    /// Get the current user's roster ID in a Sleeper league (helper for Chopped leagues)
    private func getCurrentUserRosterID(leagueID: String) async -> Int? {
        // Resolve to a Sleeper user_id first (rosters.owner_id uses user_id, not username).
        let identifier: String? = {
            if !sleeperCredentials.currentUserID.isEmpty { return sleeperCredentials.currentUserID }
            if !sleeperCredentials.currentUsername.isEmpty { return sleeperCredentials.currentUsername }
            return nil
        }()

        guard let identifier else { return nil }

        let userID: String
        do {
            if identifier.allSatisfy({ $0.isNumber }) {
                userID = identifier
            } else {
                let user = try await SleeperAPIClient.shared.fetchUser(username: identifier)
                userID = user.userID
            }
        } catch {
            return nil
        }

        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            return rosters.first(where: { $0.ownerID == userID })?.rosterID
        } catch {
            return nil
        }
    }
}