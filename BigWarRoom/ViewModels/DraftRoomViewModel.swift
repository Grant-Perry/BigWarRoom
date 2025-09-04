import Foundation
import Combine

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
final class DraftRoomViewModel: ObservableObject {
    // MARK: - Published UI State
    
    @Published var suggestions: [Suggestion] = []
    @Published var selectedPositionFilter: PositionFilter = .all
    @Published var selectedSortMethod: SortMethod = .wizard
    
    @Published var picksFeed: String = ""
    @Published var myPickInput: String = ""
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var sleeperDisplayName: String = ""
    @Published var sleeperUsername: String = ""
    
    @Published var allAvailableDrafts: [UnifiedLeagueManager.LeagueWrapper] = []
    @Published var selectedDraft: SleeperLeague?
    @Published var selectedLeagueWrapper: UnifiedLeagueManager.LeagueWrapper?
    
    @Published var allDraftPicks: [EnhancedPick] = []
    @Published var recentLivePicks: [SleeperPick] = []
    
    @Published var pollingCountdown: Double = 0.0
    @Published var maxPollingInterval: Double = 15.0
    
    @Published var roster: Roster = .init()
    
    // MARK: - Pick Notifications
    
    @Published var showingPickAlert = false
    @Published var showingConfirmationAlert = false
    @Published var pickAlertMessage = ""
    @Published var confirmationAlertMessage = ""
    @Published var isMyTurn = false
    
    // MARK: - Manual Draft Position Selection
    
    @Published var isConnectedToManualDraft = false
    @Published var manualDraftNeedsPosition = false
    @Published var selectedManualPosition: Int = 1
    @Published var manualDraftInfo: SleeperDraft?
    @Published var showManualDraftEntry = false
    
    // MARK: - ESPN Draft Pick Selection
    
    @Published var showingESPNPickPrompt = false
    @Published var pendingESPNLeagueWrapper: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedESPNDraftPosition: Int = 1
    
    // MARK: - Services
    
    internal let sleeperClient = SleeperAPIClient.shared
    internal let espnClient = ESPNAPIClient.shared
    internal let leagueManager = UnifiedLeagueManager()
    internal let playerDirectory = PlayerDirectoryStore.shared
    internal let polling = DraftPollingService.shared
    internal let suggestionEngine = SuggestionEngine()
    
    // MARK: - Draft Context & User Tracking (Internal for extensions)
    
    internal var draftRosters: [Int: DraftRosterInfo] = [:]
    internal var currentUserID: String?
    internal var _myRosterID: Int?  // Private storage
    internal var myDraftSlot: Int?
    internal var allLeagueRosters: [SleeperRoster] = []
    internal var lastPickCount = 0
    internal var lastMyPickCount = 0
    
    // MARK: - Combine
    
    internal var cancellables = Set<AnyCancellable>()
    internal var suggestionsTask: Task<Void, Never>?
    
    // MARK: - User cache for ownerID -> SleeperUser lookups
    internal var userCache: [String: SleeperUser] = [:]
    
    // MARK: - Computed Properties for Views
    
    /// Expose myRosterID for UI components to identify user's picks
    var myRosterID: Int? {
        // For ESPN leagues using positional logic, return a synthetic roster ID
        if _myRosterID == nil && myDraftSlot != nil {
            // Use a synthetic ID based on draft slot for UI components
            return myDraftSlot
        }
        return _myRosterID
    }
    
    /// Indicates whether we're using pure positional logic (for ESPN leagues and mock drafts)
    /// This helps UI components know to ignore roster correlation and use snake draft math instead
    var isUsingPositionalLogic: Bool {
        // ESPN leagues ALWAYS use positional logic, even if they have roster info
        if selectedLeagueWrapper?.source == .espn {
            return true
        }
        
        // Mock drafts and manual drafts without roster correlation
        return _myRosterID == nil && myDraftSlot != nil
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
            // xprint("🏈 maxTeamsInDraft - Using pending ESPN league: \(totalRosters)")
            return totalRosters
        }
        
        // Priority 2: Use current draft/league data
        let fallback = manualDraftInfo?.settings?.teams ??
                      selectedDraft?.settings?.teams ??
                      selectedDraft?.totalRosters ??
                      12 // Reduced default from 16 to 12 (more common)
        
        // xprint("🏈 maxTeamsInDraft - Using fallback: \(fallback)")
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
    
    init() {
        bindToPollingService()
        Task {
            if playerDirectory.needsRefresh {
                await playerDirectory.refreshPlayers()
            }
            await refreshSuggestions()
        }
    }
    
    // MARK: - Binding
    
    private func bindToPollingService() {
        polling.$allPicks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] picks in
                guard let self else { return }
                self.recentLivePicks = Array(self.polling.recentPicks)
                self.allDraftPicks = self.buildEnhancedPicks(from: picks)
                
                // Debug logging for mock draft tracking
                if self.myDraftSlot != nil && self._myRosterID == nil {
                    let mySlotPicks = picks.filter { $0.draftSlot == self.myDraftSlot }
                    // xprint("🏈 Mock Draft Tracking - Slot \(self.myDraftSlot!): \(mySlotPicks.count) picks")
                    for pick in mySlotPicks {
                        if let playerID = pick.playerID,
                           let player = self.playerDirectory.player(for: playerID) {
                            // xprint("   • Pick \(pick.pickNo): \(player.shortName)")
                        }
                    }
                }
                
                // Check for turn changes and new picks
                Task { 
                    await self.checkForTurnChange()
                    await self.checkForMyNewPicks(picks)
                    await self.updateMyRosterFromPicks(picks)
                    await self.refreshSuggestions() 
                }
            }
            .store(in: &cancellables)
        
        polling.$pollingCountdown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.pollingCountdown = value
            }
            .store(in: &cancellables)
        
        polling.$currentPollingInterval
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interval in
                self?.maxPollingInterval = interval
            }
            .store(in: &cancellables)
    }
}
