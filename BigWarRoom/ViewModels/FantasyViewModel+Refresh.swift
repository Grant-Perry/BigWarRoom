//
//  FantasyViewModel+Refresh.swift
//  BigWarRoom
//
//  Refresh and Data Management functionality for FantasyViewModel
//

import Foundation
import Combine

// MARK: -> Refresh & Data Management Extension
extension FantasyViewModel {
    
    // MARK: -> Loading Guards
    private static var currentlyFetchingLeagues = Set<String>()
    private static let fetchingLock = NSLock()
    
    /// Fetch matchups for selected league, week, and year
    func fetchMatchups() async {
        guard let league = selectedLeague else {
            matchups = []
            currentChoppedSummary = nil
            return
        }
        
        let leagueKey = "\(league.league.leagueID)_\(selectedWeek)_\(selectedYear)"
        
        // 🔥 FIX: Bulletproof loading guard to prevent infinite loops
        Self.fetchingLock.lock()
        let isAlreadyFetching = Self.currentlyFetchingLeagues.contains(leagueKey)
        if !isAlreadyFetching {
            Self.currentlyFetchingLeagues.insert(leagueKey)
        }
        Self.fetchingLock.unlock()
        
        if isAlreadyFetching {
            // x Print("🚫 FETCH GUARD: Already fetching \(league.league.name) week \(selectedWeek), skipping duplicate request")
            return
        }
        
        defer { 
            Self.fetchingLock.lock()
            Self.currentlyFetchingLeagues.remove(leagueKey)
            Self.fetchingLock.unlock()
        }
        
        // x Print("🔍 FETCH MATCHUPS: Starting for league \(league.league.leagueID) source: \(league.source)")
        
        isLoading = true
        errorMessage = nil
        
        if matchups.isEmpty || matchups.first?.leagueID != league.league.leagueID {
            matchups = []
            currentChoppedSummary = nil
        }
        
        let startTime = Date()
        
        do {
            // 🔥 CRITICAL FIX: Use cached LeagueMatchupProvider instead of direct API calls
            let cachedProvider = MatchupsHubViewModel.shared.getCachedProvider(
                for: league, 
                week: selectedWeek, 
                year: selectedYear
            )
            
            if let cachedProvider = cachedProvider {
                print("✅ FANTASY: Using cached provider for \(league.league.name)")
                
                // Get matchups from cached provider
                let providerMatchups = try await cachedProvider.fetchMatchups()
                
                if !providerMatchups.isEmpty {
                    // Use the fresh, correctly calculated matchups
                    matchups = providerMatchups
                    print("✅ FANTASY: Loaded \(matchups.count) matchups from cached provider")
                } else if league.source == .sleeper {
                    // Handle Chopped leagues
                    detectedAsChoppedLeague = true
                    hasActiveRosters = true
                    print("🔥 FANTASY: Chopped league detected from cached provider")
                }
                
                // Sync ESPN data if needed
                if league.source == .espn {
                    // Get ESPN league data from cached provider for member name resolution
                    await ensureESPNLeagueDataLoaded()
                }
                
            } else {
                // Fallback: Use original API calls if no cached provider available
                print("⚠️ FANTASY: No cached provider available, falling back to direct API calls")
                
                if league.source == .espn {
                    // x Print("🏈 ESPN LEAGUE: Fetching ESPN data for \(league.league.leagueID)")
                    await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
                } else {
                    // x Print("😴 SLEEPER LEAGUE: Fetching Sleeper data for \(league.league.leagueID)")
                    await fetchSleeperScoringSettings(leagueID: league.league.leagueID)
                    await fetchSleeperWeeklyStats()
                    await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                    await fetchSleeperMatchups(leagueID: league.league.leagueID, week: selectedWeek)
                }
            }
            
            // x Print("🎯 FETCH COMPLETE: matchups.count = \(matchups.count)")
            
            // 🔥 FIX: Better handling when matchups are empty
            if matchups.isEmpty && league.source == .sleeper {
                // x Print("🔥 CHOPPED DETECTION: 0 processed matchups for Sleeper league - MAKING IT CHOPPED!")
                detectedAsChoppedLeague = true
                hasActiveRosters = true
                
                await MainActor.run {
                    self.objectWillChange.send()
                }
            } else if matchups.isEmpty && league.source == .espn {
                // x Print("⚠️ ESPN: No matchups found for league \(league.league.leagueID) week \(selectedWeek)")
                // Don't immediately mark as chopped, ESPN leagues shouldn't be chopped
                errorMessage = "No matchups found for week \(selectedWeek). Check if this week has started."
            }
            
            if isChoppedLeague(selectedLeague) {
                // x Print("🔥 CHOPPED DETECTION: League detected as Chopped, loading summary...")
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: league.league.leagueID, 
                    week: selectedWeek
                )
                isLoadingChoppedData = false
            } else {
                // x Print("❌ CHOPPED DETECTION: League NOT detected as Chopped")
                // x Print("   - detectedAsChoppedLeague: \(detectedAsChoppedLeague)")
                // x Print("   - hasActiveRosters: \(hasActiveRosters)")
                // x Print("   - league.source: \(league.source)")
            }
            
        } catch {
            errorMessage = "Failed to load matchups: \(error.localizedDescription)"
            if matchups.isEmpty {
                matchups = []
            }
            // x Print("❌ FETCH ERROR: \(error.localizedDescription)")
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minimumLoadingTime: TimeInterval = 2.0
        
        if elapsedTime < minimumLoadingTime {
            let remainingTime = minimumLoadingTime - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        isLoading = false
        
        // x Print("🎯 FINAL STATE: matchups.count = \(matchups.count), detectedAsChoppedLeague = \(detectedAsChoppedLeague)")
        
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
        
        // 🔥 FIX: Add loading guard to refresh as well
        Self.fetchingLock.lock()
        let isAlreadyRefreshing = Self.currentlyFetchingLeagues.contains(leagueKey)
        if !isAlreadyRefreshing {
            Self.currentlyFetchingLeagues.insert(leagueKey)
        }
        Self.fetchingLock.unlock()
        
        if isAlreadyRefreshing {
            // x Print("🚫 REFRESH GUARD: Already refreshing \(league.league.name), skipping")
            return
        }
        
        defer {
            Self.fetchingLock.lock()
            Self.currentlyFetchingLeagues.remove(leagueKey)
            Self.fetchingLock.unlock()
        }
        
        // x Print("🔄 REFRESH: Starting auto-refresh for \(league.league.name)")
        
        do {
            if league.source == .espn {
                // x Print("🔄 ESPN REFRESH: Using proper authentication...")
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                // x Print("🔄 SLEEPER REFRESH: Refreshing Sleeper data with proper user names...")
                // 🔥 FIX: Ensure user data is available before refreshing matchups
                if userIDs.isEmpty {
                    // x Print("⚠️ SLEEPER REFRESH: User data missing, fetching user names first...")
                    await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                }
                await refreshSleeperData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            if isChoppedLeague(selectedLeague) {
                await refreshChoppedData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            // x Print("✅ REFRESH: Completed auto-refresh, matchups.count = \(matchups.count)")
            
        } catch {
            // x Print("❌ REFRESH: Auto-refresh failed: \(error)")
        }
    }

    /// Real-time Chopped data refresh
    private func refreshChoppedData(leagueID: String, week: Int) async {
        if let updatedSummary = await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week) {
            currentChoppedSummary = updatedSummary
            // x Print("🔥 CHOPPED REFRESH: Updated rankings for week \(week)")
        }
    }

    /// Real-time Sleeper data refresh without UI disruption
    private func refreshSleeperData(leagueID: String, week: Int) async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            
            // x Print("📊 REFRESH SLEEPER: Received \(sleeperMatchups.count) matchups")
            // x Print("👥 REFRESH DEBUG: userIDs.count = \(userIDs.count), rosterIDToManagerID.count = \(rosterIDToManagerID.count)")
            
            // 🔥 FIX: Use the proper Sleeper matchup processing instead of legacy method
            if !sleeperMatchups.isEmpty {
                await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
                // x Print("✅ REFRESH SLEEPER: Updated matchups with proper names")
            } else {
                // x Print("⚠️ REFRESH SLEEPER: No matchups found (possibly Chopped league)")
            }
            
        } catch {
            // x Print("❌ REFRESH SLEEPER: Failed to refresh - \(error)")
        }
    }
}