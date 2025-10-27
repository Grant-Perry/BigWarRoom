import Foundation
import Observation

#if os(iOS)
import AudioToolbox
import UIKit
#endif

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
}

enum SortMethod: CaseIterable, Identifiable {
    case wizard    // AI strategy
    case rankings  // Pure rankings
    case all       // All players in ranked order

    var id: String { displayName }
    var displayName: String {
        switch self {
        case .wizard: return "Wizard"
        case .rankings: return "Rankings"
        case .all: return "All"
        }
    }
}

enum PositionFilter: CaseIterable, Identifiable {
    case all, qb, rb, wr, te, k, dst

    var id: String { displayName }
    var displayName: String {
        switch self {
        case .all: return "All"
        case .qb: return "QB"
        case .rb: return "RB"
        case .wr: return "WR"
        case .te: return "TE"
        case .k: return "K"
        case .dst: return "DST"
        }
    }
}

@MainActor
@Observable
final class DraftRoomViewModel {
    
    // MARK: - Coordinators
    
    private let connectionCoordinator: DraftConnectionCoordinator
    private let rosterCoordinator: DraftRosterCoordinator
    private let suggestionsCoordinator: DraftSuggestionsCoordinator
    
    // MARK: - Forwarded Published Properties (from coordinators)
    
    // Connection properties
    var connectionStatus: ConnectionStatus { connectionCoordinator.connectionStatus }
    var sleeperDisplayName: String { connectionCoordinator.sleeperDisplayName }
    var sleeperUsername: String { connectionCoordinator.sleeperUsername }
    var allAvailableDrafts: [UnifiedLeagueManager.LeagueWrapper] { connectionCoordinator.allAvailableDrafts }
    
    // Roster properties
    var roster: Roster { rosterCoordinator.roster }
    var allDraftPicks: [EnhancedPick] { rosterCoordinator.allDraftPicks }
    var recentLivePicks: [SleeperPick] { rosterCoordinator.recentLivePicks }
    var myRosterID: Int? { rosterCoordinator.myRosterID }
    
    // Suggestions properties
    var suggestions: [Suggestion] { suggestionsCoordinator.suggestions }
    var selectedPositionFilter: PositionFilter { suggestionsCoordinator.selectedPositionFilter }
    var selectedSortMethod: SortMethod { suggestionsCoordinator.selectedSortMethod }
    
    // MARK: - 🔥 PHASE 3: @Observable UI State (no @Published needed)
    
    var picksFeed: String = ""
    var myPickInput: String = ""
    
    var selectedDraft: SleeperLeague?
    var selectedLeagueWrapper: UnifiedLeagueManager.LeagueWrapper?
    
    var pollingCountdown: Double = 0.0
    var maxPollingInterval: Double = 15.0
    
    // MARK: - Pick Notifications
    
    var showingPickAlert = false
    var showingConfirmationAlert = false
    var pickAlertMessage = ""
    var confirmationAlertMessage = ""
    var isMyTurn = false
    
    // MARK: - Manual Draft Position Selection
    
    var isConnectedToManualDraft = false
    var manualDraftNeedsPosition = false
    var selectedManualPosition: Int = 1
    var manualDraftInfo: SleeperDraft?
    var showManualDraftEntry = false
    
    // MARK: - ESPN Draft Pick Selection
    
    var showingESPNPickPrompt = false
    var pendingESPNLeagueWrapper: UnifiedLeagueManager.LeagueWrapper?
    var selectedESPNDraftPosition: Int = 1
    
    // MARK: - Services
    
    internal let sleeperClient = SleeperAPIClient.shared
    internal let espnClient = ESPNAPIClient.shared
    internal let playerDirectory = PlayerDirectoryStore.shared
    internal let polling = DraftPollingService.shared
    
    // MARK: - Draft Context & User Tracking (Internal for extensions)
    
    internal var draftRosters: [Int: DraftRosterInfo] = [:]
    internal var currentUserID: String?
    internal var myDraftSlot: Int?
    internal var allLeagueRosters: [SleeperRoster] = []
    internal var lastPickCount = 0
    internal var lastMyPickCount = 0
    
    // 🔥 PHASE 3: Replace Combine with observation task
    private var observationTask: Task<Void, Never>?
    
    // MARK: - User cache for ownerID -> SleeperUser lookups
    internal var userCache: [String: SleeperUser] = [:]
    
