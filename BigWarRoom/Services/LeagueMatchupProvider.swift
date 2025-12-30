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
    private var sleeperLeague: SleeperLeague?  // 🔥 NEW: Store full league for FAAB and other settings
    private var playerStats: [String: [String: Double]] = [:]
    private var rosterIDToManagerID: [Int: String] = [:]
    private var userIDs: [String: String] = [:]
    private var userAvatars: [String: URL] = [:]
    private var sleeperRosters: [SleeperRoster] = []  // 🔥 NEW: Store rosters for record lookup
    
    // MARK: -> Dependencies
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private let sleeperCredentials = SleeperCredentialsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 🔥 PHASE 3 DI: Store optional reference to FantasyViewModel for syncing (passed from caller)
    private weak var fantasyViewModel: FantasyViewModel?
    
    // MARK: -> Initialization
    init(league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String, fantasyViewModel: FantasyViewModel? = nil) {
        self.league = league
        self.week = week
        self.year = year
        self.fantasyViewModel = fantasyViewModel
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
        DebugPrint(mode: .leagueProvider, "fetchMatchups() called for \(league.league.leagueID), source=\(league.source)")
        // Clear previous state
        matchups = []
        byeWeekTeams = []
        choppedSummary = nil
        detectedAsChoppedLeague = false
        
        if league.source == .espn {
            DebugPrint(mode: .leagueProvider, "Fetching ESPN data")
            await fetchESPNData()
        } else {
            DebugPrint(mode: .leagueProvider, "Fetching Sleeper data")
            await fetchSleeperData()
        }
        
        DebugPrint(mode: .leagueProvider, "Returning \(matchups.count) matchups")
        return matchups
    }
    
    /// Check if this is a Chopped league
    func isChoppedLeague() -> Bool {
        guard league.source == .sleeper else { return false }
        
        // Prefer league settings (reliable, available at app launch).
        if league.league.settings?.isChoppedLeague == true {
            return true
        }
        
        // Fallback: heuristic detection if settings are missing.
        return matchups.isEmpty && detectedAsChoppedLeague
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
        DebugPrint(mode: .recordCalculation, "Starting calculation for league \(leagueID)")

        // Get all past weeks (1-8 since we're in week 9)
        let pastWeeks = 1..<week
        var teamRecords: [Int: TeamRecord] = [:]

        for pastWeek in pastWeeks {
            do {
                DebugPrint(mode: .recordCalculation, limit: 5, "Calculating records for week \(pastWeek)...")

                // Fetch matchup data for this past week
                guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(pastWeek)") else {
                    DebugPrint(mode: .recordCalculation, "Failed to create URL for week \(pastWeek)")
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
            // 🔥 PHASE 3 DI: Only sync if FantasyViewModel was provided
            if fantasyViewModel != nil {
                await syncESPNDataToMainViewModel()
            }
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
            
            // 🔥 DRY FIX: Only sync if FantasyViewModel was provided
            if fantasyViewModel != nil {
                await syncESPNRecordsToViewModel()
            }

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
            if AppConstants.debug, let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 LeagueMatchupProvider ESPN API Keys: \(jsonObject.keys.sorted())")
                if jsonObject["positionAgainstOpponent"] != nil {
                    print("✅ positionAgainstOpponent EXISTS in LeagueMatchupProvider response")
                } else {
                    print("❌ positionAgainstOpponent NOT FOUND in LeagueMatchupProvider response")
                }
            }
            
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            // Also try to decode full ESPNLeague for OPRK data
            if let fullLeagueData = try? JSONDecoder().decode(ESPNLeague.self, from: data) {
                OPRKService.shared.updateOPRKData(from: fullLeagueData)
            }
            await processESPNData(model)
        } catch {
            // Silent fail - matchup data couldn't be loaded
        }
    }
    
    private func processESPNData(_ espnModel: ESPNFantasyLeagueModel) async {
        DebugPrint(mode: .espnAPI, "processESPNData called for \(espnModel.teams.count) teams")
        
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
            // DebugPrint(mode: .lineupRX, "🔍 ESPN ROSTER DEBUG for team \(espnTeam.id):")
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let slotId = entry.lineupSlotId
                let isActive = LineupSlots.isActiveSlot(slotId)
                
                // DebugPrint(mode: .lineupRX, "  Player: \(player.fullName.firstName ?? "") \(player.fullName.lastName ?? "") | Slot: \(slotId) (\(positionString(slotId))) | isStarter: \(isActive)")
                
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                // 💊 MAP ESPN ID TO SLEEPER ID for Lineup RX projections
                let espnIDString = String(player.id)
                var sleeperPlayer = playerDirectoryStore.playerByESPNID(espnIDString)
                var sleeperID = sleeperPlayer?.playerID
                
                // Fallback: Search by name if ESPN ID mapping fails
                if sleeperID == nil {
                    let firstName = player.fullName.firstName ?? ""
                    let lastName = player.fullName.lastName ?? ""
                    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    
                    // Search through all players for a name match
                    sleeperPlayer = playerDirectoryStore.players.values.first { sleeperPlayer in
                        let sleeperFullName = "\(sleeperPlayer.firstName ?? "") \(sleeperPlayer.lastName ?? "")".trimmingCharacters(in: .whitespaces)
                        return sleeperFullName.lowercased() == fullName.lowercased()
                    }
                    sleeperID = sleeperPlayer?.playerID
                }
                
                // 🔥 CRITICAL FIX: Use player's ACTUAL position from Sleeper, not slot position
                let actualPosition = sleeperPlayer?.position ?? positionString(entry.lineupSlotId)
                
                // 🔥 MODEL-BASED ENRICHMENT: Get injury status from looked-up Sleeper player
                let injuryStatus = sleeperPlayer?.injuryStatus
                
                return FantasyPlayer(
                    id: String(player.id),
                    sleeperID: sleeperID,
                    espnID: espnIDString,
                    firstName: player.fullName.firstName,
                    lastName: player.fullName.lastName,
                    position: actualPosition,  // 🔥 Use ACTUAL position, not slot!
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: getJerseyNumberForPlayer(espnID: espnIDString, team: player.nflTeamAbbreviation, name: "\(player.fullName.firstName) \(player.fullName.lastName)"),
                    currentPoints: weeklyScore,
                    projectedPoints: weeklyScore * 1.1,
                    gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: player.nflTeamAbbreviation),
                    isStarter: LineupSlots.isActiveSlot(entry.lineupSlotId),
                    lineupSlot: positionString(entry.lineupSlotId),
                    injuryStatus: injuryStatus  // 🔥 NEW: Pass injury status from looked-up Sleeper player
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
        
        // 🔥 NEW: Get team logo URL from ESPN league data
        let teamLogoURL: String? = {
            DebugPrint(mode: .espnAPI, "🎭 AVATAR DEBUG: Processing ESPN team ID \(espnTeam.id)")
            DebugPrint(mode: .espnAPI, "   currentESPNLeague exists? \(currentESPNLeague != nil)")
            
            if let espnLeague = currentESPNLeague {
                DebugPrint(mode: .espnAPI, "   Looking for team \(espnTeam.id) in \(espnLeague.teams?.count ?? 0) teams")
                
                if let espnTeamData = espnLeague.teams?.first(where: { $0.id == espnTeam.id }) {
                    DebugPrint(mode: .espnAPI, "   ✅ Found team data for \(espnTeam.id)")
                    DebugPrint(mode: .espnAPI, "   Team logo field: \(espnTeamData.logo ?? "nil")")
                    DebugPrint(mode: .espnAPI, "   Team logoURL: \(espnTeamData.logoURL?.absoluteString ?? "nil")")
                    
                    let logoURL = espnTeamData.logoURL?.absoluteString
                    DebugPrint(mode: .espnAPI, "   🎯 Setting avatar to: \(logoURL ?? "nil")")
                    return logoURL
                } else {
                    DebugPrint(mode: .espnAPI, "   ❌ Team \(espnTeam.id) NOT FOUND in currentESPNLeague.teams")
                }
            } else {
                DebugPrint(mode: .espnAPI, "   ❌ currentESPNLeague is nil!")
            }
            
            DebugPrint(mode: .espnAPI, "   🎯 Final avatar value: nil")
            return nil
        }()
        
        DebugPrint(mode: .espnAPI, "🎭 CREATING FantasyTeam for \(realTeamName) with avatar: \(teamLogoURL ?? "nil")")
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: realTeamName,
            ownerName: realTeamName,
            record: record,
            avatar: teamLogoURL,  // 🔥 FIXED: Pass through ESPN team logo URL
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: espnTeam.id,
            faabTotal: nil,  // 🔥 NEW: ESPN doesn't use FAAB
            faabUsed: nil    // 🔥 NEW: ESPN doesn't use FAAB
        )
    }
    
    // MARK: -> Sleeper Data Fetching
    
    private func fetchSleeperData() async {
        // 🔥 PERF: We already have a `SleeperLeague` from `UnifiedLeagueManager.fetchAllLeagues()`.
        // Avoid re-fetching `/league/{id}` per league when possible.
        if sleeperLeague == nil {
            sleeperLeague = league.league
        }
        if sleeperLeagueSettings == nil, let scoringSettings = league.league.scoringSettings {
            var asAny: [String: Any] = [:]
            for (k, v) in scoringSettings {
                asAny[k] = v
            }
            sleeperLeagueSettings = asAny
        }
        
        // Fallback (should be rare): fetch full league to get scoring settings if missing.
        if sleeperLeagueSettings == nil {
            await fetchSleeperScoringSettings()
        }
        
        // 🔥 PERF: Parallelize independent pre-reqs.
        // CRITICAL: We MUST await rosters/users before processing matchups because matchup processing
        // needs manager names + roster->owner mapping. A previous implementation accidentally didn't
        // await these tasks, causing intermittent "Manager 1/2" fallbacks (race condition).
        async let statsTask: Void = fetchSleeperWeeklyStats()
        async let usersRostersTask: Void = fetchSleeperUsersAndRosters()
        _ = await (statsTask, usersRostersTask)

        await fetchSleeperMatchups()
    }
    
    private func fetchSleeperScoringSettings() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 🔥 FIXED: Decode and store the FULL SleeperLeague object
            let fullLeague = try JSONDecoder().decode(SleeperLeague.self, from: data)
            sleeperLeague = fullLeague
            
            // Also keep the scoring settings dictionary for backward compatibility
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["scoring_settings"] as? [String: Any] {
                sleeperLeagueSettings = settings
            }
        } catch {
            // Silent fail
        }
    }
    
    private func fetchSleeperWeeklyStats() async {
        do {
            // IMPORTANT: Never force-refresh week stats from inside per-league providers.
            // When multiple leagues load concurrently, force-refresh causes SharedStatsService to cancel
            // in-flight requests and re-fetch repeatedly, which blows up load times.
            let sharedStats = try await SharedStatsService.shared.loadWeekStats(
                week: week, 
                year: year, 
                forceRefresh: false
            )
            playerStats = sharedStats
            
            if AppConstants.debug {
                print("🔥 LeagueMatchupProvider: Loaded shared stats for \(sharedStats.count) players (week \(week))")
                
                // Debug: Log a few sample scores for consistency tracking
                let samplePlayers = Array(sharedStats.prefix(3))
                for (playerId, stats) in samplePlayers {
                    let pprScore = stats["pts_ppr"] ?? stats["pts_std"] ?? 0.0
                    print("🔥 LeagueMatchupProvider STATS: Player \(playerId) = \(pprScore) pts")
                }
            }
        } catch {
            playerStats = [:]  // Set empty to prevent crashes
            if AppConstants.debug {
                print("❌ LeagueMatchupProvider: Failed to load stats: \(error)")
            }
        }
    }
    
    private func fetchSleeperUsersAndRosters() async {
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters"),
              let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users") else {
            return
        }
        
        do {
            // 🔥 PERF: Fetch rosters + users concurrently
            async let rostersResponse = URLSession.shared.data(from: rostersURL)
            async let usersResponse = URLSession.shared.data(from: usersURL)
            let ((rostersData, _), (usersData, _)) = try await (rostersResponse, usersResponse)
            
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: rostersData)
            
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
            DebugPrint(mode: .dataSync, limit: 5, "Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
        
            // NOTE: `/league/{id}/users` returns league-scoped users with team metadata.
            // Decode as `SleeperLeagueUser` (NOT `SleeperUser`).
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: usersData)
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for user in users {
                // Prefer team name, then display name, then a stable fallback
                let resolvedName = user.teamName ?? user.displayName ?? "Team \(user.userID)"
                newUserIDs[user.userID] = resolvedName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    newUserAvatars[user.userID] = avatarURL
                }
            }
            
            userIDs = newUserIDs
            userAvatars = newUserAvatars
            
        } catch {
            DebugPrint(mode: .sleeperAPI, "Failed to fetch Sleeper rosters: \(error)")
        }
    }
    
    private func fetchSleeperUsers() async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users") else { 
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: usersURL)
            // NOTE: `/league/{id}/users` returns league-scoped users with team metadata.
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: data)
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for user in users {
                let resolvedName = user.teamName ?? user.displayName ?? "Team \(user.userID)"
                newUserIDs[user.userID] = resolvedName
                
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
        
        // 🔥 DRY FIX: Only sync if FantasyViewModel was provided
        if fantasyViewModel != nil {
            await syncESPNRecordsToViewModel()
        }
    }
    
    private func createSleeperFantasyTeam(
        matchupResponse: SleeperMatchupResponse,
        managerName: String,
        avatarURL: URL?
    ) -> FantasyTeam {
        var fantasyPlayers: [FantasyPlayer] = []
        
        // 🔥 KEY FIX: Get roster_positions from league to map starters to slots
        let rosterPositions = league.league.rosterPositions ?? []
        
        if let allPlayers = matchupResponse.players,
           let starterIDs = matchupResponse.starters {
            
            DebugPrint(mode: .lineupRX, "🎯 SLEEPER ROSTER MAPPING:")
            DebugPrint(mode: .lineupRX, "   Roster positions: \(rosterPositions)")
            DebugPrint(mode: .lineupRX, "   Starters count: \(starterIDs.count)")
            
            // 🔥 THE KEY: Map starters to their actual slots using array indices
            var starterSlotMap: [String: String] = [:]
            for (index, playerID) in starterIDs.enumerated() {
                if index < rosterPositions.count {
                    let slot = rosterPositions[index]
                    starterSlotMap[playerID] = slot
                    
                    if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                        DebugPrint(mode: .lineupRX, "   Starter \(index): \(sleeperPlayer.fullName) → \(slot)")
                    }
                }
            }
            
            // Process all players
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                    let isStarter = starterIDs.contains(playerID)
                    let playerScore = calculateSleeperPlayerScore(playerId: playerID)
                    let playerTeam = sleeperPlayer.team ?? getPlayerTeamFromCache(playerID) ?? "UNK"
                    let playerPosition = sleeperPlayer.position ?? "FLEX"
                    
                    // 🔥 FIX: Use the actual slot from mapping, not just position
                    let lineupSlot = isStarter ? starterSlotMap[playerID] : nil
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: playerPosition,
                        team: playerTeam,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerScore * 1.1,
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: playerTeam),
                        isStarter: isStarter,
                        lineupSlot: lineupSlot,
                        injuryStatus: sleeperPlayer.injuryStatus  // 🔥 NEW: Pass injury status from Sleeper data
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        // 🔥 NEW: Get roster record data
        let rosterRecord: TeamRecord? = {
            
            if let roster = sleeperRosters.first(where: { $0.rosterID == matchupResponse.rosterID }) {
                DebugPrint(mode: .fantasy, "🔍 Creating team for roster \(matchupResponse.rosterID):")
                DebugPrint(mode: .fantasy, "   Root level: wins=\(roster.wins ?? 0), losses=\(roster.losses ?? 0)")
                
                // Try root level first
                if let wins = roster.wins, let losses = roster.losses {
                    DebugPrint(mode: .fantasy, "✅ Record found for roster \(matchupResponse.rosterID): \(wins)-\(losses) (root level)")
                    return TeamRecord(
                        wins: wins,
                        losses: losses,
                        ties: roster.ties ?? 0
                    )
                }
                
                // Fallback to settings object
                if let wins = roster.settings?.wins, let losses = roster.settings?.losses {
                    DebugPrint(mode: .fantasy, "✅ Record found for roster \(matchupResponse.rosterID): \(wins)-\(losses) (settings)")
                    return TeamRecord(
                        wins: wins,
                        losses: losses,
                        ties: roster.settings?.ties ?? 0
                    )
                }
                
                DebugPrint(mode: .fantasy, "❌ NO record data for roster \(matchupResponse.rosterID) - wins/losses not in root or settings")
            } else {
                DebugPrint(mode: .fantasy, "❌ Roster not found for rosterID \(matchupResponse.rosterID) (sleeperRosters.count=\(sleeperRosters.count))")
            }
            return nil
        }()
        
        // 🔥 NEW: Get FAAB data from roster and league settings
        let faabTotal: Int? = sleeperLeague?.settings?.waiverBudget
        
        let faabUsed: Int? = {
            // Get FAAB already spent from roster
            if let roster = sleeperRosters.first(where: { $0.rosterID == matchupResponse.rosterID }) {
                // Try root level first
                if let used = roster.waiversBudgetUsed {
                    return used
                }
                // Fallback to settings object
                if let settings = roster.settings, let used = settings.waiver_budget_used {
                    return used
                }
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
            rosterID: matchupResponse.rosterID,
            faabTotal: faabTotal,
            faabUsed: faabUsed
        )
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
    
    /// Calculate win probability using WinProbabilityEngine SSOT
    private func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double? {
        return WinProbabilityEngine.shared.calculateWinProbability(myScore: homeScore, opponentScore: awayScore)
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
    
    // 🔥 NEW: Sync ESPN data to FantasyViewModel for score breakdowns (if provided)
    private func syncESPNDataToMainViewModel() async {
        guard let espnLeague = currentESPNLeague,
              let viewModel = fantasyViewModel else { return }
        
        await MainActor.run {
            viewModel.currentESPNLeague = espnLeague
        }
        
        // 🔥 DRY FIX: Sync records after league data is set
        await syncESPNRecordsToViewModel()
    }
    
    /// 🔥 DRY FIX: Centralized function to sync ESPN team records to FantasyViewModel (if provided)
    private func syncESPNRecordsToViewModel() async {
        guard let viewModel = fantasyViewModel else { return }
        
        await MainActor.run {
            // Sync all calculated records to FantasyViewModel for use in getManagerRecord
            for (teamId, record) in espnTeamRecords {
                viewModel.espnTeamRecords[teamId] = record
            }
            if !espnTeamRecords.isEmpty {
                DebugPrint(mode: .recordCalculation, "Synced \(espnTeamRecords.count) ESPN team records to FantasyViewModel")
            }
        }
    }
}