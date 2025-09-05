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
    @Published var choppedWeekSummary: ChoppedWeekSummary?
    @Published var currentChoppedSummary: ChoppedWeekSummary?
    @Published var isLoadingChoppedData: Bool = false
    @Published var hasActiveRosters: Bool = false // NEW: Track if league has active rosters
    @Published var detectedAsChoppedLeague: Bool = false // NEW: Detected based on empty matchups + rosters
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
        
        // FIXED: Reset Chopped league detection flags
        detectedAsChoppedLeague = false
        hasActiveRosters = false
        
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
            currentChoppedSummary = nil
            return
        }
        
        print("🔍 FETCH MATCHUPS: Starting for league \(league.league.leagueID) source: \(league.source)")
        
        isLoading = true
        errorMessage = nil
        
        // FIXED: Only clear matchups if this is a new league selection, not a refresh
        if matchups.isEmpty || matchups.first?.leagueID != league.league.leagueID {
            matchups = []
            currentChoppedSummary = nil
        }
        
        let startTime = Date()
        
        do {
            // Check if this is an ESPN league
            if league.source == .espn {
                print("🏈 ESPN LEAGUE: Fetching ESPN data for \(league.league.leagueID)")
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                print("😴 SLEEPER LEAGUE: Fetching Sleeper data for \(league.league.leagueID)")
                await fetchSleeperScoringSettings(leagueID: league.league.leagueID)
                await fetchSleeperWeeklyStats()
                await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                await fetchSleeperMatchups(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            // FUCKING SIMPLE FIX: If we end up with 0 matchups after processing, make it Chopped
            print("🎯 FETCH COMPLETE: matchups.count = \(matchups.count)")
            
            if matchups.isEmpty && league.source == .sleeper {
                print("🔥 CHOPPED DETECTION: 0 processed matchups for Sleeper league - MAKING IT CHOPPED!")
                detectedAsChoppedLeague = true
                hasActiveRosters = true
                
                // Force UI update
                await MainActor.run {
                    self.objectWillChange.send()
                }
            }
            
            // LOAD CHOPPED DATA IF APPLICABLE
            if isChoppedLeague(selectedLeague) {
                print("🔥 CHOPPED DETECTION: League detected as Chopped, loading summary...")
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: league.league.leagueID, 
                    week: selectedWeek
                )
                isLoadingChoppedData = false
            } else {
                print("❌ CHOPPED DETECTION: League NOT detected as Chopped")
                print("   - detectedAsChoppedLeague: \(detectedAsChoppedLeague)")
                print("   - hasActiveRosters: \(hasActiveRosters)")
                print("   - league.source: \(league.source)")
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
        
        print("🎯 FINAL STATE: matchups.count = \(matchups.count), detectedAsChoppedLeague = \(detectedAsChoppedLeague)")
        
        // Check if this is a Chopped league
        if isChoppedLeague(selectedLeague) {
            choppedWeekSummary = await createRealChoppedSummaryWithHistory(leagueID: selectedLeague?.league.leagueID ?? "", week: selectedWeek)
        }
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
                    let byeTeam = createFantasyTeamFromESPN(
                        espnTeam: homeTeam,
                        score: homeScore,
                        leagueID: leagueID
                    );
                    byeTeams.append(byeTeam);
                }
                continue
            }
            
            // FIXED: Use original ESPN team assignments instead of forcing arbitrary sorting
            let awayTeamId = awayTeamEntry.teamId  // Keep ESPN's original away team
            let homeTeamId = scheduleEntry.home.teamId  // Keep ESPN's original home team
            
            guard let awayTeam = espnModel.teams.first(where: { $0.id == awayTeamId }),
                  let homeTeam = espnModel.teams.first(where: { $0.id == homeTeamId }) else {
                continue
            }
            
            // Calculate real ESPN scores using SAME method as test view
            let awayScore = awayTeam.activeRosterScore(for: week)
            let homeScore = homeTeam.activeRosterScore(for: week)
            
            print("🔍 ESPN ORIGINAL ORDER - Away: team \(awayTeamId) (\(awayScore)) vs Home: team \(homeTeamId) (\(homeScore))")
            
            // Create fantasy teams with real data (SAME as test view)
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
        
        // FIXED: Keep original ESPN API order - NO MORE SORTING!
        // This prevents the order from changing every time we refresh
        matchups = processedMatchups
        byeWeekTeams = byeTeams
        
        print("🎯 ESPN \(leagueID): Created \(processedMatchups.count) matchups and \(byeTeams.count) bye week teams with ORIGINAL ESPN ORDER");
    }
    
    /// Create FantasyTeam from ESPN team data
    private func createFantasyTeamFromESPN(
        espnTeam: ESPNFantasyTeamModel,
        score: Double,
        leagueID: String
    ) -> FantasyTeam {
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        // Create players from roster entries
        if let roster = espnTeam.roster {
            for entry in roster.entries {
                let player = entry.playerPoolEntry.player
                let isStarter = entry.lineupSlotId != 20 && entry.lineupSlotId != 21 // Not bench/IR
                let playerScore = entry.getScore(for: selectedWeek)
                
                let fantasyPlayer = FantasyPlayer(
                    id: String(player.id),
                    sleeperID: nil,
                    espnID: String(player.id),
                    firstName: extractFirstName(from: player.fullName),
                    lastName: extractLastName(from: player.fullName),
                    position: entry.positionString,
                    team: player.nflTeamAbbreviation,
                    jerseyNumber: nil, // ESPN doesn't provide jersey numbers
                    currentPoints: playerScore,
                    projectedPoints: playerScore * 1.05, // ESPN doesn't provide projections in this model
                    gameStatus: GameStatus(status: "live"), 
                    isStarter: isStarter,
                    lineupSlot: entry.positionString
                )
                
                fantasyPlayers.append(fantasyPlayer)
            }
        }
        
        // Get team record if available
        let teamRecord = espnTeamRecords[espnTeam.id]
        
        return FantasyTeam(
            id: String(espnTeam.id),
            name: espnTeam.name ?? espnTeamNames[espnTeam.id] ?? "Team \(espnTeam.id)",
            ownerName: espnTeam.name ?? "Manager \(espnTeam.id)",
            record: teamRecord,
            avatar: nil, // ESPN doesn't provide team avatars like Sleeper
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
        print("🔍 SLEEPER MATCHUPS: Fetching for league \(leagueID) week \(week)")
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            print("❌ SLEEPER MATCHUPS: Invalid URL")
            return
        }
        
        do {
            print("📡 SLEEPER MATCHUPS: Making API call...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SLEEPER MATCHUPS: HTTP Status \(httpResponse.statusCode)")
            }
            
            // UPDATED: Use new SleeperMatchupResponse model with projected points
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            print("📊 SLEEPER MATCHUPS: Received \(sleeperMatchups.count) matchups")
            
            // FIXED: Detect Chopped leagues IMMEDIATELY when matchups are empty
            if sleeperMatchups.isEmpty {
                print("🔥 CHOPPED DETECTION: No matchups found for week \(week) - IMMEDIATELY flagging as Chopped!")
                print("🔥 CHOPPED: Setting detection flags...")
                
                // IMMEDIATELY set detection flags - no async waiting
                detectedAsChoppedLeague = true
                hasActiveRosters = true // Assume rosters exist if we got this far
                
                print("🔥 CHOPPED: detectedAsChoppedLeague = \(detectedAsChoppedLeague)")
                print("🔥 CHOPPED: hasActiveRosters = \(hasActiveRosters)")
                print("🔥 CHOPPED: This should trigger UI update!")
                
                // Force UI update by triggering objectWillChange
                await MainActor.run {
                    print("🔥 CHOPPED: Forcing UI update with objectWillChange.send()")
                    self.objectWillChange.send()
                }
                
                // Still check rosters in background for validation, but don't block UI
                Task {
                    await validateChoppedLeagueDetection(leagueID: leagueID, week: week)
                }
                
                return
            }
            
            print("🏈 SLEEPER MATCHUPS: Processing \(sleeperMatchups.count) regular matchups")
            // Process REAL matchups with projected points like SleepThis
            await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
            
        } catch {
            print("❌ SLEEPER MATCHUPS: API Error - \(error.localizedDescription)")
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }
    
    /// Process REAL Sleeper matchups with projected points (ENHANCED)
    private func processSleeperMatchupsWithProjections(_ sleeperMatchups: [SleeperMatchupResponse], leagueID: String) async {
        print("🏈 Processing \(sleeperMatchups.count) REAL Sleeper matchups with projections")
        
        // Group by matchup_id to get pairs
        let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchupID ?? 0 })
        var processedMatchups: [FantasyMatchup] = []
        
        for (matchupID, matchups) in groupedMatchups.sorted(by: { $0.key < $1.key }) where matchups.count == 2 {
            // FIXED: Use original Sleeper matchup order instead of sorting by roster ID
            // This keeps the order consistent with what Sleeper shows
            let team1 = matchups[0]  // First team as away (original Sleeper order)
            let team2 = matchups[1]  // Second team as home (original Sleeper order)
            
            // Get manager info
            let awayManagerID = rosterIDToManagerID[team1.rosterID] ?? ""
            let homeManagerID = rosterIDToManagerID[team2.rosterID] ?? ""
            
            let awayManagerName = userIDs[awayManagerID] ?? "Manager \(team1.rosterID)"
            let homeManagerName = userIDs[homeManagerID] ?? "Manager \(team2.rosterID)"
            
            let awayAvatarURL = userAvatars[awayManagerID]
            let homeAvatarURL = userAvatars[homeManagerID]
            
            print("🔍 SLEEPER ORIGINAL ORDER - Away: roster \(team1.rosterID) -> manager \(awayManagerID) -> name '\(awayManagerName)'")
            print("🔍 SLEEPER ORIGINAL ORDER - Home: roster \(team2.rosterID) -> manager \(homeManagerID) -> name '\(homeManagerName)'")
            
            // Use REAL points and projected points from Sleeper API
            let awayScore = team1.points ?? 0.0
            let homeScore = team2.points ?? 0.0
            
            let awayProjected = team1.projectedPoints ?? 0.0
            let homeProjected = team2.projectedPoints ?? 0.0
            
            print("📊 REAL PROJECTIONS - Away: \(String(format: "%.2f", awayScore)) pts (\(String(format: "%.2f", awayProjected)) proj) | Home: \(String(format: "%.2f", homeScore)) pts (\(String(format: "%.2f", homeProjected)) proj)")
            
            // Create fantasy teams with REAL projected points
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
            
            // Create matchup with REAL projected data and original team assignment
            let fantasyMatchup = FantasyMatchup(
                id: "\(leagueID)_\(selectedWeek)_\(team1.rosterID)_\(team2.rosterID)",
                leagueID: leagueID,
                week: selectedWeek,
                year: selectedYear,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil  // Could enhance to convert SleeperMatchupResponse to SleeperMatchup
            )
            
            processedMatchups.append(fantasyMatchup)
            
            print("✅ Sleeper matchup (ORIGINAL ORDER): \(awayManagerName) (\(String(format: "%.2f", awayScore))) vs \(homeManagerName) (\(String(format: "%.2f", homeScore)))")
        }
        
        // FIXED: Keep original Sleeper API order - NO MORE SORTING!
        // Process matchups in the order they came from Sleeper API to maintain consistency
        matchups = processedMatchups
        print("🎯 Processed \(processedMatchups.count) REAL Sleeper matchups with ORIGINAL ORDER preserved")
    }
    
    /// Calculate win probability based on scores
    private func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double {
        if homeScore == 0 && awayScore == 0 { return 0.5 }
        return homeScore / (homeScore + awayScore)
    }
    
    /// Calculate Sleeper team score using REAL starter lineup (legacy format)
    private func calculateSleeperTeamScore(matchup: SleeperMatchup) -> Double {
        guard let starters = matchup.starters else { return 0.0 }
        
        return starters.reduce(0.0) { total, playerId in
            total + calculateSleeperPlayerScore(playerId: playerId)
        }
    }
    
    /// Calculate Sleeper player score using league settings (legacy format)
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
    
    /// Create Sleeper fantasy team with REAL projected points from API
    private func createSleeperFantasyTeam(
        matchupResponse: SleeperMatchupResponse,
        managerName: String,
        avatarURL: URL?
    ) -> FantasyTeam {
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        // Create players from starters and bench
        if let allPlayers = matchupResponse.players {
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                    let isStarter = matchupResponse.starters?.contains(playerID) ?? false
                    let playerScore = calculateSleeperPlayerScore(playerId: playerID)
                    let playerProjected = playerScore * 1.1 // Could enhance with real player projections
                    
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
                        projectedPoints: playerProjected,
                        gameStatus: GameStatus(status: "live"), // Use proper GameStatus initializer
                        isStarter: isStarter,
                        lineupSlot: sleeperPlayer.position
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        let avatarString = avatarURL?.absoluteString
        
        // Get better manager name from DraftRoomViewModel
        var finalManagerName = managerName
        
        if let sharedDraftRoom = sharedDraftRoomViewModel {
            // Try to get better manager name from DraftRoomViewModel
            // We need to find the draft slot that corresponds to this roster ID
            let allPicks = sharedDraftRoom.allDraftPicks
            if let correspondingPick = allPicks.first(where: { $0.rosterInfo?.rosterID == matchupResponse.rosterID }) {
                let draftSlotBasedName = sharedDraftRoom.teamDisplayName(for: correspondingPick.draftSlot)
                
                // Check if we got a real name (not generic "Team X")
                if !draftSlotBasedName.isEmpty,
                   !draftSlotBasedName.lowercased().hasPrefix("team "),
                   !draftSlotBasedName.lowercased().hasPrefix("manager "),
                   draftSlotBasedName.count > 4 {
                    finalManagerName = draftSlotBasedName
                }
            }
        }
        
        return FantasyTeam(
            id: String(matchupResponse.rosterID),
            name: finalManagerName,
            ownerName: finalManagerName,
            record: nil,
            avatar: avatarString,
            currentScore: matchupResponse.points,  // REAL current score from API
            projectedScore: matchupResponse.projectedPoints,  // REAL projected score from API 
            roster: fantasyPlayers,
            rosterID: matchupResponse.rosterID
        )
    }
    
    /// Create Sleeper fantasy team with REAL player data
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
                        gameStatus: GameStatus(status: "live"), // Use proper GameStatus initializer
                        isStarter: isStarter,
                        lineupSlot: sleeperPlayer.position
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        let avatarString = avatarURL?.absoluteString
        
        // Get better manager name from DraftRoomViewModel
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
                }
            }
        }
        
        return FantasyTeam(
            id: String(matchup.roster_id),
            name: finalManagerName,
            ownerName: finalManagerName,
            record: nil,
            avatar: avatarString,
            currentScore: score,  // REAL current score
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: matchup.roster_id
        )
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

    /// Position sort order for roster display
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }

    /// Calculate score variance for elimination probabilities
    private func calculateScoreVariance(_ scores: [Double]) -> Double {
        guard scores.count > 1 else { return 10.0 }
        let mean = scores.reduce(0, +) / Double(scores.count)
        let squaredDifferences = scores.map { pow($0 - mean, 2) }
        return sqrt(squaredDifferences.reduce(0, +) / Double(scores.count - 1))
    }

    /// Check if there are currently live NFL games
    private func hasLiveGames() -> Bool {
        // Dummy implementation, update as desired
        return false
    }
    
    // MARK: -> SLEEPER IMPLEMENTATION - ENHANCED
    
    /// Get score for a team
    func getScore(for matchup: FantasyMatchup, teamIndex: Int) -> Double {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        
        return team.currentScore ?? 0.0
    }
    
    /// Get score difference text for VS section
    func scoreDifferenceText(matchup: FantasyMatchup) -> String {
        let awayScore = getScore(for: matchup, teamIndex: 0)
        let homeScore = getScore(for: matchup, teamIndex: 1)
        return String(format: "%.2f", abs(awayScore - homeScore))
    }
    
    /// Get manager record for display
    func getManagerRecord(managerID: String) -> String {
        // This would typically come from league data, for now return a placeholder
        return "0-0"
    }
    
    /// Get positional ranking for a player
    func getPositionalRanking(for player: FantasyPlayer, in matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> String {
        // Get all players at this position from both teams
        let allPlayers = matchup.awayTeam.roster + matchup.homeTeam.roster
        let positionPlayers = allPlayers.filter { $0.position == player.position && $0.isStarter == !isBench }
            .sorted { ($0.currentPoints ?? 0.0) > ($1.currentPoints ?? 0.0) }
        
        // Find player's rank in their position
        if let index = positionPlayers.firstIndex(where: { $0.id == player.id }) {
            return player.position.uppercased()
        }
        return player.position.uppercased()
    }

    // MARK: -> Elimination Probability Calculation
    
    /// Fetch Chopped league standings with REAL projected points and elimination probabilities
    func fetchChoppedLeagueStandings(leagueID: String, week: Int) async -> [FantasyTeamRanking] {
        // First get league settings and users
        await fetchSleeperScoringSettings(leagueID: leagueID)
        await fetchSleeperWeeklyStats()
        await fetchSleeperLeagueUsersAndRosters(leagueID: leagueID)
        
        do {
            // 🎯 Use new API method to get matchups with projected points
            let sleeperMatchups = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID, 
                week: week
            )
            
            // Convert each roster to a FantasyTeam with real scoring AND projections
            var allTeams: [FantasyTeam] = []
            
            for matchup in sleeperMatchups {
                let teamScore = matchup.points ?? 0.0
                let teamProjected = matchup.projectedPoints ?? (teamScore * 1.05)
                let managerID = rosterIDToManagerID[matchup.rosterID] ?? ""
                let managerName = userIDs[managerID] ?? "Manager \(matchup.rosterID)"
                let avatarURL = userAvatars[managerID]
                
                // Use shared DraftRoomViewModel for better manager names
                var finalManagerName = managerName
                
                if let sharedDraftRoom = sharedDraftRoomViewModel {
                    // Try to get better manager name from DraftRoomViewModel
                    // We need to find the draft slot that corresponds to this roster ID
                    let allPicks = sharedDraftRoom.allDraftPicks
                    if let correspondingPick = allPicks.first(where: { $0.rosterInfo?.rosterID == matchup.rosterID }) {
                        let draftSlotBasedName = sharedDraftRoom.teamDisplayName(for: correspondingPick.draftSlot)
                        
                        // Check if we got a real name (not generic "Team X")
                        if !draftSlotBasedName.isEmpty,
                           !draftSlotBasedName.lowercased().hasPrefix("team "),
                           !draftSlotBasedName.lowercased().hasPrefix("manager "),
                           draftSlotBasedName.count > 4 {
                            finalManagerName = draftSlotBasedName
                        }
                    }
                }
                
                let fantasyTeam = FantasyTeam(
                    id: String(matchup.rosterID),
                    name: finalManagerName,
                    ownerName: finalManagerName,
                    record: nil,
                    avatar: avatarURL?.absoluteString,
                    currentScore: teamScore,
                    projectedScore: teamProjected,  // 🎯 REAL SLEEPER PROJECTED POINTS
                    roster: [],  // Could populate if needed
                    rosterID: matchup.rosterID
                )
                
                allTeams.append(fantasyTeam)
            }
            
            // Sort teams by current score OR projected score if current is 0
            let sortedTeams = allTeams.sorted { team1, team2 in
                let score1 = (team1.currentScore ?? 0.0) > 0 ? (team1.currentScore ?? 0.0) : (team1.projectedScore ?? 0.0)
                let score2 = (team2.currentScore ?? 0.0) > 0 ? (team2.currentScore ?? 0.0) : (team2.projectedScore ?? 0.0)
                return score1 > score2
            }
            
            // Calculate elimination probabilities using REAL data
            let totalTeams = sortedTeams.count
            let allCurrentScores = sortedTeams.compactMap { $0.currentScore }
            let allProjectedScores = sortedTeams.compactMap { $0.projectedScore }
            let averageProjected = allProjectedScores.reduce(0, +) / Double(allProjectedScores.count)
            let scoreVariance = self.calculateScoreVariance(allCurrentScores)
            let weeksRemaining = max(0, 18 - week) // NFL season is 18 weeks including playoffs
            
            // Create rankings with REAL elimination probabilities like Sleeper
            let rankings = sortedTeams.enumerated().map { index, team -> FantasyTeamRanking in
                let rank = index + 1
                let teamScore = team.currentScore ?? 0.0
                let teamProjected = team.projectedScore ?? 0.0
                
                // 🎯 Calculate REAL safety percentage like Sleeper's "SAFE %"
                let safetyPercentage = EliminationProbabilityCalculator.calculateSafetyPercentage(
                    currentRank: rank,
                    totalTeams: totalTeams,
                    projectedPoints: teamProjected,
                    averageProjected: averageProjected,
                    weeklyVariance: scoreVariance,
                    weeksRemaining: weeksRemaining,
                    historicalPerformance: [] // Could add historical data later
                )
                
                // Determine elimination status based on safety percentage
                let status = EliminationProbabilityCalculator.determineEliminationStatus(
                    safetyPercentage: safetyPercentage,
                    rank: rank,
                    totalTeams: totalTeams
                )
                
                // Points from elimination line (distance from last place projected)
                let lastPlaceProjected = sortedTeams.last?.projectedScore ?? 0.0
                let safetyMargin = teamProjected - lastPlaceProjected
                
                return FantasyTeamRanking(
                    id: team.id,
                    team: team,
                    weeklyPoints: teamScore > 0 ? teamScore : teamProjected, // Use current or projected
                    rank: rank,
                    eliminationStatus: status,
                    isEliminated: false,
                    survivalProbability: safetyPercentage,  // 🎯 REAL SLEEPER-STYLE CALCULATION
                    pointsFromSafety: safetyMargin,
                    weeksAlive: week
                )
            }
            
            print("🔥 CHOPPED: Created \(rankings.count) real team rankings with Sleeper-style safety percentages for league \(leagueID) week \(week)")
            return rankings
            
        } catch {
            print("❌ CHOPPED: Failed to fetch league standings with projections: \(error)")
            return []
        }
    }

    /// Load available leagues on app start
    func loadLeagues() async {
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: AppConstants.GpSleeperID, 
            season: selectedYear
        )
    }

    /// Refresh matchups (for auto-refresh) - FIXED for real-time updates without navigation disruption
    func refreshMatchups() async {
        guard let league = selectedLeague else {
            return
        }
        
        print("🔄 REFRESH: Starting auto-refresh for \(league.league.name)")
        
        // NEVER set isLoading or clear matchups during real-time refresh
        // This prevents navigation pops and UI blinking
        
        do {
            if league.source == .espn {
                print("🔄 ESPN REFRESH: Using proper authentication...")
                // Use the same fetchESPNFantasyData method with proper auth
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                print("🔄 SLEEPER REFRESH: Refreshing Sleeper data...")
                // Sleeper real-time refresh
                await refreshSleeperData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            // CHOPPED LEAGUE REAL-TIME REFRESH
            if isChoppedLeague(selectedLeague) {
                await refreshChoppedData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            print("✅ REFRESH: Completed auto-refresh, matchups.count = \(matchups.count)")
            
        } catch {
            print("❌ REFRESH: Auto-refresh failed: \(error)")
            // Don't clear matchups on refresh failure - keep existing data
        }
    }

    /// Real-time Chopped data refresh
    private func refreshChoppedData(leagueID: String, week: Int) async {
        // Update Chopped summary without showing loading state (to prevent UI blinking)
        if let updatedSummary = await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week) {
            currentChoppedSummary = updatedSummary
            print("🔥 CHOPPED REFRESH: Updated rankings for week \(week)")
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
            
            // Update existing matchups with new Sleeper data using old format
            let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchup_id })
            var updatedMatchups: [FantasyMatchup] = []
            
            for (matchupID, matchupPair) in groupedMatchups.sorted(by: { $0.key < $1.key }) where matchupPair.count == 2 {
                // FIXED: Sort consistently by roster ID to prevent flipping during refresh
                let sortedPair = matchupPair.sorted { $0.roster_id < $1.roster_id }
                let team1 = sortedPair[0]  // Always lower roster ID as away
                let team2 = sortedPair[1]  // Always higher roster ID as home
                
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
            
            // FIXED: Keep original order during refresh - NO MORE SORTING!
            if !updatedMatchups.isEmpty {
                matchups = updatedMatchups
            }
            
        } catch {
            // xprint("❌ Sleeper real-time refresh failed: \(error)")
        }
    }
    
    /// Fetch Chopped league standings with REAL projected points and elimination probabilities
    func createRealChoppedSummary(leagueID: String, week: Int) async -> ChoppedWeekSummary? {
        return await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week)
    }
    
    /// Check if a league is a Chopped format
    func isChoppedLeague(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper?) -> Bool {
        guard let leagueWrapper = leagueWrapper,
              leagueWrapper.source == .sleeper else {
            print("❌ CHOPPED CHECK: Not a Sleeper league or nil league")
            return false
        }
        
        print("🔍 CHOPPED CHECK: Checking league \(leagueWrapper.league.leagueID)")
        print("   - detectedAsChoppedLeague: \(detectedAsChoppedLeague)")
        print("   - hasActiveRosters: \(hasActiveRosters)")
        
        // NEW: Primary detection based on data structure
        if detectedAsChoppedLeague {
            print("🔥 CHOPPED CHECK: ✅ Detected via empty matchups + active rosters")
            return true
        }
        
        // FALLBACK: Keep existing settings check as backup
        if let sleeperLeague = leagueWrapper.league as? SleeperLeague,
           let isChopped = sleeperLeague.settings?.isChopped, isChopped {
            print("🔥 CHOPPED CHECK: ✅ Detected via league settings")
            return true
        }
        
        print("❌ CHOPPED CHECK: NOT detected as Chopped league")
        return false
    }

    /// Fetch complete elimination history for Chopped league
    func fetchChoppedEliminationHistory(leagueID: String, currentWeek: Int) async -> [EliminationEvent] {
        var eliminationHistory: [EliminationEvent] = []
        
        // Fetch data for all completed weeks (1 to currentWeek-1)
        for week in 1..<currentWeek {
            if let elimination = await calculateWeeklyElimination(leagueID: leagueID, week: week) {
                eliminationHistory.append(elimination)
            }
        }
        
        print("💀 ELIMINATION TRACKER: Found \(eliminationHistory.count) eliminations across \(currentWeek-1) weeks")
        return eliminationHistory.sorted { $0.week < $1.week } // Chronological order
    }

    /// Calculate who was eliminated in a specific week
    private func calculateWeeklyElimination(leagueID: String, week: Int) async -> EliminationEvent? {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchup].self, from: data)
            
            // Calculate scores for all teams this week
            var teamScores: [(rosterID: Int, score: Double, managerName: String)] = []
            
            for matchup in sleeperMatchups {
                let teamScore = calculateSleeperTeamScore(matchup: matchup)
                let managerID = rosterIDToManagerID[matchup.roster_id] ?? ""
                let managerName = userIDs[managerID] ?? "Manager \(matchup.roster_id)"
                
                teamScores.append((
                    rosterID: matchup.roster_id,
                    score: teamScore,
                    managerName: managerName
                ))
            }
            
            // Find the lowest scorer (eliminated team)
            guard let lowestScorer = teamScores.min(by: { $0.score < $1.score }) else {
                return nil
            }
            
            // Check for ties at the bottom
            let tiedTeams = teamScores.filter { $0.score == lowestScorer.score }
            let dramaMeter = tiedTeams.count > 1 ? 1.0 : 0.6 // Higher drama for ties
            
            // Create elimination event
            let eliminationTeam = FantasyTeam(
                id: String(lowestScorer.rosterID),
                name: lowestScorer.managerName,
                ownerName: lowestScorer.managerName,
                record: nil,
                avatar: nil,
                currentScore: lowestScorer.score,
                projectedScore: lowestScorer.score,
                roster: [],
                rosterID: lowestScorer.rosterID
            )
            
            let eliminationRanking = FantasyTeamRanking(
                id: String(lowestScorer.rosterID),
                team: eliminationTeam,
                weeklyPoints: lowestScorer.score,
                rank: teamScores.count, // Last place
                eliminationStatus: .eliminated,
                isEliminated: true,
                survivalProbability: 0.0,
                pointsFromSafety: 0.0,
                weeksAlive: week
            )
            
            // Calculate elimination margin (how close was it?)
            let sortedScores = teamScores.map { $0.score }.sorted(by: >)
            let secondLowest = sortedScores.count > 1 ? sortedScores[sortedScores.count - 2] : lowestScorer.score
            let margin = secondLowest - lowestScorer.score
            
            return EliminationEvent(
                id: "elimination_\(leagueID)_week_\(week)",
                week: week,
                eliminatedTeam: eliminationRanking,
                eliminationScore: lowestScorer.score,
                margin: margin,
                dramaMeter: dramaMeter,
                lastWords: tiedTeams.count > 1 ? "Eliminated by tiebreaker" : "Couldn't score enough to survive",
                timestamp: Date() // Could calculate actual week end date
            )
        
        } catch {
            print("❌ ELIMINATION: Failed to fetch week \(week) data: \(error)")
            return nil
        }
    }

    /// Enhanced Chopped summary with elimination tracking
    func createRealChoppedSummaryWithHistory(leagueID: String, week: Int) async -> ChoppedWeekSummary? {
        // Fetch current week standings
        let rankings = await fetchChoppedLeagueStandings(leagueID: leagueID, week: week)
        
        guard !rankings.isEmpty else {
            return nil
        }
        
        // Fetch elimination history for previous weeks
        let eliminationHistory = await fetchChoppedEliminationHistory(leagueID: leagueID, currentWeek: week)
        
        // Determine current week status based on scoring
        let hasAnyScoring = rankings.contains { $0.weeklyPoints > 0 }
        let isScheduled = !hasAnyScoring
        
        // Adjust elimination status for scheduled games
        let adjustedRankings = rankings.map { ranking -> FantasyTeamRanking in
            if isScheduled {
                // Everyone is safe during scheduled mode
                return FantasyTeamRanking(
                    id: ranking.id,
                    team: ranking.team,
                    weeklyPoints: ranking.weeklyPoints,
                    rank: ranking.rank,
                    eliminationStatus: .safe, // Everyone safe when no games played
                    isEliminated: false,
                    survivalProbability: 1.0, // 100% survival when no games played
                    pointsFromSafety: 0.0,
                    weeksAlive: ranking.weeksAlive
                )
            } else {
                // Use calculated status when games are live/complete
                return ranking
            }
        }
        
        let eliminatedTeam = isScheduled ? nil : rankings.last
        let cutoffScore = eliminatedTeam?.weeklyPoints ?? 0.0
        let allScores = rankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        // Create enhanced summary with historical eliminations
        let summary = ChoppedWeekSummary(
            id: "chopped_with_history_\(leagueID)_\(week)",
            week: week,
            rankings: adjustedRankings,
            eliminatedTeam: eliminatedTeam,
            cutoffScore: cutoffScore,
            isComplete: !isScheduled && !self.hasLiveGames(),
            totalSurvivors: adjustedRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: eliminationHistory
        )
        
        // Store elimination history for UI access (we'll add this to the model)
        // For now, print the history
        if !eliminationHistory.isEmpty {
            print("💀 ELIMINATION HISTORY:")
            for elimination in eliminationHistory {
                print("   Week \(elimination.week): \(elimination.eliminatedTeam.team.ownerName) - \(elimination.eliminationScore) pts (margin: \(elimination.margin))")
            }
        }
        
        return summary
    }

    /// NEW: Validate Chopped league detection in background (don't block UI)
    private func validateChoppedLeagueDetection(leagueID: String, week: Int) async {
        print("🔍 CHOPPED VALIDATION: Checking rosters for league \(leagueID)")
        
        // Check if we have active rosters in the league (for validation)
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else {
            print("❌ CHOPPED VALIDATION: Invalid rosters URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            print("📊 CHOPPED VALIDATION: Found \(rosters.count) rosters")
            
            if !rosters.isEmpty {
                print("🔥 CHOPPED VALIDATED: \(rosters.count) active rosters confirmed - this is definitely a Chopped league!")
                
                await MainActor.run {
                    self.hasActiveRosters = true
                    print("🔥 CHOPPED: Updated hasActiveRosters = \(self.hasActiveRosters)")
                }
                
                // Load Chopped leaderboard data
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: leagueID, 
                    week: week
                )
                isLoadingChoppedData = false
            } else {
                // Revert detection if no rosters found
                print("❌ CHOPPED DETECTION FAILED: No rosters found - reverting detection")
                await MainActor.run {
                    self.detectedAsChoppedLeague = false
                    self.hasActiveRosters = false
                    self.errorMessage = "No matchups or active rosters found for week \(week)"
                }
            }
            
        } catch {
            print("⚠️ CHOPPED VALIDATION ERROR: \(error) - keeping detection as is")
        }
    }
    
    // MARK: -> Week Selection Methods
    
    /// Present the week selector sheet
    func presentWeekSelector() {
        showWeekSelector = true
    }
    
    /// Dismiss the week selector sheet
    func dismissWeekSelector() {
        showWeekSelector = false
    }
    
    /// Select a specific week and refresh data
    func selectWeek(_ week: Int) {
        guard week != selectedWeek else { return }
        
        selectedWeek = week
        
        // Refresh data for the new week
        Task {
            await fetchMatchups()
        }
    }
    
    // MARK: -> View Builder Methods
    
    /// Create the active roster section view for a matchup
    func activeRosterSection(matchup: FantasyMatchup) -> some View {
        FantasyActiveRosterSection(
            matchup: matchup,
            fantasyViewModel: self
        )
    }
    
    /// Create the bench section view for a matchup  
    func benchSection(matchup: FantasyMatchup) -> some View {
        FantasyBenchSection(
            matchup: matchup,
            fantasyViewModel: self
        )
    }
}