    // MARK: - Computed Properties
    
    /// Indicates whether we're using pure positional logic (for ESPN leagues and mock drafts)
    var isUsingPositionalLogic: Bool {
        // ESPN leagues ALWAYS use positional logic, even if they have roster info
        if selectedLeagueWrapper?.source == .espn {
            return true
        }
        
        // Mock drafts and manual drafts without roster correlation
        return myRosterID == nil && myDraftSlot != nil
    }
    
    /// Get the team count for the current draft (for positional calculations)
    var currentDraftTeamCount: Int {
        return selectedDraft?.totalRosters ?? 10
    }
    
    /// Computed property for max teams in current draft
    var maxTeamsInDraft: Int {
        // Priority 1: Use pending ESPN league data if we're in the picker
        if let pendingWrapper = pendingESPNLeagueWrapper {
            let totalRosters = pendingWrapper.league.totalRosters
            return totalRosters
        }
        
        // Priority 2: Use current draft/league data
        let fallback = manualDraftInfo?.settings?.teams ??
                      selectedDraft?.settings?.teams ??
                      selectedDraft?.totalRosters ??
                      12 // Reduced default from 16 to 12 (more common)
        
        return fallback
    }
    
    // MARK: - Current API Client
    
    /// Get the appropriate API client for the selected league
    internal var currentAPIClient: DraftAPIClient {
        return selectedLeagueWrapper?.client ?? sleeperClient
    }
    
    // MARK: - Live Mode
    
    var isLiveMode: Bool {
        connectionStatus == .connected
    }
    
    // MARK: - Init
    
    init(
        connectionCoordinator: DraftConnectionCoordinator? = nil,
        rosterCoordinator: DraftRosterCoordinator? = nil,
        suggestionsCoordinator: DraftSuggestionsCoordinator? = nil
    ) {
        // 🔥 FIX: Create coordinators with proper dependencies instead of using empty constructors
        if let connectionCoordinator = connectionCoordinator {
            self.connectionCoordinator = connectionCoordinator
        } else {
            // Create default connection coordinator with required dependencies
            let sleeperClient = SleeperAPIClient.shared
            let espnClient = ESPNAPIClient.shared
            let espnCredentials = ESPNCredentialsManager()
            let leagueManager = UnifiedLeagueManager(
                sleeperClient: sleeperClient,
                espnClient: espnClient,
                espnCredentials: espnCredentials
            )
            self.connectionCoordinator = DefaultDraftConnectionCoordinator(
                sleeperClient: sleeperClient,
                espnClient: espnClient,
                leagueManager: leagueManager,
                espnCredentials: espnCredentials
            )
        }
        
        self.rosterCoordinator = rosterCoordinator ?? DefaultDraftRosterCoordinator()
        self.suggestionsCoordinator = suggestionsCoordinator ?? DefaultDraftSuggestionsCoordinator()
        
        // Set up delegates
        (self.connectionCoordinator as? DefaultDraftConnectionCoordinator)?.delegate = self
        (self.rosterCoordinator as? DefaultDraftRosterCoordinator)?.delegate = self
        (self.suggestionsCoordinator as? DefaultDraftSuggestionsCoordinator)?.delegate = self
        
        setupObservation() // 🔥 PHASE 3: Replace Combine binding with observation
        
        // 🔥 PERFORMANCE FIX: Don't block init() with heavy operations!
        // Let the loading screen handle data loading asynchronously
        // This allows UI to show immediately while data loads in background
    }
    
    // MARK: - Async Initialization (called after UI is shown)
    
    /// Initialize heavy data operations asynchronously
    /// Call this from the loading screen or after UI appears
    func initializeDataAsync() async {
        // Only do heavy operations if needed
        if playerDirectory.needsRefresh {
            await playerDirectory.refreshPlayers()
        }
        await suggestionsCoordinator.refreshSuggestions()
    }
    
    // MARK: - 🔥 PHASE 3: Replace Combine Polling Service Binding with @Observable Observation
    
