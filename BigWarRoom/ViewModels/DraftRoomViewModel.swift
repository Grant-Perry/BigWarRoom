//
//  DraftRoomViewModel.swift
//  BigWarRoom
//
//  ViewModel coordinating live draft polling, AI suggestions, and user interactions
//

import Foundation
import Combine

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
    
    // MARK: - Services
    
    private let sleeperClient = SleeperAPIClient.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    private let polling = DraftPollingService.shared
    private let suggestionEngine = SuggestionEngine()
    
    // MARK: - Draft Context
    
    private var draftRosters: [Int: DraftRosterInfo] = [:]
    
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
                Task { await self.refreshSuggestions() }
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
    }
    
    // MARK: - Selecting a Draft
    
    func selectDraft(_ league: SleeperLeague) async {
        selectedDraft = league
        
        // Fetch roster metadata for nicer team display
        if let leagueID = selectedDraft?.leagueID {
            do {
                let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
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
            } catch {
                draftRosters = [:]
            }
        }
        
        // Start polling the actual draft
        if let draftID = league.draftID {
            polling.startPolling(draftID: draftID)
        }
        
        await refreshSuggestions()
    }
    
    // MARK: - Manual Draft ID
    
    func connectToManualDraft(draftID: String) async {
        polling.startPolling(draftID: draftID)
        connectionStatus = .connected
        await refreshSuggestions()
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
        // If AI is disabled, skip all AI context, return heuristic only
        if AppConstants.useAISuggestions == false {
            let available = self.buildAvailablePlayers()
            let fallback = await self.heuristicSuggestions(available: available, limit: 50)
            self.suggestions = fallback
            return
        }

        suggestionsTask?.cancel()
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            let available = self.buildAvailablePlayers()
            
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
        return selectedSortMethod == .rankings ? sortedByPureRank(top) : Array(top.prefix(limit))
    }
    
    private func sortedByPureRank(_ list: [Suggestion]) -> [Suggestion] {
        // Use Sleeper searchRank as "pure ranking"
        return list.sorted { lhs, rhs in
            let lRank = PlayerDirectoryStore.shared.player(for: lhs.player.id)?.searchRank ?? Int.max
            let rRank = PlayerDirectoryStore.shared.player(for: rhs.player.id)?.searchRank ?? Int.max
            return lRank < rRank
        }
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
        
        var id: String { displayName }
        var displayName: String {
            switch self {
            case .wizard: return "Wizard"
            case .rankings: return "Rankings"
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