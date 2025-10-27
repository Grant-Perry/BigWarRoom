import Foundation
import Observation

/// Protocol for managing AI suggestions and player filtering
@MainActor
protocol DraftSuggestionsCoordinator: AnyObject {
    var suggestions: [Suggestion] { get }
    var selectedPositionFilter: PositionFilter { get }
    var selectedSortMethod: SortMethod { get }
    
    func updatePositionFilter(_ filter: PositionFilter) async
    func updateSortMethod(_ method: SortMethod) async
    func refreshSuggestions() async
    func forceRefresh() async
}

/// Concrete implementation of DraftSuggestionsCoordinator
@Observable
@MainActor
final class DefaultDraftSuggestionsCoordinator: DraftSuggestionsCoordinator {
    
    // MARK: - Observable Properties
    var suggestions: [Suggestion] = []
    var selectedPositionFilter: PositionFilter = .all
    var selectedSortMethod: SortMethod = .wizard
    
    // MARK: - Internal Properties
    private let suggestionEngine = SuggestionEngine()
    private let playerDirectory = PlayerDirectoryStore.shared
    private var suggestionsTask: Task<Void, Never>?
    
    // MARK: - Delegate
    weak var delegate: DraftSuggestionsCoordinatorDelegate?
    
    init() {
        // 🔥 PERFORMANCE FIX: Keep init lightweight and non-blocking
        // No heavy operations here - they happen in initializeAsync()
    }
    
    // MARK: - Async Initialization
    
    /// Initialize suggestions asynchronously after UI is ready
    func initializeAsync() async {
        await refreshSuggestions()
    }
    
    // MARK: - Public Methods
    
    func updatePositionFilter(_ filter: PositionFilter) async {
        selectedPositionFilter = filter
        await refreshSuggestions()
    }
    
    func updateSortMethod(_ method: SortMethod) async {
        selectedSortMethod = method
        await refreshSuggestions()
    }
    
    func refreshSuggestions() async {
        suggestionsTask?.cancel()
        suggestionsTask = Task { [weak self] in
            guard let self else { return }
            
            // Get context from delegate
            guard let context = delegate?.suggestionsCoordinatorGetContext(self) else { return }
            
            let available = buildAvailablePlayers(
                allPicks: context.allPicks,
                myRosterPlayerIDs: context.myRosterPlayerIDs
            )
            
            // For "All" method, skip AI entirely and show all players sorted by rank
            if selectedSortMethod == .all {
                let playersWithRanks = available.filter { player in
                    guard let sleeperPlayer = playerDirectory.player(for: player.id),
                          let rank = sleeperPlayer.searchRank else { return false }
                    return rank > 0 && rank < 10000  // Valid fantasy rankings
                }
                
                let allPlayerSuggestions = playersWithRanks.map { player in
                    Suggestion(player: player, reasoning: nil)
                }
                let sorted = sortedByPureRank(allPlayerSuggestions)
                
                await MainActor.run { 
                    self.suggestions = sorted 
                }
                return
            }
            
            // If AI is disabled, skip all AI context, return heuristic only
            if AppConstants.useAISuggestions == false {
                let fallback = await heuristicSuggestions(
                    available: available, 
                    limit: 50,
                    context: context
                )
                await MainActor.run { self.suggestions = fallback }
                return
            }
            
            // No AI context? Fall back immediately
            guard let (league, draft) = currentSleeperLeagueAndDraft(from: context) else {
                let fallback = await heuristicSuggestions(
                    available: available, 
                    limit: 50,
                    context: context
                )
                await MainActor.run { self.suggestions = fallback }
                return
            }
            
            // Try AI-backed suggestions
            do {
                let top = try await suggestionEngine.topSuggestions(
                    from: available,
                    roster: context.roster,
                    league: league,
                    draft: draft,
                    picks: context.allPicks,
                    draftRosters: context.draftRosters,
                    limit: 50
                )
                
                // Apply secondary sort if "Rankings" method chosen
                let final = selectedSortMethod == .rankings
                    ? sortedByPureRank(top)
                    : top
                
                await MainActor.run {
                    self.suggestions = final
                }
            } catch {
                let fallback = await heuristicSuggestions(
                    available: available, 
                    limit: 50,
                    context: context
                )
                await MainActor.run { self.suggestions = fallback }
            }
        }
    }
    