    private func setupObservation() {
        observationTask = Task { @MainActor in
            var lastObservedPickCount = 0
            var lastObservedCountdown = 0.0
            var lastObservedInterval = 0.0
            
            while !Task.isCancelled {
                // Observe polling service changes
                let currentPickCount = polling.allPicks.count
                let currentCountdown = polling.pollingCountdown
                let currentInterval = polling.currentPollingInterval
                
                // Check for pick changes
                if currentPickCount != lastObservedPickCount {
                    // Update roster coordinator with latest picks
                    let enhancedPicks = rosterCoordinator.buildEnhancedPicks(
                        from: polling.allPicks, 
                        draftRosters: draftRosters
                    )
                    
                    // Update roster coordinator's published properties
                    if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
                        defaultRosterCoordinator.recentLivePicks = Array(polling.recentPicks)
                        defaultRosterCoordinator.allDraftPicks = enhancedPicks
                    }
                    
                    // Check for turn changes and new picks
                    await checkForTurnChange()
                    await checkForMyNewPicks(polling.allPicks)
                    await rosterCoordinator.updateMyRosterFromPicks(polling.allPicks)
                    await suggestionsCoordinator.refreshSuggestions()
                    
                    lastObservedPickCount = currentPickCount
                }
                
                // Check for countdown changes
                if currentCountdown != lastObservedCountdown {
                    pollingCountdown = currentCountdown
                    lastObservedCountdown = currentCountdown
                }
                
                // Check for interval changes
                if currentInterval != lastObservedInterval {
                    maxPollingInterval = currentInterval
                    lastObservedInterval = currentInterval
                }
                
                // Small delay to prevent excessive polling
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    // MARK: - Public Methods (Delegate to Coordinators)
    
    // Connection methods
    func connectWithUsernameOrID(_ input: String, season: String = "2025") async {
        await connectionCoordinator.connectWithUsernameOrID(input, season: season)
    }
    
    func connectToESPNOnly() async {
        await connectionCoordinator.connectToESPNOnly()
    }
    
    func connectWithUserID(_ userID: String, season: String = "2025") async {
        await connectionCoordinator.connectWithUserID(userID, season: season)
    }
    
    func disconnectFromLive() {
        // Clear local state
        selectedDraft = nil
        selectedLeagueWrapper = nil
        polling.stopPolling()
        currentUserID = nil
        myDraftSlot = nil
        allLeagueRosters = []
        
        // Reset manual draft state
        isConnectedToManualDraft = false
        manualDraftNeedsPosition = false
        manualDraftInfo = nil
        
        // Update roster coordinator
        if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
            defaultRosterCoordinator.setMyRosterID(nil)
            defaultRosterCoordinator.setMyDraftSlot(nil)
        }
        
        // Delegate to connection coordinator
        connectionCoordinator.disconnectFromLive()
    }
    
    func refreshAllLeagues(season: String = "2025") async {
        await connectionCoordinator.refreshAllLeagues(season: season)
    }
    
    func debugESPNConnection() async {
        await connectionCoordinator.debugESPNConnection()
    }
    
    // Roster methods
    func addFeedPick() {
        rosterCoordinator.addFeedPick(picksFeed, playerDirectory: playerDirectory)
    }
    
    func lockMyPick() async {
        await rosterCoordinator.lockMyPick(myPickInput, playerDirectory: playerDirectory)
        myPickInput = ""
    }
    
    // Suggestions methods
    func updatePositionFilter(_ filter: PositionFilter) async {
        await suggestionsCoordinator.updatePositionFilter(filter)
    }
    
    func updateSortMethod(_ method: SortMethod) async {
        await suggestionsCoordinator.updateSortMethod(method)
    }
    
    func refreshSuggestions() async {
        await suggestionsCoordinator.refreshSuggestions()
    }
    
    func forceRefresh() async {
        await suggestionsCoordinator.forceRefresh()
    }
}

// MARK: - DraftConnectionCoordinatorDelegate

extension DraftRoomViewModel: DraftConnectionCoordinatorDelegate {
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didConnectWithLeagues leagues: [UnifiedLeagueManager.LeagueWrapper]) {
        // Handle successful connection - leagues are already updated in coordinator
        AppLogger.info("DraftRoomViewModel: Connected with \(leagues.count) leagues", category: "DraftRoom")
        
        // Update our currentUserID to match
        currentUserID = coordinator.currentUserID
        
        // 🔥 PHASE 3: No need for objectWillChange.send() with @Observable - automatic change detection
    }
    
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didFailWithError error: Error) {
        AppLogger.error("DraftRoomViewModel: Connection failed: \(error)", category: "DraftRoom")
    }
    
    func connectionCoordinator(_ coordinator: DraftConnectionCoordinator, didRefreshLeagues leagues: [UnifiedLeagueManager.LeagueWrapper]) {
        AppLogger.info("DraftRoomViewModel: Refreshed \(leagues.count) leagues", category: "DraftRoom")
        // 🔥 PHASE 3: No need for objectWillChange.send() with @Observable
    }
    
    func connectionCoordinatorDidDisconnect(_ coordinator: DraftConnectionCoordinator) {
        AppLogger.info("DraftRoomViewModel: Disconnected from services", category: "DraftRoom")
        currentUserID = nil
        // 🔥 PHASE 3: No need for objectWillChange.send() with @Observable
    }
}

