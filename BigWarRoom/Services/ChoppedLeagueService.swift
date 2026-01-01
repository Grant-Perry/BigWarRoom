//
//  ChoppedLeagueService.swift
//  BigWarRoom
//
//  Phase 2: Service to consolidate all chopped league logic (DRY principle)
//

import Foundation

/// Service responsible for all chopped/guillotine league logic
/// Consolidates: chopped summary creation, team rankings, elimination tracking, etc.
@MainActor
final class ChoppedLeagueService {
    
    // MARK: - Dependencies
    
    private let sleeperClient: SleeperAPIClient
    private let playerDirectory: PlayerDirectoryStore
    private let gameStatusService: GameStatusService
    private let sharedStatsService: SharedStatsService
    private let weekSelectionManager: WeekSelectionManager
    private let seasonYearManager: SeasonYearManager
    private let sleeperCredentials: SleeperCredentialsManager
    
    // MARK: - Initialization
    
    init(
        sleeperClient: SleeperAPIClient,
        playerDirectory: PlayerDirectoryStore,
        gameStatusService: GameStatusService,
        sharedStatsService: SharedStatsService,
        weekSelectionManager: WeekSelectionManager,
        seasonYearManager: SeasonYearManager,
        sleeperCredentials: SleeperCredentialsManager
    ) {
        self.sleeperClient = sleeperClient
        self.playerDirectory = playerDirectory
        self.gameStatusService = gameStatusService
        self.sharedStatsService = sharedStatsService
        self.weekSelectionManager = weekSelectionManager
        self.seasonYearManager = seasonYearManager
        self.sleeperCredentials = sleeperCredentials
    }
    
    // MARK: - Main Entry Point
    
