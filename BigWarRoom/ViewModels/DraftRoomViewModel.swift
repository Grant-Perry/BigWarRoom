//
//  DraftRoomViewModel.swift
//  BigWarRoom
//
//  ViewModel coordinating live draft polling, AI suggestions, and user interactions
//

import Foundation
import Combine

#if os(iOS)
import AudioToolbox
import UIKit
#endif

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
    
    @Published var allAvailableDrafts: [SleeperLeague] = []
    @Published var selectedDraft: SleeperLeague?
    
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
    
    /// Computed property for max teams in current draft
    var maxTeamsInDraft: Int {
        return manualDraftInfo?.settings?.teams ??
               selectedDraft?.settings?.teams ??
               selectedDraft?.totalRosters ??
               16
    }

    // MARK: - Services
    
    private let sleeperClient = SleeperAPIClient.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    private let polling = DraftPollingService.shared
    private let suggestionEngine = SuggestionEngine()
    
    // MARK: - Draft Context & User Tracking
    
    private var draftRosters: [Int: DraftRosterInfo] = [:]
    private var currentUserID: String?
    private var myRosterID: Int?
    private var myDraftSlot: Int?
    private var allLeagueRosters: [SleeperRoster] = []
    private var lastPickCount = 0
    private var lastMyPickCount = 0
    
    // MARK: - Combine
    
    private var cancellables = Set<AnyCancellable>()
    private var suggestionsTask: Task<Void, Never>?
    
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
                if self.myDraftSlot != nil && self.myRosterID == nil {
                    let mySlotPicks = picks.filter { $0.draftSlot == self.myDraftSlot }
                    print("🔍 Mock Draft Tracking - Slot \(self.myDraftSlot!): \(mySlotPicks.count) picks")
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
    
    func connectWithUserID(_ userID: String) async {
        connectionStatus = .connecting
        currentUserID = userID  // Store the user ID
        do {
            let user = try await sleeperClient.fetchUserByID(userID: userID)
            sleeperDisplayName = user.displayName ?? user.username
            sleeperUsername = user.username
            
            // Fetch current season leagues
            let leagues = try await sleeperClient.fetchLeagues(userID: userID)
            allAvailableDrafts = leagues.filter { $0.draftID != nil }
            
            connectionStatus = .connected
        } catch {
            connectionStatus = .disconnected
        }
    }
    
    func disconnectFromLive() {
        polling.stopPolling()
        selectedDraft = nil
        allDraftPicks = []
        recentLivePicks = []
        connectionStatus = .disconnected
        currentUserID = nil
        myRosterID = nil
        myDraftSlot = nil
        allLeagueRosters = []
        
        // Reset manual draft state
        isConnectedToManualDraft = false
        manualDraftNeedsPosition = false
        manualDraftInfo = nil
        
        // Don't clear roster here - let user keep their manual roster if they want
    }
    
    // MARK: - Selecting a Draft
    
    func selectDraft(_ league: SleeperLeague) async {
        selectedDraft = league
        
        // Fetch roster metadata and find MY roster
        if let leagueID = selectedDraft?.leagueID {
            do {
                let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
                allLeagueRosters = rosters
                
                // Find MY roster by matching owner ID with current user ID
                if let userID = currentUserID {
                    if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                        myRosterID = myRoster.rosterID
                        myDraftSlot = myRoster.draftSlot
                    }
                }
                
                // Build roster info for display
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
                
                // Load MY actual roster from the league
                await loadMyActualRoster()
                
                // Initialize pick tracking
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == myRosterID }.count
                
            } catch {
                draftRosters = [:]
                myRosterID = nil
                myDraftSlot = nil
            }
        }
        
        // Start polling the actual draft
        if let draftID = league.draftID {
            polling.startPolling(draftID: draftID)
        }
        
        await refreshSuggestions()
    }
    
    /// Load the user's actual roster from the selected league
    private func loadMyActualRoster() async {
        guard let myRosterID = myRosterID,
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
            print("❌ Could not fetch draft info: \(error)")
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
            let foundRoster = await enhanceManualDraftWithRosterCorrelation(draftID: draftID, userID: userID)
            
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
            print("🔍 Fetching draft info for manual draft: \(draftID)")
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            
            guard let leagueID = draft.leagueID else {
                print("⚠️ Draft \(draftID) has no league ID - likely a mock draft")
                return false
            }
            
            print("✅ Found league ID: \(leagueID)")
            
            // Step 2: Fetch league info to create a SleeperLeague object
            let league = try await sleeperClient.fetchLeague(leagueID: leagueID)
            print("✅ Fetched league: \(league.name)")
            
            // Step 3: Fetch league rosters
            let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
            allLeagueRosters = rosters
            
            // Step 4: Find MY roster by matching owner ID with current user ID
            if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                myRosterID = myRoster.rosterID
                myDraftSlot = myRoster.draftSlot
                
                print("🎯 Found your roster! ID: \(myRoster.rosterID), Draft Slot: \(myRoster.draftSlot ?? -1)")
                
                // Step 5: Set up draft roster info for display
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
                
                // Step 6: Update selectedDraft with real league info
                selectedDraft = league
                
                // Step 7: Load your actual roster from the league
                await loadMyActualRoster()
                
                // Step 8: Initialize pick tracking for alerts
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == myRosterID }.count
                
                print("🚨 Manual draft enhanced! Pick alerts and roster correlation enabled.")
                return true
                
            } else {
                print("⚠️ Could not find your roster in league \(leagueID)")
                print("Available rosters: \(rosters.map { "\($0.rosterID): \($0.ownerID ?? "no owner")" })")
                return false
            }
            
        } catch {
            print("❌ Failed to enhance manual draft: \(error)")
            print("Manual draft will work but without roster correlation")
            return false
        }
    }

    /// Set manual draft position when auto-detection fails
    func setManualDraftPosition(_ position: Int) {
        myDraftSlot = position
        manualDraftNeedsPosition = false
        
        // Now that position is set, we can close the manual draft entry
        showManualDraftEntry = false
        
        // Initialize pick tracking with manual position - count existing picks for this slot
        lastPickCount = polling.allPicks.count
        
        // Count picks already made for this draft slot
        let existingMyPicks = polling.allPicks.filter { $0.draftSlot == position }
        lastMyPickCount = existingMyPicks.count
        
        print("🎯 Manual draft position set to: \(position)")
        print("📊 Found \(existingMyPicks.count) existing picks for slot \(position)")
        
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
            leagueID: selectedDraft?.leagueID ?? AppConstants.SleeperLeagueID,
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
                    print("🎯 All method: Showing \(sorted.count) total ranked players (filtered from \(available.count) available)")
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
        // Use SuggestionEngine fallback without AI
        let picks = polling.allPicks
        // We don't need the draft/league here; SuggestionEngine fallback ignores them
        let top = await withCheckedContinuation { (continuation: CheckedContinuation<[Suggestion], Never>) in
            Task {
                // Using the internal fallback by calling topSuggestions; AI failure path will fallback
                let dummyLeague = selectedDraft
                let dummyDraft = polling.currentDraft
                // If we can't build full context, still call with minimal (it will fallback)
                let result = try? await suggestionEngine.topSuggestions(
                    from: available,
                    roster: roster,
                    league: dummyLeague ?? SleeperLeague(
                        leagueID: AppConstants.SleeperLeagueID,
                        name: "League",
                        status: .drafting,
                        sport: "nfl",
                        season: "2024",
                        seasonType: "regular",
                        totalRosters: 12,
                        draftID: AppConstants.draftID,
                        avatar: nil,
                        settings: nil,
                        scoringSettings: nil,
                        rosterPositions: ["QB","RB","RB","WR","WR","WR","TE","FLEX","K","DST","BN","BN","BN","BN","BN"]
                    ),
                    draft: dummyDraft ?? SleeperDraft(
                        draftID: AppConstants.draftID,
                        leagueID: AppConstants.SleeperLeagueID,
                        status: .drafting,
                        type: .snake,
                        sport: "nfl",
                        season: "2024",
                        seasonType: "regular",
                        startTime: nil,
                        lastPicked: nil,
                        settings: SleeperDraftSettings(
                            teams: 12, rounds: 15,
                            pickTimer: nil,
                            slotsQB: nil, slotsRB: nil, slotsWR: nil,
                            slotsTE: nil, slotsFlex: nil, slotsK: nil,
                            slotsDEF: nil, slotsBN: nil
                        ),
                        metadata: nil, draftOrder: nil, slotToRosterID: nil
                    ),
                    picks: picks,
                    draftRosters: draftRosters,
                    limit: limit
                )
                continuation.resume(returning: result ?? [])
            }
        }
        
        // Don't apply additional limits for "rankings" or "all" methods 
        if selectedSortMethod == .rankings {
            return sortedByPureRank(top)
        } else if selectedSortMethod == .all {
            // This shouldn't be called for .all anymore, but just in case
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
            print("🏆 Top 20 players - Sequential Position vs Sleeper Rank:")
            for (index, suggestion) in sortedList.prefix(20).enumerated() {
                let sleeperRank = PlayerDirectoryStore.shared.player(for: suggestion.player.id)?.searchRank ?? -1
                let sequentialRank = index + 1
                print("  \(sequentialRank). \(suggestion.player.shortKey) - Sleeper Rank #\(sleeperRank)")
            }
            
            // Show total count
            print("🎯 All method: Showing \(sortedList.count) players in strict 1-2-3-4... order")
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
        return picks.compactMap { pick in
            guard let playerID = pick.playerID,
                  let sp = playerDirectory.player(for: playerID) else {
                return nil
            }
            let teamCode = sp.team ?? ""
            let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
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
        .sorted { $0.pickNumber < $1.pickNumber }
    }
    
    /// Update my roster based on draft picks
    private func updateMyRosterFromPicks(_ picks: [SleeperPick]) async {
        var newRoster = Roster()
        
        // Strategy 1: Use roster ID correlation (for real leagues)
        if let myRosterID = myRosterID {
            let myPicks = picks.filter { $0.rosterID == myRosterID }
            
            for pick in myPicks {
                if let playerID = pick.playerID,
                   let sleeperPlayer = playerDirectory.player(for: playerID),
                   let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
                    newRoster.add(internalPlayer)
                }
            }
        }
        // Strategy 2: Use draft slot correlation (for mock drafts/manual position)
        else if let myDraftSlot = myDraftSlot {
            let myPicks = picks.filter { $0.draftSlot == myDraftSlot }
            
            for pick in myPicks {
                if let playerID = pick.playerID,
                   let sleeperPlayer = playerDirectory.player(for: playerID),
                   let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
                    newRoster.add(internalPlayer)
                }
            }
            
            print("🎯 Updated roster from draft slot \(myDraftSlot): \(myPicks.count) picks")
        }
        
        // Update roster if it's different
        if !rostersAreEqual(newRoster, roster) {
            roster = newRoster
            print("✅ MyRoster updated with \(totalPlayersInRoster(newRoster)) players")
        }
    }
    
    /// Helper to count total players in roster
    private func totalPlayersInRoster(_ roster: Roster) -> Int {
        let starters = [roster.qb, roster.rb1, roster.rb2, roster.wr1, roster.wr2, roster.wr3,
                       roster.te, roster.flex, roster.k, roster.dst].compactMap { $0 }.count
        return starters + roster.bench.count
    }
    
    // MARK: - Turn Detection & Alerts
    
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
            
            pickAlertMessage = "🚨 IT'S YOUR PICK! 🚨\n\nRound \(round), Pick \(pickInRound)\n(\(currentPickNumber) overall)\n\nTime to make your selection!"
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
    
    /// Check for new picks I made and show confirmation
    private func checkForMyNewPicks(_ picks: [SleeperPick]) async {
        var myPicks: [SleeperPick] = []
        var newMyPickCount = 0
        
        // Strategy 1: Use roster ID (for real leagues)
        if let myRosterID = myRosterID {
            myPicks = picks.filter { $0.rosterID == myRosterID }
            newMyPickCount = myPicks.count
        }
        // Strategy 2: Use draft slot (for mock drafts)
        else if let myDraftSlot = myDraftSlot {
            myPicks = picks.filter { $0.draftSlot == myDraftSlot }
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
                    confirmationAlertMessage = "✅ PICK CONFIRMED!\n\n\(player.fullName)\n\(player.position ?? "") • \(player.team ?? "")\n\nRound \(pick.round), Pick \(pick.pickNo)"
                    showingConfirmationAlert = true
                    
                    print("🚨 Confirmed your pick: \(player.shortName) at position \(pick.draftSlot)")
                }
            }
        }
        
        lastMyPickCount = newMyPickCount
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

// MARK: - Enums

extension DraftRoomViewModel {
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
}