//
//  MatchupsHubViewModel+ChoppedLeagues.swift
//  BigWarRoom
//
//  Chopped league specific logic for MatchupsHubViewModel
//

import Foundation

// Associated object key for storing graveyard teams
private var graveyardTeamsKey: UInt8 = 0

// MARK: - Chopped League Operations
extension MatchupsHubViewModel {
    
    // Store eliminated teams for graveyard
    private var graveyardTeams: [FantasyTeam] {
        get { objc_getAssociatedObject(self, &graveyardTeamsKey) as? [FantasyTeam] ?? [] }
        set { objc_setAssociatedObject(self, &graveyardTeamsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    /// Handle chopped league processing
    internal func handleChoppedLeague(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        // Create chopped summary using proper Sleeper data
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: getCurrentWeek()) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped",
                    league: league,
                    fantasyMatchup: nil,
                    choppedSummary: choppedSummary,
                    lastUpdated: Date(),
                    myTeamRanking: myTeamRanking,
                    myIdentifiedTeamID: myTeamID
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
            let choppedTeams = createChoppedFantasyTeams(matchupData: matchupData, rosterToOwnerMap: rosterToOwnerMap, userMap: userMap, avatarMap: avatarMap, league: league)
            
            // Step 5: Process and rank teams
            return await processChoppedTeamRankings(teams: choppedTeams, league: league, week: week)
            
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
        rosterToOwnerMap: [Int: String], 
        userMap: [String: String], 
        avatarMap: [String: URL],
        league: UnifiedLeagueManager.LeagueWrapper
    ) -> [FantasyTeam] {
        var activeTeams: [FantasyTeam] = []
        var eliminatedTeams: [FantasyTeam] = [] // Track eliminated teams for graveyard
        
        for matchup in matchupData {
            let rosterID = matchup.rosterID
            let ownerID = rosterToOwnerMap[rosterID] ?? ""
            let resolvedTeamName = userMap[ownerID] ?? "Team \(rosterID)"
            let avatarURL = avatarMap[ownerID]
            
            // Only check actual player count - ignore starters
            let playerCount = matchup.players?.count ?? 0
            let hasAnyPlayers = playerCount > 0  // ONLY this matters!
            
            // Use REAL points from the matchup data (starter-only scores)
            let realTeamScore = matchup.points ?? 0.0
            let projectedScore = matchup.projectedPoints ?? (realTeamScore * 1.05)
            
            // Create actual starter roster for All Live Players integration
            let starterRoster = createStarterRoster(from: matchup, realTeamScore: realTeamScore, leagueID: league.league.leagueID)
            
            let fantasyTeam = FantasyTeam(
                id: String(rosterID),
                name: resolvedTeamName,
                ownerName: resolvedTeamName,
                record: nil,
                avatar: avatarURL?.absoluteString,
                currentScore: realTeamScore,
                projectedScore: projectedScore,
                roster: starterRoster, // Now includes actual starter players!
                rosterID: rosterID
            )
            
            if hasAnyPlayers {
                activeTeams.append(fantasyTeam)
            } else {
                eliminatedTeams.append(fantasyTeam)
            }
        }
        
        // Store eliminated teams for graveyard (we'll need to modify the summary creation)
        self.graveyardTeams = eliminatedTeams
        
        // Return ONLY active teams for main rankings
        return activeTeams
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
                gameStatus: nil,
                isStarter: true, // Mark as starter so they show in All Live Players!
                lineupSlot: playerInfo?.position
            )
            
            return player
        }
        
        return starterPlayers
    }
    
    /// Calculate real individual player score using Sleeper stats and league scoring settings
    private func calculateRealPlayerScore(playerID: String, leagueID: String) -> Double {
        // Get player stats from AllLivePlayersViewModel's cached stats
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        let playerStats = AllLivePlayersViewModel.shared.playerStats[playerID] ?? [:]
        
        // If no stats available, return 0 (game hasn't happened yet)
        guard !playerStats.isEmpty else {
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
    private func processChoppedTeamRankings(teams: [FantasyTeam], league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> ChoppedWeekSummary {
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
        
        // Get eliminated teams (bottom N teams FROM ACTIVE TEAMS)
        let eliminatedTeams = Array(teamRankings.suffix(eliminationCount))
        
        // CREATE GRAVEYARD: Convert eliminated teams to EliminationEvents
        let graveyardEvents = graveyardTeams.enumerated().map { index, team in
            
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
        
        logChoppedSummary(totalTeams: totalActiveTeams, eliminationCount: eliminationCount, eliminatedTeams: eliminatedTeams, highScore: highScore, lowScore: lowScore, avgScore: avgScore, leagueName: league.league.name)
        
        return ChoppedWeekSummary(
            id: "chopped_real_\(league.league.leagueID)_\(week)",
            week: week,
            rankings: teamRankings, // Only active teams
            eliminatedTeam: eliminatedTeams.first, // Primary eliminated team for UI
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
            
            // Calculate safety margin from elimination cutoff
            let eliminationCutoffTeams = sortedTeams.suffix(eliminationCount)
            let cutoffScore = eliminationCutoffTeams.first?.currentScore ?? 0.0
            let safetyMargin = teamScore - cutoffScore
            
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
        // Strategy 1: For Sleeper leagues, use roster ID matching
        if let userRosterID = await getCurrentUserRosterID(leagueID: leagueID) {
            // First check active rankings
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.rosterID == userRosterID
            }
            
            if let myRanking = myRanking {
                return myRanking
            }
            
            // Check elimination history if not found in active rankings
            let eliminatedRanking = choppedSummary.eliminationHistory.first { elimination in
                elimination.eliminatedTeam.team.rosterID == userRosterID
            }
            
            if let eliminatedRanking = eliminatedRanking {
                return eliminatedRanking.eliminatedTeam
            }
        }
        
        // Strategy 2: Fallback to username matching
        let authenticatedUsername = sleeperCredentials.currentUsername
        if !authenticatedUsername.isEmpty {
            // First check active rankings
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.ownerName.lowercased() == authenticatedUsername.lowercased()
            }
            
            if let myRanking = myRanking {
                return myRanking
            }
            
            // Check elimination history if not found in active rankings
            let eliminatedRanking = choppedSummary.eliminationHistory.first { elimination in
                elimination.eliminatedTeam.team.ownerName.lowercased() == authenticatedUsername.lowercased()
            }
            
            if let eliminatedRanking = eliminatedRanking {
                return eliminatedRanking.eliminatedTeam
            }
        }
        
        // Strategy 3: Match by "Gp" (specific fallback)
        // First check active rankings
        let gpRanking = choppedSummary.rankings.first { ranking in
            ranking.team.ownerName.lowercased().contains("gp")
        }
        
        if let gpRanking = gpRanking {
            return gpRanking
        }
        
        // Check elimination history for "Gp" match
        let eliminatedGpRanking = choppedSummary.eliminationHistory.first { elimination in
            elimination.eliminatedTeam.team.ownerName.lowercased().contains("gp")
        }
        
        if let eliminatedGpRanking = eliminatedGpRanking {
            return eliminatedGpRanking.eliminatedTeam
        }
        
        // Return first team as fallback
        return choppedSummary.rankings.first
    }
    
    /// Get the current user's roster ID in a Sleeper league (helper for Chopped leagues)
    private func getCurrentUserRosterID(leagueID: String) async -> Int? {
        guard !sleeperCredentials.currentUserID.isEmpty else {
            return nil
        }
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            let userRoster = rosters.first { $0.ownerID == sleeperCredentials.currentUserID }
            
            if let userRoster = userRoster {
                return userRoster.rosterID
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}