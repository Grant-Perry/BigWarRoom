//
//  MatchupsHubViewModel+WeekSpecific.swift
//  BigWarRoom
//
//  Week-specific loading functionality for MatchupsHubViewModel
//

import Foundation

// MARK: - Week-Specific Operations
extension MatchupsHubViewModel {
    
    /// Load matchups for a specific week
    internal func performLoadMatchupsForWeek(_ week: Int) async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Loading Week \(week) matchups..."
            loadingProgress = 0.0
            loadedLeagueCount = 0
        }
        
        do {
            // Step 1: Load all available leagues
            await updateLoadingState("Loading available leagues...")
            
            // 🔥 PHASE 2: Use injected credentials instead of .shared
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            totalLeagueCount = availableLeagues.count
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                return
            }
            
            // Step 2: Load matchups for each league for the specific week
            await loadMatchupsFromAllLeaguesForWeek(availableLeagues, week: week)
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load leagues: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Load matchups from all leagues for a specific week
    private func loadMatchupsFromAllLeaguesForWeek(_ leagues: [UnifiedLeagueManager.LeagueWrapper], week: Int) async {
        // Initialize loading states
        await MainActor.run {
            for league in leagues {
                loadingStates[league.id] = LeagueLoadingState(
                    name: league.league.name,
                    status: .pending,
                    progress: 0.0
                )
            }
        }
        
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: UnifiedMatchup?.self) { group in
            for league in leagues {
                group.addTask {
                    await self.loadSingleLeagueMatchupForWeek(league, week: week)
                }
            }
            
            var loadedMatchups: [UnifiedMatchup] = []
            
            for await matchup in group {
                if let matchup = matchup {
                    await MainActor.run {
                        loadedMatchups.append(matchup)
                        self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
                        
                        self.loadedLeagueCount += 1
                        self.loadingProgress = Double(self.loadedLeagueCount) / Double(self.totalLeagueCount)
                    }
                }
            }
        }
        
        // Finalize loading
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority
            self.myMatchups.sort { $0.priority > $1.priority }
        }
    }
    
    /// Load matchup for a single league for a specific week
    private func loadSingleLeagueMatchupForWeek(_ league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> UnifiedMatchup? {
        let leagueKey = "\(league.id)_\(week)_\(getCurrentYear())"
        
        // Race condition prevention
        loadingLock.lock()
        if currentlyLoadingLeagues.contains(leagueKey) {
            loadingLock.unlock()
            // x Print("⚠️ LOADING: Already loading league \(league.league.name) for week \(week), skipping duplicate request")
            return nil
        }
        currentlyLoadingLeagues.insert(leagueKey)
        loadingLock.unlock()
        
        defer { 
            loadingLock.lock()
            currentlyLoadingLeagues.remove(leagueKey)
            loadingLock.unlock()
        }
        
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.1)
        await updateLoadingState("Loading \(league.league.name) Week \(week)...")
        
        do {
            // Create isolated provider for this league with specific week
            let provider = LeagueMatchupProvider(
                league: league, 
                week: week, 
                year: getCurrentYear()
            )
            
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.2)
            
            // Step 1: Identify user's team ID
            guard let myTeamID = await provider.identifyMyTeamID() else {
                // x Print("❌ IDENTIFICATION FAILED: Could not find my team in league \(league.league.name)")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            // x Print("🎯 PROVIDER: Identified myTeamID = '\(myTeamID)' for \(league.league.name) Week \(week)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.4)
            
            // Step 2: Fetch matchups using isolated provider
            let matchups = try await provider.fetchMatchups()
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.7)
            
            // Step 3: Check for Chopped league
            if league.source == .sleeper && matchups.isEmpty {
                return await handleChoppedLeagueForWeek(league: league, myTeamID: myTeamID, week: week)
            }
            
            // Step 4: Handle regular leagues
            return await handleRegularLeagueForWeek(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider, week: week)
            
        } catch {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            // x Print("❌ LOADING: Failed to load league \(league.league.name) Week \(week): \(error)")
            return nil
        }
    }
    
    /// Handle chopped league for specific week
    private func handleChoppedLeagueForWeek(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> UnifiedMatchup? {
        // x Print("🔥 CHOPPED DETECTED: League \(league.league.name) has no matchups for week \(week) - processing as Chopped league")
        
        // Create chopped summary using proper Sleeper data for specific week
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: week) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped_\(week)",
                    league: league,
                    fantasyMatchup: nil,
                    choppedSummary: choppedSummary,
                    lastUpdated: Date(),
                    myTeamRanking: myTeamRanking,
                    myIdentifiedTeamID: myTeamID,
                    authenticatedUsername: sleeperCredentials.currentUsername
                )
                
                await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                // x Print("✅ Created Chopped league entry for \(league.league.name) Week \(week): \(myTeamRanking.team.ownerName) ranked \(myTeamRanking.rank)")
                return unifiedMatchup
            }
        }
        
        // x Print("❌ CHOPPED: Failed to create chopped summary for \(league.league.name) Week \(week)")
        await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
        return nil
    }
    
    /// Handle regular league for specific week
    private func handleRegularLeagueForWeek(league: UnifiedLeagueManager.LeagueWrapper, matchups: [FantasyMatchup], myTeamID: String, provider: LeagueMatchupProvider, week: Int) async -> UnifiedMatchup? {
        // x Print("🏈 REGULAR: Processing regular league: \(league.league.name) Week \(week)")
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
        
        if matchups.isEmpty {
            // x Print("⚠️ EMPTY MATCHUPS: No matchups found for \(league.league.name) week \(week)")
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
        
        // Step 5: Find user's matchup using provider
        if let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) {
            let unifiedMatchup = UnifiedMatchup(
                id: "\(league.id)_\(myMatchup.id)_\(week)",
                league: league,
                fantasyMatchup: myMatchup,
                choppedSummary: nil,
                lastUpdated: Date(),
                myTeamRanking: nil,
                myIdentifiedTeamID: myTeamID,
                authenticatedUsername: sleeperCredentials.currentUsername
            )
            
            await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
            // x Print("✅ Created regular matchup for \(league.league.name) Week \(week): \(myMatchup.homeTeam.ownerName) vs \(myMatchup.awayTeam.ownerName)")
            return unifiedMatchup
        } else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            // x Print("❌ REGULAR: No matchup found for team ID '\(myTeamID)' in \(league.league.name) Week \(week)")
            return nil
        }
    }
}