// 
//  FantasyViewModel.swift
//  BigWarRoom
//
//  Core ViewModel for Fantasy matchup data and operations
//
// MARK: -> Fantasy ViewModel Core

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class FantasyViewModel {
    // MARK: -> Singleton
    static let shared = FantasyViewModel()
    
    // MARK: -> 🔥 PHASE 3: @Observable State Properties (no @Published needed)
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
    var nflGameService = NFLGameDataService.shared
    
    // MARK: -> Instance tracking for debugging
    private let instanceID = UUID().uuidString.prefix(8)
    private static var instanceCount = 0 {
        didSet {
            // print("📊 FantasyViewModel instance count: \(instanceCount)")
        }
    }
    
    // MARK: -> Week Management (SSOT)
    /// The week selection manager - SINGLE SOURCE OF TRUTH for all week data
    private let weekManager = WeekSelectionManager.shared
    
    /// Public getter for selectedWeek - always use WeekSelectionManager
    var selectedWeek: Int {
        return weekManager.selectedWeek
    }
    
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
    var espnTeamRecords: [Int: TeamRecord] = [:]
    var espnTeamNames: [Int: String] = [:]
    var currentESPNLeague: ESPNLeague? = nil // For ESPN member name resolution
    
    // MARK: -> Sleeper Data Storage
    var sleeperLeagueSettings: [String: Any]? = nil
    var sleeperLeague: SleeperLeague?  // 🔥 NEW: Store full Sleeper league for FAAB and other settings
    var sleeperRosters: [SleeperRoster] = []  // 🔥 NEW: Store rosters for record and FAAB lookup
    var playerStats: [String: [String: Double]] = [:]
    var rosterIDToManagerID: [Int: String] = [:]
    var userIDs: [String: String] = [:]
    var userAvatars: [String: URL] = [:]
    
    // MARK: -> Picker Options
    let availableWeeks = Array(1...18)
    let availableYears = AppConstants.availableYears
    
    // MARK: -> Dependencies
    private let unifiedLeagueManager: UnifiedLeagueManager = {
        let sleeperClient = SleeperAPIClient()
        let espnCreds = ESPNCredentialsManager()
        let espnClient = ESPNAPIClient(credentialsManager: espnCreds)
        return UnifiedLeagueManager(
            sleeperClient: sleeperClient,
            espnClient: espnClient,
            espnCredentials: espnCreds
        )
    }()
    private let sleeperCredentials = SleeperCredentialsManager.shared // 🔥 NEW: Add Sleeper credentials manager
    let playerDirectoryStore = PlayerDirectoryStore.shared
    var sharedDraftRoomViewModel: DraftRoomViewModel?
    var refreshTimer: Timer?
    
    // 🔥 PHASE 3: Replace Combine with observation task
    private var observationTask: Task<Void, Never>?
    
    // MARK: -> Refresh control to prevent cascading
    private var isRefreshing = false
    
    // MARK: -> Initialization (Made public for navigation instances)
    init() {
        Task { @MainActor in
            FantasyViewModel.instanceCount += 1
            // print("📊 FantasyViewModel Instance \(instanceID) created (total: \(FantasyViewModel.instanceCount))")
        }
        
        setupAutoRefresh()
        setupObservation() // 🔥 PHASE 3: Replace Combine subscriptions with observation
        setupInitialNFLGameData()
    }
    
    deinit {
        Task { @MainActor in
            FantasyViewModel.instanceCount -= 1
            // print("📊 FantasyViewModel Instance \(instanceID) destroyed (remaining: \(FantasyViewModel.instanceCount))")
            refreshTimer?.invalidate()
            observationTask?.cancel()
        }
    }
    
    /// 🔥 PHASE 3: Replace Combine subscriptions with @Observable observation
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedWeek = weekManager.selectedWeek
            var lastObservedYear = nflWeekService.currentYear
            
            while !Task.isCancelled {
                // Check if WeekSelectionManager's selectedWeek changed
                let currentWeek = weekManager.selectedWeek
                if currentWeek != lastObservedWeek {
                    print("📊 FantasyViewModel \(instanceID): Week changed to \(currentWeek), refreshing data...")
                    
                    // Prevent cascading refreshes
                    guard !isRefreshing else {
                        print("📊 FantasyViewModel \(instanceID): Skipping refresh - already refreshing")
                        lastObservedWeek = currentWeek
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                    
                    isRefreshing = true
                    
                    // Update NFL game data for the new week (non-blocking)
                    refreshNFLGameData()
                    
                    // Refresh matchups for the new week (only if we have a selected league)
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
                
                // Small delay to prevent excessive polling
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    /// Setup initial NFL game data
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
    
    /// Refresh NFL game data when week changes
    private func refreshNFLGameData() {
        let currentWeek = selectedWeek
        let currentYear = AppConstants.currentSeasonYearInt
        
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
        
        // x Print("🎯 LEAGUE SELECTION: Selected league \(league.league.name) with myTeamID: \(myTeamID ?? "nil")")
        
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
        sleeperRosters.removeAll()  // 🔥 NEW: Clear roster data
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
        
        // 🔥 DISABLED: Removed competing timer - MatchupsHubViewModel handles all auto-refresh
        // Individual ViewModels should not have their own refresh timers to prevent conflicts
        // Only MatchupsHubViewModel.shared should control the global refresh cycle
        
        // Don't auto-refresh if MatchupsHub is controlling
        // if autoRefresh && !isControlledByMatchupsHub {
        //     let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
        //     refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
        //         Task { @MainActor in
        //             if UIApplication.shared.applicationState == .active {
        //                 await self.refreshMatchups()
        //             }
        //         }
        //     }
        // }
    }
    
    // MARK: -> Week Selection (DEPRECATED - Now handled by WeekSelectionManager)
    /// Show week selector sheet
    func presentWeekSelector() {
        showWeekSelector = true
    }
    
    /// Hide week selector sheet
    func dismissWeekSelector() {
        showWeekSelector = false
    }
    
    /// Select a specific week - NOW USES WeekSelectionManager
    func selectWeek(_ week: Int) {
        weekManager.selectWeek(week)
        // No need to manually refresh - the observation will handle it
    }
    
    // MARK: -> Load Leagues
    /// Load available leagues on app start
    func loadLeagues() async {
        // 🔥 FIX: Use dynamic Sleeper credentials instead of hardcoded AppConstants.GpSleeperID
        let sleeperUserID = sleeperCredentials.getUserIdentifier()
        
        await unifiedLeagueManager.fetchAllLeagues(
            sleeperUserID: sleeperUserID,
            season: AppConstants.currentSeasonYear
        )
    }
    
    /// Initialize NFL game data for the current week
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
    
    // MARK: - ADD: ESPN Scoring Settings Helper
    
    /// Convert ESPN scoring settings to format usable by ScoreBreakdownFactory
    func getESPNScoringSettings() -> [String: Double]? {
        print("🐛 DEBUG: getESPNScoringSettings called")
        
        // 🔥 FIX: If currentESPNLeague is nil, try to fetch it from the selected league
        if currentESPNLeague == nil, let league = selectedLeague, league.source == .espn {
            print("🐛 DEBUG: currentESPNLeague is nil, attempting to fetch ESPN league data")
            Task {
                do {
                    let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
                    await MainActor.run {
                        self.currentESPNLeague = espnLeague
                        print("🐛 DEBUG: Successfully fetched and stored ESPN league data")
                    }
                } catch {
                    print("🐛 DEBUG: Failed to fetch ESPN league data: \(error)")
                }
            }
            // For now, return nil since the fetch is async
            print("🐛 DEBUG: Initiated async fetch, returning nil for now")
            return nil
        }
        
        guard let espnLeague = currentESPNLeague else {
            print("🐛 DEBUG: No currentESPNLeague - selectedLeague: \(selectedLeague?.source.rawValue ?? "nil")")
            return nil
        }
        
//        print("🐛 DEBUG: Found currentESPNLeague: \(espnLeague.displayName)")
        
        // 🔥 UPDATED: Check both root level and nested scoring settings
        var scoringSettings: ESPNScoringSettings?
        
        // First try root level scoring settings
        if let rootScoring = espnLeague.scoringSettings {
//            print("🐛 DEBUG: Found root level scoringSettings")
            scoringSettings = rootScoring
        }
        // Then try nested scoring settings in league settings
        else if let nestedScoring = espnLeague.settings?.scoringSettings {
//            print("🐛 DEBUG: Found nested scoringSettings in league settings")
            scoringSettings = nestedScoring
        } else {
//            print("🐛 DEBUG: No scoringSettings found in ESPN league (checked root and nested)")
            return nil
        }
        
//        print("🐛 DEBUG: Using scoringSettings from: \(espnLeague.scoringSettings != nil ? "root" : "nested")")
        
        guard let finalScoringSettings = scoringSettings,
              let scoringItems = finalScoringSettings.scoringItems else {
//            print("🐛 DEBUG: No scoringItems in ESPN scoring settings")
            return nil
        }
        
//        print("🐛 DEBUG: Found \(scoringItems.count) ESPN scoring items")
        
        var scoringMap: [String: Double] = [:]
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { 
//                print("🐛 DEBUG: Skipping item with missing statId or points")
                continue 
            }
            
            // 🔥 FIX: Use direct ESPN stat ID to Sleeper key mapping instead of display names
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                scoringMap[sleeperKey] = points
//                print("🐛 DEBUG: ESPN Scoring - \(sleeperKey) (stat \(statId)) = \(points) points")
            } else {
//                print("🐛 DEBUG: No mapping for ESPN stat ID \(statId)")
            }
        }
        
//        print("🐛 DEBUG: Final ESPN scoring map has \(scoringMap.count) entries")
        return scoringMap.isEmpty ? nil : scoringMap
    }
    
    // 🔥 NEW: Synchronous ESPN scoring settings getter for immediate use
    func getESPNScoringSettingsSync() -> [String: Double]? {
        guard let espnLeague = currentESPNLeague else {
            return nil
        }
        
        var scoringSettings: ESPNScoringSettings?
        
        if let rootScoring = espnLeague.scoringSettings {
            scoringSettings = rootScoring
        } else if let nestedScoring = espnLeague.settings?.scoringSettings {
            scoringSettings = nestedScoring
        } else {
            return nil
        }
        
        guard let finalScoringSettings = scoringSettings,
              let scoringItems = finalScoringSettings.scoringItems else {
            return nil
        }
        
        var scoringMap: [String: Double] = [:]
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { 
                continue 
            }
            
            // Use direct ESPN stat ID to Sleeper key mapping
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                scoringMap[sleeperKey] = points
            }
        }
        
        return scoringMap.isEmpty ? nil : scoringMap
    }
    
    // 🔥 NEW: Method to ensure ESPN league data is loaded
    func ensureESPNLeagueDataLoaded() async {
        guard let league = selectedLeague, 
              league.source == .espn,
              currentESPNLeague == nil else {
            return
        }
        
        do {
            let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
            currentESPNLeague = espnLeague
//            print("✅ ESPN: Loaded league data for scoring breakdown")
        } catch {
//            print("❌ ESPN: Failed to load league data: \(error)")
        }
    }
}