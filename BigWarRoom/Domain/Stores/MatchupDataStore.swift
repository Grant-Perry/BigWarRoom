//
//  MatchupDataStore.swift
//  BigWarRoom
//
//  🔥 SINGLE SOURCE OF TRUTH: All matchup + roster data flows through here
//  
//  Design Goals:
//  - Lazy hydration: load only what's needed, when it's needed
//  - Real-time friendly: support delta updates without blocking UI
//  - Observable: emit async snapshots so SwiftUI reacts automatically
//  - DRY: eliminate duplicate fetch pipelines across Mission Control, Live Players, Detail views
//

import Foundation
import Observation

/// Single source of truth for all matchup and roster data
/// 🔥 NO SINGLETON - Pure dependency injection with @Observable
@MainActor
@Observable
final class MatchupDataStore {
    
    // MARK: - Dependencies
    
    private let unifiedLeagueManager: UnifiedLeagueManager
    private let sharedStatsService: SharedStatsService
    private let gameStatusService: GameStatusService
    private let weekSelectionManager: WeekSelectionManager
    
    // MARK: - Observable State
    
    /// Cache of league data, keyed by LeagueKey
    private(set) var leagueCaches: [LeagueKey: LeagueCache] = [:]
    
    /// Streams for observing league updates
    private var leagueStreams: [LeagueKey: AsyncStream<LeagueSnapshot>.Continuation] = [:]
    
    /// Last refresh timestamp (observable for UI updates)
    private(set) var lastRefreshTime = Date()
    
    /// 🔥 NEW: Track previous snapshots for delta detection
    private var previousSnapshots: [MatchupSnapshot.ID: MatchupSnapshot] = [:]
    
    /// 🔥 NEW: Track changed player IDs since last refresh
    private(set) var changedPlayerIDs: Set<String> = []
    
    // MARK: - Initialization (DI only, no singleton)
    
    init(
        unifiedLeagueManager: UnifiedLeagueManager,
        sharedStatsService: SharedStatsService,
        gameStatusService: GameStatusService,
        weekSelectionManager: WeekSelectionManager
    ) {
        self.unifiedLeagueManager = unifiedLeagueManager
        self.sharedStatsService = sharedStatsService
        self.gameStatusService = gameStatusService
        self.weekSelectionManager = weekSelectionManager
    }
    
    // MARK: - Public Interface
    
    /// Warm up leagues with minimal data (fast skeleton load)
    func warmLeagues(_ leagues: [LeagueDescriptor], week: Int) async {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Warming \(leagues.count) leagues for week \(week)")
        
        for league in leagues {
            let key = LeagueKey(
                leagueID: league.id,
                platform: league.platform,
                seasonYear: String(NFLWeekCalculator.getCurrentSeasonYear()),
                week: week
            )
            
            // Create empty cache with loading state
            // 🔥 FIX: Don't try to fetch league metadata during warm phase
            // It will be fetched lazily during hydrateMatchup() when needed
            if leagueCaches[key] == nil {
                leagueCaches[key] = LeagueCache(
                    summary: LeagueSummary(
                        leagueID: league.id,
                        leagueName: league.name,
                        platform: league.platform,
                        week: week,
                        totalMatchups: 0,
                        playoffWeekStart: nil,  // Will be fetched lazily
                        isChopped: false  // Will be detected lazily
                    ),
                    matchups: [:],
                    state: .loadingBasic,
                    pendingTasks: [:],
                    lastRefreshed: Date()
                )
                
                // Emit initial snapshot
                emitSnapshot(for: key)
            }
        }
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: Warmed \(leagues.count) leagues")
    }
    
    /// 🔥 NEW: Extract playoff week start from league wrapper
    private func extractPlayoffWeekStart(from wrapper: UnifiedLeagueManager.LeagueWrapper) -> Int? {
        switch wrapper.source {
        case .sleeper:
            // Sleeper leagues have settings.playoffWeekStart
            if let sleeperLeague = wrapper.league as? SleeperLeague {
                return sleeperLeague.settings?.playoffWeekStart
            }
        case .espn:
            // ESPN leagues have settings.playoffWeekStart
            // Note: ESPNLeague model would need to be checked for this field
            // For now, return nil and use default detection
            return nil
        }
        return nil
    }
    
    /// 🔁 NEW: Extract chopped league flag from league wrapper
    private func extractIsChoppedLeague(from wrapper: UnifiedLeagueManager.LeagueWrapper) -> Bool {
        switch wrapper.source {
        case .sleeper:
            // Sleeper has built-in chopped detection (type==3 or isChopped flag)
            if let sleeperLeague = wrapper.league as? SleeperLeague {
                return sleeperLeague.settings?.isChoppedLeague ?? false
            }
        case .espn:
            // ESPN doesn't support chopped/guillotine leagues
            return false
        }
        return false
    }
    
