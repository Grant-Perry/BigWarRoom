//
//  FantasyViewModel+Refresh.swift
//  BigWarRoom
//
//  Refresh and Data Management functionality for FantasyViewModel
//

import Foundation

// MARK: -> Refresh & Data Management Extension
extension FantasyViewModel {
    
    // MARK: -> Loading Guards
    // 🔥 FIXED: Use actor-isolated state instead of NSLock
    private actor LoadingGuard {
        private var currentlyFetchingLeagues = Set<String>()
        
        func shouldFetch(key: String) -> Bool {
            if currentlyFetchingLeagues.contains(key) {
                return false
            }
            currentlyFetchingLeagues.insert(key)
            return true
        }
        
        func completeFetch(key: String) {
            currentlyFetchingLeagues.remove(key)
        }
    }
    
    private static let loadingGuard = LoadingGuard()
    
    /// Fetch matchups for selected league, week, and year
    /// 🔥 PHASE 4: Refactored to use MatchupDataStore instead of LeagueMatchupProvider
    func fetchMatchups() async {
        guard let league = selectedLeague else {
            matchups = []
            currentChoppedSummary = nil
            return
        }
        
        let leagueKey = "\(league.league.leagueID)_\(selectedWeek)_\(selectedYear)"
        
        // FIX: Bulletproof loading guard to prevent infinite loops
        guard await Self.loadingGuard.shouldFetch(key: leagueKey) else {
            return
        }
        
        defer { 
            Task {
                await Self.loadingGuard.completeFetch(key: leagueKey)
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        if matchups.isEmpty || matchups.first?.leagueID != league.league.leagueID {
            matchups = []
            currentChoppedSummary = nil
        }
        
        let startTime = Date()
        
        do {
            // 🔥 PHASE 4: Use MatchupDataStore instead of cachedProviders
            DebugPrint(mode: .fantasy, "📦 Using MatchupDataStore for league \(league.league.leagueID)")
            
            // Create snapshot ID
            let snapshotID = MatchupSnapshot.ID(
                leagueID: league.league.leagueID,
                matchupID: "\(league.league.leagueID)_\(selectedWeek)",
                platform: league.source,
                week: selectedWeek
            )
            
            // Try to hydrate from store
            do {
                let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
                
                // Convert snapshot to FantasyMatchup for detail view
                let fantasyMatchup = convertSnapshotToFantasyMatchup(snapshot)
                
                // For detail view, we need to show ALL matchups in the league (for horizontal scrolling)
                // Extract all matchups from the snapshot if available
                // For now, just show the single matchup
                matchups = [fantasyMatchup]
                
                DebugPrint(mode: .fantasy, "  ✅ Store hydration complete, matchups.count=\(matchups.count)")
                
                // Sync ESPN data if needed
                if league.source == .espn {
                    await ensureESPNLeagueDataLoaded()
                }
                
            } catch {
                DebugPrint(mode: .fantasy, "❌ Store hydration failed: \(error)")
                errorMessage = "Failed to load matchup data"
                matchups = []
            }
            
            // FIX: Better handling when matchups are empty
            if matchups.isEmpty && league.source == .sleeper {
                detectedAsChoppedLeague = true
                hasActiveRosters = true
            } else if matchups.isEmpty && league.source == .espn {
                errorMessage = "No matchups found for week \(selectedWeek). Check if this week has started."
            }
            
            if isChoppedLeague(selectedLeague) {
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: league.league.leagueID, 
                    week: selectedWeek
                )
                isLoadingChoppedData = false
            }
            
        } catch {
            errorMessage = "Failed to load matchups: \(error.localizedDescription)"
            if matchups.isEmpty {
                matchups = []
            }
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minimumLoadingTime: TimeInterval = 2.0
        
        if elapsedTime < minimumLoadingTime {
            let remainingTime = minimumLoadingTime - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        isLoading = false
        
        if isChoppedLeague(selectedLeague) {
            choppedWeekSummary = await createRealChoppedSummaryWithHistory(leagueID: selectedLeague?.league.leagueID ?? "", week: selectedWeek)
        }
    }
    
    /// Refresh matchups for auto-refresh without navigation disruption
    /// 🔥 PHASE 4: Refactored to use MatchupDataStore.refresh()
    func refreshMatchups() async {
        guard let league = selectedLeague else {
            return
        }
        
        let leagueKey = "\(league.league.leagueID)_\(selectedWeek)_\(selectedYear)"
        
        // FIX: Add loading guard to refresh as well
        guard await Self.loadingGuard.shouldFetch(key: leagueKey) else {
            return
        }
        
        defer {
            Task {
                await Self.loadingGuard.completeFetch(key: leagueKey)
            }
        }
        
        do {
            // 🔥 PHASE 4: Use MatchupDataStore.refresh() with league wrapper (not LeagueKey)
            await matchupDataStore.refresh(league: league, force: true) // FIXED: Use wrapper, not LeagueKey

            // Now fetch the refreshed snapshot
            let snapshotID = MatchupSnapshot.ID(
                leagueID: league.league.leagueID,
                matchupID: "\(league.league.leagueID)_\(selectedWeek)",
                platform: league.source,
                week: selectedWeek
            )
            
            let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
            let refreshedMatchup = convertSnapshotToFantasyMatchup(snapshot)
            matchups = [refreshedMatchup]
            
            DebugPrint(mode: .fantasy, "🔄 Matchups refreshed via store")
            
            if isChoppedLeague(selectedLeague) {
                await refreshChoppedData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
        } catch {
            DebugPrint(mode: .fantasy, "❌ Refresh failed: \(error)")
        }
    }

    /// Real-time Chopped data refresh
    private func refreshChoppedData(leagueID: String, week: Int) async {
        if let updatedSummary = await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week) {
            currentChoppedSummary = updatedSummary
            DebugPrint(mode: .fantasy, "🍲 Chopped data refreshed")
        }
    }

    // MARK: - 🔥 PHASE 4: Snapshot → FantasyMatchup Conversion
    
    /// Convert MatchupSnapshot to FantasyMatchup for detail view
    private func convertSnapshotToFantasyMatchup(_ snapshot: MatchupSnapshot) -> FantasyMatchup {
        // 🔥 PHASE 2.5: Use DataConversionService
        return DataConversionService.shared.convertSnapshotToFantasyMatchup(snapshot, year: selectedYear)
    }
}