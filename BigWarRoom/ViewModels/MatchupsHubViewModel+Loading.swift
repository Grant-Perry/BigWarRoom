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
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups STARTING")
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Loading from data store..."
            loadingProgress = 0.0
        }
        
        do {
            // Step 1: Fetch available leagues - 10% progress
            await updateProgress(0.10, message: "Loading available leagues...", sessionId: "STORE")
            
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                return
            }
            
            // Step 2: Convert to LeagueDescriptor and warm the store - 30% progress
            await updateProgress(0.30, message: "Warming data store...", sessionId: "STORE")
            
            let leagueDescriptors = availableLeagues.map { league in
                LeagueDescriptor(
                    id: league.id,
                    name: league.league.name,
                    platform: league.source,
                    avatarURL: nil
                )
            }
            
            let currentWeek = getCurrentWeek()
            await matchupDataStore.warmLeagues(leagueDescriptors, week: currentWeek)
            
            // Step 3: Hydrate each matchup lazily - 40% -> 90% progress
            await updateProgress(0.40, message: "Loading matchups...", sessionId: "STORE")
            
            var loadedMatchups: [UnifiedMatchup] = []
            let totalLeagues = availableLeagues.count
            var processedLeagues = 0
            
            for league in availableLeagues {
                // Calculate base progress for this league
                let baseProgress = 0.40 + (Double(processedLeagues) / Double(totalLeagues)) * 0.45
                
                // Show we're starting this league (no sub-progress, just clear milestone)
                await updateProgress(baseProgress, message: "Loading \(league.league.name)...", sessionId: "STORE")
                
                // Create snapshot ID
                let snapshotID = MatchupSnapshot.ID(
                    leagueID: league.id,
                    matchupID: "\(league.id)_\(currentWeek)",
                    platform: league.source,
                    week: currentWeek
                )
                
                // Hydrate matchup directly (no timeout)
                do {
                    let snapshot = try await self.matchupDataStore.hydrateMatchup(snapshotID)
                    
                    // 🔥 SINGLE CONVERSION POINT: Snapshot → UnifiedMatchup
                    let unifiedMatchup = convertSnapshotToUnifiedMatchup(snapshot, league: league)
                    loadedMatchups.append(unifiedMatchup)
                    
                } catch {
                    DebugPrint(mode: .matchupLoading, "❌ Failed to hydrate \(league.league.name): \(error) - trying elimination fallback")
                    
                    // Try playoff elimination fallback
                    if let eliminatedMatchup = await tryEliminatedMatchupFallback(league: league, week: currentWeek) {
                        loadedMatchups.append(eliminatedMatchup)
                        DebugPrint(mode: .matchupLoading, "✅ Created eliminated matchup for \(league.league.name)")
                    } else {
                        DebugPrint(mode: .matchupLoading, "❌ No eliminated fallback available for \(league.league.name)")
                    }
                }
                
                // 🔥 CRITICAL: Always increment, even if hydration failed
                processedLeagues += 1
                let progress = 0.40 + (Double(processedLeagues) / Double(totalLeagues)) * 0.45
                await updateProgress(progress, message: "Loaded \(processedLeagues) of \(totalLeagues) leagues", sessionId: "STORE")
            }
            
            // Update UI with loaded matchups
            await MainActor.run {
                self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
            }
            
            // 🔥 NEW: Explicit progress milestones to ensure smooth completion
            await updateProgress(0.90, message: "Finalizing data...", sessionId: "STORE")
            try? await Task.sleep(for: .milliseconds(100)) // Brief pause for UI
            
            await updateProgress(0.95, message: "Almost ready...", sessionId: "STORE")
            try? await Task.sleep(for: .milliseconds(100))
            
            // Finalize - 100% progress
            await updateProgress(1.0, message: "Complete!", sessionId: "STORE")
            await finalizeLoading()
            
        }
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups COMPLETE - \(myMatchups.count) matchups")
    }
    
    /// 🔥 NEW: Bulletproof progress update that forces UI refresh
    private func updateProgress(_ progress: Double, message: String, sessionId: String) async {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        await MainActor.run {
            self.loadingProgress = clampedProgress
            self.currentLoadingLeague = message
        }
    }
    
    /// Finalize the loading process
    private func finalizeLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority
            self.myMatchups.sort { $0.priority > $1.priority }
        }
        
        // 💊 RX: Check optimization status for all matchups after loading
        await refreshAllOptimizationStatuses()
    }
    
    /// Fetch NFL game data for live detection
    private func fetchNFLGameData() async {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = Calendar.current.component(.year, from: Date())
        
        DebugPrint(mode: .weekCheck, "📅 MatchupsHub: Fetching NFL game data for user-selected week \(selectedWeek)")
        
        gameDataService.fetchGameData(forWeek: selectedWeek, year: currentYear)
    }
    
    // MARK: - 🔥 SINGLE SOURCE OF TRUTH: Snapshot → UnifiedMatchup Conversion
    
    /// Convert MatchupSnapshot to UnifiedMatchup (SINGLE conversion point for SSOT)
    /// This is the ONLY place where we convert from domain model (snapshot) to view model (UnifiedMatchup)
    internal func convertSnapshotToUnifiedMatchup(_ snapshot: MatchupSnapshot, league: UnifiedLeagueManager.LeagueWrapper) -> UnifiedMatchup {
        // Build FantasyMatchup from snapshot
        let fantasyMatchup = FantasyMatchup(
            id: snapshot.id.matchupID,
            leagueID: snapshot.id.leagueID,
            week: snapshot.id.week,
            year: getCurrentYear(),
            homeTeam: convertTeamSnapshot(snapshot.myTeam),
            awayTeam: convertTeamSnapshot(snapshot.opponentTeam),
            status: parseMatchupStatus(snapshot.metadata.status),
            winProbability: snapshot.myTeam.score.winProbability,
            startTime: snapshot.metadata.startTime,
            sleeperMatchups: nil
        )
        
        return UnifiedMatchup(
            id: snapshot.id.matchupID,
            league: league,
            fantasyMatchup: fantasyMatchup,
            choppedSummary: nil,  // TODO: Handle chopped leagues
            lastUpdated: snapshot.lastUpdated,
            myTeamRanking: nil,  // TODO: Handle chopped ranking
            myIdentifiedTeamID: snapshot.myTeam.info.teamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: nil,  // TODO: Handle horizontal scrolling
            gameDataService: gameDataService
        )
    }
    
    /// Convert TeamSnapshot to FantasyTeam
    private func convertTeamSnapshot(_ snapshot: TeamSnapshot) -> FantasyTeam {
        let roster = snapshot.roster.map { player in
            // Convert game status string back to GameStatus struct (if present)
            let gameStatus: GameStatus? = player.metrics.gameStatus.map { statusString in
                GameStatus(status: statusString)
            }
            
            return FantasyPlayer(
                id: player.id,
                sleeperID: player.identity.sleeperID,
                espnID: player.identity.espnID,
                firstName: player.identity.firstName,
                lastName: player.identity.lastName,
                position: player.context.position,
                team: player.context.team,
                jerseyNumber: player.context.jerseyNumber,
                currentPoints: player.metrics.currentScore,
                projectedPoints: player.metrics.projectedScore,
                gameStatus: gameStatus,
                isStarter: player.context.isStarter,
                lineupSlot: player.context.lineupSlot,
                injuryStatus: player.context.injuryStatus
            )
        }
        
        return FantasyTeam(
            id: snapshot.info.teamID,
            name: snapshot.info.ownerName,
            ownerName: snapshot.info.ownerName,
            record: parseRecord(snapshot.info.record),
            avatar: snapshot.info.avatarURL,
            currentScore: snapshot.score.actual,
            projectedScore: snapshot.score.projected,
            roster: roster,
            rosterID: Int(snapshot.info.teamID) ?? 0,
            faabTotal: nil,
            faabUsed: nil
        )
    }
    
    /// Parse record string into TeamRecord
    private func parseRecord(_ recordString: String) -> TeamRecord? {
        guard !recordString.isEmpty else { return nil }
        let parts = recordString.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        let wins = Int(parts[0]) ?? 0
        let losses = Int(parts[1]) ?? 0
        let ties = parts.count > 2 ? Int(parts[2]) : nil
        return TeamRecord(wins: wins, losses: losses, ties: ties)
    }
    
    /// Parse matchup status string to enum
    private func parseMatchupStatus(_ statusString: String) -> MatchupStatus {
        switch statusString.lowercased() {
        case "live", "in_progress":
            return .live
        case "completed", "final":
            return .complete
        default:
            return .upcoming
        }
    }
    
    // MARK: - Playoff Elimination Handling
    
    /// Robust Chopped/Guillotine league detection for Sleeper
    private func isSleeperChoppedLeagueResolved(_ league: UnifiedLeagueManager.LeagueWrapper) async -> Bool {
        guard league.source == .sleeper else { return false }

        if let settings = league.league.settings {
            if settings.type == 3 || settings.isChopped == true { return true }

            if settings.type != nil || settings.isChopped != nil {
                return false
            }
        }

        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)") else {
            return false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fullLeague = try JSONDecoder().decode(SleeperLeague.self, from: data)
            let settings = fullLeague.settings
            return settings?.type == 3 || settings?.isChopped == true || (settings?.isChoppedLeague == true)
        } catch {
            return false
        }
    }
    
    /// Handle playoff elimination - create a special matchup showing the eliminated team
    private func handlePlayoffEliminationMatchup(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> UnifiedMatchup? {
        
        DebugPrint(mode: .matchupLoading, "🏆 Creating eliminated playoff matchup for \(league.league.name)")
        
        let myTeam = await fetchEliminatedTeamRoster(
            league: league,
            myTeamID: myTeamID,
            week: week
        )
        
        guard let eliminatedTeam = myTeam else {
            DebugPrint(mode: .matchupLoading, "   ❌ Failed to fetch eliminated team roster")
            return nil
        }
        
        DebugPrint(mode: .matchupLoading, "   ✅ Successfully fetched eliminated team roster: \(eliminatedTeam.name) with score \(eliminatedTeam.currentScore ?? 0.0)")
        
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
        
        let unifiedMatchup = UnifiedMatchup(
            id: "\(league.id)_eliminated_\(week)",
            league: league,
            fantasyMatchup: eliminatedMatchup,
            choppedSummary: nil,
            lastUpdated: Date(),
            myTeamRanking: nil,
            myIdentifiedTeamID: myTeamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: [eliminatedMatchup],
            gameDataService: gameDataService
        )
        
        DebugPrint(mode: .matchupLoading, "   ✅ Created eliminated playoff matchup for \(league.league.name) Week \(week)")
        return unifiedMatchup
    }
    
    /// Fetch roster data for an eliminated team
    private func fetchEliminatedTeamRoster(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        if league.source == .sleeper {
            return await fetchEliminatedSleeperTeam(league: league, myTeamID: myTeamID, week: week)
        } else if league.source == .espn {
            return await fetchEliminatedESPNTeam(league: league, myTeamID: myTeamID, week: week)
        }
        
        return nil
    }
    
    /// Fetch Sleeper team roster for eliminated team
    private func fetchEliminatedSleeperTeam(
        league: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async -> FantasyTeam? {
        
        do {
            let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/rosters")!
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            let myRoster = rosters.first { roster in
                String(roster.rosterID) == myTeamID || roster.ownerID == myTeamID
            }
            
            guard let myRoster = myRoster else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find roster for team ID: \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found roster ID: \(myRoster.rosterID)")
            
            let matchupsURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/matchups/\(week)")!
            let (matchupData, _) = try await URLSession.shared.data(from: matchupsURL)
            let matchupResponses = try JSONDecoder().decode([SleeperMatchupResponse].self, from: matchupData)
            
            guard let myMatchupResponse = matchupResponses.first(where: { $0.rosterID == myRoster.rosterID }) else {
                DebugPrint(mode: .matchupLoading, "   ⚠️ No matchup response found, creating with empty roster")
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
            
            let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(league.league.leagueID)/users")!
            let (userData, _) = try await URLSession.shared.data(from: usersURL)
            let users = try JSONDecoder().decode([SleeperLeagueUser].self, from: userData)
            
            let myUser = users.first { $0.userID == myRoster.ownerID }
            let managerName = myUser?.displayName ?? "Team \(myRoster.rosterID)"
            
            let starters = myMatchupResponse.starters ?? []
            let allPlayers = myMatchupResponse.players ?? []
            
            var fantasyPlayers: [FantasyPlayer] = []
            
            for playerID in allPlayers {
                if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID) {
                    let isStarter = starters.contains(playerID)
                    let playerTeam = sleeperPlayer.team ?? "UNK"
                    let playerPosition = sleeperPlayer.position ?? "FLEX"
                    
                    // 🔥 FIX: Use GameStatusService.shared
                    let gameStatus = GameStatusService.shared.getGameStatusWithFallback(for: playerTeam)
                    
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
            
            let record = TeamRecord(
                wins: myRoster.wins ?? 0,
                losses: myRoster.losses ?? 0,
                ties: myRoster.ties ?? 0
            )
            
            let avatarURL = myUser?.avatar != nil ? "https://sleepercdn.com/avatars/\(myUser!.avatar!)" : nil
            
            let team = FantasyTeam(
                id: myTeamID,
                name: managerName,
                ownerName: managerName,
                record: record,
                avatar: avatarURL,
                currentScore: myMatchupResponse.points ?? 0.0,
                projectedScore: (myMatchupResponse.points ?? 0.0) * 1.05,
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
            
            guard let myTeam = model.teams.first(where: { String($0.id) == myTeamID }) else {
                DebugPrint(mode: .matchupLoading, "   ❌ Could not find team with ID \(myTeamID)")
                return nil
            }
            
            DebugPrint(mode: .matchupLoading, "   ✅ Found team: \(myTeam.name ?? "Unknown")")
            
            let myScore = myTeam.activeRosterScore(for: week)
            let teamName = myTeam.name ?? "Team \(myTeam.id)"
            
            var fantasyPlayers: [FantasyPlayer] = []
            
            if let roster = myTeam.roster {
                fantasyPlayers = roster.entries.map { entry in
                    let player = entry.playerPoolEntry.player
                    let isActive = true

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
                        // 🔥 FIX: Use GameStatusService.shared
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: player.nflTeamAbbreviation ?? "UNK"),
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
    
    // MARK: - Update League Loading State Helper
    
    /// Update individual league loading state (stub for store-based approach)
    internal func updateLeagueLoadingState(_ leagueID: String, status: LoadingStatus, progress: Double) async {
        await MainActor.run {
            loadingStates[leagueID]?.status = status
            loadingStates[leagueID]?.progress = progress
        }
    }
    
    // MARK: - Eliminated Matchup Fallback
    
    /// Try to create an eliminated matchup when store hydration fails
    private func tryEliminatedMatchupFallback(league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> UnifiedMatchup? {
        // Step 1: Check if this is a chopped league
        if await isSleeperChoppedLeagueResolved(league) {
            DebugPrint(mode: .matchupLoading, "🪓 Detected chopped league: \(league.league.name)")
            
            // Try to get my team ID
            guard let myTeamID = await getMyTeamID(for: league) else {
                DebugPrint(mode: .matchupLoading, "❌ Could not identify team ID for chopped league")
                return nil
            }
            
            // Call chopped league handler
            return await handleChoppedLeague(league: league, myTeamID: myTeamID)
        }
        
        // Step 2: Check if this is a playoff elimination scenario using service
        if playoffEliminationService.isPlayoffWeek(league: league, week: week) {
            DebugPrint(mode: .matchupLoading, "🏆 Detected playoff week: \(league.league.name)")
            
            // Try to get my team ID
            guard let myTeamID = await getMyTeamID(for: league) else {
                DebugPrint(mode: .matchupLoading, "❌ Could not identify team ID for playoff league")
                return nil
            }
            
            // Check if I'm eliminated from playoffs using service
            if await playoffEliminationService.shouldHideEliminatedPlayoffLeague(league: league, week: week, myTeamID: myTeamID) {
                // User has PE toggle OFF - don't show this league
                DebugPrint(mode: .matchupLoading, "❌ Playoff eliminated and toggle OFF - hiding league")
                return nil
            }
            
            // Check if I'm in winners bracket using service
            let isInWinnersBracket: Bool
            switch league.source {
            case .espn:
                isInWinnersBracket = await playoffEliminationService.isESPNTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
            case .sleeper:
                isInWinnersBracket = await playoffEliminationService.isSleeperTeamInWinnersBracket(league: league, week: week, myTeamID: myTeamID)
            }
            
            if !isInWinnersBracket && UserDefaults.standard.showEliminatedPlayoffLeagues {
                DebugPrint(mode: .matchupLoading, "✅ Playoff eliminated but toggle ON - creating eliminated matchup")
                return await handlePlayoffEliminationMatchup(league: league, myTeamID: myTeamID, week: week)
            }
        }
        
        return nil
    }
    
    /// Get my team ID for a league (helper for eliminated fallback)
    private func getMyTeamID(for league: UnifiedLeagueManager.LeagueWrapper) async -> String? {
        if league.source == .sleeper {
            guard let username = sleeperCredentials.getUserIdentifier() else {
                return nil
            }
            
            let resolvedUserID: String
            do {
                if username.allSatisfy({ $0.isNumber }) {
                    resolvedUserID = username
                } else {
                    let user = try await SleeperAPIClient.shared.fetchUser(username: username)
                    resolvedUserID = user.userID
                }
            } catch {
                return nil
            }
            
            do {
                let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: league.league.leagueID)
                if let userRoster = rosters.first(where: { $0.ownerID == resolvedUserID }) {
                    return String(userRoster.rosterID)
                }
            } catch {
                return nil
            }
            
            return nil
        } else if league.source == .espn {
            let myESPNID = AppConstants.GpESPNID
            
            do {
                let espnLeague = try await ESPNAPIClient.shared.fetchESPNLeagueData(leagueID: league.league.leagueID)
                
                if let teams = espnLeague.teams {
                    for team in teams {
                        if let owners = team.owners {
                            if owners.contains(myESPNID) {
                                return String(team.id)
                            }
                        }
                    }
                }
            } catch {
                return nil
            }
            
            return nil
        }
        
        return nil
    }
}