    /// Hydrate a specific matchup on demand (lazy load)
    func hydrateMatchup(_ id: MatchupSnapshot.ID) async throws -> MatchupSnapshot {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Hydrating matchup \(id.matchupID)")
        
        let key = LeagueKey(
            leagueID: id.leagueID,
            platform: id.platform,
            seasonYear: String(NFLWeekCalculator.getCurrentSeasonYear()),
            week: id.week
        )
        
        // Check if already cached
        if let cached = leagueCaches[key]?.matchups[id] {
            let age = Date().timeIntervalSince(cached.lastUpdated)
            if age < cacheTTL(for: key) {
                DebugPrint(mode: .liveUpdates, "✅ STORE: Cache hit for \(id.matchupID) (age: \(Int(age))s)")
                return cached
            }
        }
        
        // Check if fetch is already in progress (dedupe)
        if let pending = leagueCaches[key]?.pendingTasks[id] {
            DebugPrint(mode: .liveUpdates, "⏳ STORE: Deduping fetch for \(id.matchupID)")
            return try await pending.value
        }
        
        // Start new fetch
        let task = Task<MatchupSnapshot, Error> {
            try await fetchMatchupSnapshot(id: id, key: key)
        }
        
        leagueCaches[key]?.pendingTasks[id] = task
        
        do {
            let snapshot = try await task.value
            
            // Cache it
            leagueCaches[key]?.matchups[id] = snapshot
            leagueCaches[key]?.pendingTasks[id] = nil
            leagueCaches[key]?.lastRefreshed = Date()
            
            // Emit update
            emitSnapshot(for: key)
            
            DebugPrint(mode: .liveUpdates, "✅ STORE: Hydrated \(id.matchupID)")
            return snapshot
            
        } catch {
            leagueCaches[key]?.pendingTasks[id] = nil
            DebugPrint(mode: .liveUpdates, "❌ STORE: Failed to hydrate \(id.matchupID): \(error)")
            throw error
        }
    }
    
    /// Get cached matchup (synchronous, returns nil if not cached)
    func cachedMatchup(_ id: MatchupSnapshot.ID) -> MatchupSnapshot? {
        let key = LeagueKey(
            leagueID: id.leagueID,
            platform: id.platform,
            seasonYear: String(NFLWeekCalculator.getCurrentSeasonYear()),
            week: id.week
        )
        return leagueCaches[key]?.matchups[id]
    }
    
    /// Get all cached matchups for a league
    func cachedMatchups(for league: LeagueKey) -> [MatchupSnapshot] {
        guard let cache = leagueCaches[league] else { return [] }  // 🔥 FIX: Handle nil safely
        return Array(cache.matchups.values)
    }
    
