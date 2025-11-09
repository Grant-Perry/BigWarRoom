//
//  LeagueMatchupProvider.swift
//  BigWarRoom
//
//  🔥 ISOLATED LEAGUE DATA PROVIDER 🔥
//  Eliminates race conditions by providing isolated data fetching for each league
//  No more shared state bullshit between concurrent league loads!
//

import Foundation
import Combine

/// **LeagueMatchupProvider**
/// 
/// Provides isolated data fetching for a single league to eliminate race conditions.
/// Each instance handles one league's data independently, preventing the shared state
/// issues that plagued MatchupsHubViewModel when using a shared FantasyViewModel.
@MainActor
final class LeagueMatchupProvider {
    
    // MARK: -> League Context
    let league: UnifiedLeagueManager.LeagueWrapper
    let week: Int
    let year: String
    
    // MARK: -> Isolated State (NO SHARING!)
    private var matchups: [FantasyMatchup] = []
    private var byeWeekTeams: [FantasyTeam] = []
    private var choppedSummary: ChoppedWeekSummary?
    private var detectedAsChoppedLeague: Bool = false
    
    // MARK: -> ESPN State
    private var espnTeamRecords: [Int: TeamRecord] = [:]
    private var espnTeamNames: [Int: String] = [:]
    private var currentESPNLeague: ESPNLeague?
    
    // MARK: -> Sleeper State
    private var sleeperLeagueSettings: [String: Any]?
    private var playerStats: [String: [String: Double]] = [:]
    private var rosterIDToManagerID: [Int: String] = [:]
    private var userIDs: [String: String] = [:]
    private var userAvatars: [String: URL] = [:]
    private var sleeperRosters: [SleeperRoster] = []  // 🔥 NEW: Store rosters for record lookup
    
    // MARK: -> Dependencies
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private let sleeperCredentials = SleeperCredentialsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: -> Initialization
    init(league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String) {
        self.league = league
        self.week = week
        self.year = year
    }
    
    // MARK: -> Team Identification
    
