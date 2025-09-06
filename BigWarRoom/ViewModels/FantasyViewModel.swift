// 
//  FantasyViewModel.swift
//  BigWarRoom
//
//  Core ViewModel for Fantasy matchup data and operations
//
// MARK: -> Fantasy ViewModel Core

import Foundation
import Combine
import SwiftUI

@MainActor
final class FantasyViewModel: ObservableObject {
    // MARK: -> Published Properties
    @Published var matchups: [FantasyMatchup] = []
    @Published var byeWeekTeams: [FantasyTeam] = []
    @Published var selectedLeague: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedWeek: Int = 1
    @Published var selectedYear: String = String(Calendar.current.component(.year, from: Date()))
    @Published var autoRefresh: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showWeekSelector: Bool = false
    @Published var choppedWeekSummary: ChoppedWeekSummary?
    @Published var currentChoppedSummary: ChoppedWeekSummary?
    @Published var isLoadingChoppedData: Bool = false
    @Published var hasActiveRosters: Bool = false
    @Published var detectedAsChoppedLeague: Bool = false
    @Published var nflGameService = NFLGameDataService.shared
    
    // Flag to disable auto-refresh when MatchupsHub is managing refreshes
    var isControlledByMatchupsHub: Bool = false

    // MARK: -> Team Identification
    /// The authenticated user's team ID for the currently selected league
    /// This ensures Mission Control shows the correct matchup every damn time
    var myTeamID: String?

    // Make nflWeekService publicly accessible for UI
    private let nflWeekService = NFLWeekService.shared
    
    // Public getter for UI access
    var currentNFLWeek: Int {
        return nflWeekService.currentWeek
    }
    
    // MARK: -> ESPN Data Storage
    @Published var espnTeamRecords: [Int: TeamRecord] = [:]
    @Published var espnTeamNames: [Int: String] = [:]
    @Published var currentESPNLeague: ESPNLeague? = nil // For ESPN member name resolution
    
    // MARK: -> Sleeper Data Storage
    @Published var sleeperLeagueSettings: [String: Any]? = nil
    @Published var playerStats: [String: [String: Double]] = [:]
    @Published var rosterIDToManagerID: [Int: String] = [:]
    @Published var userIDs: [String: String] = [:]
    @Published var userAvatars: [String: URL] = [:]
    
    // MARK: -> Picker Options
    let availableWeeks = Array(1...18)
    let availableYears = ["2023", "2024", "2025"]
    
    // MARK: -> Dependencies
    private let unifiedLeagueManager = UnifiedLeagueManager()
    let playerDirectoryStore = PlayerDirectoryStore.shared
    var sharedDraftRoomViewModel: DraftRoomViewModel?
    var refreshTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    
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
        nflWeekService.$currentWeek
            .sink { [weak self] newWeek in
                if self?.selectedWeek != newWeek {
                    self?.selectedWeek = newWeek
                    self?.refreshNFLGameData()
                }
            }
            .store(in: &cancellables)
        
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
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
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
    
    /// Enable/disable MatchupsHub control to prevent refresh conflicts
    nonisolated func setMatchupsHubControl(_ enabled: Bool) {
        Task { @MainActor in
            self.isControlledByMatchupsHub = enabled
            if enabled {
                // Disable auto-refresh when hub is controlling
                self.refreshTimer?.invalidate()
            } else {
                // Re-enable auto-refresh if it was enabled
                self.setupAutoRefresh()
            }
        }
    }
    
    // MARK: -> League Selection
    /// Set the connected league from War Room
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper) {
        selectedLeague = league
        clearAllData()
        
        Task {
            await fetchMatchups()
        }
    }
    
    /// Set the connected league with explicit team ID for reliable identification
    /// This method ensures Mission Control shows YOUR fucking matchup, not some random one
    func selectLeague(_ league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String?) {
        // Only update if it's a new league or we are refreshing the same league with team ID
        guard selectedLeague?.id != league.id || myTeamID != nil else {
            return
        }
        
        selectedLeague = league
        self.myTeamID = myTeamID
        clearAllData()
        
        print("🎯 LEAGUE SELECTION: Selected league \(league.league.name) with myTeamID: \(myTeamID ?? "nil")")
        
        Task {
            await fetchMatchups()
        }
    }
    
    /// Available leagues from UnifiedLeagueManager
    var availableLeagues: [UnifiedLeagueManager.LeagueWrapper] {
        return unifiedLeagueManager.allLeagues
    }
    
    /// Clear all cached data
    private func clearAllData() {
        matchups = []
        byeWeekTeams = []
        errorMessage = nil
        detectedAsChoppedLeague = false
        hasActiveRosters = false
        currentChoppedSummary = nil
        // Don't clear myTeamID here - it's needed for reliable identification
        
        // Clear ESPN-specific data
        espnTeamRecords.removeAll()
        espnTeamNames.removeAll()
        
        // Clear Sleeper-specific data
        sleeperLeagueSettings = nil
        playerStats.removeAll()
        rosterIDToManagerID.removeAll()
        userIDs.removeAll()
        userAvatars.removeAll()
    }
    
    // MARK: -> Auto Refresh Setup
    /// Toggle auto refresh on/off
    func toggleAutoRefresh() {
        autoRefresh.toggle()
        setupAutoRefresh()
    }
    
    /// Setup auto refresh timer
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        // Don't auto-refresh if MatchupsHub is controlling
        if autoRefresh && !isControlledByMatchupsHub {
            let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
                Task { @MainActor in
                    if UIApplication.shared.applicationState == .active {
                        await self.refreshMatchups()
                    }
                }
            }
        }
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
        
        Task {
            await fetchMatchups()
        }
    }
    
    // MARK: -> Load Leagues
    /// Load available leagues on app start
    func loadLeagues() async {
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: AppConstants.GpSleeperID, 
            season: selectedYear
        )
    }
    
    /// Initialize NFL game data for the current week
    func setupNFLGameData() {
        let currentWeek = getCurrentWeek()
        let currentYear = Int(selectedYear) ?? 2024
        
        nflGameService.fetchGameData(forWeek: currentWeek, year: currentYear)
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        if [1, 2, 5].contains(weekday) {
            nflGameService.startLiveUpdates(forWeek: currentWeek, year: currentYear)
        }
    }
    
    /// Helper to get current NFL week
    private func getCurrentWeek() -> Int {
        return nflWeekService.currentWeek
    }
}