    /// Observe league updates (returns AsyncStream)
    func observeLeague(_ league: LeagueKey) -> AsyncStream<LeagueSnapshot> {
        AsyncStream { continuation in
            leagueStreams[league] = continuation
            
            // Emit current state immediately
            if let cache = leagueCaches[league] {
                let snapshot = LeagueSnapshot(
                    leagueID: league.leagueID,
                    leagueName: cache.summary.leagueName,
                    platform: league.platform,
                    week: league.week,
                    matchups: Array(cache.matchups.values),
                    state: cache.state,
                    lastRefreshed: cache.lastRefreshed
                )
                continuation.yield(snapshot)
            }
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.leagueStreams[league] = nil
                }
            }
        }
    }
    
    /// Refresh league data (manual or automatic)
    func refresh(league: LeagueKey?, force: Bool) async {
        // 🔥 NEW: Clear changed players at start of refresh cycle
        changedPlayerIDs.removeAll()
        
        if let league = league {
            // Refresh specific league
            await refreshLeague(league, force: force)
        } else {
            // Refresh all leagues
            for key in leagueCaches.keys {
                await refreshLeague(key, force: force)
            }
        }
        
        lastRefreshTime = Date()
    }
    
    /// Clear all caches (for debugging / logout)
    func clearCaches() async {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Clearing all caches")
        leagueCaches.removeAll()
        leagueStreams.values.forEach { $0.finish() }
        leagueStreams.removeAll()
        previousSnapshots.removeAll()
        changedPlayerIDs.removeAll()
    }
    
    /// Remove stale cache entries for leagues that no longer exist in UnifiedLeagueManager
    func cleanupStaleLeagues() async {
        let currentLeagueIDs = Set(unifiedLeagueManager.allLeagues.map { $0.id })
        let cachedLeagueIDs = Set(leagueCaches.keys.map { $0.leagueID })
        let staleLeagueIDs = cachedLeagueIDs.subtracting(currentLeagueIDs)
        
        if !staleLeagueIDs.isEmpty {
            DebugPrint(mode: .liveUpdates, "🧹 STORE: Cleaning up \(staleLeagueIDs.count) stale league caches")
            
            for staleID in staleLeagueIDs {
                let staleKeys = leagueCaches.keys.filter { $0.leagueID == staleID }
                for key in staleKeys {
                    leagueCaches.removeValue(forKey: key)
                    leagueStreams[key]?.finish()
                    leagueStreams.removeValue(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get current year as string
    private func getCurrentYear() -> String {
        return String(NFLWeekCalculator.getCurrentSeasonYear())
    }
    
    /// Create league wrapper from LeagueSummary (needed for provider creation)
    private func createLeagueWrapper(from summary: LeagueSummary) throws -> UnifiedLeagueManager.LeagueWrapper {
        // Get the actual league wrapper from UnifiedLeagueManager
        let allLeagues = unifiedLeagueManager.allLeagues
        
        DebugPrint(mode: .matchupLoading, "🔍 STORE: Looking for league \(summary.leagueID) in \(allLeagues.count) loaded leagues")
        
        if allLeagues.isEmpty {
            DebugPrint(mode: .matchupLoading, "⚠️ STORE: UnifiedLeagueManager has NO leagues loaded yet! This is a timing issue.")
        } else {
            DebugPrint(mode: .matchupLoading, "📋 STORE: Available leagues: \(allLeagues.map { "[\($0.id): \($0.league.name)]" }.joined(separator: ", "))")
        }
        
        // Find matching league
        if let wrapper = allLeagues.first(where: { $0.id == summary.leagueID }) {
            DebugPrint(mode: .matchupLoading, "✅ STORE: Found league wrapper for \(summary.leagueName)")
            return wrapper
        }
        
        // League not found - this can happen if:
        // 1. League was removed from user's leagues
        // 2. League failed to load initially
        // 3. Timing issue (rare with current architecture)
        DebugPrint(mode: .matchupLoading, "❌ STORE: League \(summary.leagueID) not found in UnifiedLeagueManager")
        
        throw NSError(
            domain: "MatchupDataStore",
            code: 404,
            userInfo: [
                NSLocalizedDescriptionKey: "League not found in loaded leagues",
                NSLocalizedFailureReasonErrorKey: "League \(summary.leagueName) (\(summary.leagueID)) is not available in UnifiedLeagueManager"
            ]
        )
    }
    
    /// Create appropriate matchup provider based on league platform
    private func createProvider(
        for leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        year: String
    ) -> LeagueMatchupProvider {
        // LeagueMatchupProvider handles both Sleeper and ESPN internally
        return LeagueMatchupProvider(
            league: leagueWrapper,
            week: week,
            year: year,
            fantasyViewModel: nil  // No ViewModel injection for store-level fetching
        )
    }
    
    /// Build MatchupSnapshot from FantasyMatchup
    private func buildMatchupSnapshot(
        from matchup: FantasyMatchup,
        myTeamID: String,
        leagueKey: LeagueKey,
        leagueDescriptor: LeagueDescriptor
    ) -> MatchupSnapshot {
        // Determine which team is mine
        let isHomeTeamMine: Bool
        if let homeRosterID = matchup.homeTeam.rosterID {
            isHomeTeamMine = matchup.homeTeam.id == myTeamID || String(homeRosterID) == myTeamID
        } else {
            isHomeTeamMine = matchup.homeTeam.id == myTeamID
        }
        
        let myTeam = isHomeTeamMine ? matchup.homeTeam : matchup.awayTeam
        let opponentTeam = isHomeTeamMine ? matchup.awayTeam : matchup.homeTeam
        
        // Build team snapshots
        let myTeamSnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: myTeam.id,
                ownerName: myTeam.ownerName,
                record: formatRecord(myTeam.record),
                avatarURL: myTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: myTeam.currentScore ?? 0.0,
                projected: myTeam.projectedScore ?? 0.0,
                winProbability: matchup.winProbability,
                margin: (myTeam.currentScore ?? 0.0) - (opponentTeam.currentScore ?? 0.0)
            ),
            roster: myTeam.roster.map { buildPlayerSnapshot(from: $0) }
        )
        
        let opponentTeamSnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: opponentTeam.id,
                ownerName: opponentTeam.ownerName,
                record: formatRecord(opponentTeam.record),
                avatarURL: opponentTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: opponentTeam.currentScore ?? 0.0,
                projected: opponentTeam.projectedScore ?? 0.0,
                winProbability: matchup.winProbability.map { 1.0 - $0 },
                margin: (opponentTeam.currentScore ?? 0.0) - (myTeam.currentScore ?? 0.0)
            ),
            roster: opponentTeam.roster.map { buildPlayerSnapshot(from: $0) }
        )
        
        // Detect playoff and elimination status
        let isPlayoff = detectPlayoffStatus(leagueKey: leagueKey)
        let isChopped = detectChoppedLeague(leagueKey: leagueKey)
        let isEliminated = detectEliminationStatus(matchup: matchup, isChopped: isChopped)
        
        // Build metadata
        let metadata = MatchupSnapshot.Metadata(
            status: matchup.status.rawValue,
            startTime: matchup.startTime,
            isPlayoff: isPlayoff,
            isChopped: isChopped,
            isEliminated: isEliminated
        )
        
        // Create snapshot ID
        let snapshotID = MatchupSnapshot.ID(
            leagueID: leagueKey.leagueID,
            matchupID: matchup.id,
            platform: leagueKey.platform,
            week: leagueKey.week
        )
        
        return MatchupSnapshot(
            id: snapshotID,
            metadata: metadata,
            myTeam: myTeamSnapshot,
            opponentTeam: opponentTeamSnapshot,
            league: leagueDescriptor,
            lastUpdated: Date()
        )
    }
    
    /// Fetch a matchup snapshot from providers
    private func fetchMatchupSnapshot(id: MatchupSnapshot.ID, key: LeagueKey) async throws -> MatchupSnapshot {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Fetching matchup snapshot for \(id.matchupID)")
        
        // Step 1: Get league descriptor
        guard let leagueDescriptor = leagueCaches[key]?.summary else {
            DebugPrint(mode: .liveUpdates, "❌ STORE: League not found in cache for \(id.matchupID)")
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "League not found in cache"])
        }
        
        DebugPrint(mode: .liveUpdates, "📋 STORE: Processing league '\(leagueDescriptor.leagueName)' for week \(key.week)")
        
        // Step 2: Create league wrapper for provider
        let leagueWrapper: UnifiedLeagueManager.LeagueWrapper
        do {
            leagueWrapper = try createLeagueWrapper(from: leagueDescriptor)
            
            // 🔥 NEW: Now that we have the wrapper, lazily populate playoff week if not set
            if leagueCaches[key]?.summary.playoffWeekStart == nil {
                let playoffWeek = extractPlayoffWeekStart(from: leagueWrapper)
                leagueCaches[key]?.summary.playoffWeekStart = playoffWeek
                DebugPrint(mode: .liveUpdates, "📊 STORE: Set playoff week for \(leagueDescriptor.leagueName): \(playoffWeek?.description ?? "nil")")
            }
            
            // 🔁 NEW: Lazily detect chopped league status
            if !leagueCaches[key]!.summary.isChopped {
                let isChopped = extractIsChoppedLeague(from: leagueWrapper)
                leagueCaches[key]?.summary.isChopped = isChopped
                if isChopped {
                    DebugPrint(mode: .liveUpdates, "🪓 STORE: Detected chopped league: \(leagueDescriptor.leagueName)")
                }
            }
            
        } catch {
            // If league wrapper not found, this league is no longer available
            // Clean up the cache entry and propagate the error
            DebugPrint(mode: .matchupLoading, "❌ STORE: Removing stale cache entry for league \(key.leagueID)")
            leagueCaches.removeValue(forKey: key)
            throw error
        }
        
        // Step 3: Create provider for this league
        let provider = createProvider(for: leagueWrapper, week: key.week, year: key.seasonYear)
        
        // Step 4: Identify my team first (needed for elimination checks)
        guard let myTeamID = try await provider.identifyMyTeamID() else {
            DebugPrint(mode: .liveUpdates, "❌ STORE: Could not identify team for \(leagueDescriptor.leagueName)")
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not identify user's team"])
        }
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: My team ID = \(myTeamID) for \(leagueDescriptor.leagueName)")
        
        // 🔥 STEP 4A: Check for chopped league BEFORE fetching matchups
        if await isSleeperChoppedLeagueResolved(leagueWrapper) {
            DebugPrint(mode: .matchupLoading, "🪓 STORE: Detected chopped league - routing to chopped handler")
            return try await fetchChoppedMatchupSnapshot(
                id: id,
                key: key,
                leagueWrapper: leagueWrapper,
                leagueDescriptor: leagueDescriptor,
                myTeamID: myTeamID
            )
        }
        
        // Step 5: Fetch matchup data from provider
        DebugPrint(mode: .liveUpdates, "🔄 STORE: Fetching matchups from provider for \(leagueDescriptor.leagueName)")
        let matchups = try await provider.fetchMatchups()
        DebugPrint(mode: .liveUpdates, "📦 STORE: Received \(matchups.count) matchups for \(leagueDescriptor.leagueName)")
        
        // 🔥 STEP 5A: Check for playoff elimination (empty matchups during playoffs)
        if matchups.isEmpty && isPlayoffWeek(key.week, leagueWrapper: leagueWrapper) {
            DebugPrint(mode: .matchupLoading, "🏆 STORE: Empty matchups during playoffs - checking elimination status")
            
            // Check PE toggle
            if UserDefaults.standard.showEliminatedPlayoffLeagues {
                DebugPrint(mode: .matchupLoading, "✅ STORE: PE toggle ON - creating eliminated matchup for \(leagueDescriptor.leagueName)")
                return try await fetchEliminatedPlayoffSnapshot(
                    id: id,
                    key: key,
                    leagueWrapper: leagueWrapper,
                    leagueDescriptor: leagueDescriptor,
                    myTeamID: myTeamID
                )
            } else {
                DebugPrint(mode: .matchupLoading, "❌ STORE: PE toggle OFF - throwing elimination error for \(leagueDescriptor.leagueName)")
                throw EliminatedLeagueError.playoffEliminatedHidden
            }
        }
        
        // Step 6: Find my matchup
        DebugPrint(mode: .liveUpdates, "🔍 STORE: Looking for my matchup in \(matchups.count) matchups for \(leagueDescriptor.leagueName)")
        guard let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) else {
            DebugPrint(mode: .liveUpdates, "⚠️ STORE: My matchup not found for \(leagueDescriptor.leagueName)")
            
            // 🔥 STEP 6A: No matchup found - could be playoff elimination
            if isPlayoffWeek(key.week, leagueWrapper: leagueWrapper) {
                DebugPrint(mode: .matchupLoading, "🏆 STORE: No matchup found during playoffs - checking winners bracket for \(leagueDescriptor.leagueName)")
                
                let isInWinnersBracket = await checkWinnersBracket(
                    leagueWrapper: leagueWrapper,
                    week: key.week,
                    myTeamID: myTeamID
                )
                
                DebugPrint(mode: .liveUpdates, "🏅 STORE: Winners bracket check result: \(isInWinnersBracket) for \(leagueDescriptor.leagueName)")
                
                if !isInWinnersBracket {
                    if UserDefaults.standard.showEliminatedPlayoffLeagues {
                        DebugPrint(mode: .matchupLoading, "✅ STORE: Eliminated but PE toggle ON - creating eliminated matchup for \(leagueDescriptor.leagueName)")
                        return try await fetchEliminatedPlayoffSnapshot(
                            id: id,
                            key: key,
                            leagueWrapper: leagueWrapper,
                            leagueDescriptor: leagueDescriptor,
                            myTeamID: myTeamID
                        )
                    } else {
                        DebugPrint(mode: .matchupLoading, "❌ STORE: Eliminated and PE toggle OFF - throwing elimination error for \(leagueDescriptor.leagueName)")
                        throw EliminatedLeagueError.playoffEliminatedHidden
                    }
                }
            }
            
            DebugPrint(mode: .liveUpdates, "❌ STORE: Throwing no matchup error for \(leagueDescriptor.leagueName)")
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "No matchup found for team \(myTeamID)"])
        }
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: Found my matchup for \(leagueDescriptor.leagueName)")
        
        // Step 7: Build snapshot from matchup WITH my team ID
        let snapshot = buildMatchupSnapshot(
            from: myMatchup,
            myTeamID: myTeamID,
            leagueKey: key,
            leagueDescriptor: LeagueDescriptor(
                id: leagueDescriptor.leagueID,
                name: leagueDescriptor.leagueName,
                platform: leagueDescriptor.platform,
                avatarURL: nil
            )
        )
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: Built snapshot for \(leagueDescriptor.leagueName) - opponent: \(snapshot.opponentTeam.info.ownerName)")
        return snapshot
    }
    
    // MARK: - Eliminated Matchup Handling
    
    /// Custom error for eliminated leagues
    enum EliminatedLeagueError: Error {
        case playoffEliminatedHidden
        case choppedEliminatedHidden
    }
    
    /// Check if current week is playoffs
    private func isPlayoffWeek(_ week: Int, leagueWrapper: UnifiedLeagueManager.LeagueWrapper) -> Bool {
        let playoffStart: Int?
        
        if leagueWrapper.source == .sleeper {
            playoffStart = leagueWrapper.league.settings?.playoffWeekStart ?? 15
        } else {
            playoffStart = 15  // ESPN default
        }
        
        // Hard rule: week 15+ is always playoffs
        if week >= 15 { return true }
        
        guard let start = playoffStart else { return false }
        return week >= start
    }
    
    /// Check if Sleeper league is chopped/guillotine
    private func isSleeperChoppedLeagueResolved(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async -> Bool {
        guard leagueWrapper.source == .sleeper else { return false }

        if let settings = leagueWrapper.league.settings {
            if settings.type == 3 || settings.isChopped == true { return true }

            if settings.type != nil || settings.isChopped != nil {
                return false
            }
        }

        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueWrapper.league.leagueID)") else {
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
    
    /// Check if team is in winners bracket
    private func checkWinnersBracket(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        switch leagueWrapper.source {
        case .espn:
            return await checkESPNWinnersBracket(leagueWrapper: leagueWrapper, week: week, myTeamID: myTeamID)
        case .sleeper:
            return await checkSleeperWinnersBracket(leagueWrapper: leagueWrapper, week: week, myTeamID: myTeamID)
        }
    }
    
    /// Check ESPN winners bracket
    private func checkESPNWinnersBracket(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        guard let myTeamIdInt = Int(myTeamID) else { return false }
        
        do {
            let year = getCurrentYear()
            guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(leagueWrapper.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
                return false
            }
            
            var request = URLRequest(url: url)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let espnToken = year == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
            request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
            
            let playoffStartWeek = leagueWrapper.league.settings?.playoffWeekStart ?? 15
            guard week >= playoffStartWeek else { return true }
            
            guard let schedule = model.schedule else { return true }
            
            if let entry = schedule.first(where: { entry in
                guard entry.matchupPeriodId == week else { return false }
                let homeId = entry.home.teamId
                let awayId = entry.away?.teamId
                return homeId == myTeamIdInt || awayId == myTeamIdInt
            }) {
                return (entry.playoffTierType ?? "NONE") == "WINNERS_BRACKET"
            }
            
            let appearsInFutureWinners = schedule.contains { entry in
                guard (entry.playoffTierType ?? "NONE") == "WINNERS_BRACKET" else { return false }
                guard entry.matchupPeriodId >= week else { return false }
                let homeId = entry.home.teamId
                let awayId = entry.away?.teamId
                return homeId == myTeamIdInt || awayId == myTeamIdInt
            }
            
            return appearsInFutureWinners
        } catch {
            return true
        }
    }
    
    /// Check Sleeper winners bracket
    private func checkSleeperWinnersBracket(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        guard let myRosterID = Int(myTeamID) else { return false }
        
        let playoffStartWeek = leagueWrapper.league.settings?.playoffWeekStart ?? 15
        let round = max(1, week - playoffStartWeek + 1)
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueWrapper.league.leagueID)/winners_bracket") else {
            return false
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let winnersBracket = try JSONDecoder().decode([SleeperPlayoffBracketMatchup].self, from: data)
            
            let eliminatedInWinners = winnersBracket.contains { matchup in
                let isParticipant = matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID
                return isParticipant && matchup.loserRosterID == myRosterID
            }
            if eliminatedInWinners { return false }
            
            let appearsThisRound = winnersBracket.contains { matchup in
                matchup.round == round && (matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID)
            }
            
            let myRounds = winnersBracket.compactMap { matchup -> Int? in
                let isParticipant = matchup.team1RosterID == myRosterID || matchup.team2RosterID == myRosterID
                return isParticipant ? matchup.round : nil
            }
            let firstAppearanceRound = myRounds.min()
            let hasByeIntoLaterRound = (firstAppearanceRound != nil && firstAppearanceRound! > round)
            
            return appearsThisRound || hasByeIntoLaterRound
        } catch {
            return false
        }
    }
    
    /// Fetch eliminated playoff matchup snapshot
    private func fetchEliminatedPlayoffSnapshot(
        id: MatchupSnapshot.ID,
        key: LeagueKey,
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        leagueDescriptor: LeagueSummary,
        myTeamID: String
    ) async throws -> MatchupSnapshot {
        DebugPrint(mode: .matchupLoading, "🏆 STORE: Creating eliminated playoff snapshot")
        
        // Fetch my team's roster with live scores
        let myTeam = try await fetchEliminatedTeamRoster(
            leagueWrapper: leagueWrapper,
            myTeamID: myTeamID,
            week: key.week
        )
        
        // Create placeholder opponent
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
        
        // Create fake matchup
        let eliminatedMatchup = FantasyMatchup(
            id: "\(key.leagueID)_eliminated_\(key.week)_\(myTeamID)",
            leagueID: key.leagueID,
            week: key.week,
            year: key.seasonYear,
            homeTeam: myTeam,
            awayTeam: placeholderOpponent,
            status: .complete,
            winProbability: 0.0,
            startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            sleeperMatchups: nil
        )
        
        // Build snapshot from eliminated matchup
        return buildMatchupSnapshot(
            from: eliminatedMatchup,
            myTeamID: myTeamID,
            leagueKey: key,
            leagueDescriptor: LeagueDescriptor(
                id: leagueDescriptor.leagueID,
                name: leagueDescriptor.leagueName,
                platform: leagueDescriptor.platform,
                avatarURL: nil
            )
        )
    }
    
    /// Fetch chopped league snapshot
    private func fetchChoppedMatchupSnapshot(
        id: MatchupSnapshot.ID,
        key: LeagueKey,
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        leagueDescriptor: LeagueSummary,
        myTeamID: String
    ) async throws -> MatchupSnapshot {
        DebugPrint(mode: .matchupLoading, "🪓 STORE: Creating chopped league snapshot")
        
        // For now, throw an error to indicate chopped leagues need special handling
        // This can be enhanced later to call handleChoppedLeague() from MatchupsHubViewModel+ChoppedLeagues
        throw NSError(domain: "MatchupDataStore", code: 501, userInfo: [NSLocalizedDescriptionKey: "Chopped league snapshots not yet implemented in store"])
    }
    
    /// Fetch eliminated team roster (delegated to existing functions)
    private func fetchEliminatedTeamRoster(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async throws -> FantasyTeam {
        if leagueWrapper.source == .sleeper {
            return try await fetchEliminatedSleeperTeam(leagueWrapper: leagueWrapper, myTeamID: myTeamID, week: week)
        } else {
            return try await fetchEliminatedESPNTeam(leagueWrapper: leagueWrapper, myTeamID: myTeamID, week: week)
        }
    }
    
    /// Fetch Sleeper eliminated team roster
    private func fetchEliminatedSleeperTeam(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async throws -> FantasyTeam {
        let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueWrapper.league.leagueID)/rosters")!
        let (data, _) = try await URLSession.shared.data(from: rostersURL)
        let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
        
        let myRoster = rosters.first { roster in
            String(roster.rosterID) == myTeamID || roster.ownerID == myTeamID
        }
        
        guard let myRoster = myRoster else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find roster for team ID: \(myTeamID)"])
        }
        
        let matchupsURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueWrapper.league.leagueID)/matchups/\(week)")!
        let (matchupData, _) = try await URLSession.shared.data(from: matchupsURL)
        let matchupResponses = try JSONDecoder().decode([SleeperMatchupResponse].self, from: matchupData)
        
        guard let myMatchupResponse = matchupResponses.first(where: { $0.rosterID == myRoster.rosterID }) else {
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
                faabTotal: leagueWrapper.league.settings?.waiverBudget,
                faabUsed: myRoster.waiversBudgetUsed
            )
        }
        
        let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueWrapper.league.leagueID)/users")!
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
                
                let gameStatus = gameStatusService.getGameStatusWithFallback(for: playerTeam)
                
                let fantasyPlayer = FantasyPlayer(
                    id: playerID,
                    sleeperID: playerID,
                    espnID: sleeperPlayer.espnID,
                    firstName: sleeperPlayer.firstName,
                    lastName: sleeperPlayer.lastName,
                    position: playerPosition,
                    team: playerTeam,
                    jerseyNumber: sleeperPlayer.number?.description,
                    currentPoints: 0.0,
                    projectedPoints: 0.0,
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
        
        return FantasyTeam(
            id: myTeamID,
            name: managerName,
            ownerName: managerName,
            record: record,
            avatar: avatarURL,
            currentScore: myMatchupResponse.points ?? 0.0,
            projectedScore: (myMatchupResponse.points ?? 0.0) * 1.05,
            roster: fantasyPlayers,
            rosterID: myRoster.rosterID,
            faabTotal: leagueWrapper.league.settings?.waiverBudget,
            faabUsed: myRoster.waiversBudgetUsed
        )
    }
    
    /// Fetch ESPN eliminated team roster
    private func fetchEliminatedESPNTeam(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        myTeamID: String,
        week: Int
    ) async throws -> FantasyTeam {
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(getCurrentYear())/segments/0/leagues/\(leagueWrapper.league.leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mPositionalRatings&scoringPeriodId=\(week)") else {
            throw NSError(domain: "MatchupDataStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid ESPN URL"])
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = getCurrentYear() == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let model = try JSONDecoder().decode(ESPNFantasyLeagueModel.self, from: data)
        
        guard let myTeam = model.teams.first(where: { String($0.id) == myTeamID }) else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find team with ID \(myTeamID)"])
        }
        
        let myScore = myTeam.activeRosterScore(for: week)
        let teamName = myTeam.name ?? "Team \(myTeam.id)"
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let roster = myTeam.roster {
            fantasyPlayers = roster.entries.map { entry in
                let player = entry.playerPoolEntry.player

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
                    gameStatus: gameStatusService.getGameStatusWithFallback(for: player.nflTeamAbbreviation ?? "UNK"),
                    isStarter: true,
                    lineupSlot: nil,
                    injuryStatus: nil
                )
            }
        }
        
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
    }
    
    /// 🔁 NEW: Detect if matchup is in playoff period
    private func detectPlayoffStatus(leagueKey: LeagueKey) -> Bool {
        // Method 1: Check league cache for playoff week setting
        if let cache = leagueCaches[leagueKey],
           let playoffWeekStart = getPlayoffWeekStart(from: cache.summary) {
            return leagueKey.week >= playoffWeekStart
        }
        
        // Method 2: Default to week 15+ being playoffs (standard NFL fantasy)
        // Most leagues start playoffs week 15 (some week 14, rare week 16)
        return leagueKey.week >= 15
    }
    
    /// 🔁 NEW: Detect if league is chopped/guillotine
    private func detectChoppedLeague(leagueKey: LeagueKey) -> Bool {
        // Check league cache for chopped flag
        if let cache = leagueCaches[leagueKey] {
            return cache.summary.isChopped
        }
        return false
    }
    
    /// 🔁 NEW: Detect if matchup involves elimination
    private func detectEliminationStatus(matchup: FantasyMatchup, isChopped: Bool) -> Bool {
        // Method 1: Check for playoff elimination marker
        if matchup.awayTeam.name == "Eliminated from Playoffs" || 
           matchup.homeTeam.name == "Eliminated from Playoffs" {
            return true
        }
        
        // Method 2: Check for chopped league elimination (empty rosters)
        if isChopped {
            // If either team has zero players and zero score, they're eliminated
            let homeEliminated = matchup.homeTeam.roster.isEmpty && (matchup.homeTeam.currentScore ?? 0.0) == 0.0
            let awayEliminated = matchup.awayTeam.roster.isEmpty && (matchup.awayTeam.currentScore ?? 0.0) == 0.0
            return homeEliminated || awayEliminated
        }
        
        return false
    }
    
    /// 🔁 NEW: Extract playoff week start from league settings
    private func getPlayoffWeekStart(from summary: LeagueSummary) -> Int? {
        // Return cached playoff week start
        return summary.playoffWeekStart
    }
    
    /// Build PlayerSnapshot from FantasyPlayer
    private func buildPlayerSnapshot(from player: FantasyPlayer) -> PlayerSnapshot {
        // 🔥 TODO #8: Get kickoff time from game data (GameStatusService doesn't expose this yet)
        // For now, set to nil - can be enhanced later when game data provides kickoff times
        let kickoffTime: Date? = nil
        
        return PlayerSnapshot(
            id: player.id,
            identity: PlayerSnapshot.PlayerIdentity(
                playerID: player.id,
                sleeperID: player.sleeperID,
                espnID: player.espnID,
                firstName: player.firstName ?? "",
                lastName: player.lastName ?? "",
                fullName: player.fullName
            ),
            metrics: PlayerSnapshot.PlayerMetrics(
                currentScore: player.currentPoints ?? 0.0,
                projectedScore: player.projectedPoints ?? 0.0,
                delta: 0.0, // Calculated during delta updates at store level
                lastActivity: nil, // Tracked during delta updates at store level
                gameStatus: player.gameStatus?.status
            ),
            context: PlayerSnapshot.PlayerContext(
                position: player.position,
                lineupSlot: player.lineupSlot,
                isStarter: player.isStarter,
                team: player.team,
                injuryStatus: player.injuryStatus,
                jerseyNumber: player.jerseyNumber,
                kickoffTime: kickoffTime  // 🔥 Set to nil for now
            )
        )
    }
    
    /// Format team record as string
    private func formatRecord(_ record: TeamRecord?) -> String {
        guard let record = record else { return "" }
        if let ties = record.ties, ties > 0 {
            return "\(record.wins)-\(record.losses)-\(ties)"
        }
        return "\(record.wins)-\(record.losses)"
    }
    
    /// Refresh a specific league
    private func refreshLeague(_ key: LeagueKey, force: Bool) async {
        guard var cache = leagueCaches[key] else { return }
        
        let age = Date().timeIntervalSince(cache.lastRefreshed)
        if !force && age < cacheTTL(for: key) {
            DebugPrint(mode: .liveUpdates, "⏭️ STORE: Skipping refresh for \(key.leagueID) (age: \(Int(age))s)")
            return
        }
        
        DebugPrint(mode: .liveUpdates, "🔄 STORE: Refreshing league \(key.leagueID)")
        
        cache.state = .loading
        leagueCaches[key] = cache
        emitSnapshot(for: key)
        
        // Refresh all cached matchups for this league
        for (matchupID, _) in cache.matchups {
            do {
                let newSnapshot = try await fetchMatchupSnapshot(id: matchupID, key: key)
                
                // 🔁 NEW: Detect changed players
                if let oldSnapshot = previousSnapshots[matchupID] {
                    let changedPlayers = detectChangedPlayers(old: oldSnapshot, new: newSnapshot)
                    changedPlayerIDs.formUnion(changedPlayers)
                }
                
                // Update snapshots
                previousSnapshots[matchupID] = cache.matchups[matchupID] // Store old before updating
                cache.matchups[matchupID] = newSnapshot
                
            } catch {
                DebugPrint(mode: .liveUpdates, "❌ STORE: Failed to refresh matchup \(matchupID.matchupID): \(error)")
            }
        }
        
        cache.state = .loaded
        cache.lastRefreshed = Date()
        leagueCaches[key] = cache
        emitSnapshot(for: key)
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: Refreshed \(cache.matchups.count) matchups for \(key.leagueID) - \(changedPlayerIDs.count) players changed")
    }
    
    /// Calculate TTL for a league (shorter during live games)
    private func cacheTTL(for key: LeagueKey) -> TimeInterval {
        // Check if any matchups in this league have live games
        guard let cache = leagueCaches[key] else { return 90.0 }
        
        let hasLiveGames = cache.matchups.values.contains { snapshot in
            // Check if any starter is in an active game
            snapshot.myTeam.roster.contains { player in
                player.context.isStarter && player.metrics.gameStatus == "live"
            } || snapshot.opponentTeam.roster.contains { player in
                player.context.isStarter && player.metrics.gameStatus == "live"
            }
        }
        
        // Shorter TTL during live games, longer otherwise
        return hasLiveGames ? 15.0 : 300.0  // 15s live, 5min otherwise
    }
    
    /// Emit snapshot to observers
    private func emitSnapshot(for key: LeagueKey) {
        guard let cache = leagueCaches[key],
              let continuation = leagueStreams[key] else {
            return
        }
        
        let snapshot = LeagueSnapshot(
            leagueID: key.leagueID,
            leagueName: cache.summary.leagueName,
            platform: key.platform,
            week: key.week,
            matchups: Array(cache.matchups.values),
            state: cache.state,
            lastRefreshed: cache.lastRefreshed
        )
        
        continuation.yield(snapshot)
    }
    
    /// 🔁 NEW: Detect which players changed between snapshots
    private func detectChangedPlayers(old: MatchupSnapshot, new: MatchupSnapshot) -> Set<String> {
        var changed = Set<String>()
        
        // Check my team roster
        for (oldPlayer, newPlayer) in zip(old.myTeam.roster, new.myTeam.roster) {
            if hasPlayerChanged(old: oldPlayer, new: newPlayer) {
                changed.insert(newPlayer.id)
            }
        }
        
        // Check opponent team roster
        for (oldPlayer, newPlayer) in zip(old.opponentTeam.roster, new.opponentTeam.roster) {
            if hasPlayerChanged(old: oldPlayer, new: newPlayer) {
                changed.insert(newPlayer.id)
            }
        }
        
        return changed
    }
    
    /// 🔁 NEW: Check if individual player changed
    private func hasPlayerChanged(old: PlayerSnapshot, new: PlayerSnapshot) -> Bool {
        // Score changed
        if abs(old.metrics.currentScore - new.metrics.currentScore) > 0.01 {
            return true
        }
        
        // Game status changed
        if old.metrics.gameStatus != new.metrics.gameStatus {
            return true
        }
        
        // Injury status changed
        if old.context.injuryStatus != new.context.injuryStatus {
            return true
        }
        
        return false
    }
    
    /// 🔁 NEW: Get changed players since last refresh
    func getChangedPlayers() -> Set<String> {
        return changedPlayerIDs
    }
    
    /// 🔁 NEW: Get all players from cache (for initial load)
    func getAllPlayers() -> [PlayerSnapshot] {
        var allPlayers: [PlayerSnapshot] = []
        
        for cache in leagueCaches.values {
            for matchup in cache.matchups.values {
                allPlayers.append(contentsOf: matchup.myTeam.roster)
                allPlayers.append(contentsOf: matchup.opponentTeam.roster)
            }
        }
        
        return allPlayers
    }
}

