//
//  FantasyViewModel+Refresh.swift
//  BigWarRoom
//
//  🔥 PHASE 3 REFACTOR: Simplified refresh logic using services
//  Refresh and Data Management functionality for FantasyViewModel
//

import Foundation

// MARK: - Refresh & Data Management Extension
extension FantasyViewModel {
    
    // MARK: - Loading Guards
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
    
    // MARK: - Fetch Matchups (Main Entry Point)
    
    func fetchMatchups() async {
        guard let league = selectedLeague else {
            matchups = []
            currentChoppedSummary = nil
            return
        }
        
        let leagueKey = "\(league.league.leagueID)_\(selectedWeek)_\(selectedYear)"
        
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
            // 🔥 PHASE 4: Use MatchupDataStore to hydrate snapshot
            let snapshotID = MatchupSnapshot.ID(
                leagueID: league.league.leagueID,
                matchupID: "\(league.league.leagueID)_\(selectedWeek)",
                platform: league.source,
                week: selectedWeek
            )
            
            let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
            
            // 🔥 PHASE 3: Use MatchupMapperService to convert snapshot
            let fantasyMatchup = matchupMapperService.snapshotToFantasyMatchup(snapshot, year: selectedYear)
            matchups = [fantasyMatchup]
            
            DebugPrint(mode: .fantasy, "✅ Store hydration complete, matchups.count=\(matchups.count)")
            
            // Sync platform-specific data
            if league.source == .espn {
                await ensureESPNLeagueDataLoaded()
            }
            
        } catch {
            DebugPrint(mode: .fantasy, "❌ Store hydration failed: \(error)")
            errorMessage = "Failed to load matchup data"
            matchups = []
        }
        
        // Handle empty matchups
        if matchups.isEmpty && league.source == .sleeper {
            detectedAsChoppedLeague = true
            hasActiveRosters = true
        } else if matchups.isEmpty && league.source == .espn {
            errorMessage = "No matchups found for week \(selectedWeek). Check if this week has started."
        }
        
        // Handle chopped leagues
        if isChoppedLeague(selectedLeague) {
            isLoadingChoppedData = true
            currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                leagueID: league.league.leagueID,
                week: selectedWeek
            )
            isLoadingChoppedData = false
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minimumLoadingTime: TimeInterval = 2.0
        
        if elapsedTime < minimumLoadingTime {
            let remainingTime = minimumLoadingTime - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        isLoading = false
        
        if isChoppedLeague(selectedLeague) {
            choppedWeekSummary = await createRealChoppedSummaryWithHistory(
                leagueID: selectedLeague?.league.leagueID ?? "",
                week: selectedWeek
            )
        }
    }
    
    // MARK: - Refresh Matchups
    
    func refreshMatchups() async {
        guard let league = selectedLeague else {
            return
        }
        
        let leagueKey = "\(league.league.leagueID)_\(selectedWeek)_\(selectedYear)"
        
        guard await Self.loadingGuard.shouldFetch(key: leagueKey) else {
            return
        }
        
        defer {
            Task {
                await Self.loadingGuard.completeFetch(key: leagueKey)
            }
        }
        
        do {
            // 🔥 PHASE 4: Use MatchupDataStore.refresh()
            let key = MatchupDataStore.LeagueKey(
                leagueID: league.league.leagueID,
                platform: league.source,
                seasonYear: selectedYear,
                week: selectedWeek
            )
            
            await matchupDataStore.refresh(league: key, force: true)
            
            // Fetch the refreshed snapshot
            let snapshotID = MatchupSnapshot.ID(
                leagueID: league.league.leagueID,
                matchupID: "\(league.league.leagueID)_\(selectedWeek)",
                platform: league.source,
                week: selectedWeek
            )
            
            let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
            
            // 🔥 PHASE 3: Use MatchupMapperService to convert
            let refreshedMatchup = matchupMapperService.snapshotToFantasyMatchup(snapshot, year: selectedYear)
            matchups = [refreshedMatchup]
            
            DebugPrint(mode: .fantasy, "🔄 Matchups refreshed via store")
            
            if isChoppedLeague(selectedLeague) {
                await refreshChoppedData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
        } catch {
            DebugPrint(mode: .fantasy, "❌ Refresh failed: \(error)")
        }
    }
    
    // MARK: - Chopped League Helpers
    
    private func refreshChoppedData(leagueID: String, week: Int) async {
        if let updatedSummary = await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week) {
            currentChoppedSummary = updatedSummary
            DebugPrint(mode: .fantasy, "🍲 Chopped data refreshed")
        }
    }
}