// MARK: -> Fantasy Active Roster Section View
struct FantasyActiveRosterSection: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                
                Text("Active Lineup")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(activePlayersCount) players")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Away team active players
            VStack(alignment: .leading, spacing: 8) {
                Text(matchup.awayTeam.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                
                ForEach(awayActiveRoster, id: \.id) { player in
                    FantasyPlayerCard(
                        player: player,
                        fantasyViewModel: fantasyViewModel,
                        matchup: matchup,
                        teamIndex: 0,
                        isBench: false
                    )
                    .padding(.horizontal, 16)
                }
            }
            
            // Home team active players  
            VStack(alignment: .leading, spacing: 8) {
                Text(matchup.homeTeam.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 16)
                
                ForEach(homeActiveRoster, id: \.id) { player in
                    FantasyPlayerCard(
                        player: player,
                        fantasyViewModel: fantasyViewModel,
                        matchup: matchup,
                        teamIndex: 1,
                        isBench: false
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal, 16)
    }
    
    /// Get active roster for away team
    private var awayActiveRoster: [FantasyPlayer] {
        return matchup.awayTeam.roster.filter { $0.isStarter }
    }
    
    /// Get active roster for home team
    private var homeActiveRoster: [FantasyPlayer] {
        return matchup.homeTeam.roster.filter { $0.isStarter }
    }
    
    /// Total active players count
    private var activePlayersCount: Int {
        return awayActiveRoster.count + homeActiveRoster.count
    }
}

// MARK: -> Fantasy Bench Section View
struct FantasyBenchSection: View {
    let matchup: FantasyMatchup
    let fantasyViewModel: FantasyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text("Bench")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(benchPlayersCount) players")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            if benchPlayersCount == 0 {
                // Empty bench message
                HStack {
                    Spacer()
                    Text("No bench players")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                // Away team bench players
                if !awayBenchRoster.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(matchup.awayTeam.ownerName) Bench")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .padding(.horizontal, 16)
                        
                        ForEach(awayBenchRoster, id: \.id) { player in
                            FantasyPlayerCard(
                                player: player,
                                fantasyViewModel: fantasyViewModel,
                                matchup: matchup,
                                teamIndex: 0,
                                isBench: true
                            )
                            .padding(.horizontal, 16)
                            .opacity(0.7)
                        }
                    }
                }
                
                // Home team bench players
                if !homeBenchRoster.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(matchup.homeTeam.ownerName) Bench")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .padding(.horizontal, 16)
                        
                        ForEach(homeBenchRoster, id: \.id) { player in
                            FantasyPlayerCard(
                                player: player,
                                fantasyViewModel: fantasyViewModel,
                                matchup: matchup,
                                teamIndex: 1,
                                isBench: true
                            )
                            .padding(.horizontal, 16)
                            .opacity(0.7)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal, 16)
    }
    
    /// Get bench roster for away team
    private var awayBenchRoster: [FantasyPlayer] {
        return matchup.awayTeam.roster.filter { !$0.isStarter }
    }
    
    /// Get bench roster for home team
    private var homeBenchRoster: [FantasyPlayer] {
        return matchup.homeTeam.roster.filter { !$0.isStarter }
    }
    
    /// Total bench players count
    private var benchPlayersCount: Int {
        return awayBenchRoster.count + homeBenchRoster.count
    }
}