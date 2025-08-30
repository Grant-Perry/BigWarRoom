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
    
    /// Computed property for max teams in current draft
    var maxTeamsInDraft: Int {
        // Priority 1: Use pending ESPN league data if we're in the picker
        if let pendingWrapper = pendingESPNLeagueWrapper {
            let totalRosters = pendingWrapper.league.totalRosters
            print(" maxTeamsInDraft - Using pending ESPN league: \(totalRosters)")
            return totalRosters
        }
        
        // Priority 2: Use current draft/league data
        let fallback = manualDraftInfo?.settings?.teams ??
                      selectedDraft?.settings?.teams ??
                      selectedDraft?.totalRosters ??
                      12 // Reduced default from 16 to 12 (more common)
        
        print(" maxTeamsInDraft - Using fallback: \(fallback)")
        return fallback
    }

    // MARK: - Public Team Name Helper with Debugging
    
    /// Get the display name for a team by draft slot
    func teamDisplayName(for draftSlot: Int) -> String {
        print("🔍 DEBUG teamDisplayName for draftSlot \(draftSlot):")
        print("   draftRosters count: \(draftRosters.count)")
        
        // Strategy 1: Find the rosterID that corresponds to this draft slot
        // Look through picks to find which roster ID is associated with this draft slot
        let picksForSlot = allDraftPicks.filter { $0.draftSlot == draftSlot }
        print("   Picks for slot \(draftSlot): \(picksForSlot.count)")
        
        // Get the roster ID from any pick in this draft slot
        var rosterIDForSlot: Int? = nil
        if let firstPick = picksForSlot.first {
            rosterIDForSlot = firstPick.rosterInfo?.rosterID
            print("   Found rosterID \(rosterIDForSlot ?? -1) for draftSlot \(draftSlot)")
        }
        
        // Strategy 2: If we found a roster ID, lookup its display name
        if let rosterID = rosterIDForSlot,
           let rosterInfo = draftRosters[rosterID] {
            print("   Found roster info for rosterID \(rosterID): '\(rosterInfo.displayName)'")
            
            // Check if this is a real name (not generic "Team X")
            if !rosterInfo.displayName.isEmpty,
               !rosterInfo.displayName.lowercased().hasPrefix("team "),
               rosterInfo.displayName != "Team \(draftSlot)",
               rosterInfo.displayName != "Team \(rosterID)",
               rosterInfo.displayName.count > 4 {
                print("   ✅ Using real name: '\(rosterInfo.displayName)'")
                return rosterInfo.displayName
            } else {
                print("   ❌ Name '\(rosterInfo.displayName)' appears to be generic")
            }
        }
        
        // Strategy 3: Direct roster lookup by draft slot (if rosters have draftSlot info)
        if let directRoster = draftRosters.values.first(where: { _ in
            // We don't have direct access to draftSlot in DraftRosterInfo
            // This would require adding draftSlot to DraftRosterInfo or another approach
            return false
        }) {
            return directRoster.displayName
        }
        
        print("   ❌ No real name found, using fallback")
        return "Team \(draftSlot)"
    }
    
    // MARK: - ESPN Draft Pick Selection
    
    @Published var showingESPNPickPrompt = false
    @Published var pendingESPNLeagueWrapper: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedESPNDraftPosition: Int = 1 // Separate variable for ESPN pick selection

    // MARK: - Services
    
    private let sleeperClient = SleeperAPIClient.shared
    private let espnClient = ESPNAPIClient.shared
    private let leagueManager = UnifiedLeagueManager()
    private let playerDirectory = PlayerDirectoryStore.shared
    private let polling = DraftPollingService.shared
    private let suggestionEngine = SuggestionEngine()
    
    // MARK: - Current API Client
    
    /// Get the appropriate API client for the selected league
    private var currentAPIClient: DraftAPIClient {
        return selectedLeagueWrapper?.client ?? sleeperClient
    }
    
    // MARK: - Draft Context & User Tracking
    
    private var draftRosters: [Int: DraftRosterInfo] = [:]
    private var currentUserID: String?
    private var _myRosterID: Int?  // Private storage
    private var myDraftSlot: Int?
    private var allLeagueRosters: [SleeperRoster] = []
    private var lastPickCount = 0
    private var lastMyPickCount = 0
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    private var suggestionsTask: Task<Void, Never>?
    
    // MARK: - User cache for ownerID -> SleeperUser lookups
    private var userCache: [String: SleeperUser] = [:]
    
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
    
    // MARK: - Live Mode
    
    var isLiveMode: Bool {
        connectionStatus == .connected
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
                    print(" Mock Draft Tracking - Slot \(self.myDraftSlot!): \(mySlotPicks.count) picks")
                    for pick in mySlotPicks {
                        if let playerID = pick.playerID,
                           let player = self.playerDirectory.player(for: playerID) {
                            print("   • Pick \(pick.pickNo): \(player.shortName)")
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
    
    // MARK: - Connect / Disconnect

    /// Connect using either username or User ID (Sleeper only)
    func connectWithUsernameOrID(_ input: String) async {
        connectionStatus = .connecting
        
        do {
            let user: SleeperUser
            
            // Try to determine if input is a username or User ID
            if input.allSatisfy(\.isNumber) && input.count > 10 {
                // Looks like a User ID (all numbers, long)
                user = try await sleeperClient.fetchUserByID(userID: input)
                currentUserID = input
                print(" Connected using User ID: \(input)")
            } else {
                // Looks like a username
                user = try await sleeperClient.fetchUser(username: input)
                currentUserID = user.userID
                print(" Connected using username: \(input) -> User ID: \(user.userID)")
            }
            
            sleeperDisplayName = user.displayName ?? user.username
            sleeperUsername = user.username
            
            // Fetch leagues from both Sleeper and ESPN
            await leagueManager.fetchAllLeagues(sleeperUserID: user.userID)
            allAvailableDrafts = leagueManager.allLeagues
            
            connectionStatus = .connected
        } catch {
            print(" Connection failed for input '\(input)': \(error)")
            connectionStatus = .disconnected
        }
    }

    /// Connect to ESPN leagues only (without Sleeper account)
    func connectToESPNOnly() async {
        connectionStatus = .connecting
        
        // Fetch ESPN leagues only
        await leagueManager.fetchESPNLeagues()
        allAvailableDrafts = leagueManager.allLeagues

        sleeperDisplayName = "ESPN User"
        sleeperUsername = "espn_user"
        // Set currentUserID to SWID for ESPN roster matching
        currentUserID = AppConstants.SWID
        connectionStatus = .connected

        print(" Connected to ESPN leagues")
        print(" Set currentUserID to SWID: \(AppConstants.SWID)")
    }

    func connectWithUserID(_ userID: String) async {
        await connectWithUsernameOrID(userID)
    }

    func disconnectFromLive() {
        polling.stopPolling()
        selectedDraft = nil
        selectedLeagueWrapper = nil
        allDraftPicks = []
        recentLivePicks = []
        connectionStatus = .disconnected
        currentUserID = nil
        _myRosterID = nil
        myDraftSlot = nil
        allLeagueRosters = []
        
        // Reset manual draft state
        isConnectedToManualDraft = false
        manualDraftNeedsPosition = false
        manualDraftInfo = nil
        
        // Clear league manager
        leagueManager.allLeagues.removeAll()
        allAvailableDrafts.removeAll()
        
        // Don't clear roster here - let user keep their manual roster if they want
    }
    
    // MARK: - Selectinging a Draft

    func selectDraft(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        // ESPN leagues: Ask for position FIRST, then complete setup
        if leagueWrapper.source == .espn {
            print("🏈 ESPN league selected - prompting for draft position first")
            print("   League: \(leagueWrapper.league.name)")
            print("   Total Rosters: \(leagueWrapper.league.totalRosters)")
            
            // Store the league wrapper and show position prompt
            pendingESPNLeagueWrapper = leagueWrapper
            
            // Debug the maxTeamsInDraft calculation
            print("   maxTeamsInDraft will be: \(maxTeamsInDraft)")
            
            // Initialize ESPN draft position to 1 (don't rely on selectedManualPosition)
            selectedESPNDraftPosition = 1
            
            showingESPNPickPrompt = true
            
            // Don't proceed with setup yet - wait for position selection
            return
        }
        
        // For Sleeper leagues, proceed normally
        await completeLeagueSelection(leagueWrapper)
    }
    
    /// Complete the league selection after position is determined (or for Sleeper leagues)
    private func completeLeagueSelection(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        selectedLeagueWrapper = leagueWrapper
        selectedDraft = leagueWrapper.league
        let apiClient = leagueWrapper.client
        
        // Fetch roster metadata and find MY roster
        if let leagueID = selectedDraft?.leagueID {
            do {
                let rosters = try await apiClient.fetchRosters(leagueID: leagueID)
                allLeagueRosters = rosters
                
                print(" Found \(rosters.count) rosters in league \(leagueID)")
                for (index, roster) in rosters.enumerated() {
                    print("  Roster \(index + 1): ID=\(roster.rosterID), Owner=\(roster.ownerID ?? "nil"), Display=\(roster.ownerDisplayName ?? "nil")")
                }
                
                // ESPN leagues: Use the pre-selected draft pick to find roster
                if leagueWrapper.source == .espn {
                    print(" ESPN league - using pre-selected draft pick: \(myDraftSlot ?? -1)")
                    
                    // FIXED: Pure positional logic - ignore ESPN teamIds completely
                    if let draftPosition = myDraftSlot {
                        // Don't try to match roster IDs - just use pure draft slot logic
                        _myRosterID = nil // Set to nil - we'll use draft slot matching instead
                        print(" ESPN: Using pure positional logic for draft slot \(draftPosition)")
                        print(" Your picks will be calculated using snake draft math from position \(draftPosition)")
                    } else {
                        print(" Could not determine draft position for ESPN league")
                    }
                    
                } else {
                    // Sleeper leagues: Use Sleeper user ID matching
                    if let userID = currentUserID {
                        print(" Sleeper league - looking for my roster with userID: \(userID)")
                        if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                            _myRosterID = myRoster.rosterID
                            myDraftSlot = myRoster.draftSlot
                            print(" Found MY Sleeper roster! RosterID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)")
                        } else {
                            print(" Could not find my roster with Sleeper userID: \(userID)")
                        }
                    }
                }
                
                if _myRosterID == nil {
                    print(" Could not identify my roster in this league")
                } else {
                    print(" Successfully identified my roster: ID=\(_myRosterID!), DraftSlot=\(myDraftSlot ?? -1)")
                }

                // Build roster info for display with proper user name lookup
                var info: [Int: DraftRosterInfo] = [:]

                print("🔍 DEBUG: Building draftRosters dictionary...")
                print("   Found \(rosters.count) rosters in league")
                print("   League source: \(leagueWrapper.source)")
                
                for roster in rosters {
                    print("   Processing roster \(roster.rosterID):")
                    print("     ownerID: \(roster.ownerID ?? "nil")")
                    print("     draftSlot: \(roster.draftSlot ?? -1)")
                    print("     ownerDisplayName: \(roster.ownerDisplayName ?? "nil")")
                    print("     teamName: \(roster.metadata?.teamName ?? "nil")")
                    print("     ownerName: \(roster.metadata?.ownerName ?? "nil")")
                    
                    var displayName: String? = nil

                    // For ESPN leagues accessed through Sleeper, ALWAYS try Sleeper user lookup FIRST
                    // Skip the generic ESPN team names and go straight to Sleeper user data
                    if let ownerID = roster.ownerID, !ownerID.isEmpty {
                        print("     Trying Sleeper user lookup for ownerID: \(ownerID)")
                        
                        // Try cache first
                        if let cached = userCache[ownerID] {
                            displayName = cached.displayName ?? cached.username
                            print("     ✅ Using cached user: \(displayName ?? "nil")")
                        } else {
                            // Fetch and store in cache
                            do {
                                let fetched = try await sleeperClient.fetchUserByID(userID: ownerID)
                                userCache[ownerID] = fetched
                                displayName = fetched.displayName ?? fetched.username
                                print("     ✅ Fetched user: \(displayName ?? "nil") (username: \(fetched.username))")
                            } catch {
                                print("     ❌ Could not fetch user for ownerID \(ownerID): \(error)")
                                displayName = nil
                            }
                        }
                    }
                    
                    // Only fall back to roster metadata if Sleeper lookup failed
                    if displayName == nil || displayName!.isEmpty {
                        if let name = roster.metadata?.teamName, !name.isEmpty, !name.hasPrefix("Team ") {
                            displayName = name
                            print("     Using non-generic teamName: \(name)")
                        } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
                            displayName = ownerName
                            print("     Using ownerName: \(ownerName)")
                        } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty, !ownerDisplayName.hasPrefix("Team ") {
                            displayName = ownerDisplayName
                            print("     Using non-generic ownerDisplayName: \(ownerDisplayName)")
                        }
                    }

                    if displayName == nil || displayName!.isEmpty {
                        displayName = "Team \(roster.rosterID)"
                        print("     Using fallback: \(displayName!)")
                    }

                    info[roster.rosterID] = DraftRosterInfo(
                        rosterID: roster.rosterID,
                        ownerID: roster.ownerID,
                        displayName: displayName!
                    )
                    
                    print("     Final result: rosterID \(roster.rosterID) → '\(displayName!)' (draftSlot: \(roster.draftSlot ?? -1))")
                }
                
                print("🔍 Final draftRosters mapping:")
                for (rosterID, rosterInfo) in info.sorted(by: { $0.key < $1.key }) {
                    print("   RosterID \(rosterID): '\(rosterInfo.displayName)' (owner: \(rosterInfo.ownerID ?? "nil"))")
                }
                
                draftRosters = info
                
                // Only load actual roster if we have a roster ID
                if _myRosterID != nil {
                    await loadMyActualRoster()
                }
                
                // Initialize pick tracking
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                
            } catch {
                print(" Failed to fetch rosters for \(leagueWrapper.source.displayName) league: \(error)")
                draftRosters = [:]
                _myRosterID = nil
                myDraftSlot = nil
            }
        }
        
        // Start polling the actual draft
        if let draftID = leagueWrapper.league.draftID {
            print(" Starting draft polling for \(leagueWrapper.source.displayName) league with draftID: \(draftID)")
            polling.startPolling(draftID: draftID, apiClient: apiClient)
        } else {
            print(" No draftID found for league: \(leagueWrapper.league.name)")
            // For ESPN leagues, try using the league ID as draft ID
            if leagueWrapper.source == .espn {
                print(" ESPN league - trying to use leagueID as draftID: \(leagueWrapper.league.leagueID)")
                polling.startPolling(draftID: leagueWrapper.league.leagueID, apiClient: apiClient)
            }
        }
        
        await refreshSuggestions()
    }
    
    /// Handle ESPN draft pick selection
    func setESPNDraftPosition(_ position: Int) async {
        guard let pendingWrapper = pendingESPNLeagueWrapper else {
            print(" No pending ESPN league to configure")
            return
        }
        
        print(" ESPN draft pick selected: \(position)")
        
        // Set the position first
        myDraftSlot = position
        
        // Clear pending state
        pendingESPNLeagueWrapper = nil
        showingESPNPickPrompt = false
        
        // Now complete the league selection with position set
        await completeLeagueSelection(pendingWrapper)
    }
    
    /// Cancel ESPN pick selection
    func cancelESPNPositionSelection() {
        pendingESPNLeagueWrapper = nil
        showingESPNPickPrompt = false
        print(" ESPN league selection cancelled")
    }
    
    // Legacy method for backward compatibility
    func selectDraft(_ league: SleeperLeague) async {
        // Find the corresponding league wrapper
        if let wrapper = allAvailableDrafts.first(where: { $0.league.id == league.id }) {
            await selectDraft(wrapper)
        } else {
            // Fallback to legacy behavior
            selectedDraft = league
            selectedLeagueWrapper = nil
            
            if let leagueID = selectedDraft?.leagueID {
                do {
                    let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
                    allLeagueRosters = rosters
                    
                    if let userID = currentUserID {
                        if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                            _myRosterID = myRoster.rosterID
                            myDraftSlot = myRoster.draftSlot
                        }
                    }
                    
                    var info: [Int: DraftRosterInfo] = [:]
                    for roster in rosters {
                        let displayName = roster.ownerDisplayName ?? "Team \(roster.rosterID)"
                        info[roster.rosterID] = DraftRosterInfo(
                            rosterID: roster.rosterID,
                            ownerID: roster.ownerID,
                            displayName: displayName
                        )
                    }
                    draftRosters = info
                    
                    await loadMyActualRoster()
                    
                    lastPickCount = polling.allPicks.count
                    lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                    
                } catch {
                    draftRosters = [:]
                    _myRosterID = nil
                    myDraftSlot = nil
                }
            }
            
            if let draftID = league.draftID {
                polling.startPolling(draftID: draftID)
            }
            
            await refreshSuggestions()
        }
    }
    
    /// Load the user's actual roster from the selected league
    private func loadMyActualRoster() async {
        guard let myRosterID = _myRosterID,
              let myRoster = allLeagueRosters.first(where: { $0.rosterID == myRosterID }),
              let playerIDs = myRoster.playerIDs else {
            return
        }
        
        // Convert Sleeper player IDs to our internal Player objects
        var newRoster = Roster()
        
        for playerID in playerIDs {
            if let sleeperPlayer = playerDirectory.player(for: playerID),
               let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
                newRoster.add(internalPlayer)
            }
        }
        
        // Update the roster
        roster = newRoster
    }
    
    // MARK: - Manual Draft ID
    
    func connectToManualDraft(draftID: String) async {
        // Start polling immediately to show picks
        polling.startPolling(draftID: draftID)
        connectionStatus = .connected
        isConnectedToManualDraft = true
        
        // DON'T auto-close the manual draft entry yet - user still needs to select position
        // showManualDraftEntry = false
        
        // Try to fetch draft info for basic display
        do {
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            manualDraftInfo = draft
            
            // Create a minimal league object for UI consistency
            let draftLeague = SleeperLeague(
                leagueID: draft.leagueID ?? "manual_\(draftID)",
                name: draft.metadata?.name ?? "Manual Draft",
                status: .drafting,
                sport: "nfl",
                season: "2024",
                seasonType: "regular", 
                totalRosters: draft.settings?.teams ?? 12,
                draftID: draftID,
                avatar: nil,
                settings: SleeperLeagueSettings(
                    teams: draft.settings?.teams,
                    playoffTeams: nil,
                    playoffWeekStart: nil,
                    leagueAverageMatch: nil,
                    maxKeepers: nil,
                    tradeDeadline: nil,
                    reserveSlots: nil,
                    taxiSlots: nil
                ),
                scoringSettings: nil,
                rosterPositions: nil
            )
            selectedDraft = draftLeague
            
        } catch {
            print(" Could not fetch draft info: \(error)")
            // Create fallback league for display
            selectedDraft = SleeperLeague(
                leagueID: "manual_\(draftID)",
                name: "Manual Draft",
                status: .drafting,
                sport: "nfl",
                season: "2024", 
                seasonType: "regular",
                totalRosters: 12,
                draftID: draftID,
                avatar: nil,
                settings: nil,
                scoringSettings: nil,
                rosterPositions: nil
            )
        }
        
        // If we have a connected user, try to enhance with roster correlation
        if let userID = currentUserID {
            let foundRoster = await enhanceManualDraftWithRosterCorrelation(draftID: draftID,userID: userID)
            
            // If we couldn't auto-detect, ask for manual position
            if !foundRoster {
                manualDraftNeedsPosition = true
                // Ensure selectedManualPosition is valid for this draft
                let teamCount = manualDraftInfo?.settings?.teams ?? selectedDraft?.totalRosters ?? 16
                if selectedManualPosition > teamCount {
                    selectedManualPosition = 1 // Reset to valid position
                }
            } else {
                // Only close if we successfully auto-detected the roster
                showManualDraftEntry = false
            }
        } else {
            // Not connected to Sleeper - ask for manual position
            manualDraftNeedsPosition = true
            // Ensure selectedManualPosition is valid for this draft
            let teamCount = manualDraftInfo?.settings?.teams ?? selectedDraft?.totalRosters ?? 16
            if selectedManualPosition > teamCount {
                selectedManualPosition = 1 // Reset to valid position
            }
        }
        
        await refreshSuggestions()
    }

    /// Enhanced manual draft connection with full roster correlation
    /// Returns true if roster was found, false if manual position needed
    private func enhanceManualDraftWithRosterCorrelation(draftID: String, userID: String) async -> Bool {
        do {
            // Step 1: Fetch draft info to get league ID
            print(" Fetching draft info for manual draft: \(draftID)")
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            
            guard let leagueID = draft.leagueID else {
                print(" Draft \(draftID) has no league ID - likely a mock draft")
                return false
            }
            
            print(" Found league ID: \(leagueID)")
            
            // Step 2: Fetch league info to create a SleeperLeague object
            let league = try await sleeperClient.fetchLeague(leagueID: leagueID)
            print(" Fetched league: \(league.name)")
            
            // Step 3: Fetch league rosters
            let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
            allLeagueRosters = rosters
            
            // Step 4: Find MY roster by matching owner ID with current user ID
            if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                _myRosterID = myRoster.rosterID
                myDraftSlot = myRoster.draftSlot
                
                print(" Found your roster! ID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)")
                
                // Step 5: Set up draft roster info for display
                var info: [Int: DraftRosterInfo] = [:]
                
                print("🔍 DEBUG: Building draftRosters dictionary...")
                print("   Found \(rosters.count) rosters in league")
                
                for roster in rosters {
                    print("   Processing roster \(roster.rosterID):")
                    print("     ownerID: \(roster.ownerID ?? "nil")")
                    print("     draftSlot: \(roster.draftSlot ?? -1)")
                    print("     ownerDisplayName: \(roster.ownerDisplayName ?? "nil")")
                    print("     teamName: \(roster.metadata?.teamName ?? "nil")")
                    print("     ownerName: \(roster.metadata?.ownerName ?? "nil")")
                    
                    var displayName: String? = nil

                    // Team name from roster metadata (usually blank unless user set it)
                    if let name = roster.metadata?.teamName, !name.isEmpty {
                        displayName = name
                        print("     Using teamName: \(name)")
                    } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
                        displayName = ownerName
                        print("     Using ownerName: \(ownerName)")
                    } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty {
                        displayName = ownerDisplayName
                        print("     Using ownerDisplayName: \(ownerDisplayName)")
                    } else if let ownerID = roster.ownerID, !ownerID.isEmpty {
                        // ALWAYS try Sleeper user lookup for both Sleeper AND ESPN leagues
                        // ESPN leagues still have Sleeper owner IDs if they're connected via Sleeper
                        
                        print("     Trying Sleeper user lookup for ownerID: \(ownerID)")
                        
                        // Try cache first
                        if let cached = userCache[ownerID] {
                            displayName = cached.displayName ?? cached.username
                            print("     ✅ Using cached user: \(displayName ?? "nil")")
                        } else {
                            // Fetch and store in cache
                            do {
                                let fetched = try await sleeperClient.fetchUserByID(userID: ownerID)
                                userCache[ownerID] = fetched
                                displayName = fetched.displayName ?? fetched.username
                                print("     ✅ Fetched user: \(displayName ?? "nil") (username: \(fetched.username))")
                            } catch {
                                print("     ❌ Could not fetch user for ownerID \(ownerID): \(error)")
                                displayName = nil
                            }
                        }
                    }

                    if displayName == nil || displayName!.isEmpty {
                        displayName = "Team \(roster.rosterID)"
                        print("     Using fallback: \(displayName!)")
                    }

                    info[roster.rosterID] = DraftRosterInfo(
                        rosterID: roster.rosterID,
                        ownerID: roster.ownerID,
                        displayName: displayName!
                    )
                    
                    print("     Final result: rosterID \(roster.rosterID) → '\(displayName!)' (draftSlot: \(roster.draftSlot ?? -1))")
                }
                
                print("🔍 Final draftRosters mapping:")
                for (rosterID, rosterInfo) in info.sorted(by: { $0.key < $1.key }) {
                    print("   RosterID \(rosterID): '\(rosterInfo.displayName)' (owner: \(rosterInfo.ownerID ?? "nil"))")
                }
                
                draftRosters = info
                
                // Step 6: Update selectedDraft with real league info
                selectedDraft = league
                
                // Step 7: Load your actual roster from the league
                await loadMyActualRoster()
                
                // Step 8: Initialize pick tracking for alerts
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                
                print(" Manual draft enhanced! Pick alerts and roster correlation enabled.")
                return true
                
            } else {
                print(" Could not find your roster in league \(leagueID)")
                print(" Available rosters: \(rosters.map { "\($0.rosterID): \($0.ownerID ?? "no owner")" })")
                return false
            }
            
        } catch {
            print(" Failed to enhance manual draft: \(error)")
            print(" Manual draft will work but without roster correlation")
            return false
        }
    }

    /// Set manual draft position when auto-detection fails or for ESPN leagues
    func setManualDraftPosition(_ position: Int) {
        myDraftSlot = position
        manualDraftNeedsPosition = false
        
        // For ESPN leagues, we need to find the roster ID that corresponds to this draft pick
        if let leagueWrapper = selectedLeagueWrapper, leagueWrapper.source == .espn {
            // Find the roster with this roster ID (ESPN roster ID = draft pick number)
            if let matchingRoster = allLeagueRosters.first(where: { $0.rosterID == position }) {
                _myRosterID = matchingRoster.rosterID
                print(" ESPN: Set roster ID \(matchingRoster.rosterID) for draft pick \(position)")
                
                // Load the actual roster now that we know which one is mine
                Task {
                    await loadMyActualRoster()
                }
            } else {
                print(" ESPN: Could not find roster with ID \(position)")
            }
        }
        
        // Now that position is set, we can close any manual draft entry UI
        showManualDraftEntry = false
        
        // Initialize pick tracking with manual position - count existing picks for this slot
        lastPickCount = polling.allPicks.count
        
        // Count picks already made for this draft slot
        let existingMyPicks = polling.allPicks.filter { $0.draftSlot == position }
        lastMyPickCount = existingMyPicks.count
        
        print(" Draft pick set to: \(position)")
        print(" Found \(existingMyPicks.count) existing picks for slot \(position)")
        
        // Update roster immediately with any existing picks for this position
        Task {
            await updateMyRosterFromPicks(polling.allPicks)
            await checkForTurnChange()
        }
    }

    func dismissManualPositionPrompt() {
        manualDraftNeedsPosition = false
        
        // Close the manual draft entry when they skip position selection
        showManualDraftEntry = false
    }
    
    func forceRefresh() async {
        await polling.forceRefresh()
        await refreshSuggestions()
    }
    
    /// Refresh all available leagues
    func refreshAllLeagues() async {
        await leagueManager.refreshAllLeagues(sleeperUserID: currentUserID)
        allAvailableDrafts = leagueManager.allLeagues
    }
    
    // MARK: - Suggestions
    
    func updatePositionFilter(_ filter: PositionFilter) {
        selectedPositionFilter = filter
        Task { await refreshSuggestions() }
    }
    
    func updateSortMethod(_ method: SortMethod) {
        selectedSortMethod = method
        Task { await refreshSuggestions() }
    }
    
    private func buildAvailablePlayers() -> [Player] {
        let draftedIDs = Set(polling.allPicks.compactMap { $0.playerID })
        let myRosterIDs = Set(myRosterPlayerIDs()) // Filter out your own roster too!
        
        // Base pool: active players with valid position/team
        let base = playerDirectory.players.values.compactMap { sp -> Player? in
            guard let _ = sp.position,
                  let _ = sp.team else { return nil }
            return playerDirectory.convertToInternalPlayer(sp)
        }
        .filter { !draftedIDs.contains($0.id) && !myRosterIDs.contains($0.id) } // Exclude both drafted AND rostered players
        
        switch selectedPositionFilter {
        case .all:
            return base
        case .qb:
            return base.filter { $0.position == .qb }
        case .rb:
            return base.filter { $0.position == .rb }
        case .wr:
            return base.filter { $0.position == .wr }
        case .te:
            return base.filter { $0.position == .te }
        case .k:
            return base.filter { $0.position == .k }
        case .dst:
            return base.filter { $0.position == .dst }
        }
    }
    
    private func currentSleeperLeagueAndDraft() -> (SleeperLeague, SleeperDraft)? {
        guard let league = selectedDraft,
              let draftID = league.draftID else {
            return nil
        }
        // Best effort: pull from polling service if it has a draft struct
        if let draft = polling.currentDraft {
            return (league, draft)
        }
        // Construct a minimal draft placeholder when poller hasn't loaded it yet
        let placeholder = SleeperDraft(
            draftID: draftID,
            leagueID: league.leagueID,
            status: .drafting,
            type: .snake,
            sport: "nfl",
            season: league.season,
            seasonType: league.seasonType,
            startTime: nil,
            lastPicked: nil,
            settings: league.settings.map { settings in SleeperDraftSettings(
                teams: settings.teams,
                rounds: nil,
                pickTimer: nil,
                slotsQB: nil, slotsRB: nil, slotsWR: nil, slotsTE: nil,
                slotsFlex: nil, slotsK: nil, slotsDEF: nil, slotsBN: nil
            )} ?? nil,
            metadata: nil,
            draftOrder: nil,
            slotToRosterID: nil
        )
        return (league, placeholder)
    }
    
    private func availablePlayersMap(_ available: [Player]) -> [String: SleeperPlayer] {
        let ids = Set(available.map { $0.id })
        return playerDirectory.players.filter { ids.contains($0.key) }
    }
    
    private func currentRosterAsSleeper() -> SleeperRoster {
        return SleeperRoster(
            rosterID: 1,
            ownerID: nil,
            leagueID: selectedDraft?.leagueID ?? "temp_league", // Use generic placeholder instead
            playerIDs: myRosterPlayerIDs(),
            draftSlot: nil,
            wins: nil, losses: nil, ties: nil,
            totalMoves: nil, totalMovesMade: nil,
            waiversBudgetUsed: nil,
            settings: nil,
            metadata: nil
        )
    }
    
    private func myRosterPlayerIDs() -> [String] {
        var ids: [String] = []
        if let qb = roster.qb { ids.append(qb.id) }
        if let rb1 = roster.rb1 { ids.append(rb1.id) }
        if let rb2 = roster.rb2 { ids.append(rb2.id) }
        if let wr1 = roster.wr1 { ids.append(wr1.id) }
        if let wr2 = roster.wr2 { ids.append(wr2.id) }
        if let wr3 = roster.wr3 { ids.append(wr3.id) }
        if let te = roster.te { ids.append(te.id) }
        if let flex = roster.flex { ids.append(flex.id) }
        if let k = roster.k { ids.append(k.id) }
        if let dst = roster.dst { ids.append(dst.id) }
        ids.append(contentsOf: roster.bench.map { $0.id })
        return ids
    }
    
    /// Refreshes suggestions using AI first, then falls back to heuristic engine.
    func refreshSuggestions() async {
        suggestionsTask?.cancel()
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            let available = self.buildAvailablePlayers()
            
            // For "All" method, skip AI entirely and show all players sorted by rank
            if self.selectedSortMethod == .all {
                // Only include players with valid fantasy rankings for the "All" list
                let playersWithRanks = available.filter { player in
                    guard let sleeperPlayer = PlayerDirectoryStore.shared.player(for: player.id),
                          let rank = sleeperPlayer.searchRank else { return false }
                    return rank > 0 && rank < 10000  // Valid fantasy rankings
                }
                
                let allPlayerSuggestions = playersWithRanks.map { player in
                    Suggestion(player: player, reasoning: nil)
                }
                let sorted = self.sortedByPureRank(allPlayerSuggestions)
                
                await MainActor.run { 
                    print(" All method: Showing \(sorted.count) total ranked players (filtered from \(available.count) available)")
                    self.suggestions = sorted 
                }
                return
            }
            
            // If AI is disabled, skip all AI context, return heuristic only
            if AppConstants.useAISuggestions == false {
                let fallback = await self.heuristicSuggestions(available: available, limit: 50)
                await MainActor.run { self.suggestions = fallback }
                return
            }
            
            // No AI context? Fall back immediately
            guard let (league, draft) = self.currentSleeperLeagueAndDraft() else {
                let fallback = await self.heuristicSuggestions(available: available, limit: 50)
                await MainActor.run { self.suggestions = fallback }
                return
            }
            
            // Try AI-backed suggestions
            do {
                let top = try await self.suggestionEngine.topSuggestions(
                    from: available,
                    roster: self.roster,
                    league: league,
                    draft: draft,
                    picks: self.polling.allPicks,
                    draftRosters: self.draftRosters,
                    limit: 50
                )
                
                // Apply secondary sort if "Rankings" method chosen
                let final = self.selectedSortMethod == .rankings
                    ? self.sortedByPureRank(top)
                    : top
                
                await MainActor.run {
                    self.suggestions = final
                }
            } catch {
                let fallback = await self.heuristicSuggestions(available: available, limit: 50)
                await MainActor.run { self.suggestions = fallback }
            }
        }
    }
    
    private func heuristicSuggestions(available: [Player], limit: Int) async -> [Suggestion] {
        // If no draft is selected, just return basic ranked suggestions
        guard let selectedDraft = selectedDraft else {
            // No draft context - just rank by Sleeper rankings
            let rankedSuggestions = available.compactMap { player -> Suggestion? in
                guard let sleeperPlayer = PlayerDirectoryStore.shared.player(for: player.id),
                      let rank = sleeperPlayer.searchRank,
                      rank > 0 && rank < 10000 else { return nil }
                return Suggestion(player: player, reasoning: nil)
            }
            .sorted { lhs, rhs in
                let lRank = PlayerDirectoryStore.shared.player(for: lhs.player.id)?.searchRank ?? Int.max
                let rRank = PlayerDirectoryStore.shared.player(for: rhs.player.id)?.searchRank ?? Int.max
                return lRank < rRank
            }
            
            return Array(rankedSuggestions.prefix(limit))
        }
        
        // Use SuggestionEngine fallback without AI but with real draft context
        let picks = polling.allPicks
        let currentDraft = polling.currentDraft
        
        // Only use real draft/league data if available
        guard let currentDraft = currentDraft else {
            // No draft data available, fall back to basic ranking
            return Array(available.prefix(limit).map { Suggestion(player: $0, reasoning: nil) })
        }
        
        let top = await withCheckedContinuation { (continuation: CheckedContinuation<[Suggestion], Never>) in
            Task {
                let result = try? await suggestionEngine.topSuggestions(
                    from: available,
                    roster: roster,
                    league: selectedDraft,
                    draft: currentDraft,
                    picks: picks,
                    draftRosters: draftRosters,
                    limit: limit
                )
                continuation.resume(returning: result ?? [])
            }
        }
        
        // Apply sorting based on method
        if selectedSortMethod == .rankings {
            return sortedByPureRank(top)
        } else if selectedSortMethod == .all {
            return sortedByPureRank(top)
        } else {
            return Array(top.prefix(limit))
        }
    }
    
    private func sortedByPureRank(_ list: [Suggestion]) -> [Suggestion] {
        // Use Sleeper searchRank as "pure ranking" - lower numbers = better players
        let sortedList = list.sorted { lhs, rhs in
            let lRank = PlayerDirectoryStore.shared.player(for: lhs.player.id)?.searchRank ?? Int.max
            let rRank = PlayerDirectoryStore.shared.player(for: rhs.player.id)?.searchRank ?? Int.max
            
            // If ranks are the same, use secondary sorting by player name for consistency
            if lRank == rRank {
                return lhs.player.shortKey < rhs.player.shortKey
            }
            return lRank < rRank  // 1, 2, 3, 4... (ascending order)
        }
        
        // Debug: Print first 20 players with their Sleeper ranks and our sequential position
        if selectedSortMethod == .all {
            print(" Top 20 players - Sequential Position vs Sleeper Rank:")
            for (index, suggestion) in sortedList.prefix(20).enumerated() {
                let sleeperRank = PlayerDirectoryStore.shared.player(for: suggestion.player.id)?.searchRank ?? -1
                let sequentialRank = index + 1
                print("  \(sequentialRank). \(suggestion.player.shortKey) - Sleeper Rank #\(sleeperRank)")
            }
            
            // Show total count
            print(" All method: Showing \(sortedList.count) players in strict 1-2-3-4... order")
        }
        
        return sortedList
    }
    
    // MARK: - Picks Feed / My Pick
    
    func addFeedPick() {
        // This is a lightweight helper: parse the last entry and add to bench for context
        guard let last = picksFeed.split(separator: ",").last?.trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else { return }
        
        if let found = findInternalPlayer(matchingShortKey: String(last)) {
            roster.bench.append(found)
            Task { await refreshSuggestions() }
        }
    }
    
    func lockMyPick() {
        let input = myPickInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if let found = findInternalPlayer(matchingShortKey: input) {
            var r = roster
            r.add(found)
            roster = r
            myPickInput = ""
            Task { await refreshSuggestions() }
        }
    }
    
    private func findInternalPlayer(matchingShortKey key: String) -> Player? {
        // Expected format: "J Chase"
        let comps = key.split(separator: " ")
        guard comps.count >= 2 else { return nil }
        let firstInitial = String(comps[0]).uppercased()
        let lastName = comps.dropFirst().joined(separator: " ").lowercased()
        
        // Match among directory players converted to internal
        for (_, sp) in playerDirectory.players {
            guard let spFirst = sp.firstName, let spLast = sp.lastName,
                  let posStr = sp.position, let team = sp.team,
                  let pos = Position(rawValue: posStr.uppercased()) else { continue }
            let candidate = Player(
                id: sp.playerID,
                firstInitial: String(spFirst.prefix(1)).uppercased(),
                lastName: spLast,
                position: pos,
                team: team,
                tier: playerDirectory.convertToInternalPlayer(sp)?.tier ?? 4
            )
            if candidate.firstInitial == firstInitial &&
               candidate.lastName.lowercased().hasPrefix(lastName) {
                return candidate
            }
        }
        return nil
    }
    
    // MARK: - Enhanced Picks building
    
    private func buildEnhancedPicks(from picks: [SleeperPick]) -> [EnhancedPick] {
        let teams = polling.currentDraft?.settings?.teams ?? selectedDraft?.settings?.teams ?? 12
        return picks.compactMap { pick -> EnhancedPick? in
            
            // Strategy 1: Use embedded ESPN player data (for ESPN leagues) - CHECK THIS FIRST
            if let espnInfo = pick.espnPlayerInfo {
                let teamCode = espnInfo.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("🏈 Using ESPN data for pick \(pick.pickNo): \(espnInfo.fullName)")
                
                // Create a fake SleeperPlayer using JSON encoding/decoding trick
                let playerData: [String: Any] = [
                    "player_id": "espn_\(espnInfo.espnPlayerID)",
                    "first_name": espnInfo.firstName as Any,
                    "last_name": espnInfo.lastName as Any,
                    "position": espnInfo.position as Any,
                    "team": espnInfo.team as Any,
                    "number": espnInfo.jerseyNumber as Any,
                    "status": "Active",
                    "espn_id": String(espnInfo.espnPlayerID)
                ]
                
                // Try to create SleeperPlayer with fallbacks
                let fakeSleeperPlayer: SleeperPlayer?
                
                // First attempt: Full ESPN data
                if let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
                   let player = try? JSONDecoder().decode(SleeperPlayer.self, from: jsonData) {
                    fakeSleeperPlayer = player
                } else {
                    print("⚠️ Failed to create fake SleeperPlayer from ESPN data")
                    
                    // Second attempt: Minimal fallback data  
                    let fallbackPlayerData: [String: Any] = [
                        "player_id": "espn_\(espnInfo.espnPlayerID)",
                        "first_name": espnInfo.firstName ?? "Unknown",
                        "last_name": espnInfo.lastName ?? "Player"
                    ]
                    
                    if let fallbackJsonData = try? JSONSerialization.data(withJSONObject: fallbackPlayerData),
                       let fallbackPlayer = try? JSONDecoder().decode(SleeperPlayer.self, from: fallbackJsonData) {
                        fakeSleeperPlayer = fallbackPlayer
                    } else {
                        print("💥 Failed to create minimal SleeperPlayer, skipping pick")
                        fakeSleeperPlayer = nil
                    }
                }
                
                // If we couldn't create a SleeperPlayer at all, skip this pick
                guard let finalPlayer = fakeSleeperPlayer else {
                    return nil
                }
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: espnInfo.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: finalPlayer,
                    displayName: espnInfo.fullName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // Strategy 2: Try Sleeper player lookup (for Sleeper leagues)
            else if let playerID = pick.playerID,
               !playerID.hasPrefix("espn_"), // Skip ESPN-prefixed IDs
               let sp = playerDirectory.player(for: playerID) {
                let teamCode = sp.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("😴 Using Sleeper data for pick \(pick.pickNo): \(sp.shortName)")
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: sp.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: sp,
                    displayName: sp.shortName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // Strategy 3: Fallback - use metadata if available
            else if let metadata = pick.metadata {
                let displayName = [metadata.firstName, metadata.lastName].compactMap { $0 }.joined(separator: " ")
                let teamCode = metadata.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("📝 Using metadata for pick \(pick.pickNo): \(displayName)")
                
                // Create minimal SleeperPlayer from metadata using similar approach
                let playerData: [String: Any] = [
                    "player_id": pick.playerID ?? "unknown_\(pick.pickNo)",
                    "first_name": metadata.firstName as Any,
                    "last_name": metadata.lastName as Any,
                    "position": metadata.position as Any,
                    "team": metadata.team as Any,
                    "number": metadata.number as Any,
                    "status": metadata.status ?? "Active"
                ]
                
                // Try to create SleeperPlayer with fallbacks
                let fallbackPlayer: SleeperPlayer?
                
                // First attempt: Full metadata
                if let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
                   let player = try? JSONDecoder().decode(SleeperPlayer.self, from: jsonData) {
                    fallbackPlayer = player
                } else {
                    print("⚠️ Failed to create fallback SleeperPlayer from metadata")
                    
                    // Second attempt: Minimal data
                    let minimalPlayerData: [String: Any] = [
                        "player_id": pick.playerID ?? "unknown_\(pick.pickNo)",
                        "first_name": metadata.firstName ?? "Unknown",
                        "last_name": metadata.lastName ?? "Player"
                    ]
                    
                    if let minimalJsonData = try? JSONSerialization.data(withJSONObject: minimalPlayerData),
                       let minimalPlayer = try? JSONDecoder().decode(SleeperPlayer.self, from: minimalJsonData) {
                        fallbackPlayer = minimalPlayer
                    } else {
                        print("💥 Failed to create minimal SleeperPlayer from metadata, skipping pick")
                        fallbackPlayer = nil
                    }
                }
                
                // If we couldn't create a SleeperPlayer, skip this pick
                guard let finalPlayer = fallbackPlayer else {
                    return nil
                }
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: metadata.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: finalPlayer,
                    displayName: displayName.isEmpty ? "Unknown Player" : displayName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // If all else fails, return nil (skip this pick)
            else {
                print("❌ Could not build EnhancedPick for pick \(pick.pickNo) - no player data available")
                print("   PlayerID: \(pick.playerID ?? "nil")")
                print("   ESPN Info: \(pick.espnPlayerInfo != nil ? "present" : "nil")")
                print("   Metadata: \(pick.metadata != nil ? "present" : "nil")")
                return nil
            }
        }
        .sorted { $0.pickNumber < $1.pickNumber }
    }
    
    /// Update my roster based on draft picks
    private func updateMyRosterFromPicks(_ picks: [SleeperPick]) async {
        var newRoster = Roster()
        
        // Strategy 1: Use roster ID correlation (for real Sleeper leagues)
        if let myRosterID = _myRosterID {
            let myPicks = picks.filter { $0.rosterID == myRosterID }
            
            for pick in myPicks {
                // Try to convert pick to internal Player format
                if let internalPlayer = convertPickToInternalPlayer(pick) {
                    newRoster.add(internalPlayer)
                }
            }
        }
        // Strategy 2: Use PURE POSITIONAL logic (for ESPN leagues and mock drafts)
        else if let myDraftSlot = myDraftSlot {
            // Calculate which pick numbers belong to this draft position using snake draft
            let teamCount = selectedDraft?.totalRosters ?? 10
            var myPickNumbers: [Int] = []
            
            // Generate all pick numbers for this position across all rounds
            for round in 1...16 { // Assume max 16 rounds
                let pickNumber = calculateSnakeDraftPickNumber(
                    draftPosition: myDraftSlot,
                    round: round,
                    teamCount: teamCount
                )
                if pickNumber <= picks.count { // Only include picks that exist
                    myPickNumbers.append(pickNumber)
                }
            }
            
            print(" Positional Logic: Slot \(myDraftSlot) owns pick numbers: \(myPickNumbers.prefix(10))")
            
            // Find all picks with these pick numbers
            let myPicks = picks.filter { myPickNumbers.contains($0.pickNo) }
            
            for pick in myPicks {
                if let internalPlayer = convertPickToInternalPlayer(pick) {
                    newRoster.add(internalPlayer)
                }
            }
            
            print(" Updated roster using positional logic: \(myPicks.count) picks for slot \(myDraftSlot)")
        }
        
        // Update roster if it's different
        if !rostersAreEqual(newRoster, roster) {
            roster = newRoster
            print(" MyRoster updated with \(totalPlayersInRoster(newRoster)) players")
        }
    }
    
    /// Calculate the correct pick number for a snake draft (helper method)
    private func calculateSnakeDraftPickNumber(draftPosition: Int, round: Int, teamCount: Int) -> Int {
        if round % 2 == 1 {
            // Odd rounds: normal order (1, 2, 3, ..., teamCount)
            return (round - 1) * teamCount + draftPosition
        } else {
            // Even rounds: snake/reverse order (teamCount, ..., 3, 2, 1)
            return (round - 1) * teamCount + (teamCount - draftPosition + 1)
        }
    }
    
    /// Convert a SleeperPick (which might contain ESPN data) to internal Player format
    private func convertPickToInternalPlayer(_ pick: SleeperPick) -> Player? {
        // Strategy 1: Use Sleeper player directory (for Sleeper leagues)
        if let playerID = pick.playerID,
           !playerID.hasPrefix("espn_"),
           let sleeperPlayer = playerDirectory.player(for: playerID),
           let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
            return internalPlayer
        }
        
        // Strategy 2: Convert from ESPN data (for ESPN leagues)
        if let espnInfo = pick.espnPlayerInfo,
           let position = espnInfo.position,
           let team = espnInfo.team,
           let pos = Position(rawValue: position.uppercased()) {
            
            return Player(
                id: "espn_\(espnInfo.espnPlayerID)",
                firstInitial: String(espnInfo.firstName?.prefix(1) ?? ""),
                lastName: espnInfo.lastName ?? "Unknown",
                position: pos,
                team: team,
                tier: 4 // Default tier for ESPN players since we don't have rankings
            )
        }
        
        // Strategy 3: Convert from metadata (fallback)
        if let metadata = pick.metadata,
           let firstName = metadata.firstName,
           let lastName = metadata.lastName,
           let position = metadata.position,
           let team = metadata.team,
           let pos = Position(rawValue: position.uppercased()) {
            
            return Player(
                id: pick.playerID ?? "unknown_\(pick.pickNo)",
                firstInitial: String(firstName.prefix(1)),
                lastName: lastName,
                position: pos,
                team: team,
                tier: 4 // Default tier
            )
        }
        
        print(" Could not convert pick \(pick.pickNo) to internal Player format")
        return nil
    }
    
    /// Helper to count total players in roster
    private func totalPlayersInRoster(_ roster: Roster) -> Int {
        let starters = [roster.qb, roster.rb1, roster.rb2, roster.wr1, roster.wr2, roster.wr3,
                       roster.te, roster.flex, roster.k, roster.dst].compactMap { $0 }.count
        return starters + roster.bench.count
    }
    
    // MARK: - Turn Detection & Alerts
    
    /// Check for new picks I made and show confirmation
    private func checkForMyNewPicks(_ picks: [SleeperPick]) async {
        var myPicks: [SleeperPick] = []
        var newMyPickCount = 0
        
        // Strategy 1: Use roster ID (for real Sleeper leagues)
        if let myRosterID = _myRosterID {
            myPicks = picks.filter { $0.rosterID == myRosterID }
            newMyPickCount = myPicks.count
        }
        // Strategy 2: Use PURE POSITIONAL logic (for ESPN leagues and mock drafts)
        else if let myDraftSlot = myDraftSlot {
            let teamCount = selectedDraft?.totalRosters ?? 10
            var myPickNumbers: [Int] = []
            
            // Generate all pick numbers for this position
            for round in 1...16 {
                let pickNumber = calculateSnakeDraftPickNumber(
                    draftPosition: myDraftSlot,
                    round: round,
                    teamCount: teamCount
                )
                if pickNumber <= picks.count {
                    myPickNumbers.append(pickNumber)
                }
            }
            
            myPicks = picks.filter { myPickNumbers.contains($0.pickNo) }
            newMyPickCount = myPicks.count
        } else {
            return // No way to identify my picks
        }
        
        // Did I just make a pick?
        if newMyPickCount > lastMyPickCount {
            let newPicks = myPicks.suffix(newMyPickCount - lastMyPickCount)
            
            for pick in newPicks {
                if let playerID = pick.playerID,
                   let player = playerDirectory.player(for: playerID) {
                    confirmationAlertMessage = " PICK CONFIRMED!\n\n\(player.fullName)\n\(player.position ?? "") • \(player.team ?? "")\n\nRound \(pick.round), Pick \(pick.pickNo)"
                    showingConfirmationAlert = true
                    
                    print(" Confirmed your pick: \(player.shortName) at position \(pick.draftSlot)")
                }
            }
        }
        
        lastMyPickCount = newMyPickCount
    }
    
    /// Check if it's the user's turn to pick
    private func checkForTurnChange() async {
        guard let draft = polling.currentDraft,
              let myDraftSlot = myDraftSlot,
              let teams = draft.settings?.teams else {
            isMyTurn = false
            return
        }
        
        let currentPickNumber = polling.allPicks.count + 1
        let wasMyTurn = isMyTurn
        let newIsMyTurn = isMyTurnToPick(pickNumber: currentPickNumber, mySlot: myDraftSlot, totalTeams: teams)
        
        isMyTurn = newIsMyTurn
        
        // Show alert if it just became my turn
        if newIsMyTurn && !wasMyTurn {
            let round = ((currentPickNumber - 1) / teams) + 1
            let pickInRound = ((currentPickNumber - 1) % teams) + 1
            
            pickAlertMessage = " IT'S YOUR PICK! \n\nRound \(round), Pick \(pickInRound)\n(\(currentPickNumber) overall)\n\nTime to make your selection!"
            showingPickAlert = true
            
            // Haptic feedback
            await triggerPickAlert()
        }
    }
    
    /// Calculate if it's my turn based on snake draft logic
    private func isMyTurnToPick(pickNumber: Int, mySlot: Int, totalTeams: Int) -> Bool {
        let round = ((pickNumber - 1) / totalTeams) + 1
        let pickInRound = ((pickNumber - 1) % totalTeams) + 1
        
        if round % 2 == 1 {
            // Odd rounds: normal order (1, 2, 3, ..., totalTeams)
            return pickInRound == mySlot
        } else {
            // Even rounds: snake/reverse order (totalTeams, ..., 3, 2, 1)
            return pickInRound == (totalTeams - mySlot + 1)
        }
    }
    
    /// Trigger haptic and audio feedback for pick alerts
    private func triggerPickAlert() async {
        #if os(iOS)
        // Strong haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // System sound for notification
        AudioServicesPlaySystemSound(1007) // SMS received sound
        #endif
    }
    
    /// Dismiss pick alert
    func dismissPickAlert() {
        showingPickAlert = false
        pickAlertMessage = ""
    }
    
    /// Dismiss confirmation alert
    func dismissConfirmationAlert() {
        showingConfirmationAlert = false
        confirmationAlertMessage = ""
    }
    
    /// Debug ESPN connection (wrapper method for the view)
    func debugESPNConnection() async {
        guard let testLeagueID = AppConstants.ESPNLeagueID.first else {
            print(" No ESPN league IDs configured")
            return
        }
        await ESPNAPIClient.shared.debugESPNConnection(leagueID: testLeagueID)
    }

    /// Helper to compare rosters to avoid unnecessary updates
    private func rostersAreEqual(_ r1: Roster, _ r2: Roster) -> Bool {
        // Get all player IDs from both rosters
        let r1IDs = Set([
            r1.qb?.id, r1.rb1?.id, r1.rb2?.id, r1.wr1?.id, r1.wr2?.id, r1.wr3?.id,
            r1.te?.id, r1.flex?.id, r1.k?.id, r1.dst?.id
        ].compactMap { $0 } + r1.bench.map { $0.id })
        
        let r2IDs = Set([
            r2.qb?.id, r2.rb1?.id, r2.rb2?.id, r2.wr1?.id, r2.wr2?.id, r2.wr3?.id,
            r2.te?.id, r2.flex?.id, r2.k?.id, r2.dst?.id
        ].compactMap { $0 } + r2.bench.map { $0.id })
        
        return r1IDs == r2IDs
    }
}