// MARK: - DraftRosterCoordinatorDelegate

extension DraftRoomViewModel: DraftRosterCoordinatorDelegate {
    func rosterCoordinator(_ coordinator: DraftRosterCoordinator, didUpdateRoster roster: Roster) {
        AppLogger.info("DraftRoomViewModel: Roster updated with \(totalPlayersInRoster(roster)) players", category: "DraftRoom")
        // Trigger suggestions refresh after roster update
        Task {
            await suggestionsCoordinator.refreshSuggestions()
        }
        // 🔥 PHASE 3: No need for objectWillChange.send() with @Observable
    }
    
    func rosterCoordinatorTeamCount(_ coordinator: DraftRosterCoordinator) -> Int {
        return currentDraftTeamCount
    }
    
    private func totalPlayersInRoster(_ roster: Roster) -> Int {
        let starters = [roster.qb, roster.rb1, roster.rb2, roster.wr1, roster.wr2, roster.wr3,
                       roster.te, roster.flex, roster.k, roster.dst].compactMap { $0 }.count
        return starters + roster.bench.count
    }
}

// MARK: - DraftSuggestionsCoordinatorDelegate

extension DraftRoomViewModel: DraftSuggestionsCoordinatorDelegate {
    func suggestionsCoordinatorGetContext(_ coordinator: DraftSuggestionsCoordinator) -> DraftSuggestionsContext? {
        return DraftSuggestionsContext(
            roster: roster,
            selectedDraft: selectedDraft,
            currentDraft: polling.currentDraft,
            allPicks: polling.allPicks,
            draftRosters: draftRosters,
            myRosterPlayerIDs: rosterCoordinator.myRosterPlayerIDs()
        )
    }
    
    func suggestionsCoordinatorForceRefresh(_ coordinator: DraftSuggestionsCoordinator) async {
        await polling.forceRefresh()
    }
}

// MARK: - Internal Helper Methods (needed by extensions that remain)

extension DraftRoomViewModel {
    
    // MARK: - Logging Helper Methods
    
    internal func logInfo(_ message: String, category: String) {
        AppLogger.info(message, category: category)
    }
    
    internal func logWarning(_ message: String, category: String) {
        AppLogger.warning(message, category: category)
    }
    
    internal func logError(_ message: String, category: String) {
        AppLogger.error(message, category: category)
    }
    
    internal func logDebug(_ message: String, category: String) {
        AppLogger.debug(message, category: category)
    }
    
    // MARK: - Roster Management Helpers
    
    internal func loadMyActualRoster() async {
        await rosterCoordinator.loadMyActualRoster(from: allLeagueRosters)
    }
    
    internal func updateMyRosterFromPicks(_ picks: [SleeperPick]) async {
        await rosterCoordinator.updateMyRosterFromPicks(picks)
        updateMyRosterInfo()
    }
    
    internal func buildEnhancedPicks(from picks: [SleeperPick]) -> [EnhancedPick] {
        return rosterCoordinator.buildEnhancedPicks(from: picks, draftRosters: draftRosters)
    }
    
    internal func myRosterPlayerIDs() -> [String] {
        return rosterCoordinator.myRosterPlayerIDs()
    }
    
    internal func rostersAreEqual(_ r1: Roster, _ r2: Roster) -> Bool {
        return rosterCoordinator.rostersAreEqual(r1, r2)
    }
    
    internal func updateMyRosterInfo() {
        // Update roster coordinator with current context
        if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
            defaultRosterCoordinator.setMyDraftSlot(self.myDraftSlot)
        }
    }
}