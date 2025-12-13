//
//  MatchupsHubViewModel+Loading.swift
//  BigWarRoom
//
//  Main loading logic for MatchupsHubViewModel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading Operations
extension MatchupsHubViewModel {
    
    /// Main loading function - Load all matchups across all connected leagues
    internal func performLoadAllMatchups() async {
        guard !isLoading else { 
            DebugPrint(mode: .matchupLoading, "performLoadAllMatchups called - ALREADY LOADING, ignoring")
            return 
        }
        
        DebugPrint(mode: .matchupLoading, "performLoadAllMatchups STARTING")
        
        let loadingSessionId = UUID().uuidString.prefix(8)
        DebugPrint(mode: .matchupLoading, "LOADING SESSION \(loadingSessionId): Starting new loading session")
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Discovering leagues..."
            loadingProgress = 0.0
            loadedLeagueCount = 0
        }
        
        do {
            // Step 0: Fetch NFL game data for live detection - 5% progress
            // print("  → Step 0: Fetching NFL game data...")
            await updateProgress(0.05, message: "Loading NFL data...", sessionId: String(loadingSessionId))
            await fetchNFLGameData()
            DebugPrint(mode: .matchupLoading, "Step 0: NFL data loaded")
            
            // Step 1: Load all available leagues - 10% progress
            // print("  → Step 1: Loading available leagues...")
            await updateProgress(0.10, message: "Loading available leagues...", sessionId: String(loadingSessionId))
            
            // 🔥 PHASE 2: Use injected credentials instead of .shared
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            totalLeagueCount = availableLeagues.count
            DebugPrint(mode: .matchupLoading, "Step 1: Found \(availableLeagues.count) leagues")
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                DebugPrint(mode: .matchupLoading, "No leagues found")
                return
            }
            
