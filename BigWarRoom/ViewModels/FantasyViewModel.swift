//
//  FantasyViewModel.swift
//  BigWarRoom
//
//  ViewModel for Fantasy matchup data and operations
//
// MARK: -> Fantasy ViewModel

import Foundation
import Combine
import SwiftUI

@MainActor
final class FantasyViewModel: ObservableObject {
    // MARK: -> Published Properties
    @Published var matchups: [FantasyMatchup] = []
    @Published var selectedLeague: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedWeek: Int = 1
    @Published var selectedYear: String = AppConstants.ESPNLeagueYear // FIXED: Use ESPN year from AppConstants
    @Published var autoRefresh: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: -> ESPN Data Storage
    @Published var espnTeamRecords: [Int: TeamRecord] = [:] // teamID -> record
    @Published var espnTeamNames: [Int: String] = [:] // teamID -> team name
    
    // MARK: -> Sleeper Data Storage (like SleepThis - CORRECT implementation)
    @Published var sleeperLeagueSettings: [String: Any]? = nil // Sleeper scoring settings
    @Published var playerStats: [String: [String: Double]] = [:] // Weekly player stats
    @Published var rosterIDToManagerID: [Int: String] = [:]
    @Published var userIDs: [String: String] = [:]  // userID -> display name
    @Published var userAvatars: [String: URL] = [:] // userID -> avatar URL
    
    // MARK: -> Picker Options
    let availableWeeks = Array(1...18) // NFL regular season + playoffs
    let availableYears = ["2023", "2024", "2025"]
    
    // MARK: -> Dependencies
    private let unifiedLeagueManager = UnifiedLeagueManager()
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: -> Initialization
    init() {
        setupAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: -> League Selection
    /// Set the selected league and fetch matchups
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper) {
        selectedLeague = league
        Task {
            await fetchMatchups()
        }
    }
    
    /// Available leagues from UnifiedLeagueManager
    var availableLeagues: [UnifiedLeagueManager.LeagueWrapper] {
        return unifiedLeagueManager.allLeagues
    }
    
    // MARK: -> Week/Year Selection
    /// Update selected week and refetch data
    func selectWeek(_ week: Int) {
        selectedWeek = week
        Task {
            await fetchMatchups()
        }
    }
    
    /// Update selected year and refetch data
    func selectYear(_ year: String) {
        selectedYear = year
        Task {
            await fetchMatchups()
        }
    }
    
    // MARK: -> Auto Refresh
    /// Toggle auto refresh on/off
    func toggleAutoRefresh() {
        autoRefresh.toggle()
        setupAutoRefresh()
    }
    
