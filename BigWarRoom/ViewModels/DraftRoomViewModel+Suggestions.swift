import Foundation

// MARK: - AI Suggestions & Player Filtering
extension DraftRoomViewModel {
    
    func updatePositionFilter(_ filter: PositionFilter) {
        selectedPositionFilter = filter
        Task { await refreshSuggestions() }
    }
    
    func updateSortMethod(_ method: SortMethod) {
        selectedSortMethod = method
        Task { await refreshSuggestions() }
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
                    // xprint("🏈 All method: Showing \(sorted.count) total ranked players (filtered from \(available.count) available)")
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
    
    internal func buildAvailablePlayers() -> [Player] {
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
    
    internal func currentSleeperLeagueAndDraft() -> (SleeperLeague, SleeperDraft)? {
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
    
    internal func sortedByPureRank(_ list: [Suggestion]) -> [Suggestion] {
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
            // xprint("🏈 Top 20 players - Sequential Position vs Sleeper Rank:")
            for (index, suggestion) in sortedList.prefix(20).enumerated() {
                let sleeperRank = PlayerDirectoryStore.shared.player(for: suggestion.player.id)?.searchRank ?? -1
                let sequentialRank = index + 1
                // xprint("  \(sequentialRank). \(suggestion.player.shortKey) - Sleeper Rank #\(sleeperRank)")
            }
            
            // Show total count
            // xprint("🏈 All method: Showing \(sortedList.count) players in strict 1-2-3-4... order")
        }
        
        return sortedList
    }
    
    func forceRefresh() async {
        await polling.forceRefresh()
        await refreshSuggestions()
    }
}