            // Step 2: Load matchups for each league in parallel
            // print("  → Step 2: Loading matchups from all leagues...")
            await loadMatchupsFromAllLeagues(availableLeagues, sessionId: String(loadingSessionId))
            DebugPrint(mode: .matchupLoading, "Step 2: Matchups loaded")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load leagues: \(error.localizedDescription)"
                isLoading = false
            }
            DebugPrint(mode: .matchupLoading, "Error: \(error)")
        }
        
        DebugPrint(mode: .matchupLoading, "LOADING SESSION \(loadingSessionId): Completed - myMatchups.count=\(myMatchups.count)")
        DebugPrint(mode: .matchupLoading, "performLoadAllMatchups COMPLETE")
    }
    
    /// 🔥 NEW: Bulletproof progress update that forces UI refresh
    private func updateProgress(_ progress: Double, message: String, sessionId: String) async {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        // print("🔥 SESSION \(sessionId): Setting progress to \(clampedProgress) (\(Int(clampedProgress * 100))%)")
        
        await MainActor.run {
            // Update all progress-related properties at once
            self.loadingProgress = clampedProgress
            self.currentLoadingLeague = message
            
            // print("🔥 SESSION \(sessionId): UI properties updated - progress=\(self.loadingProgress), message='\(self.currentLoadingLeague)'")
        }
    }
    
    /// Load matchups from all leagues with progressive updates
    internal func loadMatchupsFromAllLeagues(_ leagues: [UnifiedLeagueManager.LeagueWrapper], sessionId: String) async {
        // Initialize loading states - 15% progress
        await updateProgress(0.15, message: "Initializing leagues...", sessionId: sessionId)
        
        // print("🔥 SESSION \(sessionId): Starting to load \(leagues.count) leagues")
        
        await MainActor.run {
            for league in leagues {
                loadingStates[league.id] = LeagueLoadingState(
                    name: league.league.name,
                    status: .pending,
                    progress: 0.0
                )
                // print("🔥 SESSION \(sessionId): Initialized league: \(league.league.name)")
            }
        }
        
        // 🔥 PROGRESS RANGE: 20% -> 90% for league loading
        let totalLeagues = leagues.count
        var processedLeagues = 0
        
        // print("🔥 SESSION \(sessionId): About to start withTaskGroup for \(totalLeagues) leagues")
        
        // Load leagues in parallel for maximum speed
        await withTaskGroup(of: (UnifiedMatchup?, String).self) { group in
            // print("🔥 SESSION \(sessionId): Inside withTaskGroup, adding tasks...")
            
            for league in leagues {
                // print("🔥 SESSION \(sessionId): Adding task for league: \(league.league.name)")
                group.addTask {
                    // print("🔥 SESSION \(sessionId): Starting task for league: \(league.league.name)")
                    let matchup = await self.loadSingleLeagueMatchup(league)
                    // print("🔥 SESSION \(sessionId): Finished task for league: \(league.league.name), matchup: \(matchup != nil ? "SUCCESS" : "FAILED")")
                    return (matchup, league.id)
                }
            }
            
            var loadedMatchups: [UnifiedMatchup] = []
            
            // print("🔥 SESSION \(sessionId): About to iterate through task group results...")
            
            for await (matchup, leagueID) in group {
                processedLeagues += 1
                // print("🔥 SESSION \(sessionId): Processed league \(processedLeagues)/\(totalLeagues), matchup: \(matchup != nil ? "SUCCESS" : "FAILED")")
                
                if let matchup = matchup {
                    await MainActor.run {
                        loadedMatchups.append(matchup)
                        self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
                    }
                    // print("🔥 SESSION \(sessionId): Added matchup to collection, total: \(loadedMatchups.count)")
                }
                
                // 🔥 BULLETPROOF PROGRESS: Linear interpolation from 20% to 90%
                let progressPercent = 0.20 + (Double(processedLeagues) / Double(totalLeagues)) * 0.70
                // print("🔥 SESSION \(sessionId): Updating progress to \(progressPercent) (\(Int(progressPercent * 100))%)")
                await updateProgress(
                    progressPercent, 
                    message: "Loaded \(processedLeagues) of \(totalLeagues) leagues...",
                    sessionId: sessionId
                )
                
                await MainActor.run {
                    self.loadedLeagueCount = processedLeagues
                }
            }
            
            // print("🔥 SESSION \(sessionId): Finished processing all league tasks")
        }
        
        // print("🔥 SESSION \(sessionId): Exited withTaskGroup, proceeding to finalization...")
        
        // 🔥 FINAL STEPS: 90% -> 100% (no artificial delays!)
        await updateProgress(0.95, message: "Finalizing matchups...", sessionId: sessionId)
        await updateProgress(1.0, message: "Complete!", sessionId: sessionId)
        
        // Finalize loading
        // print("🔥 SESSION \(sessionId): Calling finalizeLoading()...")
        await finalizeLoading()
        
        // print("🔥 SESSION \(sessionId): Completely finished loading process")
    }
    
    /// Load matchup for a single league using isolated LeagueMatchupProvider
    internal func loadSingleLeagueMatchup(_ league: UnifiedLeagueManager.LeagueWrapper) async -> UnifiedMatchup? {
        let currentWeek = getCurrentWeek()
        let currentYear = getCurrentYear()
        let leagueKey = "\(league.id)_\(currentWeek)_\(currentYear)"
        
        // 🔥 FIXED: Use actor instead of NSLock
        guard await loadingGuard.shouldLoad(key: leagueKey) else {
            return nil
        }
        
        defer { 
            Task {
                await loadingGuard.completeLoad(key: leagueKey)
            }
        }
        
        // Update individual league progress
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.1)
        
        do {
            // print("🔥 SINGLE LEAGUE: Creating provider for \(league.league.name)")
            DebugPrint(mode: .leagueProvider, limit: 10, "loadSingleLeague called for \(league.league.name)")
            
            // 🔥 NEW APPROACH: Create isolated provider for this league
            let provider = LeagueMatchupProvider(
                league: league, 
                week: currentWeek,  // Use the actual week
                year: currentYear
            )
            
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.3)
            
            // print("🔥 SINGLE LEAGUE: Identifying team ID for \(league.league.name)")
            DebugPrint(mode: .leagueProvider, limit: 10, "Identifying team ID for \(league.league.name)...")
            
            // Step 1: Identify user's team ID
            guard let myTeamID = await provider.identifyMyTeamID() else {
                // print("🔥 SINGLE LEAGUE: Failed to identify team ID for \(league.league.name)")
                DebugPrint(mode: .leagueProvider, "Failed to identify team ID")
                await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
                return nil
            }
            
            // print("🔥 SINGLE LEAGUE: Found team ID '\(myTeamID)' for \(league.league.name)")
            DebugPrint(mode: .leagueProvider, "Found team ID: \(myTeamID)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.6)
            
            // Step 2: Fetch matchups using isolated provider
            // print("🔥 SINGLE LEAGUE: Fetching matchups for \(league.league.name)")
            DebugPrint(mode: .leagueProvider, "Fetching matchups via provider.fetchMatchups()...")
            let matchups = try await provider.fetchMatchups()
            DebugPrint(mode: .leagueProvider, "Returning \(matchups.count) matchups")
            // print("🔥 SINGLE LEAGUE: Fetched \(matchups.count) matchups for \(league.league.name)")
            await updateLeagueLoadingState(league.id, status: .loading, progress: 0.8)
            
            // 🔥 NEW: Cache the fully-loaded provider for later use
            await MainActor.run {
                // 🔥 DISABLED: Provider caching causes stale records to persist across weeks
                // self.cacheProvider(provider, for: league, week: currentWeek, year: currentYear)
                // Each time we load, we need FRESH providers with current week data
            }
            
            // Step 3: Check for Chopped league
            if league.source == .sleeper && matchups.isEmpty {
                // print("🔥 SINGLE LEAGUE: Detected Chopped league: \(league.league.name)")
                // print("  🍲 Detected Chopped league")
                return await handleChoppedLeague(league: league, myTeamID: myTeamID)
            }
            
            // Step 4: Handle regular leagues
            // print("🔥 SINGLE LEAGUE: Processing regular league: \(league.league.name)")
            // print("  → Processing regular league...")
            return await handleRegularLeague(league: league, matchups: matchups, myTeamID: myTeamID, provider: provider)
            
        } catch {
            DebugPrint(mode: .leagueProvider, "Error loading \(league.league.name): \(error)")
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
    }
    
    /// Handle regular league processing
    private func handleRegularLeague(
        league: UnifiedLeagueManager.LeagueWrapper, 
        matchups: [FantasyMatchup], 
        myTeamID: String, 
        provider: LeagueMatchupProvider
    ) async -> UnifiedMatchup? {
        await updateLeagueLoadingState(league.id, status: .loading, progress: 0.9)
        
        if matchups.isEmpty {
            // 🔥 NEW: Check if this is a playoff elimination scenario
            let currentWeek = getCurrentWeek()
            if isPlayoffWeek(league: league, week: currentWeek) {
                DebugPrint(mode: .matchupLoading, "🏆 EMPTY MATCHUPS + PLAYOFF WEEK: Treating as elimination for \(league.league.name)")
                return await handlePlayoffEliminationMatchup(league: league, myTeamID: myTeamID, week: currentWeek, provider: provider, allMatchups: matchups)
            }
            
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
        
        // Step 5: Find user's matchup using provider
        if let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) {
            let unifiedMatchup = UnifiedMatchup(
                id: "\(league.id)_\(myMatchup.id)",
                league: league,
                fantasyMatchup: myMatchup,
                choppedSummary: nil,
                lastUpdated: Date(),
                myTeamRanking: nil,
                myIdentifiedTeamID: myTeamID,
                authenticatedUsername: sleeperCredentials.currentUsername
            )
            
            await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
            return unifiedMatchup
        } else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
    }
    
    // MARK: - Playoff Elimination Handling
    
    /// Check if the current week is a playoff week
    private func isPlayoffWeek(league: UnifiedLeagueManager.LeagueWrapper, week: Int) -> Bool {
        DebugPrint(mode: .matchupLoading, "🔍 isPlayoffWeek called for \(league.league.name), week \(week)")
        
        // Get playoff start week from league settings
        let playoffStart: Int?
        
        if league.source == .sleeper {
            playoffStart = league.league.settings?.playoffWeekStart
            DebugPrint(mode: .matchupLoading, "   Sleeper playoff start: \(playoffStart ?? 0)")
        } else if league.source == .espn {
            // ESPN stores playoff info in league settings
            // For now, assume week 15+ is playoffs (standard ESPN)
            playoffStart = 15
            DebugPrint(mode: .matchupLoading, "   ESPN playoff start: 15 (default)")
        } else {
            playoffStart = nil
        }
        
        guard let playoffWeekStart = playoffStart else {
            DebugPrint(mode: .matchupLoading, "   ❌ No playoff start found")
            return false
        }
        
        let isPlayoffs = week >= playoffWeekStart
        DebugPrint(mode: .matchupLoading, "   Result: \(isPlayoffs ? "YES" : "NO") (week \(week) >= \(playoffWeekStart))")
        return isPlayoffs
    }
    
    /// Handle playoff elimination - create a special matchup showing the eliminated team
    private func handlePlayoffEliminationMatchup(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int,
        provider: LeagueMatchupProvider,
        allMatchups: [FantasyMatchup]
    ) async -> UnifiedMatchup? {
        
        DebugPrint(mode: .matchupLoading, "🏆 Creating eliminated playoff matchup for \(league.league.name)")
        
        // Try to build my team from the roster API
        let myTeam = await fetchEliminatedTeamRoster(
            league: league,
            myTeamID: myTeamID,
            week: week,
            provider: provider
        )
        
        guard let eliminatedTeam = myTeam else {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated team roster")
            return nil
        }
        
        DebugPrint(mode: .matchupLoading, "   ✅ Successfully fetched eliminated team roster: \(eliminatedTeam.name) with score \(eliminatedTeam.currentScore ?? 0.0)")
        
        // 🔥 NEW: Fetch ALL active playoff matchups in this league (not just yours)
        DebugPrint(mode: .matchupLoading, "   🔍 Fetching ALL active playoff matchups for \(league.league.name)...")
        let allActivePlayoffMatchups = await fetchAllActivePlayoffMatchups(league: league, week: week)
        DebugPrint(mode: .matchupLoading, "   ✅ Found \(allActivePlayoffMatchups.count) active playoff matchups")
        
        // Create a placeholder opponent team to indicate elimination
        let placeholderOpponent = FantasyTeam(
            id: "eliminated_placeholder",
            name: "Eliminated from Playoffs",
            ownerName: "Eliminated from Playoffs",
            record: nil,
            avatar: nil,
            currentScore: 0.0,
            projectedScore: 0.0,
            roster: [],
            rosterID: 0,
            faabTotal: nil,
            faabUsed: nil
        )
        
        // Create eliminated matchup
        let eliminatedMatchup = FantasyMatchup(
            id: "\(league.league.leagueID)_eliminated_\(week)_\(myTeamID)",
            leagueID: league.league.leagueID,
            week: week,
            year: getCurrentYear(),
            homeTeam: eliminatedTeam,
            awayTeam: placeholderOpponent,
            status: .complete,
            winProbability: 0.0,
            startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            sleeperMatchups: nil
        )
        
        // 🔥 NEW: Combine your eliminated matchup with all active playoff matchups
        var allMatchupsIncludingMine = [eliminatedMatchup] + allActivePlayoffMatchups
        
        let unifiedMatchup = UnifiedMatchup(
            id: "\(league.id)_eliminated_\(week)",
            league: league,
            fantasyMatchup: eliminatedMatchup,
            choppedSummary: nil,
            lastUpdated: Date(),
            myTeamRanking: nil,
            myIdentifiedTeamID: myTeamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: allMatchupsIncludingMine
        )
        
        await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
        DebugPrint(mode: .matchupLoading, "   ✅ Created eliminated playoff matchup for \(league.league.name) Week \(week) with \(allMatchupsIncludingMine.count) total matchups")
        return unifiedMatchup
    }
    
    // 🔥 NEW: Fetch all active playoff matchups in a league (excluding eliminated teams)
    private func fetchAllActivePlayoffMatchups(league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> [FantasyMatchup] {
        DebugPrint(mode: .matchupLoading, "   🔍 fetchAllActivePlayoffMatchups called for \(league.league.name)")
        
        do {
            if league.source == .espn {
                DebugPrint(mode: .matchupLoading, "   → Fetching ESPN playoff matchups...")
                return try await fetchAllActiveESPNPlayoffMatchups(league: league, week: week)
            } else if league.source == .sleeper {
                DebugPrint(mode: .matchupLoading, "   → Fetching Sleeper playoff matchups...")
                return try await fetchAllActiveSleeperPlayoffMatchups(league: league, week: week)
            }
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch active playoff matchups: \(error)")
        }
        
        DebugPrint(mode: .matchupLoading, "   ⚠️ No matchups fetched (unsupported platform?)")
        return []
    }
    
    // 🔥 NEW: Fetch all active ESPN playoff matchups
    private func fetchAllActiveESPNPlayoffMatchups(league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> [FantasyMatchup] {
        DebugPrint(mode: .matchupLoading, "   🌐 fetchAllActiveESPNPlayoffMatchups STARTED for \(league.league.name)")
        
        do {
            // 🔥 DYNAMIC: Get playoff start week from league settings (not hardcoded!)
            let playoffStartWeek = league.league.settings?.playoffWeekStart ?? 15  // Fallback to 15 if not set
            DebugPrint(mode: .matchupLoading, "   📅 League playoff start week: \(playoffStartWeek)")
            
            // 🔥 CRITICAL: ESPN stores playoff BRACKET in week (playoffStart-1), but SCORES in current week
            // Query week (playoffStart-1) to get matchup pairings, but use current week for scores
            let bracketWeek = week >= playoffStartWeek ? (playoffStartWeek - 1) : week
            DebugPrint(mode: .matchupLoading, "   📅 Querying week \(bracketWeek) for bracket structure (selected week: \(week), playoffs start: \(playoffStartWeek))")
            
            guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(getCurrentYear())/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(bracketWeek)") else {
                DebugPrint(mode: .matchupLoading, "   ❌ Failed to create URL")
                return []
            }
            
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let espnToken = getCurrentYear() == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
            request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
            
            DebugPrint(mode: .matchupLoading, "   📡 Fetching bracket data from ESPN API...")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded league - \(model.teams.count) teams, \(model.schedule.count) schedule items")
            
            // 🔥 FIXED: During playoffs, ONLY include matchups with playoff tier types
            let weekMatchups: [ESPNFantasyMatchupModel]
            
            if week >= playoffStartWeek {
                DebugPrint(mode: .matchupLoading, "   🏆 PLAYOFF WEEK DETECTED - Filtering by playoffTierType != 'NONE'")
                
                // ONLY include matchups with a non-NONE playoff tier type
                weekMatchups = model.schedule.filter { matchup in
                    guard let tierType = matchup.playoffTierType, !tierType.isEmpty, tierType != "NONE" else {
                        return false
                    }
                    DebugPrint(mode: .matchupLoading, "      ✅ Including playoff matchup: ID=\(matchup.id), tier=\(tierType), period=\(matchup.matchupPeriodId)")
                    return true
                }
                
                DebugPrint(mode: .matchupLoading, "   → Found \(weekMatchups.count) TRUE playoff bracket matchups (week \(week))")
            } else {
                // Regular season - exact week match
                weekMatchups = model.schedule.filter { $0.matchupPeriodId == week }
                DebugPrint(mode: .matchupLoading, "   → Found \(weekMatchups.count) regular season matchups for week \(week)")
            }
            
            // 🔥 DEBUG: Log all available matchupPeriodIds for debugging
            let allPeriodIds = Set(model.schedule.map { $0.matchupPeriodId })
            DebugPrint(mode: .matchupLoading, "   📊 Available matchupPeriodIds in schedule: \(allPeriodIds.sorted())")
            
            // 🔥 DEBUG: Log all playoff tier types
            let allPlayoffTiers = Set(model.schedule.compactMap { $0.playoffTierType })
            DebugPrint(mode: .matchupLoading, "   🏆 Available playoffTierTypes in schedule: \(allPlayoffTiers.sorted())")
            
            // 🔥 NEW: For playoffs, fetch CURRENT week scores separately
            var currentWeekScores: ESPNFantasyLeagueModel? = nil
            if week >= playoffStartWeek {
                DebugPrint(mode: .matchupLoading, "   📊 Fetching current week (\(week)) scores for playoff matchups...")
                guard let scoresURL = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(getCurrentYear())/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
                    DebugPrint(mode: .matchupLoading, "   ⚠️ Failed to create scores URL")
                    return []
                }
                
                var scoresRequest = URLRequest(url: scoresURL)
                scoresRequest.addValue("application/json", forHTTPHeaderField: "Accept")
                scoresRequest.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
                
                DebugPrint(mode: .matchupLoading, "   📡 Fetching current week scores...")
                
                let (scoresData, _) = try await URLSession.shared.data(for: scoresRequest)
                currentWeekScores = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: scoresData)
                DebugPrint(mode: .matchupLoading, "   ✅ Fetched current week scores")
            }
            
            var activeMatchups: [FantasyMatchup] = []
            
            for scheduleItem in weekMatchups {
                // Skip bye weeks (where away is nil)
                guard let awayTeamId = scheduleItem.away?.teamId else { 
                    DebugPrint(mode: .matchupLoading, "   ⏭️ Skipping bye week matchup")
                    continue 
                }
                
                // 🔥 CRITICAL: Use current week scores if in playoffs, otherwise use bracket week data
                let scoresModel = currentWeekScores ?? model
                
                // Find home and away teams from SCORES data
                guard let homeTeamData = scoresModel.teams.first(where: { $0.id == scheduleItem.home.teamId }),
                      let awayTeamData = scoresModel.teams.first(where: { $0.id == awayTeamId }) else {
                    DebugPrint(mode: .matchupLoading, "   ⚠️ Could not find team data for matchup \(scheduleItem.id)")
                    continue
                }
                
                DebugPrint(mode: .matchupLoading, "   ✅ Building matchup: \(homeTeamData.name ?? "Home") vs \(awayTeamData.name ?? "Away")")
                
                // Build FantasyTeam objects using CURRENT WEEK for scores
                let homeTeam = buildESPNFantasyTeam(from: homeTeamData, week: week)  // ← Use actual week!
                let awayTeam = buildESPNFantasyTeam(from: awayTeamData, week: week)  // ← Use actual week!
                
                let matchup = FantasyMatchup(
                    id: "\(scheduleItem.id)",
                    leagueID: league.league.leagueID,
                    week: week,  // Use actual selected week for display
                    year: getCurrentYear(),
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    status: .complete,
                    winProbability: nil,
                    startTime: nil,
                    sleeperMatchups: nil
                )
                
                activeMatchups.append(matchup)
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Fetched \(activeMatchups.count) active ESPN playoff matchups")
            return activeMatchups
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ ESPN playoff matchup fetch failed: \(error)")
            return []
        }
    }
    
    // 🔥 NEW: Helper to build FantasyTeam from ESPN data
    private func buildESPNFantasyTeam(from teamData: ESPNFantasyTeamModel, week: Int) -> FantasyTeam {
        let teamName = teamData.name ?? "Team \(teamData.id)"
        let score = teamData.activeRosterScore(for: week)
        
        var fantasyPlayers: [FantasyPlayer] = []
        if let roster = teamData.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player
                let isActive = entry.isActiveLineup
                
                let weeklyScore = player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 0
                }?.appliedTotal ?? 0.0
                
                let projectedScore = player.stats.first { stat in
                    stat.scoringPeriodId == week && stat.statSourceId == 1
                }?.appliedTotal ?? 0.0
                
                return FantasyPlayer(
                    id: String(player.id),
                    sleeperID: nil,
                    espnID: String(player.id),
                    firstName: player.fullName,
                    lastName: "",
                    position: entry.positionString,
                    team: player.nflTeamAbbreviation ?? "UNK",
                    jerseyNumber: nil,
                    currentPoints: weeklyScore,
                    projectedPoints: projectedScore,
                    gameStatus: (Mirror(reflecting: self).children.first { $0.label == "gameStatusService" }?.value as? GameStatusService)?.getGameStatusWithFallback(for: player.nflTeamAbbreviation ?? "UNK"),
                    isStarter: isActive,
                    lineupSlot: nil,
                    injuryStatus: nil  // ESPN doesn't provide injury status
                )
            }
        }
        
        return FantasyTeam(
            id: String(teamData.id),
            name: teamName,
            ownerName: teamName,
            record: TeamRecord(
                wins: teamData.record?.overall.wins ?? 0,
                losses: teamData.record?.overall.losses ?? 0,
                ties: teamData.record?.overall.ties ?? 0
            ),
            avatar: nil,
            currentScore: score,
            projectedScore: score * 1.05,
            roster: fantasyPlayers,
            rosterID: teamData.id,
            faabTotal: nil,
            faabUsed: nil
        )
    }
    
    // 🔥 NEW: Fetch all active Sleeper playoff matchups  
    private func fetchAllActiveSleeperPlayoffMatchups(league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> [FantasyMatchup] {
        DebugPrint(mode: .matchupLoading, "   🌐 fetchAllActiveSleeperPlayoffMatchups STARTED for \(league.league.name)")
        
        do {
            // Fetch matchups for this week
            guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)") else {
                DebugPrint(mode: .matchupLoading, "   ❌ Failed to create URL")
                return []
            }
            
            DebugPrint(mode: .matchupLoading, "   📡 Fetching matchup data from Sleeper API...")
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let matchupResponses = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded \(matchupResponses.count) matchup responses")
            
            // Fetch rosters to get team info
            let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters")!
            let (rosterData, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: rosterData)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded \(rosters.count) rosters")
            
            // Fetch users for display names
            let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users")!
            let (userData, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: userData)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded \(users.count) users")
            
            // Group matchups by matchupID (each matchupID represents a head-to-head matchup)
            var matchupGroups: [Int: [SleeperMatchupResponse]] = [:]
            for matchupResponse in matchupResponses {
                guard let matchupID = matchupResponse.matchupID else { continue }
                matchupGroups[matchupID, default: []].append(matchupResponse)
            }
            
            DebugPrint(mode: .matchupLoading, "   📊 Found \(matchupGroups.count) matchup groups")
            
            var activeMatchups: [FantasyMatchup] = []
            
            // Build FantasyMatchup for each group
            for (matchupID, matchupGroup) in matchupGroups {
                // Skip if not exactly 2 teams (should always be 2 in head-to-head)
                guard matchupGroup.count == 2 else {
                    DebugPrint(mode: .matchupLoading, "   ⚠️ Skipping matchup \(matchupID) - has \(matchupGroup.count) teams instead of 2")
                    continue
                }
                
                let team1Response = matchupGroup[0]
                let team2Response = matchupGroup[1]
                
                // Build FantasyTeam objects
                let team1 = await buildSleeperFantasyTeam(
                    from: team1Response,
                    rosters: rosters,
                    users: users,
                    week: week,
                    league: league
                )
                
                let team2 = await buildSleeperFantasyTeam(
                    from: team2Response,
                    rosters: rosters,
                    users: users,
                    week: week,
                    league: league
                )
                
                guard let homeTeam = team1, let awayTeam = team2 else {
                    DebugPrint(mode: .matchupLoading, "   ⚠️ Could not build teams for matchup \(matchupID)")
                    continue
                }
                
                DebugPrint(mode: .matchupLoading, "   ✅ Building matchup: \(homeTeam.name) vs \(awayTeam.name)")
                
                // Convert SleeperMatchupResponse to SleeperMatchup for compatibility
                let sleeperMatchup1 = SleeperMatchup(
                    roster_id: team1Response.rosterID,
                    points: team1Response.points,
                    projected_points: team1Response.projectedPoints,
                    matchup_id: team1Response.matchupID ?? 0,
                    starters: team1Response.starters,
                    players: team1Response.players
                )
                
                let sleeperMatchup2 = SleeperMatchup(
                    roster_id: team2Response.rosterID,
                    points: team2Response.points,
                    projected_points: team2Response.projectedPoints,
                    matchup_id: team2Response.matchupID ?? 0,
                    starters: team2Response.starters,
                    players: team2Response.players
                )
                
                // Create FantasyMatchup
                let matchup = FantasyMatchup(
                    id: "\(league.league.leagueID)_\(matchupID)_\(week)",
                    leagueID: league.league.leagueID,
                    week: week,
                    year: getCurrentYear(),
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    status: .complete,
                    winProbability: nil,
                    startTime: nil,
                    sleeperMatchups: (sleeperMatchup1, sleeperMatchup2)
                )
                
                activeMatchups.append(matchup)
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Fetched \(activeMatchups.count) active Sleeper playoff matchups")
            return activeMatchups
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Sleeper playoff matchup fetch failed: \(error)")
            return []
        }
    }
    
    // 🔥 NEW: Helper to build FantasyTeam from Sleeper matchup response
    private func buildSleeperFantasyTeam(
        from matchupResponse: SleeperMatchupResponse,
        rosters: [SleeperRoster],
        users: [SleeperLeagueUser],
        week: Int,
        league: UnifiedLeagueManager.LeagueWrapper
    ) async -> FantasyTeam? {
        
        // Find roster for this matchup response
        guard let roster = rosters.first(where: { $0.rosterID == matchupResponse.rosterID }) else {
            DebugPrint(mode: .matchupLoading, "   ⚠️ Could not find roster for rosterID \(matchupResponse.rosterID)")
            return nil
        }
        
        // Find user for this roster
        let user = users.first { $0.userID == roster.ownerID }
        let managerName = user?.displayName ?? "Team \(roster.rosterID)"
        
        // Build roster of FantasyPlayer objects
        let starters = matchupResponse.starters ?? []
        let allPlayers = matchupResponse.players ?? []
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        // Access private properties using Mirror reflection (like in fetchEliminatedSleeperTeam)
        let playerDirectoryService = (Mirror(reflecting: self).children.first { $0.label == "playerDirectory" }?.value as? PlayerDirectoryStore)
        let gameStatusServiceInstance = (Mirror(reflecting: self).children.first { $0.label == "gameStatusService" }?.value as? GameStatusService)
        
        for playerID in allPlayers {
            if let sleeperPlayer = playerDirectoryService?.player(for: playerID) {
                let isStarter = starters.contains(playerID)
                let playerTeam = sleeperPlayer.team ?? "UNK"
                let playerPosition = sleeperPlayer.position ?? "FLEX"
                
                // Get game status
                let gameStatus = gameStatusServiceInstance?.getGameStatusWithFallback(for: playerTeam)
                
                // Get player score (would need to be fetched separately or from cached provider)
                // For now, use 0.0 as placeholder - we could enhance this later
                let playerScore = 0.0
                
                let fantasyPlayer = FantasyPlayer(
                    id: playerID,
                    sleeperID: playerID,
                    espnID: sleeperPlayer.espnID,
                    firstName: sleeperPlayer.firstName,
                    lastName: sleeperPlayer.lastName,
                    position: playerPosition,
                    team: playerTeam,
                    jerseyNumber: sleeperPlayer.number?.description,
                    currentPoints: playerScore,
                    projectedPoints: playerScore * 1.1,
                    gameStatus: gameStatus,
                    isStarter: isStarter,
                    lineupSlot: isStarter ? playerPosition : nil,
                    injuryStatus: sleeperPlayer.injuryStatus
                )
                fantasyPlayers.append(fantasyPlayer)
            }
        }
        
        // Get team record
        let record = TeamRecord(
            wins: roster.wins ?? 0,
            losses: roster.losses ?? 0,
            ties: roster.ties ?? 0
        )
        
        // Get avatar URL
        let avatarURL = user?.avatar != nil ? "https://sleepercdn.com/avatars/\(user!.avatar!)" : nil
        
        let team = FantasyTeam(
            id: String(roster.rosterID),
            name: managerName,
            ownerName: managerName,
            record: record,
            avatar: avatarURL,
            currentScore: matchupResponse.points ?? 0.0,
            projectedScore: matchupResponse.projectedPoints ?? 0.0,
            roster: fantasyPlayers,
            rosterID: roster.rosterID,
            faabTotal: league.league.settings?.waiverBudget,
            faabUsed: roster.waiversBudgetUsed
        )
        
        DebugPrint(mode: .matchupLoading, "   ✅ Built Sleeper team: \(managerName) with \(fantasyPlayers.count) players, score: \(matchupResponse.points ?? 0.0)")
        return team
    }
    
    /// Fetch roster data for an eliminated team
    private func fetchEliminatedTeamRoster(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int,
        provider: LeagueMatchupProvider
    ) async -> FantasyTeam? {
        
        if league.source == .sleeper {
            return await fetchEliminatedSleeperTeam(league: league, myTeamID: myTeamID, week: week, provider: provider)
        } else if league.source == .espn {
            return await fetchEliminatedESPNTeam(league: league, myTeamID: myTeamID, week: week)
        }
        
        return nil
    }
    
    /// Fetch Sleeper team roster for eliminated team
    private func fetchEliminatedSleeperTeam(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int,
        provider: LeagueMatchupProvider
    ) async -> FantasyTeam? {
        
        do {
            // Fetch roster data
            let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters")!
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            // Find my roster - try both String and Int matching
            let myRoster = rosters.first { roster in
                String(roster.rosterID) == myTeamID || roster.ownerID == myTeamID
            }
            
            guard let myRoster = myRoster else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find roster for team ID: \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found roster ID: \(myRoster.rosterID)")
            
            // Fetch matchup response for this week to get starters and scores
            let matchupsURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)")!
            let (matchupData, _) = try await URLSession.shared.data(from: matchupsURL)
            let matchupResponses = try JSONDecoder().decode([SleeperMatchupResponse].self, from: matchupData)
            
            // Find my matchup response (has starters and points)
            guard let myMatchupResponse = matchupResponses.first(where: { $0.rosterID == myRoster.rosterID }) else {
                DebugPrint(mode: .matchupLoading, "   ⚠️ No matchup response found, creating with empty roster")
                // Return basic team with no players (eliminated scenario)
                let record = TeamRecord(
                    wins: myRoster.wins ?? 0,
                    losses: myRoster.losses ?? 0,
                    ties: myRoster.ties ?? 0
                )
                
                return FantasyTeam(
                    id: myTeamID,
                    name: "Team \(myRoster.rosterID)",
                    ownerName: "Team \(myRoster.rosterID)",
                    record: record,
                    avatar: nil,
                    currentScore: 0.0,
                    projectedScore: 0.0,
                    roster: [],
                    rosterID: myRoster.rosterID,
                    faabTotal: league.league.settings?.waiverBudget,
                    faabUsed: myRoster.waiversBudgetUsed
                )
            }
            
            // Fetch user info for display name
            let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users")!
            let (userData, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: userData)
            
            let myUser = users.first { $0.userID == myRoster.ownerID }
            let managerName = myUser?.displayName ?? "Team \(myRoster.rosterID)"
            
            // Build roster of FantasyPlayer objects
            let starters = myMatchupResponse.starters ?? []
            let allPlayers = myMatchupResponse.players ?? []
            
            var fantasyPlayers: [FantasyPlayer] = []
            
            // Access private properties using Mirror reflection (like in fetchEliminatedSleeperTeam)
            let playerDirectoryService = (Mirror(reflecting: self).children.first { $0.label == "playerDirectory" }?.value as? PlayerDirectoryStore)
            let gameStatusServiceInstance = (Mirror(reflecting: self).children.first { $0.label == "gameStatusService" }?.value as? GameStatusService)
            
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryService?.player(for: playerID) {
                    let isStarter = starters.contains(playerID)
                    let playerTeam = sleeperPlayer.team ?? "UNK"
                    let playerPosition = sleeperPlayer.position ?? "FLEX"
                    
                    // Get game status
                    let gameStatus = gameStatusServiceInstance?.getGameStatusWithFallback(for: playerTeam)
                    
                    // Get player score (would need to be fetched separately or from cached provider)
                    // For now, use 0.0 as placeholder - we could enhance this later
                    let playerScore = 0.0
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: playerPosition,
                        team: playerTeam,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerScore * 1.1,
                        gameStatus: gameStatus,
                        isStarter: isStarter,
                        lineupSlot: isStarter ? playerPosition : nil,
                        injuryStatus: sleeperPlayer.injuryStatus
                    )
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
            
            // Get team record
            let record = TeamRecord(
                wins: myRoster.wins ?? 0,
                losses: myRoster.losses ?? 0,
                ties: myRoster.ties ?? 0
            )
            
            // Get avatar URL
            let avatarURL = myUser?.avatar != nil ? "https://sleepercdn.com/avatars/\(myUser!.avatar!)" : nil
            
            let team = FantasyTeam(
                id: myTeamID,
                name: managerName,
                ownerName: managerName,
                record: record,
                avatar: avatarURL,
                currentScore: myMatchupResponse.points ?? 0.0,
                projectedScore: myMatchupResponse.projectedPoints ?? 0.0,
                roster: fantasyPlayers,
                rosterID: myRoster.rosterID,
                faabTotal: league.league.settings?.waiverBudget,
                faabUsed: myRoster.waiversBudgetUsed
            )
            
            DebugPrint(mode: .matchupLoading, "   ✅ Built Sleeper eliminated team: \(managerName) with \(fantasyPlayers.count) players, score: \(myMatchupResponse.points ?? 0.0)")
            return team
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated Sleeper team: \(error)")
            return nil
        }
    }
    
    /// Fetch ESPN team roster for eliminated team
    private func fetchEliminatedESPNTeam(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        DebugPrint(mode: .matchupLoading, "   🔍 Fetching eliminated ESPN team for league \(league.league.name), team ID \(myTeamID), week \(week)")
        
        do {
            // Fetch full league data for this week
            guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(getCurrentYear())/segments/0/leagues/\(league.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   🌐 Fetching from ESPN API...")
            
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let espnToken = getCurrentYear() == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
            request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
            
            DebugPrint(mode: .matchupLoading, "   🔐 Using credentials for year \(getCurrentYear())")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            DebugPrint(mode: .matchupLoading, "   ✅ Decoded ESPN league data, found \(model.teams.count) teams")
            
            // Find my team
            guard let myTeam = model.teams.first(where: { String($0.id) == myTeamID }) else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find team with ID \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found team: \(myTeam.name ?? "Unknown")")
            
            // Calculate my score
            let myScore = myTeam.activeRosterScore(for: week)
            
            // Get team name
            let teamName = myTeam.name ?? "Team \(myTeam.id)"
            
            // Build roster
            var fantasyPlayers: [FantasyPlayer] = []
            
            if let roster = myTeam.roster {
                fantasyPlayers = roster.entries.map { entry in
                    let player = entry.playerPoolEntry.player
                    let isActive = true  // treat as active for now

                    let weeklyScore = player.stats.first { stat in
                        stat.scoringPeriodId == week && stat.statSourceId == 0
                    }?.appliedTotal ?? 0.0

                    let projectedScore = player.stats.first { stat in
                        stat.scoringPeriodId == week && stat.statSourceId == 1
                    }?.appliedTotal ?? 0.0

                    return FantasyPlayer(
                        id: String(player.id),
                        sleeperID: nil,
                        espnID: String(player.id),
                        firstName: player.fullName,
                        lastName: "",
                        position: entry.positionString,
                        team: player.nflTeamAbbreviation ?? "UNK",
                        jerseyNumber: nil,
                        currentPoints: weeklyScore,
                        projectedPoints: projectedScore,
                        gameStatus: (Mirror(reflecting: self).children.first { $0.label == "gameStatusService" }?.value as? GameStatusService)?.getGameStatusWithFallback(for: player.nflTeamAbbreviation ?? "UNK"),
                        isStarter: isActive,
                        lineupSlot: nil,
                        injuryStatus: nil
                    )
                }
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Built ESPN eliminated team: \(teamName) with \(fantasyPlayers.count) players")
            
            return FantasyTeam(
                id: myTeamID,
                name: teamName,
                ownerName: teamName,
                record: TeamRecord(
                    wins: myTeam.record?.overall.wins ?? 0,
                    losses: myTeam.record?.overall.losses ?? 0,
                    ties: myTeam.record?.overall.ties ?? 0
                ),
                avatar: nil,
                currentScore: myScore,
                projectedScore: myScore * 1.05,
                roster: fantasyPlayers,
                rosterID: myTeam.id,
                faabTotal: nil,
                faabUsed: nil
            )
            
        } catch {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated ESPN team: \(error)")
            return nil
        }
    }
    
    /// Finalize the loading process
    private func finalizeLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority (live games first, then by league importance)
            self.myMatchups.sort { $0.priority > $1.priority }
        }
        
        // 💊 RX: Check optimization status for all matchups after loading
        await refreshAllOptimizationStatuses()
    }
    
    // MARK: - Loading State Management
    
    /// Update loading state message
    internal func updateLoadingState(_ message: String) async {
        await MainActor.run {
            currentLoadingLeague = message
        }
    }
    
    /// Update individual league loading state
    internal func updateLeagueLoadingState(_ leagueID: String, status: LoadingStatus, progress: Double) async {
        await MainActor.run {
            loadingStates[leagueID]?.status = status
            loadingStates[leagueID]?.progress = progress
        }
    }
    
    /// Fetch NFL game data for live detection
    private func fetchNFLGameData() async {
        // 🔥 CRITICAL FIX: Use WeekSelectionManager.selectedWeek (user's chosen week) instead of currentWeek
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = Calendar.current.component(.year, from: Date())
        
        DebugPrint(mode: .weekCheck, "📅 MatchupsHub: Fetching NFL game data for user-selected week \(selectedWeek)")
        
        NFLGameDataService.shared.fetchGameData(forWeek: selectedWeek, year: currentYear)
    }
}