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
    @Published var byeWeekTeams: [FantasyTeam] = []  // NEW: Teams on bye week
    @Published var selectedLeague: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedWeek: Int = 1 // Will be synced with NFLWeekService
    @Published var selectedYear: String = String(Calendar.current.component(.year, from: Date())) // FIXED: Use current year dynamically
    @Published var autoRefresh: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showWeekSelector: Bool = false  // NEW: Controls week selector sheet

    @Published var nflGameService = NFLGameDataService.shared

    // Make nflWeekService publicly accessible for UI
    private let nflWeekService = NFLWeekService.shared
    
    // Public getter for UI access
    var currentNFLWeek: Int {
        return nflWeekService.currentWeek
    }
    
    // MARK: -> ESPN Data Storage
    @Published var espnTeamRecords: [Int: TeamRecord] = [:]
    @Published var espnTeamNames: [Int: String] = [:]
    
    // MARK: -> Sleeper Data Storage (like SleepThis - CORRECT implementation)
    @Published var sleeperLeagueSettings: [String: Any]? = nil
    @Published var playerStats: [String: [String: Double]] = [:]
    @Published var rosterIDToManagerID: [Int: String] = [:]
    @Published var userIDs: [String: String] = [:]
    @Published var userAvatars: [String: URL] = [:]
    
    // MARK: -> Picker Options
    let availableWeeks = Array(1...18)
    let availableYears = ["2023", "2024", "2025"] // FIXED: Include current and future years
    
    // MARK: -> Dependencies
    private let unifiedLeagueManager = UnifiedLeagueManager()
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private var sharedDraftRoomViewModel: DraftRoomViewModel?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: -> Initialization
    init() {
        setupAutoRefresh()
        subscribeToNFLWeekService()
        setupInitialNFLGameData()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    /// Subscribe to NFL Week Service updates
    private func subscribeToNFLWeekService() {
        // Update selectedWeek when NFL week service updates
        nflWeekService.$currentWeek
            .sink { [weak self] newWeek in
                if self?.selectedWeek != newWeek {
                    self?.selectedWeek = newWeek
                    self?.refreshNFLGameData()
                }
            }
            .store(in: &cancellables)
        
        // Update selectedYear when NFL week service updates
        nflWeekService.$currentYear
            .sink { [weak self] newYear in
                if self?.selectedYear != newYear {
                    self?.selectedYear = newYear
                    self?.refreshNFLGameData()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Setup initial NFL game data
    private func setupInitialNFLGameData() {
        let currentWeek = nflWeekService.currentWeek
        let currentYear = Int(nflWeekService.currentYear) ?? 2024
        
        // Fetch real NFL game data
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        // Start live updates if it's during NFL game time (Sunday/Monday/Thursday)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // Start live updates on game days (Sunday=1, Monday=2, Thursday=5)
        if [1, 2, 5].contains(weekday) {
            nflGameService.startLiveUpdates(forWeek: currentWeek, year: currentYear)
        }
    }
    
    /// Refresh NFL game data when week changes
    private func refreshNFLGameData() {
        let currentWeek = selectedWeek
        let currentYear = Int(selectedYear) ?? 2024
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear, forceRefresh: true)
    }
    
    /// Set the shared DraftRoomViewModel for manager name resolution
    func setSharedDraftRoomViewModel(_ viewModel: DraftRoomViewModel) {
        sharedDraftRoomViewModel = viewModel
    }
    
    // MARK: -> League Selection (Simplified)
    /// Set the connected league from War Room (no switching allowed)
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper) {
        selectedLeague = league
        
        // Clear all cached data to ensure fresh load
        matchups = []
        byeWeekTeams = []  // Clear bye week teams too
        errorMessage = nil
        
        // Clear ESPN-specific data
        espnTeamRecords.removeAll()
        espnTeamNames.removeAll()
        
        // Clear Sleeper-specific data
        sleeperLeagueSettings = nil
        playerStats.removeAll()
        rosterIDToManagerID.removeAll()
        userIDs.removeAll()
        userAvatars.removeAll()
        
        Task {
            await fetchMatchups()
        }
    }
    
    /// Available leagues from UnifiedLeagueManager (for internal use only)
    var availableLeagues: [UnifiedLeagueManager.LeagueWrapper] {
        return unifiedLeagueManager.allLeagues
    }
    
    // MARK: -> Auto Refresh (KEEP for live updates)
    /// Toggle auto refresh on/off
    func toggleAutoRefresh() {
        autoRefresh.toggle()
        setupAutoRefresh()
    }
    
    /// Setup auto refresh timer - FIXED to use AppConstants.MatchupRefresh
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        if autoRefresh {
            // Use AppConstants.MatchupRefresh for configurable timing
            let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
                Task { @MainActor in
                    // Only refresh if app is active and not during user interaction
                    if UIApplication.shared.applicationState == .active {
                        await self.refreshMatchups()
                    }
                }
            }
        }
    }
    
    // MARK: -> Data Fetching
    /// Fetch matchups for selected league, week, and year - FIXED to show proper loading states
    func fetchMatchups() async {
        guard let league = selectedLeague else {
            matchups = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // FIXED: Only clear matchups if this is a new league selection, not a refresh
        if matchups.isEmpty || matchups.first?.leagueID != league.league.leagueID {
            matchups = []
        }
        
        let startTime = Date()
        
        do {
            // Check if this is an ESPN league
            if league.source == .espn {
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                await fetchSleeperScoringSettings(leagueID: league.league.leagueID)
                await fetchSleeperWeeklyStats()
                await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                await fetchSleeperMatchups(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
        } catch {
            errorMessage = "Failed to load matchups: \(error.localizedDescription)"
            if matchups.isEmpty {
                matchups = []
            }
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minimumLoadingTime: TimeInterval = 2.0 // 2 seconds minimum
        
        if elapsedTime < minimumLoadingTime {
            let remainingTime = minimumLoadingTime - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        isLoading = false
    }
    
    // MARK: -> ESPN Fantasy Data Fetchinging (like SleepThis - CORRECT implementation)
    /// Fetch real ESPN fantasy data - FIXED: Use same Combine approach as working test view
    private func fetchESPNFantasyData(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(selectedYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
            errorMessage = "Invalid ESPN API URL"
            return
        }
        
        print("🔍 ESPN: Fetching \(leagueID) week \(week)")
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = selectedYear == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        // FIXED: Use EXACT same approach as working ESPNFantasyTestView
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                // LOG BASIC INFO WITH NSLog
                NSLog("📡 ESPN: Received \(data.count) bytes for \(leagueID)")
                
                // Try to parse and log just the schedule info
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let schedule = json["schedule"] as? [[String: Any]] {
                    NSLog("📊 ESPN: \(leagueID) has \(schedule.count) total schedule entries")
                    
                    let currentWeekEntries = schedule.filter { entry in
                        if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                            return matchupPeriodId == week
                        }
                        return false
                    }
                    NSLog("🏈 ESPN: \(leagueID) has \(currentWeekEntries.count) entries for week \(week)")
                }
            })
            .decode(type: ESPNFantasyLeagueModel.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure(let error):
                    NSLog("❌ ESPN Decode Error for \(leagueID): \(error)")
                    self?.tryAlternateTokenSync(url: url, leagueID: leagueID, week: week)
                case .finished:
                    NSLog("✅ ESPN Success for \(leagueID)")
                }
            }, receiveValue: { [weak self] model in
                NSLog("📊 ESPN \(leagueID): \(model.teams.count) teams, \(model.schedule.count) schedule")
                Task {
                    await self?.processESPNFantasyDataLikeTestView(espnModel: model, leagueID: leagueID, week: week)
                }
            })
            .store(in: &cancellables)
    }
    
    /// Try alternate ESPN token synchronously 
    private func tryAlternateTokenSync(url: URL, leagueID: String, week: Int) {
        let alternateToken = selectedYear == "2025" ? AppConstants.ESPN_S2 : AppConstants.ESPN_S2_2025
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(alternateToken)", forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure:
                    // Check what's actually in the schedule
                    self?.debugScheduleStructure(data: nil, leagueID: leagueID)
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] data in
                self?.debugScheduleStructure(data: data, leagueID: leagueID)
            })
            .store(in: &cancellables)
    }
    
    /// Debug just the schedule structure - BETTER VISIBILITY
    private func debugScheduleStructure(data: Data?, leagueID: String) {
        guard let data = data else {
            NSLog("❌ \(leagueID): No data received")
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("❌ \(leagueID): Could not parse JSON at all");
            return
        }
        
        // Print top-level keys first
        NSLog("🔍 \(leagueID): Top-level keys: \(Array(json.keys).sorted())");
        
        guard let schedule = json["schedule"] as? [[String: Any]] else {
            NSLog("❌ \(leagueID): No schedule array found");
            return
        }
        
        NSLog("📊 \(leagueID): \(schedule.count) total schedule entries");
        
        // Look for current week entries
        let currentWeekEntries = schedule.filter { entry in
            if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                return matchupPeriodId == selectedWeek;
            }
            return false
        }
        
        NSLog("🏈 \(leagueID): \(currentWeekEntries.count) entries for week \(selectedWeek)");
        
        // Examine each current week entry in detail
        for (index, entry) in currentWeekEntries.enumerated() {
            NSLog("🔍 \(leagueID): Schedule entry \(index + 1) keys: \(Array(entry.keys).sorted())");
            
            // Check for away/home structure
            if let away = entry["away"] as? [String: Any] {
                NSLog("✅ \(leagueID): Entry \(index + 1) HAS 'away' key with: \(Array(away.keys).sorted())");
            } else {
                NSLog("❌ \(leagueID): Entry \(index + 1) MISSING 'away' key!");
            }
            
            if let home = entry["home"] as? [String: Any] {
                NSLog("✅ \(leagueID): Entry \(index + 1) HAS 'home' key with: \(Array(home.keys).sorted())");
            } else {
                NSLog("❌ \(leagueID): Entry \(index + 1) MISSING 'home' key!");
            }
            
            // Print matchup period info
            if let matchupPeriodId = entry["matchupPeriodId"] as? Int {
                NSLog("📅 \(leagueID): Entry \(index + 1) matchupPeriodId: \(matchupPeriodId)");
            }
            
            // Print the full structure of this entry
            if let prettyEntry = try? JSONSerialization.data(withJSONObject: entry, options: .prettyPrinted),
               let prettyString = String(data: prettyEntry, encoding: .utf8) {
                // Split into smaller chunks to avoid truncation
                let lines = prettyString.components(separatedBy: .newlines);
                NSLog("📋 \(leagueID): Entry \(index + 1) structure START:");
                for line in lines.prefix(50) { // Only first 50 lines
                    NSLog("   \(line)");
                }
                NSLog("📋 \(leagueID): Entry \(index + 1) structure END");
            }
        }
    }
    
    /// Try alternate ESPN token if first attempt fails
    private func tryAlternateESPNToken(url: URL, leagueID: String, week: Int) async {
        let alternateToken = selectedYear == "2025" ? AppConstants.ESPN_S2 : AppConstants.ESPN_S2_2025
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(alternateToken)", forHTTPHeaderField: "Cookie")
        
        let cancellable = URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ESPNFantasyLeagueModel.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .failure:
                    self?.errorMessage = "Failed to load ESPN matchups";
                    self?.matchups = [];
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] model in
                Task {
                    await self?.processESPNFantasyDataLikeTestView(espnModel: model, leagueID: leagueID, week: week)
                }
            })
        
        cancellable.store(in: &cancellables);
    }
    
    /// Process ESPN Fantasy data EXACTLY like the test view (WORKING)
    private func processESPNFantasyDataLikeTestView(espnModel: ESPNFantasyLeagueModel, leagueID: String, week: Int) async {
        // Store team records and names for later lookup (SAME as test view)
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
        var byeTeams: [FantasyTeam] = []  // Track bye week teams
        
        // Filter schedule for the selected week (SAME as test view)
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        
        print("🏈 ESPN \(leagueID): Week \(week) has \(weekSchedule.count) matchups");
        
        for scheduleEntry in weekSchedule {
            // FIXED: Handle bye weeks - collect bye week teams
            guard let awayTeamEntry = scheduleEntry.away else {
                NSLog("🛌 ESPN: Found bye week for team \(scheduleEntry.home.teamId)");
                
                // Create bye week team entry
                if let homeTeam = espnModel.teams.first(where: { $0.id == scheduleEntry.home.teamId }) {
                    let homeScore = homeTeam.activeRosterScore(for: week);
                    let byeTeam = createFantasyTeamFromESPNLikeTestView(
                        espnTeam: homeTeam,
                        score: homeScore,
                        leagueID: leagueID
                    );
                    byeTeams.append(byeTeam);
                }
                continue
            }
            
            let awayTeamId = awayTeamEntry.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores using SAME method as test view
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            // Create fantasy teams with real data (SAME as test view)
            let awayFantasyTeam = createFantasyTeamFromESPNLikeTestView(
                espnTeam: awayTeam,
                score: awayScore,
                leagueID: leagueID
            )
            
            let homeFantasyTeam = createFantasyTeamFromESPNLikeTestView(
                espnTeam: homeTeam,
                score: homeScore,
                leagueID: leagueID
            )
            
            // Create matchup (SAME as test view)
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
                sleeperMatchups: nil
            )
            
            processedMatchups.append(matchup)
        }
        
        // Update both matchups and bye week teams
        matchups = processedMatchups
        byeWeekTeams = byeTeams
        
        print("🎯 ESPN \(leagueID): Created \(processedMatchups.count) matchups and \(byeTeams.count) bye week teams");
    }

    /// Create FantasyTeam from ESPN data EXACTLY like the test view (WORKING)
    private func createFantasyTeamFromESPNLikeTestView(espnTeam: ESPNFantasyTeamModel, score: Double, leagueID: String) -> FantasyTeam {
        // Convert ESPN roster to fantasy players (SAME as test view)
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
        
        // Get team record (SAME as test view)
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
        
        // FIXED: Use ESPN team name directly (NOT DraftRoomViewModel)
        let managerName = espnTeam.name ?? "Team \(espnTeam.id)"
        let teamName = espnTeam.name ?? "Team \(espnTeam.id)"
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: teamName,
            ownerName: managerName,
            record: record,
            avatar: nil,
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: espnTeam.id
        )
    }

    // MARK: -> SLEEPER IMPLEMENTATION - FIXED to match SleepThis
    
    /// Fetch Sleeper league scoring settings (like SleepThis)
    private func fetchSleeperScoringSettings(leagueID: String) async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["scoring_settings"] as? [String: Any] {
                sleeperLeagueSettings = settings
            }
        } catch {
            // Silent error handling
        }
    }
    
    /// Fetch Sleeper weekly player stats (like SleepThis)
    private func fetchSleeperWeeklyStats() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(selectedYear)/\(selectedWeek)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            playerStats = statsData
        } catch {
            // Silent error handling
        }
    }
    
    /// Fetch Sleeper league users and rosters (like SleepThis)
    private func fetchSleeperLeagueUsersAndRosters(leagueID: String) async {
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
            // Silent error handling
        }
    }
    
    /// Fetch Sleeper users (like SleepThis)
    private func fetchSleeperUsers(leagueID: String) async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else { 
            return 
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            
            for user in users {
                userIDs[user.userID] = user.displayName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    userAvatars[user.userID] = avatarURL
                }
            }
        } catch {
            // Silent error handling
        }
    }
    
    /// Fetch REAL Sleeper matchups (like SleepThis - CORRECT implementation)
    private func fetchSleeperMatchups(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
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
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }

    /// Process REAL Sleeper matchups (like SleepThis - CORRECT implementation)
    private func processSleeperMatchups(_ sleeperMatchups: [SleeperMatchup], leagueID: String) async {
        // xprint("🏈 Processing \(sleeperMatchups.count) REAL Sleeper matchups")
        
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
            
            // xprint("🔍 Away: roster \(team1.roster_id) -> manager \(awayManagerID) -> name '\(awayManagerName)' -> avatar \(awayAvatarURL?.absoluteString ?? "nil")")
            // xprint("🔍 Home: roster \(team2.roster_id) -> manager \(homeManagerID) -> name '\(homeManagerName)' -> avatar \(homeAvatarURL?.absoluteString ?? "nil")")
            
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
            
            // xprint("✅ Sleeper matchup: \(awayManagerName) (\(String(format: "%.2f", awayScore))) vs \(homeManagerName) (\(String(format: "%.2f", homeScore)))")
        }
        
        matchups = processedMatchups
        // xprint("🎯 Processed \(processedMatchups.count) REAL Sleeper matchups with accurate scoring")
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
    
    /// Create Sleeper fantasy team with REAL manager names from shared DraftRoomViewModel
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
        
        // FIXED: Use shared DraftRoomViewModel for better manager name resolution
        var finalManagerName = managerName
        
        if let sharedDraftRoom = sharedDraftRoomViewModel {
            // Try to get better manager name from DraftRoomViewModel
            // We need to find the draft slot that corresponds to this roster ID
            let allPicks = sharedDraftRoom.allDraftPicks
            if let correspondingPick = allPicks.first(where: { $0.rosterInfo?.rosterID == matchup.roster_id }) {
                let draftSlotBasedName = sharedDraftRoom.teamDisplayName(for: correspondingPick.draftSlot)
                
                // Check if we got a real name (not generic "Team X")
                if !draftSlotBasedName.isEmpty,
                   !draftSlotBasedName.lowercased().hasPrefix("team "),
                   !draftSlotBasedName.lowercased().hasPrefix("manager "),
                   draftSlotBasedName.count > 4 {
                    finalManagerName = draftSlotBasedName
                    // xprint("🏈 Sleeper Fantasy: Using manager name '\(finalManagerName)' from DraftRoomViewModel for roster \(matchup.roster_id)")
                }
            }
        }
        
        return FantasyTeam(
            id: String(matchup.roster_id),
            name: finalManagerName, // REAL manager name from DraftRoom
            ownerName: finalManagerName, // REAL manager name
            record: nil,  // Would need roster data for record
            avatar: avatarString, // FIXED: Store full URL string
            currentScore: score,  // Real calculated score
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: matchup.roster_id
        )
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
    
    /// Refresh matchups (for auto-refresh) - FIXED for real-time updates without navigation disruption
    func refreshMatchups() async {
        guard let league = selectedLeague else {
            return
        }
        
        // NEVER set isLoading or clear matchups during real-time refresh
        // This prevents navigation pops and UI blinking
        
        do {
            if league.source == .espn {
                // Real-time ESPN refresh with AUTH RETRY - FIXED to use same URL as test view
                guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(selectedYear)/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(selectedWeek)") else {
                    return
                }
                
                let currentWeek = selectedWeek
                let currentLeagueID = league.league.leagueID
                
                let cancellable = URLSession.shared.dataTaskPublisher(for: url)
                    .map(\.data)
                    .decode(type: ESPNFantasyLeagueModel.self, decoder: JSONDecoder())
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        switch completion {
                        case .failure(let error):
                            // Try alternate token if this fails
                            Task {
                                await self?.tryAlternateESPNToken(url: url, leagueID: currentLeagueID, week: currentWeek)
                            }
                        case .finished:
                            break
                        }
                    }, receiveValue: { [weak self] model in
                        Task {
                            await self?.processESPNRefreshData(espnModel: model, leagueID: currentLeagueID, week: currentWeek)
                        }
                    })

                cancellable.store(in: &cancellables)
            } else {
                // Sleeper real-time refresh
                await refreshSleeperData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
        } catch {
            // Silent error handling for refresh
        }
    }
    
    /// Process ESPN refresh data without UI disruption
    private func processESPNRefreshData(espnModel: ESPNFantasyLeagueModel, leagueID: String, week: Int) async {
        let weekSchedule = espnModel.schedule.filter { $0.matchupPeriodId == week }
        var updatedMatchups: [FantasyMatchup] = []
        var updatedByeTeams: [FantasyTeam] = []
        
        // Build updated matchups while preserving existing IDs and structure
        for scheduleEntry in weekSchedule {
            // FIXED: Handle bye weeks during refresh
            guard let awayTeamEntry = scheduleEntry.away else {
                NSLog("🛌 ESPN Refresh: Found bye week for team \(scheduleEntry.home.teamId)");
                
                // Create bye week team entry
                if let homeTeam = espnModel.teams.first(where: { $0.id == scheduleEntry.home.teamId }) {
                    let homeScore = homeTeam.activeRosterScore(for: week);
                    let byeTeam = createFantasyTeamFromESPNLikeTestView(
                        espnTeam: homeTeam,
                        score: homeScore,
                        leagueID: leagueID
                    );
                    updatedByeTeams.append(byeTeam);
                }
                continue
            }
            
            let awayTeamId = awayTeamEntry.teamId
            let homeTeamId = scheduleEntry.home.teamId
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores using SAME method as test view
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            // Find existing matchup to preserve navigation state
            let matchupId = "\(leagueID)_\(week)_\(awayTeamId)_\(homeTeamId)"
            
            // Create updated fantasy teams
            let awayFantasyTeam = createFantasyTeamFromESPNLikeTestView(
                espnTeam: awayTeam,
                score: awayScore,
                leagueID: leagueID
            )
            
            let homeFantasyTeam = createFantasyTeamFromESPNLikeTestView(
                espnTeam: homeTeam,
                score: homeScore,
                leagueID: leagueID
            )
            
            // Create updated matchup with same ID structure
            let updatedMatchup = FantasyMatchup(
                id: matchupId,
                leagueID: leagueID,
                week: week,
                year: selectedYear,
                homeTeam: homeFantasyTeam,
                awayTeam: awayFantasyTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            updatedMatchups.append(updatedMatchup)
        }
        
        // Atomically update both matchups and bye teams - this prevents navigation issues
        if !updatedMatchups.isEmpty || !updatedByeTeams.isEmpty {
            matchups = updatedMatchups
            byeWeekTeams = updatedByeTeams
            // xprint("🚀 Real-time update: \(updatedMatchups.count) matchups and \(updatedByeTeams.count) bye teams refreshed")
        }
    }

    /// Real-time Sleeper data refresh without UI disruption
    private func refreshSleeperData(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchup].self, from: data)
            
            // Update existing matchups with new Sleeper data
            let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchup_id })
            var updatedMatchups: [FantasyMatchup] = []
            
            for (_, matchupPair) in groupedMatchups where matchupPair.count == 2 {
                let team1 = matchupPair[0]
                let team2 = matchupPair[1]
                
                let awayManagerID = rosterIDToManagerID[team1.roster_id] ?? ""
                let homeManagerID = rosterIDToManagerID[team2.roster_id] ?? ""
                
                let awayManagerName = userIDs[awayManagerID] ?? "Manager \(team1.roster_id)"
                let homeManagerName = userIDs[homeManagerID] ?? "Manager \(team2.roster_id)"
                
                let awayAvatarURL = userAvatars[awayManagerID]
                let homeAvatarURL = userAvatars[homeManagerID]
                
                let awayScore = calculateSleeperTeamScore(matchup: team1)
                let homeScore = calculateSleeperTeamScore(matchup: team2)
                
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
                
                let updatedMatchup = FantasyMatchup(
                    id: "\(leagueID)_\(week)_\(team1.roster_id)_\(team2.roster_id)",
                    leagueID: leagueID,
                    week: week,
                    year: selectedYear,
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    status: .live,
                    winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                    startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                    sleeperMatchups: (team1, team2)
                )
                
                updatedMatchups.append(updatedMatchup)
            }
            
            if !updatedMatchups.isEmpty {
                matchups = updatedMatchups
            }
            
        } catch {
            // xprint("❌ Sleeper real-time refresh failed: \(error)")
        }
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
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false
                        )
                    }
                    
                    let awayScore = getScore(for: matchup, teamIndex: 0)
                    let homeScore = getScore(for: matchup, teamIndex: 1);
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
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false
                        )
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
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true
                        )
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
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true
                        )
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
    
    /// Get roster for a team (active or bench) with PROPER POSITION SORTING
    private func getRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        // FIXED: Sort by position in the order Gp specified
        return filteredPlayers.sorted { player1, player2 in
            let order1 = positionSortOrder(player1.position)
            let order2 = positionSortOrder(player2.position)
            
            if order1 != order2 {
                // Different positions, sort by position order
                return order1 < order2
            } else {
                // Same position, sort by fantasy points (highest first for position rank)
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
    }
    
    /// Get positional ranking for a player (e.g., "RB1", "WR2", "TE1")
    func getPositionalRanking(for player: FantasyPlayer, in matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> String {
        let roster = getRoster(for: matchup, teamIndex: teamIndex, isBench: isBench)
        
        // Get all players in the same position group
        let samePositionPlayers = roster.filter { $0.position.uppercased() == player.position.uppercased() }
        
        // Find this player's rank within their position group (1-based)
        if let playerIndex = samePositionPlayers.firstIndex(where: { $0.id == player.id }) {
            let rank = playerIndex + 1
            return "\(player.position.uppercased())\(rank)"
        }
        
        // Fallback to regular position if ranking fails
        return player.position.uppercased()
    }
    
    /// Position sorting order as requested by Gp: QB, WR, RB, TE, FLEX, Super Flex, K, D/ST
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9// Bench players last
        default: return 10 // Unknown positions last
        }
    }
    
    /// Initialize NFL game data for the current week
    func setupNFLGameData() {
        let currentWeek = getCurrentWeek()
        let currentYear = Int(selectedYear) ?? 2024
        
        // Fetch real NFL game data
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        // Start live updates if it's during NFL game time (Sunday/Monday/Thursday)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // Start live updates on game days (Sunday=1, Monday=2, Thursday=5)
        if [1, 2, 5].contains(weekday) {
            nflGameService.startLiveUpdates(forWeek: currentWeek, year: currentYear)
        }
    }
    
    /// Helper to get current NFL week
    private func getCurrentWeek() -> Int {
        // TODO: Integrate with your existing NFLWeekCalculator
        // For now return a reasonable default
        return 15
    }
    
    // MARK: -> Week Selection
    
    /// Show week selector sheet
    func presentWeekSelector() {
        showWeekSelector = true
    }
    
    /// Hide week selector sheet
    func dismissWeekSelector() {
        showWeekSelector = false
    }
    
    /// Select a specific week and update matchups
    func selectWeek(_ week: Int) {
        selectedWeek = week
        refreshNFLGameData()
        
        // Refresh matchups for the new week
        Task {
            await fetchMatchups()
        }
    }
}