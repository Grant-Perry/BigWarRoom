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
            print("🚫 FETCH GUARD: Already fetching \(league.league.name) week \(selectedWeek), skipping duplicate request")
            return
        }
        
        defer { 
            Self.fetchingLock.lock()
            Self.currentlyFetchingLeagues.remove(leagueKey)
            Self.fetchingLock.unlock()
        }
        
        print("🔍 FETCH MATCHUPS: Starting for league \(league.league.leagueID) source: \(league.source)")
        
        isLoading = true
        errorMessage = nil
        
        if matchups.isEmpty || matchups.first?.leagueID != league.league.leagueID {
            matchups = []
            currentChoppedSummary = nil
        }
        
        let startTime = Date()
        
        do {
            if league.source == .espn {
                print("🏈 ESPN LEAGUE: Fetching ESPN data for \(league.league.leagueID)")
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                print("😴 SLEEPER LEAGUE: Fetching Sleeper data for \(league.league.leagueID)")
                await fetchSleeperScoringSettings(leagueID: league.league.leagueID)
                await fetchSleeperWeeklyStats()
                await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                await fetchSleeperMatchups(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            print("🎯 FETCH COMPLETE: matchups.count = \(matchups.count)")
            
            // 🔥 FIX: Better handling when matchups are empty
            if matchups.isEmpty && league.source == .sleeper {
                print("🔥 CHOPPED DETECTION: 0 processed matchups for Sleeper league - MAKING IT CHOPPED!")
                detectedAsChoppedLeague = true
                hasActiveRosters = true
                
                await MainActor.run {
                    self.objectWillChange.send()
                }
            } else if matchups.isEmpty && league.source == .espn {
                print("⚠️ ESPN: No matchups found for league \(league.league.leagueID) week \(selectedWeek)")
                // Don't immediately mark as chopped, ESPN leagues shouldn't be chopped
                errorMessage = "No matchups found for week \(selectedWeek). Check if this week has started."
            }
            
            if isChoppedLeague(selectedLeague) {
                print("🔥 CHOPPED DETECTION: League detected as Chopped, loading summary...")
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: league.league.leagueID, 
                    week: selectedWeek
                )
                isLoadingChoppedData = false
            } else {
                print("❌ CHOPPED DETECTION: League NOT detected as Chopped")
                print("   - detectedAsChoppedLeague: \(detectedAsChoppedLeague)")
                print("   - hasActiveRosters: \(hasActiveRosters)")
                print("   - league.source: \(league.source)")
            }
            
        } catch {
            errorMessage = "Failed to load matchups: \(error.localizedDescription)"
            if matchups.isEmpty {
                matchups = []
            }
            print("❌ FETCH ERROR: \(error.localizedDescription)")
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let minimumLoadingTime: TimeInterval = 2.0
        
        if elapsedTime < minimumLoadingTime {
            let remainingTime = minimumLoadingTime - elapsedTime
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        isLoading = false
        
        print("🎯 FINAL STATE: matchups.count = \(matchups.count), detectedAsChoppedLeague = \(detectedAsChoppedLeague)")
        
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
            print("🚫 REFRESH GUARD: Already refreshing \(league.league.name), skipping")
            return
        }
        
        defer {
            Self.fetchingLock.lock()
            Self.currentlyFetchingLeagues.remove(leagueKey)
            Self.fetchingLock.unlock()
        }
        
        print("🔄 REFRESH: Starting auto-refresh for \(league.league.name)")
        
        do {
            if league.source == .espn {
                print("🔄 ESPN REFRESH: Using proper authentication...")
                await fetchESPNFantasyData(leagueID: league.league.leagueID, week: selectedWeek)
            } else {
                print("🔄 SLEEPER REFRESH: Refreshing Sleeper data with proper user names...")
                // 🔥 FIX: Ensure user data is available before refreshing matchups
                if userIDs.isEmpty {
                    print("⚠️ SLEEPER REFRESH: User data missing, fetching user names first...")
                    await fetchSleeperLeagueUsersAndRosters(leagueID: league.league.leagueID)
                }
                await refreshSleeperData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            if isChoppedLeague(selectedLeague) {
                await refreshChoppedData(leagueID: league.league.leagueID, week: selectedWeek)
            }
            
            print("✅ REFRESH: Completed auto-refresh, matchups.count = \(matchups.count)")
            
        } catch {
            print("❌ REFRESH: Auto-refresh failed: \(error)")
        }
    }

    /// Real-time Chopped data refresh
    private func refreshChoppedData(leagueID: String, week: Int) async {
        if let updatedSummary = await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week) {
            currentChoppedSummary = updatedSummary
            print("🔥 CHOPPED REFRESH: Updated rankings for week \(week)")
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
            
            print("📊 REFRESH SLEEPER: Received \(sleeperMatchups.count) matchups")
            print("👥 REFRESH DEBUG: userIDs.count = \(userIDs.count), rosterIDToManagerID.count = \(rosterIDToManagerID.count)")
            
            // 🔥 FIX: Use the proper Sleeper matchup processing instead of legacy method
            if !sleeperMatchups.isEmpty {
                await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
                print("✅ REFRESH SLEEPER: Updated matchups with proper names")
            } else {
                print("⚠️ REFRESH SLEEPER: No matchups found (possibly Chopped league)")
            }
            
        } catch {
            print("❌ REFRESH SLEEPER: Failed to refresh - \(error)")
        }
    }
}