    /// Identify the authenticated user's team ID in this league (robust to async races)
    func identifyMyTeamID() async -> String? {
        if league.source == .sleeper {
            guard let username = sleeperCredentials.getUserIdentifier() else {
                return nil
            }

            let resolvedUserID: String
            do {
                if username.allSatisfy({ $0.isNumber }) {
                    resolvedUserID = username
                } else {
                    let user = try await SleeperAPIClient.shared.fetchUser(username: username)
                    resolvedUserID = user.userID
                }
            } catch {
                return nil
            }

            // 💡 FIX: Only use *loaded* rosters (already fetched/set earlier)
            if !sleeperRosters.isEmpty, 
               let myRoster = sleeperRosters.first(where: { $0.ownerID == resolvedUserID }) {
                return String(myRoster.rosterID)
            }

            // Fallback: If not already loaded (shouldn’t happen!), do blocking load
            do {
                let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: league.league.leagueID)
                if let userRoster = rosters.first(where: { $0.ownerID == resolvedUserID }) {
                    return String(userRoster.rosterID)
                } else {
                    return nil
                }
            } catch {
                return nil
            }
        } else if league.source == .espn {
            if let teamID = await getESPNUserTeamID() {
                return teamID
            }
        }
        return nil
    }
    
    /// Get current user's roster ID for Sleeper leagues
    private func getCurrentUserRosterID() async -> Int? {
        // 🔥 FIX: Use username resolution instead of empty currentUserID
        guard let username = sleeperCredentials.getUserIdentifier() else {
            return nil
        }
        
        // Resolve username to user ID if needed
        let resolvedUserID: String
        do {
            if username.allSatisfy({ $0.isNumber }) {
                // Already a user ID
                resolvedUserID = username
            } else {
                // It's a username, resolve to user ID
                let user = try await SleeperAPIClient.shared.fetchUser(username: username)
                resolvedUserID = user.userID
            }
        } catch {
            return nil
        }
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: league.league.leagueID)
            let userRoster = rosters.first { $0.ownerID == resolvedUserID }
            
            if let userRoster = userRoster {
                return userRoster.rosterID
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    /// Get current user's team ID for ESPN leagues
    private func getESPNUserTeamID() async -> String? {
        let myESPNID = AppConstants.GpESPNID

        do {
            let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)

            if let teams = espnLeague.teams {
                for team in teams {
                    if let owners = team.owners {
                        if owners.contains(myESPNID) {
                            return String(team.id)
                        }
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }
    
    // MARK: -> Data Fetching
    
    /// Fetch all matchup data for this league
    func fetchMatchups() async throws -> [FantasyMatchup] {
        debugPrint(mode: .leagueProvider, "fetchMatchups() called for \(league.league.leagueID), source=\(league.source)")
        // Clear previous state
        matchups = []
        byeWeekTeams = []
        choppedSummary = nil
        detectedAsChoppedLeague = false
        
        if league.source == .espn {
            debugPrint(mode: .leagueProvider, "Fetching ESPN data")
            await fetchESPNData()
        } else {
            debugPrint(mode: .leagueProvider, "Fetching Sleeper data")
            await fetchSleeperData()
        }
        
        debugPrint(mode: .leagueProvider, "Returning \(matchups.count) matchups")
        return matchups
    }
    
    /// Check if this is a Chopped league
    func isChoppedLeague() -> Bool {
        return league.source == .sleeper && matchups.isEmpty && detectedAsChoppedLeague
    }
    
    /// Get Chopped league summary (if applicable)
    func getChoppedSummary() async -> ChoppedWeekSummary? {
        guard isChoppedLeague() else { return nil }

        if choppedSummary == nil {
            choppedSummary = await createChoppedSummary()
        }

        return choppedSummary
    }

    /// Calculate team records from matchup history when standings don't provide them
    private func calculateRecordsFromMatchupHistory(leagueID: String) async {
        debugPrint(mode: .recordCalculation, "Starting calculation for league \(leagueID)")

        // Get all past weeks (1-8 since we're in week 9)
        let pastWeeks = 1..<week
        var teamRecords: [Int: TeamRecord] = [:]

        for pastWeek in pastWeeks {
            do {
                debugPrint(mode: .recordCalculation, limit: 5, "Calculating records for week \(pastWeek)...")

                // Fetch matchup data for this past week
                guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(pastWeek)") else {
                    debugPrint(mode: .recordCalculation, "Failed to create URL for week \(pastWeek)")
                    continue
                }

                var request = URLRequest(url: url)
                request.addValue("application/json", forHTTPHeaderField: "Accept")

                let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
                request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")

                let (data, _) = try await URLSession.shared.data(for: request)
                let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)

                // Process each matchup to determine winner/loser
                for scheduleEntry in model.schedule {
                    guard let awayTeam = scheduleEntry.away else {
                        continue // Skip bye weeks where away team doesn't exist
                    }
                    let homeTeam = scheduleEntry.home

                    // Calculate scores for this specific week
                    let awayScore = calculateTeamScoreForWeek(team: awayTeam, week: pastWeek)
                    let homeScore = calculateTeamScoreForWeek(team: homeTeam, week: pastWeek)

                    // Initialize records if not exists
                    if teamRecords[awayTeam.teamId] == nil {
                        teamRecords[awayTeam.teamId] = TeamRecord(wins: 0, losses: 0, ties: 0)
                    }
                    if teamRecords[homeTeam.teamId] == nil {
                        teamRecords[homeTeam.teamId] = TeamRecord(wins: 0, losses: 0, ties: 0)
                    }

                    // Determine winner
                    if awayScore > homeScore {
                        // Away team wins
                        let currentAway = teamRecords[awayTeam.teamId]!
                        let currentHome = teamRecords[homeTeam.teamId]!
                        teamRecords[awayTeam.teamId] = TeamRecord(wins: currentAway.wins + 1, losses: currentAway.losses, ties: currentAway.ties)
                        teamRecords[homeTeam.teamId] = TeamRecord(wins: currentHome.wins, losses: currentHome.losses + 1, ties: currentHome.ties)
                    } else if homeScore > awayScore {
                        // Home team wins
                        let currentAway = teamRecords[awayTeam.teamId]!
                        let currentHome = teamRecords[homeTeam.teamId]!
                        teamRecords[homeTeam.teamId] = TeamRecord(wins: currentHome.wins + 1, losses: currentHome.losses, ties: currentHome.ties)
                        teamRecords[awayTeam.teamId] = TeamRecord(wins: currentAway.wins, losses: currentAway.losses + 1, ties: currentAway.ties)
                    } else {
                        // Tie
                        let currentAway = teamRecords[awayTeam.teamId]!
                        let currentHome = teamRecords[homeTeam.teamId]!
                        teamRecords[awayTeam.teamId] = TeamRecord(wins: currentAway.wins, losses: currentAway.losses, ties: (currentAway.ties ?? 0) + 1)
                        teamRecords[homeTeam.teamId] = TeamRecord(wins: currentHome.wins, losses: currentHome.losses, ties: (currentHome.ties ?? 0) + 1)
                    }
                }

            } catch {
                continue
            }
        }

        // Store calculated records
        espnTeamRecords = teamRecords
    }

    /// Calculate a team's score for a specific week from their roster
    private func calculateTeamScoreForWeek(team: ESPNTeamMatchupModel, week: Int) -> Double {
        guard let roster = team.roster else { return 0.0 }

        // Active slots for standard fantasy football
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17] // QB, RB, RB, WR, WR, TE, FLEX, D/ST, K

        return roster.entries
            .filter { activeSlotsOrder.contains($0.lineupSlotId) }
            .reduce(0.0) { sum, entry in
                sum + entry.getScore(for: week)
            }
    }

    /// Find user's matchup by team ID
    func findMyMatchup(myTeamID: String) -> FantasyMatchup? {
        for (index, matchup) in matchups.enumerated() {
            if matchup.homeTeam.id == myTeamID {
                return matchup
            } else if matchup.awayTeam.id == myTeamID {
                return matchup
            }
        }
        
        return nil
    }
    
    // MARK: -> ESPN Data Fetching
    
    private func fetchESPNData() async {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
            return
        }
        
        // First fetch league data for name resolution
        do {
            currentESPNLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
            await syncESPNDataToMainViewModel()
        } catch {
            currentESPNLeague = nil
        }

        // 🔥 NEW: Fetch ESPN standings to get team records BEFORE processing matchups
        do {
            let standingsData = try await ESPNAPIClient.shared.fetchESPNStandings(leagueID: league.league.leagueID)

            // Extract and store team records from standings
            espnTeamRecords.removeAll() // Clear any existing records
            for team in standingsData.teams ?? [] {
                if let espnRecord = team.record, let record = espnRecord.overall {
                    espnTeamRecords[team.id] = TeamRecord(
                        wins: record.wins,
                        losses: record.losses,
                        ties: record.ties
                    )
                }
            }

            // If no records found in standings, calculate from matchup history
            if espnTeamRecords.isEmpty {
                await calculateRecordsFromMatchupHistory(leagueID: league.league.leagueID)
            }
            
            // 🔥 DRY FIX: Sync calculated records to FantasyViewModel after calculation completes
            await syncESPNRecordsToViewModel()

        } catch {
            // Continue without standings data - records will be nil but won't crash
        }

        // NOTE: ESPN's standings endpoint does NOT support historical weeks
        // It always returns current standings regardless of parameters
        // Since Sleeper records work correctly, we only use Sleeper for team records
        
        // Now fetch matchup data
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // 🔍 DEBUG: Check if positionAgainstOpponent key exists in response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 LeagueMatchupProvider ESPN API Keys: \(jsonObject.keys.sorted())")
                if jsonObject["positionAgainstOpponent"] != nil {
                    print("✅ positionAgainstOpponent EXISTS in LeagueMatchupProvider response")
                } else {
                    print("❌ positionAgainstOpponent NOT FOUND in LeagueMatchupProvider response")
                }
            }
            
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            // 🔥 NEW: Also try to decode full ESPNLeague for OPRK data
            if let fullLeagueData = try? JSONDecoder().decode(ESPNLeague.self, from: data) {
                OPRKService.shared.updateOPRKData(from: fullLeagueData)
            }
            await processESPNData(model)
        } catch {
            // Silent fail - matchup data couldn't be loaded
        }
    }
    
    private func processESPNData(_ espnModel: ESPNFantasyLeagueModel) async {
        debugPrint(mode: .espnAPI, "processESPNData called for \(espnModel.teams.count) teams")
        
        // Store team records and names
        for team in espnModel.teams {
            espnTeamNames[team.id] = team.name
        }
        
        var processedMatchups: [FantasyMatchup] = []
        var byeTeams: [FantasyTeam] = []
        
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        
        for scheduleEntry in weekSchedule {
            
            guard let awayTeamEntry = scheduleEntry.away else {
                if let homeTeam = espnModel.teams.first(where: { $0.id == scheduleEntry.home.teamId }) {
                    let homeScore = homeTeam.activeRosterScore(for: week)
                    let byeTeam = createESPNFantasyTeam(espnTeam: homeTeam, score: homeScore)
                    byeTeams.append(byeTeam)
                }
                continue
            }
            
            let awayTeamId = awayTeamEntry.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            let awayFantasyTeam = createESPNFantasyTeam(espnTeam: awayTeam, score: awayScore)
            let homeFantasyTeam = createESPNFantasyTeam(espnTeam: homeTeam, score: homeScore)
            
            let matchup = FantasyMatchup(
                id: "\(league.league.leagueID)_\(week)_\(awayTeamId)_\(homeTeamId)",
                leagueID: league.league.leagueID,
                week: week,
                year: year,
                homeTeam: homeFantasyTeam,
                awayTeam: awayFantasyTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            processedMatchups.append(matchup)
        }
        
        matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
        byeWeekTeams = byeTeams
    }
    
    private func createESPNFantasyTeam(espnTeam: ESPNFantasyTeamModel, score: Double) -> FantasyTeam {
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let roster = espnTeam.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                return FantasyPlayer(
                    id: String(player.id),
                    sleeperID: nil,
                    espnID: String(player.id),
                    firstName: player.fullName.firstName,
                    lastName: player.fullName.lastName,
                    position: positionString(entry.lineupSlotId),
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: getJerseyNumberForPlayer(espnID: String(player.id), team: player.nflTeamAbbreviation, name: "\(player.fullName.firstName) \(player.fullName.lastName)"),
                    currentPoints: weeklyScore,
                    projectedPoints: weeklyScore * 1.1,
                    gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: player.nflTeamAbbreviation),
                    isStarter: [0, 2, 3, 4, 5, 6, 23, 16, 17].contains(entry.lineupSlotId),
                    lineupSlot: positionString(entry.lineupSlotId)
                )
            }
        }
        
        let record: TeamRecord?
        if let espnRecord = espnTeamRecords[espnTeam.id] {
            record = TeamRecord(
                wins: espnRecord.wins,
                losses: espnRecord.losses,
                ties: espnRecord.ties
            )
        } else {
            record = nil
        }
        
        // Get real team name using league member data
        let realTeamName: String = {
            if let espnLeague = currentESPNLeague {
                if let espnTeamData = espnLeague.teams?.first(where: { $0.id == espnTeam.id }) {
                    let managerName = espnLeague.getManagerName(for: espnTeamData.owners)
                    
                    if !managerName.hasPrefix("Manager ") && managerName.count > 4 {
                        return managerName
                    }
                }
            }
            
            if let teamName = espnTeam.name, 
               !teamName.hasPrefix("Team ") && teamName.count > 4 {
                return teamName
            }
            
            return "ESPN Team \(espnTeam.id)"
        }()
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: realTeamName,
            ownerName: realTeamName,
            record: record,
            avatar: nil,
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: espnTeam.id
        )
    }
    
    // MARK: -> Sleeper Data Fetching
    
    private func fetchSleeperData() async {
        await fetchSleeperScoringSettings()
        await fetchSleeperWeeklyStats()
        await fetchSleeperUsersAndRosters()
        await fetchSleeperMatchups()
    }
    
    private func fetchSleeperScoringSettings() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["scoring_settings"] as? [String: Any] {
                sleeperLeagueSettings = settings
            }
        } catch {
            // Silent fail
        }
    }
    
    private func fetchSleeperWeeklyStats() async {
        // 🔥 FIX: Use SharedStatsService instead of making redundant API calls
        do {
            let sharedStats = try await SharedStatsService.shared.loadWeekStats(week: week, year: year)
            playerStats = sharedStats
        } catch {
            playerStats = [:]  // Set empty to prevent crashes
        }
    }
    
    private func fetchSleeperUsersAndRosters() async {
        // Fetch rosters
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters") else { 
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            // 🔥 NEW: Store rosters for record lookup
            sleeperRosters = rosters
            
            // DISABLED VERBOSE LOGGING - uncomment if needed for debugging Sleeper records
            /*
            print("🔍 SLEEPER API RESPONSE - Record Diagnosis:")
            print("   Total rosters: \(rosters.count)")
            for (index, roster) in rosters.prefix(5).enumerated() {
                let winsDisplay = roster.wins.map(String.init) ?? "nil"
                let lossesDisplay = roster.losses.map(String.init) ?? "nil"
                let tieValue = roster.ties ?? 0
                
                print("   Roster \(index): ID=\(roster.rosterID), Owner=\(roster.ownerID ?? "nil")")
                print("      Root level - wins:\(winsDisplay), losses:\(lossesDisplay), ties:\(tieValue)")
                
                if let settings = roster.settings {
                    let settingsWins = settings.wins ?? -1
                    let settingsLosses = settings.losses ?? -1
                    print("      Settings level - wins:\(settingsWins), losses:\(settingsLosses)")
                }
            }
            */
            
            var newRosterMapping: [Int: String] = [:]
            
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    newRosterMapping[roster.rosterID] = ownerID
                }
            }
            
            rosterIDToManagerID = newRosterMapping
            debugPrint(mode: .dataSync, limit: 5, "Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
            
            // Fetch users
            await fetchSleeperUsers()
            
        } catch {
            debugPrint(mode: .sleeperAPI, "Failed to fetch Sleeper rosters: \(error)")
        }
    }
    
    private func fetchSleeperUsers() async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users") else { 
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for user in users {
                newUserIDs[user.userID] = user.displayName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    newUserAvatars[user.userID] = avatarURL
                }
            }
            
            userIDs = newUserIDs
            userAvatars = newUserAvatars
            
        } catch {
            // Silent fail
        }
    }
    
    private func fetchSleeperMatchups() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            
            if sleeperMatchups.isEmpty {
                detectedAsChoppedLeague = true
                await processChoppedLeaguePlayerScores()
                return
            }
            
            await processSleeperMatchups(sleeperMatchups)
            
        } catch {
            // Silent fail
        }
    }
    
    // 🔥 NEW: Process player scores for Chopped leagues using their specific scoring settings
    private func processChoppedLeaguePlayerScores() async {
        // Get all players from the stats API that have passing yards > 100 (QBs like Bo Nix)
        let quarterbacks = playerStats.filter { playerID, stats in
            if let passYards = stats["pass_yd"], passYards > 100 {
                return true
            }
            return false
        }
        
        // Calculate scores for these players using THIS league's scoring settings
        for (playerID, stats) in quarterbacks {
            let calculatedScore = calculateSleeperPlayerScore(playerId: playerID)
        }
    }
    
    private func processSleeperMatchups(_ sleeperMatchups: [SleeperMatchupResponse]) async {
        let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchupID ?? 0 })
        var processedMatchups: [FantasyMatchup] = []
        
        for (_, matchups) in groupedMatchups where matchups.count == 2 {
            let team1 = matchups[0]
            let team2 = matchups[1]
            
            let awayManagerID = rosterIDToManagerID[team1.rosterID] ?? ""
            let homeManagerID = rosterIDToManagerID[team2.rosterID] ?? ""
            
            let awayManagerName = userIDs[awayManagerID] ?? "Manager \(team1.rosterID)"
            let homeManagerName = userIDs[homeManagerID] ?? "Manager \(team2.rosterID)"
            
            let awayAvatarURL = userAvatars[awayManagerID]
            let homeAvatarURL = userAvatars[homeManagerID]
            
            let awayTeam = createSleeperFantasyTeam(
                matchupResponse: team1,
                managerName: awayManagerName,
                avatarURL: awayAvatarURL
            )
            
            let homeTeam = createSleeperFantasyTeam(
                matchupResponse: team2,
                managerName: homeManagerName,
                avatarURL: homeAvatarURL
            )
            
            let fantasyMatchup = FantasyMatchup(
                id: "\(league.league.leagueID)_\(week)_\(team1.rosterID)_\(team2.rosterID)",
                leagueID: league.league.leagueID,
                week: week,
                year: year,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: team2.points ?? 0, awayScore: team1.points ?? 0),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            processedMatchups.append(fantasyMatchup)
        }
        
        matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
        
        // 🔥 DRY FIX: Final sync of records after matchups are created to ensure they're available
        await syncESPNRecordsToViewModel()
    }
    
    private func createSleeperFantasyTeam(
        matchupResponse: SleeperMatchupResponse,
        managerName: String,
        avatarURL: URL?
    ) -> FantasyTeam {
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let allPlayers = matchupResponse.players {
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                    let isStarter = matchupResponse.starters?.contains(playerID) ?? false
                    let playerScore = calculateSleeperPlayerScore(playerId: playerID)
                    
                    // 🔥 PRIORITY FIX: Ensure team is ALWAYS loaded for colors
                    let playerTeam = sleeperPlayer.team ?? getPlayerTeamFromCache(playerID) ?? "UNK"
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: playerTeam,  // 🔥 GUARANTEED to have a value for team colors
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerScore * 1.1,
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: playerTeam),
                        isStarter: isStarter,
                        lineupSlot: sleeperPlayer.position
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        // 🔥 NEW: Get roster record data
        let rosterRecord: TeamRecord? = {
            
            if let roster = sleeperRosters.first(where: { $0.rosterID == matchupResponse.rosterID }) {
                DebugLogger.fantasy("🔍 Creating team for roster \(matchupResponse.rosterID):")
                DebugLogger.fantasy("   Root level: wins=\(roster.wins ?? 0), losses=\(roster.losses ?? 0)")
                
                // Try root level first
                if let wins = roster.wins, let losses = roster.losses {
                    DebugLogger.fantasy("✅ Record found for roster \(matchupResponse.rosterID): \(wins)-\(losses) (root level)")
                    return TeamRecord(
                        wins: wins,
                        losses: losses,
                        ties: roster.ties ?? 0
                    )
                }
                
                // Fallback to settings object
                if let settings = roster.settings,
                   let wins = settings.wins,
                   let losses = settings.losses {
                    DebugLogger.fantasy("✅ Record found for roster \(matchupResponse.rosterID): \(wins)-\(losses) (settings)")
                    return TeamRecord(
                        wins: wins,
                        losses: losses,
                        ties: settings.ties ?? 0
                    )
                }
                
                DebugLogger.fantasy("❌ NO record data for roster \(matchupResponse.rosterID) - wins/losses not in root or settings")
            } else {
                DebugLogger.fantasy("❌ Roster not found for rosterID \(matchupResponse.rosterID) (sleeperRosters.count=\(sleeperRosters.count))")
            }
            return nil
        }()
        
        return FantasyTeam(
            id: String(matchupResponse.rosterID),
            name: managerName,
            ownerName: managerName,
            record: rosterRecord,
            avatar: avatarURL?.absoluteString,
            currentScore: matchupResponse.points,
            projectedScore: matchupResponse.projectedPoints,
            roster: fantasyPlayers,
            rosterID: matchupResponse.rosterID
        )
    }
    
    // 🔥 NEW: Player team cache for instant color loading
    private func getPlayerTeamFromCache(_ playerID: String) -> String? {
        // Try to get team from known associations (cache popular players)
        let knownTeams: [String: String] = [
            // QBs
            "4046": "BUF",  // Josh Allen
            "4035": "KC",   // Patrick Mahomes
            "3157": "CIN",  // Joe Burrow
            "2309": "BAL",  // Lamar Jackson
            
            // RBs  
            "4018": "BUF",  // James Cook
            "4029": "KC",   // Isiah Pacheco
            "4039": "SF",   // Christian McCaffrey (fixed duplicate)
            "4988": "BAL",  // Derrick Henry
            "6130": "CIN",  // Joe Mixon (new ID to avoid duplicate)
            
            // WRs
            "5048": "CIN",  // Ja'Marr Chase
            "4866": "KC",   // Travis Kelce
            "4017": "BUF",  // Stefon Diggs
            "5045": "BAL",  // Mark Andrews
            
            // Popular players (add more as needed)
            "4098": "LAR",  // Cooper Kupp
            "4036": "GB",   // Aaron Rodgers  
            "5849": "SF",   // Brock Purdy
        ]
        
        return knownTeams[playerID]
    }
    
    // MARK: -> Chopped League Support
    
    private func createChoppedSummary() async -> ChoppedWeekSummary? {
        // This would use the existing Chopped logic from FantasyViewModel+Chopped
        // For now, returning nil as this is complex and may not be needed immediately
        return nil
    }
    
    // 🔥 NEW: Get player score for a specific player in this league context
    func getPlayerScore(playerId: String) -> Double {
        guard playerStats[playerId] != nil,
              sleeperLeagueSettings != nil else {
            return 0.0
        }
        
        let score = calculateSleeperPlayerScore(playerId: playerId)
        
        return score
    }
    
    // 🔥 NEW: Check if this league has calculated player scores
    func hasPlayerScores() -> Bool {
        return !playerStats.isEmpty && sleeperLeagueSettings != nil
    }
    
    // MARK: -> Helper Methods
    
    private func calculateSleeperPlayerScore(playerId: String) -> Double {
        guard let playerStats = playerStats[playerId],
              let scoringSettings = sleeperLeagueSettings else {
            return 0.0
        }
        
        // 🔥 NEVER USE OFFICIAL POINTS - ALWAYS CALCULATE WITH LEAGUE SETTINGS
        // We need to calculate using this league's specific scoring settings, not Sleeper's official points
        
        var totalScore = 0.0
        
        for (statKey, statValue) in playerStats {
            if let scoring = scoringSettings[statKey] as? Double {
                let points = statValue * scoring
                totalScore += points
            }
        }
        
        return totalScore
    }
    
    private func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double? {
        let difference = homeScore - awayScore
        return 0.5 + (difference / 100.0) * 0.3
    }
    
    private func positionString(_ lineupSlotId: Int) -> String {
        switch lineupSlotId {
        case 0: return "QB"
        case 2, 3: return "RB" 
        case 4, 5: return "WR"
        case 6: return "TE"
        case 16: return "D/ST"
        case 17: return "K"
        case 23: return "FLEX"
        default: return "BN"
        }
    }
    
    // 🔥 NEW: Sync ESPN data to main FantasyViewModel for score breakdowns
    private func syncESPNDataToMainViewModel() async {
        guard let espnLeague = currentESPNLeague else { return }
        
        await MainActor.run {
            FantasyViewModel.shared.currentESPNLeague = espnLeague
        }
        
        // 🔥 DRY FIX: Sync records after league data is set
        await syncESPNRecordsToViewModel()
    }
    
    /// 🔥 DRY FIX: Centralized function to sync ESPN team records to FantasyViewModel
    private func syncESPNRecordsToViewModel() async {
        await MainActor.run {
            // Sync all calculated records to FantasyViewModel for use in getManagerRecord
            for (teamId, record) in espnTeamRecords {
                FantasyViewModel.shared.espnTeamRecords[teamId] = record
            }
            if !espnTeamRecords.isEmpty {
                debugPrint(mode: .recordCalculation, "Synced \(espnTeamRecords.count) ESPN team records to FantasyViewModel")
            }
        }
    }
    
    // MARK: -> Jersey Number Helper
    
    /// Get jersey number for a player by looking them up in the Sleeper directory
    private func getJerseyNumberForPlayer(espnID: String? = nil, sleeperID: String? = nil, team: String?, name: String) -> String? {
        // First try to find by ESPN ID if provided
        if let espnID = espnID {
            if let sleeperPlayer = playerDirectoryStore.players.values.first(where: { $0.espnID == espnID }) {
                return sleeperPlayer.number?.description
            }
        }
        
        // Then try by Sleeper ID if provided
        if let sleeperID = sleeperID {
            if let sleeperPlayer = playerDirectoryStore.player(for: sleeperID) {
                return sleeperPlayer.number?.description
            }
        }
        
        // Finally, try to match by name and team
        if let team = team {
            let normalizedName = name.lowercased()
            let nameComponents = normalizedName.components(separatedBy: " ")
            
            if nameComponents.count >= 2 {
                let firstName = nameComponents[0]
                let lastName = nameComponents.dropFirst().joined(separator: " ")
                
                let matchingPlayer = playerDirectoryStore.players.values.first { player in
                    guard let playerTeam = player.team?.uppercased(),
                          playerTeam == team.uppercased() else { return false }
                    
                    let playerFirstName = (player.firstName ?? "").lowercased()
                    let playerLastName = (player.lastName ?? "").lowercased()
                    
                    return playerFirstName == firstName && playerLastName == lastName
                }
                
                return matchingPlayer?.number?.description
            }
        }
        
        return nil
    }
}
