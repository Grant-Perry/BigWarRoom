// 
//  FantasyViewModel.swift
//  BigWarRoom
//
//  🔥 PHASE 3 REFACTOR: Simplified ViewModel with extracted services
//  Core ViewModel for Fantasy matchup data and operations
//  NOW: Pure orchestration layer - business logic moved to services
//

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class FantasyViewModel {
    
    // MARK: - State Properties
    var matchups: [FantasyMatchup] = []
    var byeWeekTeams: [FantasyTeam] = []
    var selectedLeague: UnifiedLeagueManager.LeagueWrapper?
    var selectedYear: String = AppConstants.currentSeasonYear
    var autoRefresh: Bool = true
    var isLoading: Bool = false
    var errorMessage: String?
    var showWeekSelector: Bool = false
    var choppedWeekSummary: ChoppedWeekSummary?
    var currentChoppedSummary: ChoppedWeekSummary?
    var isLoadingChoppedData: Bool = false
    var hasActiveRosters: Bool = false
    var detectedAsChoppedLeague: Bool = false
    
    // MARK: - ESPN Data Storage (for UI access)
    var espnTeamRecords: [Int: TeamRecord] = [:]
    var espnTeamNames: [Int: String] = [:]
    var currentESPNLeague: ESPNLeague? = nil
    
    // MARK: - Sleeper Data Storage (for UI access)
    var sleeperLeague: SleeperLeague?
    var sleeperRosters: [SleeperRoster] = []
    var rosterIDToManagerID: [Int: String] = [:]
    var userIDs: [String: String] = [:]
    var userAvatars: [String: URL] = [:]
    
    // MARK: - Team Identification
    var myTeamID: String?
    
    // MARK: - Control Flags
    var isControlledByMatchupsHub: Bool = false
    var sharedDraftRoomViewModel: DraftRoomViewModel?
    
    // MARK: - Instance Tracking
    private let instanceID = UUID().uuidString.prefix(8)
    private static var instanceCount = 0
    
    // MARK: - Week Management (SSOT)
    private let weekManager = WeekSelectionManager.shared
    
    var selectedWeek: Int {
        return weekManager.selectedWeek
    }
    
    // MARK: - Dependencies (Injected)
    private let unifiedLeagueManager: UnifiedLeagueManager
    private let sleeperCredentials: SleeperCredentialsManager
    private let playerDirectoryStore: PlayerDirectoryStore
    let nflGameService: NFLGameDataService
    private let nflWeekService: NFLWeekService
    
    // 🔥 PHASE 3: NEW service dependencies (internal for extensions)
    internal let matchupDataStore: MatchupDataStore
    internal let espnFantasyService: ESPNFantasyService
    internal let sleeperFantasyService: SleeperFantasyService
    internal let matchupMapperService: MatchupMapperService
    
    // MARK: - Refresh Control
    private var refreshTimer: Timer?
    private var observationTask: Task<Void, Never>?
    private var isRefreshing = false
    
    // MARK: - Initialization
    init(
        matchupDataStore: MatchupDataStore,
        unifiedLeagueManager: UnifiedLeagueManager,
        sleeperCredentials: SleeperCredentialsManager,
        playerDirectoryStore: PlayerDirectoryStore,
        nflGameService: NFLGameDataService,
        nflWeekService: NFLWeekService,
        espnFantasyService: ESPNFantasyService,
        sleeperFantasyService: SleeperFantasyService,
        matchupMapperService: MatchupMapperService
    ) {
        self.matchupDataStore = matchupDataStore
        self.unifiedLeagueManager = unifiedLeagueManager
        self.sleeperCredentials = sleeperCredentials
        self.playerDirectoryStore = playerDirectoryStore
        self.nflGameService = nflGameService
        self.nflWeekService = nflWeekService
        self.espnFantasyService = espnFantasyService
        self.sleeperFantasyService = sleeperFantasyService
        self.matchupMapperService = matchupMapperService
        
        Task { @MainActor in
            FantasyViewModel.instanceCount += 1
        }
        
        setupObservation()
        setupInitialNFLGameData()
    }
    
    deinit {
        Task { @MainActor in
            FantasyViewModel.instanceCount -= 1
            refreshTimer?.invalidate()
            observationTask?.cancel()
        }
    }
    
    // MARK: - Observation Setup
    
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedWeek = weekManager.selectedWeek
            var lastObservedYear = nflWeekService.currentYear
            
            while !Task.isCancelled {
                // Check if WeekSelectionManager's selectedWeek changed
                let currentWeek = weekManager.selectedWeek
                if currentWeek != lastObservedWeek {
                    DebugPrint(mode: .weekCheck, "📊 FantasyViewModel \(instanceID): Week changed to \(currentWeek), refreshing data...")
                    
                    guard !isRefreshing else {
                        lastObservedWeek = currentWeek
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                    
                    isRefreshing = true
                    
                    refreshNFLGameData()
                    
                    if selectedLeague != nil {
                        await fetchMatchups()
                    }
                    
                    isRefreshing = false
                    lastObservedWeek = currentWeek
                }
                
                // Check if NFLWeekService's currentYear changed
                let currentYear = nflWeekService.currentYear
                if currentYear != lastObservedYear {
                    if selectedYear != currentYear {
                        selectedYear = currentYear
                        refreshNFLGameData()
                    }
                    lastObservedYear = currentYear
                }
                
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    // MARK: - NFL Game Data Management
    
    var currentNFLWeek: Int {
        return nflWeekService.currentWeek
    }
    
    private func setupInitialNFLGameData() {
        let currentWeek = selectedWeek
        let currentYear = AppConstants.currentSeasonYearInt
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        if [1, 2, 5].contains(weekday) {
            nflGameService.startLiveUpdates(forWeek: currentWeek, year: currentYear)
        }
    }
    
    private func refreshNFLGameData() {
        let currentWeek = selectedWeek
        let currentYear = AppConstants.currentSeasonYearInt
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear, forceRefresh: true)
    }
    
    func setupNFLGameData() {
        let currentWeek = selectedWeek
        let currentYear = AppConstants.currentSeasonYearInt
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        if [1, 2, 5].contains(weekday) {
            nflGameService.startLiveUpdates(forWeek: currentWeek, year: currentYear)
        }
    }
    
    // MARK: - League Management
    
    var availableLeagues: [UnifiedLeagueManager.LeagueWrapper] {
        return unifiedLeagueManager.allLeagues
    }
    
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper) {
        selectedLeague = league
        clearAllData()
        
        Task {
            await fetchMatchups()
        }
    }
    
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String?) {
        guard selectedLeague?.id != league.id || myTeamID != nil else {
            return
        }
        
        selectedLeague = league
        self.myTeamID = myTeamID
        clearAllData()
        
        DebugPrint(mode: .fantasy, "🎯 LEAGUE SELECTION: Selected league \(league.league.name) with myTeamID: \(myTeamID ?? "nil")")
        
        Task {
            await fetchMatchups()
        }
    }
    
    func loadLeagues() async {
        let sleeperUserID = sleeperCredentials.getUserIdentifier()
        
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: sleeperUserID,
            season: AppConstants.currentSeasonYear
        )
    }
    
    private func clearAllData() {
        matchups = []
        byeWeekTeams = []
        errorMessage = nil
        detectedAsChoppedLeague = false
        hasActiveRosters = false
        currentChoppedSummary = nil
        
        espnTeamRecords.removeAll()
        espnTeamNames.removeAll()
        currentESPNLeague = nil
        
        rosterIDToManagerID.removeAll()
        userIDs.removeAll()
        userAvatars.removeAll()
        sleeperRosters.removeAll()
        sleeperLeague = nil
    }
    
    // MARK: - Week Selection
    
    let availableWeeks = Array(1...18)
    let availableYears = AppConstants.availableYears
    
    func presentWeekSelector() {
        showWeekSelector = true
    }
    
    func dismissWeekSelector() {
        showWeekSelector = false
    }
    
    func selectWeek(_ week: Int) {
        weekManager.selectWeek(week)
    }
    
    // MARK: - MatchupsHub Control
    
    nonisolated func setMatchupsHubControl(_ enabled: Bool) {
        Task { @MainActor in
            self.isControlledByMatchupsHub = enabled
            if enabled {
                self.refreshTimer?.invalidate()
            }
        }
    }
    
    func setSharedDraftRoomViewModel(_ viewModel: DraftRoomViewModel) {
        sharedDraftRoomViewModel = viewModel
    }
    
    // MARK: - ESPN Scoring Settings
    
    func getESPNScoringSettings() -> [String: Double]? {
        if currentESPNLeague == nil, let league = selectedLeague, league.source == .espn {
            Task {
                do {
                    let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
                    await MainActor.run {
                        self.currentESPNLeague = espnLeague
                    }
                } catch {
                    DebugPrint(mode: .espnAPI, "Failed to fetch ESPN league data: \(error)")
                }
            }
            return nil
        }
        
        guard let espnLeague = currentESPNLeague else {
            return nil
        }
        
        return espnFantasyService.getScoringSettings(from: espnLeague)
    }
    
    func getESPNScoringSettingsSync() -> [String: Double]? {
        guard let espnLeague = currentESPNLeague else {
            return nil
        }
        
        return espnFantasyService.getScoringSettings(from: espnLeague)
    }
    
    func ensureESPNLeagueDataLoaded() async {
        guard let league = selectedLeague,
              league.source == .espn,
              currentESPNLeague == nil else {
            return
        }
        
        do {
            let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
            currentESPNLeague = espnLeague
        } catch {
            DebugPrint(mode: .espnAPI, "❌ ESPN: Failed to load league data: \(error)")
        }
    }
}