    /// Create chopped summary and return unified matchup for a chopped league
    func createChoppedMatchup(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        currentWeek: Int
    ) async -> UnifiedMatchup? {
        // Create chopped summary using proper Sleeper data
        guard let choppedSummary = await createSleeperChoppedSummary(
            league: league,
            myTeamID: myTeamID,
            week: currentWeek
        ) else {
            return nil
        }
        
        guard let myTeamRanking = await findMyTeamInChoppedLeaderboard(
            choppedSummary,
            leagueID: league.league.leagueID
        ) else {
            return nil
        }
        
        DebugPrint(
            mode: .matchupLoading,
            limit: 20,
            "🪓 CHOPPED STATUS: \(league.league.name) rosterID=\(String(describing: myTeamRanking.team.rosterID)) rank=\(myTeamRanking.rank) status=\(myTeamRanking.eliminationStatus.rawValue) isEliminated=\(myTeamRanking.isEliminated) showElimToggle=\(UserDefaults.standard.showEliminatedChoppedLeagues)"
        )
        
        // If the user disabled eliminated chopped leagues, skip loading them entirely.
        if !UserDefaults.standard.showEliminatedChoppedLeagues, myTeamRanking.isEliminated {
            DebugPrint(mode: .matchupLoading, limit: 20, "🪓 FILTER OUT: \(league.league.name) (chopped eliminated, toggle OFF)")
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
        
        return unifiedMatchup
    }
    
    // MARK: - Chopped League Detection
    
    /// Robust Chopped/Guillotine league detection for Sleeper
    /// Consolidates logic previously duplicated in MatchupsHubViewModel and MatchupDataStore
    func isSleeperChoppedLeagueResolved(_ league: UnifiedLeagueManager.LeagueWrapper) async -> Bool {
        guard league.source == .sleeper else { return false }
    
        if let settings = league.league.settings {
            if settings.type == 3 || settings.isChopped == true { return true }
    
            if settings.type != nil || settings.isChopped != nil {
                return false
            }
        }
    
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)") else {
            return false
        }
    
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fullLeague = try JSONDecoder().decode(SleeperLeague.self, from: data)
            let settings = fullLeague.settings
            return settings?.type == 3 || settings?.isChopped == true || (settings?.isChoppedLeague == true)
        } catch {
            return false
        }
    }
    
    // MARK: - Chopped Summary Creation
    
    /// Create Chopped league summary for Sleeper leagues with no matchups
    private func createSleeperChoppedSummary(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> ChoppedWeekSummary? {
        do {
            // Step 1: Fetch REAL matchup data for this week to get actual starter scores
            let matchupData = try await sleeperClient.fetchMatchups(
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
    
    // MARK: - Data Fetching
    
    /// Fetch rosters and users data in parallel
    private func fetchRostersAndUsers(for leagueID: String) async throws -> ([SleeperRoster], [SleeperLeagueUser]) {
        async let rosters = sleeperClient.fetchRosters(leagueID: leagueID)
        async let users = sleeperClient.fetchUsers(leagueID: leagueID)
        
        let rostersResult = try await rosters
        let usersResult = try await users
        
        return (rostersResult, usersResult)
    }
    
    // MARK: - Team Mapping
    
    /// Create team mapping dictionaries
    private func createTeamMappings(
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser]
    ) -> (rosterToOwnerMap: [Int: String], userMap: [String: String], avatarMap: [String: URL]) {
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
    
    // MARK: - Fantasy Team Creation
    
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
        var eliminatedTeams: [FantasyTeam] = []
        let matchupByRosterID = Dictionary(uniqueKeysWithValues: matchupData.map { ($0.rosterID, $0) })

        // Build teams from /rosters so eliminated guillotine teams still get classified correctly
        for roster in rosters {
            let rosterID = roster.rosterID
            let matchup = matchupByRosterID[rosterID]

            let ownerID = roster.ownerID ?? rosterToOwnerMap[rosterID] ?? ""
            let resolvedTeamName = userMap[ownerID] ?? "Team \(rosterID)"
            let avatarURL = avatarMap[ownerID]

            // Guillotine elimination signal: roster has no players and/or no owner
            let hasAnyPlayers = (roster.playerIDs?.isEmpty == false)
            let hasOwner = !ownerID.isEmpty

            // Week-specific activity signal: only active teams have starters for this week
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

            // Active = has owner + has players + has a playable lineup for the selected week
            if hasOwner && hasAnyPlayers && hasAnyStarters && !starterRoster.isEmpty {
                activeTeams.append(fantasyTeam)
            } else {
                eliminatedTeams.append(fantasyTeam)
            }
        }

        return (activeTeams, eliminatedTeams)
    }
    
    // MARK: - Starter Roster Creation
    
    /// Create starter roster from Sleeper matchup data for All Live Players integration
    private func createStarterRoster(
        from matchup: SleeperMatchupResponse,
        realTeamScore: Double,
        leagueID: String
    ) -> [FantasyPlayer] {
        guard let starters = matchup.starters, !starters.isEmpty else {
            return []
        }
        
        // Create FantasyPlayer objects from starter player IDs
        let starterPlayers = starters.compactMap { playerID -> FantasyPlayer? in
            // Get player info from PlayerDirectoryStore
            let playerInfo = playerDirectory.player(for: playerID)
            
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
                currentPoints: actualPlayerScore,
                projectedPoints: actualPlayerScore * 1.05,
                gameStatus: gameStatusService.getGameStatusWithFallback(for: playerInfo?.team),
                isStarter: true,
                lineupSlot: playerInfo?.position,
                injuryStatus: playerInfo?.injuryStatus
            )
            
            return player
        }
        
        return starterPlayers
    }
    
    // MARK: - Player Scoring
    
    /// Calculate real individual player score using Sleeper stats and league scoring settings
    private func calculateRealPlayerScore(playerID: String, leagueID: String) -> Double {
        let currentWeek = weekSelectionManager.selectedWeek
        let currentYear = seasonYearManager.selectedYear
        
        // Get player stats from SharedStatsService
        guard let playerStats = sharedStatsService.getCachedPlayerStats(
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
            "pass_yd": 0.04,
            "pass_td": 4.0,
            "pass_int": -1.0,
            
            // Rushing
            "rush_yd": 0.1,
            "rush_td": 6.0,
            
            // Receiving
            "rec": 1.0,
            "rec_yd": 0.1,
            "rec_td": 6.0,
            
            // Kicking
            "fgm": 3.0,
            "xpm": 1.0,
            
            // Defense
            "def_td": 6.0,
            "def_int": 2.0,
            "def_fr": 2.0,
            "def_sack": 1.0,
            "def_safe": 2.0,
            
            // Fumbles
            "fum_lost": -1.0,
        ]
    }
    
    // MARK: - Team Rankings
    
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
        let teamRankings = createTeamRankings(
            sortedTeams: sortedTeams,
            eliminationCount: eliminationCount,
            totalTeams: totalActiveTeams,
            week: week
        )
        
        // Calculate summary stats
        let (avgScore, highScore, lowScore) = calculateSummaryStats(teamRankings: teamRankings)
        
        // Get "death row" teams for this week (bottom N teams FROM ACTIVE TEAMS)
        let eliminatedThisWeek = Array(teamRankings.suffix(eliminationCount))
        
        // CREATE GRAVEYARD: Convert already-eliminated teams to EliminationEvents
        let graveyardEvents = eliminatedTeams.enumerated().map { index, team in
            let eliminatedRanking = FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: team.currentScore ?? 0.0,
                rank: totalActiveTeams + index + 1,
                eliminationStatus: .eliminated,
                isEliminated: true,
                survivalProbability: 0.0,
                pointsFromSafety: 0.0,
                weeksAlive: week - 1
            )
            
            return EliminationEvent(
                id: "eliminated_\(team.id)",
                week: week - 1,
                eliminatedTeam: eliminatedRanking,
                eliminationScore: team.currentScore ?? 0.0,
                margin: 0.0,
                dramaMeter: 0.5,
                lastWords: "Left with no players to field...",
                timestamp: Date()
            )
        }
        
        return ChoppedWeekSummary(
            id: "chopped_real_\(league.league.leagueID)_\(week)",
            week: week,
            rankings: teamRankings,
            eliminatedTeam: eliminatedThisWeek.first,
            cutoffScore: lowScore,
            isComplete: true,
            totalSurvivors: teamRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: graveyardEvents
        )
    }
    
    /// Create team rankings with elimination status
    private func createTeamRankings(
        sortedTeams: [FantasyTeam],
        eliminationCount: Int,
        totalTeams: Int,
        week: Int
    ) -> [FantasyTeamRanking] {
        return sortedTeams.enumerated().map { (index, team) -> FantasyTeamRanking in
            let rank = index + 1
            let teamScore = team.currentScore ?? 0.0
            
            // DEATH ROW CALCULATION: Bottom N teams based on elimination count
            let isInEliminationZone = rank > (totalTeams - eliminationCount)
            
            let status: EliminationStatus
            if rank == 1 {
                status = .champion
            } else if isInEliminationZone {
                status = .critical
            } else if rank > (totalTeams * 3 / 4) {
                status = .danger
            } else if rank > (totalTeams / 2) {
                status = .warning
            } else {
                status = .safe
            }
            
            // HYBRID LOGIC: Strategic delta based on your situation
            let safetyMargin: Double
            
            if isInEliminationZone {
                // IN ELIMINATION ZONE: Show distance to next person above
                if index > 0 {
                    let nextPersonAbove = sortedTeams[index - 1]
                    let nextPersonScore = nextPersonAbove.currentScore ?? 0.0
                    safetyMargin = teamScore - nextPersonScore
                } else {
                    safetyMargin = 0.0
                }
            } else {
                // SAFE ZONE: Show distance from elimination cutoff line
                let eliminationCutoffTeams = sortedTeams.suffix(eliminationCount)
                let cutoffScore = eliminationCutoffTeams.first?.currentScore ?? 0.0
                safetyMargin = teamScore - cutoffScore
            }
            
            return FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: teamScore,
                rank: rank,
                eliminationStatus: status,
                isEliminated: false,
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
    
    // MARK: - Team Identification
    
    /// Find the authenticated user's team in the Chopped leaderboard using proper Sleeper user identification
    func findMyTeamInChoppedLeaderboard(
        _ choppedSummary: ChoppedWeekSummary,
        leagueID: String
    ) async -> FantasyTeamRanking? {
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
    
    /// Get the current user's roster ID in a Sleeper league
    private func getCurrentUserRosterID(leagueID: String) async -> Int? {
        // Resolve to a Sleeper user_id first
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
                let user = try await sleeperClient.fetchUser(username: identifier)
                userID = user.userID
            }
        } catch {
            return nil
        }

        do {
            let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
            return rosters.first(where: { $0.ownerID == userID })?.rosterID
        } catch {
            return nil
        }
    }
}