    func forceRefresh() async {
        await delegate?.suggestionsCoordinatorForceRefresh(self)
        await refreshSuggestions()
    }
    
    // MARK: - Private Methods
    
    private func buildAvailablePlayers(allPicks: [SleeperPick], myRosterPlayerIDs: [String]) -> [Player] {
        let draftedIDs = Set(allPicks.compactMap { $0.playerID })
        let myRosterIDs = Set(myRosterPlayerIDs)
        
        // Base pool: active players with valid position/team
        let base = playerDirectory.players.values.compactMap { sp -> Player? in
            guard let _ = sp.position,
                  let _ = sp.team else { return nil }
            return playerDirectory.convertToInternalPlayer(sp)
        }
        .filter { !draftedIDs.contains($0.id) && !myRosterIDs.contains($0.id) }
        
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
    
    private func currentSleeperLeagueAndDraft(from context: DraftSuggestionsContext) -> (SleeperLeague, SleeperDraft)? {
        guard let league = context.selectedDraft,
              let draftID = league.draftID else {
            return nil
        }
        
        // Best effort: pull from context if it has a draft struct
        if let draft = context.currentDraft {
            return (league, draft)
        }
        
        // Construct a minimal draft placeholder
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
    
    private func heuristicSuggestions(available: [Player], limit: Int, context: DraftSuggestionsContext) async -> [Suggestion] {
        // If no draft is selected, just return basic ranked suggestions
        guard let selectedDraft = context.selectedDraft else {
            let rankedSuggestions = available.compactMap { player -> Suggestion? in
                guard let sleeperPlayer = playerDirectory.player(for: player.id),
                      let rank = sleeperPlayer.searchRank,
                      rank > 0 && rank < 10000 else { return nil }
                return Suggestion(player: player, reasoning: nil)
            }
            .sorted { lhs, rhs in
                let lRank = playerDirectory.player(for: lhs.player.id)?.searchRank ?? Int.max
                let rRank = playerDirectory.player(for: rhs.player.id)?.searchRank ?? Int.max
                return lRank < rRank
            }
            
            return Array(rankedSuggestions.prefix(limit))
        }
        
        // Use SuggestionEngine fallback without AI but with real draft context
        guard let currentDraft = context.currentDraft else {
            // No draft data available, fall back to basic ranking
            return Array(available.prefix(limit).map { Suggestion(player: $0, reasoning: nil) })
        }
        
        let top = await withCheckedContinuation { (continuation: CheckedContinuation<[Suggestion], Never>) in
            Task {
                let result = try? await suggestionEngine.topSuggestions(
                    from: available,
                    roster: context.roster,
                    league: selectedDraft,
                    draft: currentDraft,
                    picks: context.allPicks,
                    draftRosters: context.draftRosters,
                    limit: limit
                )
                continuation.resume(returning: result ?? [])
            }
        }
        
        // Apply sorting based on method
        if selectedSortMethod == .rankings || selectedSortMethod == .all {
            return sortedByPureRank(top)
        } else {
            return Array(top.prefix(limit))
        }
    }
    
    private func sortedByPureRank(_ list: [Suggestion]) -> [Suggestion] {
        let sortedList = list.sorted { lhs, rhs in
            let lRank = playerDirectory.player(for: lhs.player.id)?.searchRank ?? Int.max
            let rRank = playerDirectory.player(for: rhs.player.id)?.searchRank ?? Int.max
            
            if lRank == rRank {
                return lhs.player.shortKey < rhs.player.shortKey
            }
            return lRank < rRank
        }
        
        return sortedList
    }
}

// MARK: - Context Structure

struct DraftSuggestionsContext {
    let roster: Roster
    let selectedDraft: SleeperLeague?
    let currentDraft: SleeperDraft?
    let allPicks: [SleeperPick]
    let draftRosters: [Int: DraftRosterInfo]
    let myRosterPlayerIDs: [String]
}

// MARK: - Delegate Protocol

@MainActor
protocol DraftSuggestionsCoordinatorDelegate: AnyObject {
    func suggestionsCoordinatorGetContext(_ coordinator: DraftSuggestionsCoordinator) -> DraftSuggestionsContext?
    func suggestionsCoordinatorForceRefresh(_ coordinator: DraftSuggestionsCoordinator) async
}