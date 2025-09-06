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
    
    // MARK: -> Dependencies
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private let sleeperCredentials = SleeperCredentialsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: -> Initialization
    init(league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String) {
        self.league = league
        self.week = week
        self.year = year
        
        print("🆕 PROVIDER: Created isolated provider for \(league.league.name) week \(week)")
    }
    
    // MARK: -> Team Identification
    
    /// Identify the authenticated user's team ID in this league
    func identifyMyTeamID() async -> String? {
        print("🔍 PROVIDER: Identifying user team in \(league.league.name)")
        
        if league.source == .sleeper {
            if let rosterID = await getCurrentUserRosterID() {
                let teamID = String(rosterID)
                print("🎯 SLEEPER: Identified myTeamID = \(teamID) (rosterID: \(rosterID))")
                return teamID
            }
        } else if league.source == .espn {
            if let teamID = await getESPNUserTeamID() {
                print("🎯 ESPN: Identified myTeamID = \(teamID)")
                return teamID
            }
        }
        
        print("❌ PROVIDER: Failed to identify user team in \(league.league.name)")
        return nil
    }
    
    /// Get current user's roster ID for Sleeper leagues
    private func getCurrentUserRosterID() async -> Int? {
        guard !sleeperCredentials.currentUserID.isEmpty else {
            print("❌ SLEEPER: No user ID available for roster identification")
            return nil
        }
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: league.league.leagueID)
            let userRoster = rosters.first { $0.ownerID == sleeperCredentials.currentUserID }
            
            if let userRoster = userRoster {
                print("🎯 SLEEPER: Found user roster ID \(userRoster.rosterID) for user \(sleeperCredentials.currentUserID)")
                return userRoster.rosterID
            } else {
                print("⚠️ SLEEPER: No roster found for user \(sleeperCredentials.currentUserID) in league \(league.league.leagueID)")
                return nil
            }
        } catch {
            print("❌ SLEEPER: Failed to fetch rosters for league \(league.league.leagueID): \(error)")
            return nil
        }
    }
    
    /// Get current user's team ID for ESPN leagues
    private func getESPNUserTeamID() async -> String? {
        do {
            let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
            let myESPNID = AppConstants.GpESPNID
            
            if let teams = espnLeague.teams {
                for team in teams {
                    if let owners = team.owners, owners.contains(myESPNID) {
                        return String(team.id)
                    }
                }
            }
            
            print("❌ ESPN: Could not find team for SWID '\(myESPNID)' in league \(league.league.name)")
            return nil
        } catch {
            print("❌ ESPN: Failed to fetch team ownership for league \(league.league.leagueID): \(error)")
            return nil
        }
    }
    
    // MARK: -> Data Fetching
    
    /// Fetch all matchup data for this league
    func fetchMatchups() async throws -> [FantasyMatchup] {
        print("🔍 PROVIDER: Fetching matchups for \(league.league.name) week \(week)")
        
        // Clear previous state
        matchups = []
        byeWeekTeams = []
        choppedSummary = nil
        detectedAsChoppedLeague = false
        
        if league.source == .espn {
            await fetchESPNData()
        } else {
            await fetchSleeperData()
        }
        
        print("🎯 PROVIDER: Fetch complete - \(matchups.count) matchups for \(league.league.name)")
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
    
    /// Find user's matchup by team ID
    func findMyMatchup(myTeamID: String) -> FantasyMatchup? {
        print("🔍 PROVIDER: Looking for team ID '\(myTeamID)' in \(matchups.count) matchups")
        
        for (index, matchup) in matchups.enumerated() {
            print("   Matchup \(index + 1): Home=\(matchup.homeTeam.id) vs Away=\(matchup.awayTeam.id)")
            
            if matchup.homeTeam.id == myTeamID {
                print("🎯 PROVIDER: Found user as HOME team in matchup \(index + 1)")
                return matchup
            }
            
            if matchup.awayTeam.id == myTeamID {
                print("🎯 PROVIDER: Found user as AWAY team in matchup \(index + 1)")
                return matchup
            }
        }
        
        print("❌ PROVIDER: No matchup found for team ID '\(myTeamID)'")
        return nil
    }
    
    // MARK: -> ESPN Data Fetching
    
    private func fetchESPNData() async {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
            print("❌ ESPN: Invalid API URL")
            return
        }
        
        print("🔍 ESPN: Fetching \(league.league.leagueID) week \(week)")
        
        // First fetch league data for name resolution
        do {
            currentESPNLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
            print("✅ ESPN: Got league member data for name resolution")
        } catch {
            print("⚠️ ESPN: Failed to get league member data, using fallback names")
            currentESPNLeague = nil
        }
        
        // Now fetch matchup data
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            print("📊 ESPN: \(model.teams.count) teams, \(model.schedule.count) schedule entries")
            await processESPNData(model)
            
        } catch {
            print("❌ ESPN: Failed to fetch/decode data: \(error)")
        }
    }
    
    private func processESPNData(_ espnModel: ESPNFantasyLeagueModel) async {
        // Store team records and names
        for team in espnModel.teams {
            espnTeamNames[team.id] = team.name
            if let record = team.record?.overall {
                espnTeamRecords[team.id] = TeamRecord(
                    wins: record.wins,
                    losses: record.losses,
                    ties: record.ties
                )
            }
        }
        
        var processedMatchups: [FantasyMatchup] = []
        var byeTeams: [FantasyTeam] = []
        
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        print("🏈 ESPN: Week \(week) has \(weekSchedule.count) matchups")
        
        for scheduleEntry in weekSchedule {
            // Handle bye weeks
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
        
        print("🎯 ESPN: Created \(processedMatchups.count) matchups and \(byeTeams.count) bye week teams")
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
                    firstName: extractFirstName(from: player.fullName),
                    lastName: extractLastName(from: player.fullName),
                    position: positionString(entry.lineupSlotId),
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: nil,
                    currentPoints: weeklyScore,
                    projectedPoints: weeklyScore * 1.1,
                    gameStatus: createMockGameStatus(),
                    isStarter: [0, 2, 3, 4, 5, 6, 23, 16, 17].contains(entry.lineupSlotId),
                    lineupSlot: positionString(entry.lineupSlotId)
                )
            }
        }
        
        let record: TeamRecord?
        if let espnRecord = espnTeam.record?.overall {
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
        print("🔍 SLEEPER: Fetching data for \(league.league.leagueID) week \(week)")
        
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
            print("❌ SLEEPER: Failed to fetch scoring settings: \(error)")
        }
    }
    
    private func fetchSleeperWeeklyStats() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(year)/\(week)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            playerStats = statsData
        } catch {
            print("❌ SLEEPER: Failed to fetch weekly stats: \(error)")
        }
    }
    
    private func fetchSleeperUsersAndRosters() async {
        // Fetch rosters
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters") else { 
            print("❌ SLEEPER: Invalid rosters URL")
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            var newRosterMapping: [Int: String] = [:]
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    newRosterMapping[roster.rosterID] = ownerID
                }
            }
            rosterIDToManagerID = newRosterMapping
            
            // Fetch users
            await fetchSleeperUsers()
            
        } catch {
            print("❌ SLEEPER: Failed to fetch rosters: \(error)")
        }
    }
    
    private func fetchSleeperUsers() async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users") else { 
            print("❌ SLEEPER: Invalid users URL")
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
            print("❌ SLEEPER: Failed to fetch users: \(error)")
        }
    }
    
    private func fetchSleeperMatchups() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)") else {
            print("❌ SLEEPER: Invalid matchups URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            
            print("📊 SLEEPER: Received \(sleeperMatchups.count) matchups")
            
            if sleeperMatchups.isEmpty {
                print("🔥 CHOPPED: No matchups found - this might be a chopped league")
                detectedAsChoppedLeague = true
                return
            }
            
            await processSleeperMatchups(sleeperMatchups)
            
        } catch {
            print("❌ SLEEPER: Failed to fetch matchups: \(error)")
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
        print("🎯 SLEEPER: Processed \(processedMatchups.count) matchups")
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
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerScore * 1.1,
                        gameStatus: createMockGameStatus(),
                        isStarter: isStarter,
                        lineupSlot: sleeperPlayer.position
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        return FantasyTeam(
            id: String(matchupResponse.rosterID),
            name: managerName,
            ownerName: managerName,
            record: nil,
            avatar: avatarURL?.absoluteString,
            currentScore: matchupResponse.points,
            projectedScore: matchupResponse.projectedPoints,
            roster: fantasyPlayers,
            rosterID: matchupResponse.rosterID
        )
    }
    
    // MARK: -> Chopped League Support
    
    private func createChoppedSummary() async -> ChoppedWeekSummary? {
        // This would use the existing Chopped logic from FantasyViewModel+Chopped
        // For now, returning nil as this is complex and may not be needed immediately
        print("🔥 CHOPPED: Creating chopped summary for \(league.league.name)")
        return nil
    }
    
    // MARK: -> Helper Methods
    
    private func calculateSleeperPlayerScore(playerId: String) -> Double {
        guard let playerStats = playerStats[playerId],
              let scoringSettings = sleeperLeagueSettings else {
            return 0.0
        }
        
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
    
    private func extractFirstName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        return String(fullName.split(separator: " ").first ?? "")
    }
    
    private func extractLastName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        let components = fullName.split(separator: " ")
        return components.count > 1 ? String(components.last!) : nil
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
    
    private func createMockGameStatus() -> GameStatus {
        return GameStatus(
            status: "pregame",
            startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
            timeRemaining: nil,
            quarter: nil,
            homeScore: nil,
            awayScore: nil
        )
    }
}