// MARK: - Supporting Types

extension MatchupDataStore {
    
    /// Unique key for a league at a specific week
    struct LeagueKey: Hashable {
        let leagueID: String
        let platform: LeagueSource  // 🔥 FIX: Use LeagueSource instead of LeaguePlatform
        let seasonYear: String
        let week: Int
    }
    
    /// Internal cache for a league
    struct LeagueCache {
        var summary: LeagueSummary
        var matchups: [MatchupSnapshot.ID: MatchupSnapshot]
        var state: LoadState
        var pendingTasks: [MatchupSnapshot.ID: Task<MatchupSnapshot, Error>]
        var lastRefreshed: Date
    }
    
    /// League summary (lightweight metadata)
    struct LeagueSummary {
        let leagueID: String
        let leagueName: String
        let platform: LeagueSource  // 🔥 FIX: Use LeagueSource
        let week: Int
        var totalMatchups: Int  // 🔥 FIX: Make mutable
        var playoffWeekStart: Int?  // 🔁 NEW: Store playoff start week for accurate detection
        var isChopped: Bool  // 🔁 NEW: Store chopped league flag
    }
    
    /// Loading state
    enum LoadState {
        case loadingBasic    // Initial skeleton load
        case loading         // Full refresh
        case loaded          // Data available
        case error(String)   // Failed to load
    }
}

