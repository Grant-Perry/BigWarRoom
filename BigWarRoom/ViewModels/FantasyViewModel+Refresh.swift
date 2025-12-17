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
            // CRITICAL FIX: Use cached LeagueMatchupProvider instead of direct API calls
            let cachedProvider = MatchupsHubViewModel.shared.getCachedProvider(
                for: league, 
                week: selectedWeek, 
                year: selectedYear
            )
            
            if let cachedProvider = cachedProvider {
                DebugPrint(mode: .fantasy, "📦 Using CACHED provider for league \(league.league.leagueID)")
                
                // Get matchups from cached provider
                let providerMatchups = try await cachedProvider.fetchMatchups()
                
                if !providerMatchups.isEmpty {
                    // Use the fresh, correctly calculated matchups
                    matchups = providerMatchups
                } else if league.source == .sleeper {
                    // Handle Chopped leagues
                    detectedAsChoppedLeague = true
                    hasActiveRosters = true
                }
                
                // Sync ESPN data if needed
                if league.source == .espn {
                    // Get ESPN league data from cached provider for member name resolution
                    await ensureESPNLeagueDataLoaded()
                }
                
            } else {
                // Fallback: Create a NEW provider if no cached one available
                DebugPrint(mode: .fantasy, "📦 NO CACHED PROVIDER - Creating NEW provider for league \(league.league.leagueID)")
                
                let newProvider = LeagueMatchupProvider(
                    league: league,
                    week: selectedWeek,
                    year: selectedYear
                )
                
                // Fetch matchups using the new provider
                let providerMatchups = try await newProvider.fetchMatchups()
                
                if !providerMatchups.isEmpty {
                    matchups = providerMatchups
                    DebugPrint(mode: .fantasy, "  ✅ NEW provider fetch complete, matchups.count=\(matchups.count)")
                } else if league.source == .sleeper {
                    // Handle Chopped leagues
                    detectedAsChoppedLeague = true
                    hasActiveRosters = true
                    DebugPrint(mode: .fantasy, "  🍲 Detected Chopped league (empty matchups)")
                } else if league.source == .espn {
                    // ESPN shouldn't have empty matchups unless there's an error
                    errorMessage = "No matchups found for week \(selectedWeek). Check if this week has started."
                    DebugPrint(mode: .fantasy, "  ⚠️ ESPN league has empty matchups")
                }
            }
            
            // FIX: Better handling when matchups are empty
            if matchups.isEmpty && league.source == .sleeper {
                detectedAsChoppedLeague = true
                hasActiveRosters = true
            } else if matchups.isEmpty && league.source == .espn {
                // Don't immediately mark as chopped, ESPN leagues shouldn't be chopped
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
            // 🔥 FIXED: Use LeagueMatchupProvider for refresh instead of direct API calls
            let provider = LeagueMatchupProvider(
                league: league,
                week: selectedWeek,
                year: selectedYear
            )
            
            let refreshedMatchups = try await provider.fetchMatchups()
            
            if !refreshedMatchups.isEmpty {
                matchups = refreshedMatchups
                DebugPrint(mode: .fantasy, "🔄 Matchups refreshed: \(refreshedMatchups.count) matchups")
            }
            
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

    /// Real-time Sleeper data refresh without UI disruption
    private func refreshSleeperData(leagueID: String, week: Int) async {
        // 🔥 REMOVED: This method is no longer needed since we use LeagueMatchupProvider
        // Keeping the stub in case it's called from elsewhere
        DebugPrint(mode: .fantasy, "⚠️ refreshSleeperData called but is deprecated - use refreshMatchups() instead")
    }
}