    /// Setup auto refresh timer
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        if autoRefresh {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                Task { @MainActor in
                    await self.refreshMatchups()
                }
            }
        }
    }
    
    // MARK: -> Data Fetching
    /// Fetch matchups for selected league, week, and year
    func fetchMatchups() async {
        guard let league = selectedLeague else {
            matchups = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🏈 Fetching matchups for league: '\(league.league.name)' (\(league.league.leagueID)) - Source: \(league.source)")
        
        do {
            // Check if this is an ESPN league
            if league.source == .espn {
                print("📺 Processing as ESPN league")
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                print("💤 Processing as Sleeper league")
                // FIXED: Sleeper league - fetch REAL matchups like SleepThis
                await fetchSleeperScoringSettings(leagueID: league.league.leagueID)
                await fetchSleeperWeeklyStats()
                await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                await fetchSleeperMatchups(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
        } catch {
            errorMessage = "Failed to load matchups: \(error.localizedDescription)"
            matchups = []
        }
        
        isLoading = false
    }
    
    // MARK: -> ESPN Fantasy Data Fetching (like SleepThis - CORRECT implementation)
    /// Fetch real ESPN fantasy data like SleepThis
    private func fetchESPNFantasyData(leagueID: String, week: Int) async {
        print("🏈 Fetching ESPN fantasy data for league: \(leagueID), week: \(week)")
        
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(selectedYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mStats&view=mTeam&view=modular&view=mNav&view=members_live&scoringPeriodId=\(week)") else {
            print("❌ Invalid ESPN Fantasy URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // FIXED: Use correct ESPN_S2 token based on year
        let espnToken = selectedYear == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        print("🔍 Using ESPN year: \(selectedYear)")
        print("🔍 Using ESPN token: \(selectedYear == "2025" ? "ESPN_S2_2025" : "ESPN_S2")")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ ESPN API request failed")
                return
            }
            
            // DEBUG: Print raw ESPN response to find avatar data
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔍 ESPN API Response (looking for avatar fields):")
                
                // Look specifically for avatar, photo, or image fields
                let lines = jsonString.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if line.lowercased().contains("avatar") || 
                       line.lowercased().contains("photo") || 
                       line.lowercased().contains("image") ||
                       line.lowercased().contains("members") {
                        // Print context around avatar mentions
                        let startIndex = max(0, index - 2)
                        let endIndex = min(lines.count - 1, index + 2)
                        print("--- Avatar context around line \(index) ---")
                        for i in startIndex...endIndex {
                            print(lines[i])
                        }
                        print("--- End context ---")
                    }
                }
            }
            
            // Parse ESPN Fantasy response using SleepThis model structure
            let espnModel = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            await processESPNFantasyData(espnModel: espnModel, leagueID: leagueID, week: week)
            
        } catch {
            print("❌ ESPN Fantasy API error: \(error)")
            errorMessage = "Failed to fetch ESPN fantasy data: \(error.localizedDescription)"
        }
    }
    
    /// Process ESPN Fantasy data into matchups (like SleepThis - CORRECT)
    private func processESPNFantasyData(espnModel: ESPNFantasyLeagueModel, leagueID: String, week: Int) async {
        print("🏈 Processing ESPN fantasy data - \(espnModel.teams.count) teams, \(espnModel.schedule.count) schedule entries")
        
        // Store team records and names for later lookup
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
        
        // Filter schedule for the selected week
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        
        for scheduleEntry in weekSchedule {
            let awayTeamId = scheduleEntry.away.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores using SleepThis method (CORRECT)
            let awayScore = calculateESPNTeamActiveScore(team: awayTeam, week: week)
            let homeScore = calculateESPNTeamActiveScore(team: homeTeam, week: week)
            
            // Create fantasy teams with real data
            let awayFantasyTeam = createFantasyTeamFromESPN(
                espnTeam: awayTeam,
                score: awayScore,
                leagueID: leagueID
            )
            
            let homeFantasyTeam = createFantasyTeamFromESPN(
                espnTeam: homeTeam,
                score: homeScore,
                leagueID: leagueID
            )
            
            // Create matchup
            let matchup = FantasyMatchup(
                id: "\(leagueID)_\(week)_\(awayTeamId)_\(homeTeamId)",
                leagueID: leagueID,
                week: week,
                year: selectedYear,
                homeTeam: homeFantasyTeam,
                awayTeam: awayFantasyTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil  // ESPN leagues don't have Sleeper data
            )
            
            processedMatchups.append(matchup)
            
            print("✅ Created ESPN matchup: \(awayTeam.name ?? "Away") (\(String(format: "%.2f", awayScore))) vs \(homeTeam.name ?? "Home") (\(String(format: "%.2f", homeScore)))")
        }
        
        matchups = processedMatchups
        print("🎯 Processed \(processedMatchups.count) ESPN matchups with REAL scores")
    }
    
    /// Calculate real ESPN team active score like SleepThis (CORRECT implementation)
    private func calculateESPNTeamActiveScore(team: ESPNFantasyTeamModel, week: Int) -> Double {
        guard let roster = team.roster else { return 0.0 }
        
        // ESPN active lineup slot IDs (same as SleepThis - CORRECT)
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17]
        
        return roster.entries
            .filter { activeSlotsOrder.contains($0.lineupSlotId) }
            .reduce(0.0) { sum, entry in
                // Get the actual fantasy points for this week (like SleepThis - CORRECT)
                let weeklyScore = entry.playerPoolEntry.player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                return sum + weeklyScore
            }
    }

    /// Create FantasyTeam from ESPN data (like SleepThis - CORRECT with REAL manager names)
    private func createFantasyTeamFromESPN(espnTeam: ESPNFantasyTeamModel, score: Double, leagueID: String) -> FantasyTeam {
        // Convert ESPN roster to fantasy players
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let roster = espnTeam.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == selectedWeek && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                return FantasyPlayer(
                    id: String(player.id),
                    sleeperID: nil,
                    espnID: String(player.id),
                    firstName: extractFirstName(from: player.fullName),
                    lastName: extractLastName(from: player.fullName),
                    position: positionString(entry.lineupSlotId),
                    team: nil, // Could be enhanced with team mapping
                    jerseyNumber: nil,
                    currentPoints: weeklyScore,  // REAL scoring
                    projectedPoints: weeklyScore * 1.1, // Mock projection
                    gameStatus: createMockGameStatus(),
                    isStarter: [0, 2, 3, 4, 5, 6, 23, 16, 17].contains(entry.lineupSlotId),  // CORRECT starter detection
                    lineupSlot: positionString(entry.lineupSlotId)
                )
            }
        }
        
        // Get team record
        let record = espnTeam.record?.overall.map { overall in
            TeamRecord(
                wins: overall.wins,
                losses: overall.losses,
                ties: overall.ties
            )
        }
        
        // FIXED: Use real team name as both name and ownerName for ESPN
        let teamName = espnTeam.name ?? "Team \(espnTeam.id)"
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: teamName, // Real team name like "DrLizard"
            ownerName: teamName, // Use team name as owner name for ESPN
            record: record,
            avatar: nil, // ESPN doesn't have user avatars, but team name shows instead
            currentScore: score, // Real calculated score using SleepThis method
            projectedScore: score * 1.05, // Mock projection
            roster: fantasyPlayers,
            rosterID: espnTeam.id
        )
    }
    
    // MARK: -> SLEEPER IMPLEMENTATION - FIXED to match SleepThis
    
    /// Fetch Sleeper league scoring settings (like SleepThis)
    private func fetchSleeperScoringSettings(leagueID: String) async {
        print("🏈 Fetching Sleeper scoring settings for league: \(leagueID)")
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["scoring_settings"] as? [String: Any] {
                sleeperLeagueSettings = settings
                print("✅ Sleeper scoring settings fetched: \(settings.keys.count) stats")
            }
        } catch {
            print("❌ Error fetching Sleeper scoring settings: \(error)")
        }
    }
    
    /// Fetch Sleeper weekly player stats (like SleepThis)
    private func fetchSleeperWeeklyStats() async {
        print("🏈 Fetching Sleeper weekly stats for week \(selectedWeek)")
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(selectedYear)/\(selectedWeek)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            playerStats = statsData
            print("✅ Sleeper weekly stats fetched for \(statsData.count) players")
        } catch {
            print("❌ Error fetching Sleeper weekly stats: \(error)")
        }
    }
    
    /// Fetch Sleeper league users and rosters (like SleepThis)
    private func fetchSleeperLeagueUsersAndRosters(leagueID: String) async {
        print("🏈 Fetching Sleeper users and rosters for league: \(leagueID)")
        
        // Fetch rosters first
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            // Store roster ID mappings
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    rosterIDToManagerID[roster.rosterID] = ownerID
                }
            }
            
            // Fetch users
            await fetchSleeperUsers(leagueID: leagueID)
            
        } catch {
            print("❌ Error fetching Sleeper rosters: \(error)")
        }
    }
    
    /// Fetch Sleeper users (like SleepThis)
    private func fetchSleeperUsers(leagueID: String) async {
        print("🔍 Fetching Sleeper users for league: \(leagueID)")
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else { 
            print("❌ Invalid users URL")
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            
            print("✅ Successfully decoded \(users.count) Sleeper users")
            
            for user in users {
                userIDs[user.userID] = user.displayName
                print("👤 User: \(user.displayName ?? "Unknown") (ID: \(user.userID))")
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    userAvatars[user.userID] = avatarURL
                    print("   🖼️ Avatar: https://sleepercdn.com/avatars/\(avatar)")
                } else {
                    print("   ❌ No avatar for user \(user.displayName ?? "Unknown")")
                }
            }
            
            print("📊 Final userIDs count: \(userIDs.count)")
            print("📊 Final userAvatars count: \(userAvatars.count)")
            print("🗂️ User IDs mapping: \(userIDs)")
            print("🖼️ Avatar URLs: \(userAvatars.mapValues { $0.absoluteString })")
            
        } catch {
            print("❌ Error fetching Sleeper users: \(error)")
        }
    }
    
    /// Fetch REAL Sleeper matchups (like SleepThis - CORRECT implementation)
    private func fetchSleeperMatchups(leagueID: String, week: Int) async {
        print("🏈 Fetching REAL Sleeper matchups for league: \(leagueID), week: \(week)")
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            print("❌ Invalid Sleeper matchup URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchup].self, from: data)
            
            if sleeperMatchups.isEmpty {
                errorMessage = "No matchups available for week \(week)"
                return
            }
            
            // Process REAL matchups like SleepThis
            await processSleeperMatchups(sleeperMatchups, leagueID: leagueID)
            
        } catch {
            print("❌ Error fetching Sleeper matchups: \(error)")
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }
    
    /// Process REAL Sleeper matchups (like SleepThis - CORRECT implementation)
    private func processSleeperMatchups(_ sleeperMatchups: [SleeperMatchup], leagueID: String) async {
        print("🏈 Processing \(sleeperMatchups.count) REAL Sleeper matchups")
        
        // Group by matchup_id to get pairs
        let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchup_id })
        var processedMatchups: [FantasyMatchup] = []
        
        for (_, matchups) in groupedMatchups where matchups.count == 2 {
            let team1 = matchups[0]
            let team2 = matchups[1]
            
            // Get manager info
            let awayManagerID = rosterIDToManagerID[team1.roster_id] ?? ""
            let homeManagerID = rosterIDToManagerID[team2.roster_id] ?? ""
            
            let awayManagerName = userIDs[awayManagerID] ?? "Manager \(team1.roster_id)"
            let homeManagerName = userIDs[homeManagerID] ?? "Manager \(team2.roster_id)"
            
            let awayAvatarURL = userAvatars[awayManagerID]
            let homeAvatarURL = userAvatars[homeManagerID]
            
            print("🔍 Away: roster \(team1.roster_id) -> manager \(awayManagerID) -> name '\(awayManagerName)' -> avatar \(awayAvatarURL?.absoluteString ?? "nil")")
            print("🔍 Home: roster \(team2.roster_id) -> manager \(homeManagerID) -> name '\(homeManagerName)' -> avatar \(homeAvatarURL?.absoluteString ?? "nil")")
            
            // Calculate REAL scores using ACTUAL starter lineups like SleepThis
            let awayScore = calculateSleeperTeamScore(matchup: team1)
            let homeScore = calculateSleeperTeamScore(matchup: team2)
            
            // Create fantasy teams with real scoring
            let awayTeam = createSleeperFantasyTeam(
                matchup: team1,
                managerName: awayManagerName,
                avatarURL: awayAvatarURL,
                score: awayScore
            )
            
            let homeTeam = createSleeperFantasyTeam(
                matchup: team2,
                managerName: homeManagerName,
                avatarURL: homeAvatarURL,
                score: homeScore
            )
            
            // Create matchup with REAL data
            let fantasyMatchup = FantasyMatchup(
                id: "\(leagueID)_\(selectedWeek)_\(team1.roster_id)_\(team2.roster_id)",
                leagueID: leagueID,
                week: selectedWeek,
                year: selectedYear,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: (team1, team2)  // Store real matchup data
            )
            
            processedMatchups.append(fantasyMatchup)
            
            print("✅ Sleeper matchup: \(awayManagerName) (\(String(format: "%.2f", awayScore))) vs \(homeManagerName) (\(String(format: "%.2f", homeScore)))")
        }
        
        matchups = processedMatchups
        print("🎯 Processed \(processedMatchups.count) REAL Sleeper matchups with accurate scoring")
    }
    
    /// Calculate Sleeper team score using REAL starter lineup (like SleepThis - CORRECT)
    private func calculateSleeperTeamScore(matchup: SleeperMatchup) -> Double {
        guard let starters = matchup.starters else { return 0.0 }
        
        return starters.reduce(0.0) { total, playerId in
            total + calculateSleeperPlayerScore(playerId: playerId)
        }
    }
    
    /// Calculate Sleeper player score using league settings (like SleepThis - CORRECT)
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
    
    /// Create Sleeper fantasy team with REAL manager names and avatars (FIXED)
    private func createSleeperFantasyTeam(
        matchup: SleeperMatchup,
        managerName: String,
        avatarURL: URL?,
        score: Double
    ) -> FantasyTeam {
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        // Create players from starters and bench
        if let allPlayers = matchup.players {
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                    let isStarter = matchup.starters?.contains(playerID) ?? false
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
        
        let avatarString = avatarURL?.absoluteString
        print("🎨 Creating FantasyTeam:")
        print("   Name: '\(managerName)'")
        print("   Avatar URL: '\(avatarString ?? "nil")'")
        print("   Score: \(score)")
        
        let team = FantasyTeam(
            id: String(matchup.roster_id),
            name: managerName, // REAL manager name like "TheRoadWarrior"
            ownerName: managerName, // REAL manager name
            record: nil,  // Would need roster data for record
            avatar: avatarString, // FIXED: Store full URL string
            currentScore: score,  // Real calculated score
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: matchup.roster_id
        )
        
        // DEBUG: Check what the avatarURL computed property returns
        print("   Computed avatarURL: '\(team.avatarURL?.absoluteString ?? "nil")'")
        
        return team
    }
    
    /// Calculate win probability based on scores
    private func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double {
        if homeScore == 0 && awayScore == 0 { return 0.5 }
        return homeScore / (homeScore + awayScore)
    }
    
    /// Extract first name from full name
    private func extractFirstName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        return String(fullName.split(separator: " ").first ?? "")
    }
    
    /// Extract last name from full name
    private func extractLastName(from fullName: String?) -> String? {
        guard let fullName = fullName else { return nil }
        let components = fullName.split(separator: " ")
        return components.count > 1 ? String(components.last!) : nil
    }
    
    /// Convert ESPN lineup slot ID to position string
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
    
    /// Refresh matchups (for auto-refresh)
    func refreshMatchups() async {
        await fetchMatchups()
    }
    
    /// Create mock game status for testing
    private func createMockGameStatus() -> GameStatus {
        let statuses = ["pregame", "live", "postgame", "bye"]
        let randomStatus = statuses.randomElement() ?? "pregame"
        
        return GameStatus(
            status: randomStatus,
            startTime: Calendar.current.date(byAdding: .hour, value: Int.random(in: 1...6), to: Date()),
            timeRemaining: randomStatus == "live" ? "14:32" : nil,
            quarter: randomStatus == "live" ? "2nd" : nil,
            homeScore: randomStatus != "pregame" ? Int.random(in: 0...35) : nil,
            awayScore: randomStatus != "pregame" ? Int.random(in: 0...35) : nil
        )
    }
    
    // MARK: -> Load Leagues
    /// Load available leagues on app start
    func loadLeagues() async {
        // FIXED: Pass Sleeper user ID and season to get both ESPN and Sleeper leagues
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: AppConstants.GpSleeperID, 
            season: selectedYear
        )
    }
    
    // MARK: -> Helper Methods for Detail View
    
    /// Get score for a team in a matchup
    func getScore(for matchup: FantasyMatchup, teamIndex: Int) -> Double {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        return team.currentScore ?? 0.0
    }
    
    /// Get manager record for display with real ESPN data
    func getManagerRecord(managerID: String) -> String {
        // For ESPN leagues, look up the team record
        if let selectedLeague = selectedLeague, selectedLeague.source == .espn {
            if let teamID = Int(managerID),
               let record = espnTeamRecords[teamID] {
                return "\(record.wins)-\(record.losses) • Rank: 2nd"
            }
        }
        // Fallback
        return "0-0 • Rank: 2nd"
    }
    
    /// Get score difference text for VS section
    func scoreDifferenceText(matchup: FantasyMatchup) -> String {
        let awayScore = getScore(for: matchup, teamIndex: 0)
        let homeScore = getScore(for: matchup, teamIndex: 1)
        return String(format: "%.2f", abs(awayScore - homeScore))
    }
    
    /// Active roster section view
    func activeRosterSection(matchup: FantasyMatchup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Roster")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Active Roster
                VStack(spacing: 8) {
                    let awayActiveRoster = getRoster(for: matchup, teamIndex: 0, isBench: false)
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(player: player, fantasyViewModel: self)
                    }
                    
                    let awayScore = getScore(for: matchup, teamIndex: 0)
                    let homeScore = getScore(for: matchup, teamIndex: 1)
                    let awayWinning = awayScore > homeScore
                    
                    Text("Active Total: \(String(format: "%.2f", awayScore))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(awayWinning ? .gpGreen : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Home Team Active Roster
                VStack(spacing: 8) {
                    let homeActiveRoster = getRoster(for: matchup, teamIndex: 1, isBench: false)
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(player: player, fantasyViewModel: self)
                    }
                    
                    let awayScore = getScore(for: matchup, teamIndex: 0)
                    let homeScore = getScore(for: matchup, teamIndex: 1)
                    let homeWinning = homeScore > awayScore
                    
                    Text("Active Total: \(String(format: "%.2f", homeScore))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(homeWinning ? .gpGreen : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Bench section view
    func benchSection(matchup: FantasyMatchup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Bench
                VStack(spacing: 8) {
                    let awayBenchRoster = getRoster(for: matchup, teamIndex: 0, isBench: true)
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(player: player, fantasyViewModel: self)
                    }
                    
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    Text("Bench Total: \(String(format: "%.2f", benchTotal))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Home Team Bench
                VStack(spacing: 8) {
                    let homeBenchRoster = getRoster(for: matchup, teamIndex: 1, isBench: true)
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(player: player, fantasyViewModel: self)
                    }
                    
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    Text("Bench Total: \(String(format: "%.2f", benchTotal))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Get roster for a team (active or bench)
    private func getRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        return team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
    }
}