// MARK: - Snapshot Types

/// Snapshot of league state for consumers
struct LeagueSnapshot {
    let leagueID: String
    let leagueName: String
    let platform: LeagueSource  // 🔥 FIX: Use LeagueSource
    let week: Int
    let matchups: [MatchupSnapshot]
    let state: MatchupDataStore.LoadState
    let lastRefreshed: Date
}

/// Snapshot of a single matchup
struct MatchupSnapshot: Identifiable {
    let id: ID
    let metadata: Metadata
    let myTeam: TeamSnapshot
    let opponentTeam: TeamSnapshot
    let league: LeagueDescriptor
    let lastUpdated: Date
    
    struct ID: Hashable {
        let leagueID: String
        let matchupID: String
        let platform: LeagueSource  // 🔥 FIX: Use LeagueSource
        let week: Int
    }
    
    struct Metadata {
        let status: String
        let startTime: Date?
        let isPlayoff: Bool
        let isChopped: Bool
        let isEliminated: Bool
    }
}

/// Snapshot of a team in a matchup
struct TeamSnapshot {
    let info: TeamInfo
    let score: ScoreInfo
    let roster: [PlayerSnapshot]
    
    struct TeamInfo {
        let teamID: String
        let ownerName: String
        let record: String
        let avatarURL: String?
    }
    
    struct ScoreInfo {
        let actual: Double
        let projected: Double
        let winProbability: Double?
        let margin: Double
    }
}

/// Snapshot of a player
struct PlayerSnapshot: Identifiable {
    let id: String
    let identity: PlayerIdentity
    let metrics: PlayerMetrics
    let context: PlayerContext
    
    struct PlayerIdentity {
        let playerID: String
        let sleeperID: String?
        let espnID: String?
        let firstName: String
        let lastName: String
        let fullName: String
    }
    
    struct PlayerMetrics {
        let currentScore: Double
        let projectedScore: Double
        let delta: Double
        let lastActivity: Date?
        let gameStatus: String?  // 🔁 FIX: Store as String, not enum
    }
    
    struct PlayerContext {
        let position: String
        let lineupSlot: String?
        let isStarter: Bool
        let team: String?
        let injuryStatus: String?
        let jerseyNumber: String?
        let kickoffTime: Date?
    }
}

/// Lightweight league descriptor
struct LeagueDescriptor: Hashable {
    let id: String
    let name: String
    let platform: LeagueSource  // 🔁 FIX: Use LeagueSource
    let avatarURL: String?
}