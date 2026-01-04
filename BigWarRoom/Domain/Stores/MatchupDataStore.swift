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
    private let playoffEliminationService: PlayoffEliminationService  // 🔥 NEW: Phase 2 service
    private let teamRosterFetchService: TeamRosterFetchService  // 🔥 NEW: Phase 2 service
    private let choppedLeagueService: ChoppedLeagueService  // 🔥 NEW: Phase 2 service
    private let teamIdentificationService: TeamIdentificationService  // 🔥 NEW: Phase 2 service
    private let dataConversionService = DataConversionService.shared  // 🔥 NEW: Phase 2.5 service
    
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
        weekSelectionManager: WeekSelectionManager,
        playoffEliminationService: PlayoffEliminationService,  // 🔥 NEW: Phase 2 service
        teamRosterFetchService: TeamRosterFetchService,  // 🔥 NEW: Phase 2 service
        choppedLeagueService: ChoppedLeagueService,  // 🔥 NEW: Phase 2 service
        teamIdentificationService: TeamIdentificationService  // 🔥 NEW: Phase 2 service
    ) {
        self.unifiedLeagueManager = unifiedLeagueManager
        self.sharedStatsService = sharedStatsService
        self.gameStatusService = gameStatusService
        self.weekSelectionManager = weekSelectionManager
        self.playoffEliminationService = playoffEliminationService  // 🔥 NEW: Store service
        self.teamRosterFetchService = teamRosterFetchService  // 🔥 NEW: Store service
        self.choppedLeagueService = choppedLeagueService  // 🔥 NEW: Store service
        self.teamIdentificationService = teamIdentificationService  // 🔥 NEW: Store service
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
        
        if force {
            let week = weekSelectionManager.selectedWeek
            let year = getCurrentYear()
            _ = try? await sharedStatsService.forceRefreshWeekStats(week: week, year: year)
        }
        
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
        
        // Build team snapshots for my/opponent orientation
        let myTeamSnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: myTeam.id,
                ownerName: myTeam.ownerName,
                record: dataConversionService.formatRecord(myTeam.record),
                avatarURL: myTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: myTeam.currentScore ?? 0.0,
                projected: myTeam.projectedScore ?? 0.0,
                winProbability: matchup.winProbability,
                margin: (myTeam.currentScore ?? 0.0) - (opponentTeam.currentScore ?? 0.0)
            ),
            roster: myTeam.roster.map { dataConversionService.buildPlayerSnapshot(from: $0) }
        )
        
        let opponentTeamSnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: opponentTeam.id,
                ownerName: opponentTeam.ownerName,
                record: dataConversionService.formatRecord(opponentTeam.record),
                avatarURL: opponentTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: opponentTeam.currentScore ?? 0.0,
                projected: opponentTeam.projectedScore ?? 0.0,
                winProbability: matchup.winProbability.map { 1.0 - $0 },
                margin: (opponentTeam.currentScore ?? 0.0) - (myTeam.currentScore ?? 0.0)
            ),
            roster: opponentTeam.roster.map { dataConversionService.buildPlayerSnapshot(from: $0) }
        )
        
        // Build snapshots preserving true schedule sides from provider
        let homeSnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: matchup.homeTeam.id,
                ownerName: matchup.homeTeam.ownerName,
                record: dataConversionService.formatRecord(matchup.homeTeam.record),
                avatarURL: matchup.homeTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: matchup.homeTeam.currentScore ?? 0.0,
                projected: matchup.homeTeam.projectedScore ?? 0.0,
                winProbability: isHomeTeamMine ? matchup.winProbability : matchup.winProbability.map { 1.0 - $0 },
                margin: (matchup.homeTeam.currentScore ?? 0.0) - (matchup.awayTeam.currentScore ?? 0.0)
            ),
            roster: matchup.homeTeam.roster.map { dataConversionService.buildPlayerSnapshot(from: $0) }
        )
        
        let awaySnapshot = TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: matchup.awayTeam.id,
                ownerName: matchup.awayTeam.ownerName,
                record: dataConversionService.formatRecord(matchup.awayTeam.record),
                avatarURL: matchup.awayTeam.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: matchup.awayTeam.currentScore ?? 0.0,
                projected: matchup.awayTeam.projectedScore ?? 0.0,
                winProbability: isHomeTeamMine ? matchup.winProbability.map { 1.0 - $0 } : matchup.winProbability,
                margin: (matchup.awayTeam.currentScore ?? 0.0) - (matchup.homeTeam.currentScore ?? 0.0)
            ),
            roster: matchup.awayTeam.roster.map { dataConversionService.buildPlayerSnapshot(from: $0) }
        )
        
        // Detect playoff/chopped/elimination states
        let isPlayoff = detectPlayoffStatus(leagueKey: leagueKey)
        let isChopped = detectChoppedLeague(leagueKey: leagueKey)
        let isEliminated = detectEliminationStatus(matchup: matchup, isChopped: isChopped)
        
        let metadata = MatchupSnapshot.Metadata(
            status: matchup.status.rawValue,
            startTime: matchup.startTime,
            isPlayoff: isPlayoff,
            isChopped: isChopped,
            isEliminated: isEliminated
        )
        
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
            lastUpdated: Date(),
            homeTeam: homeSnapshot,
            awayTeam: awaySnapshot,
            myTeamSide: isHomeTeamMine ? .home : .away
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
        if await choppedLeagueService.isSleeperChoppedLeagueResolved(leagueWrapper) {
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
        
        // 🔥 STEP 5A: Check for playoff elimination (empty matchups during playoffs) using service
        if matchups.isEmpty && playoffEliminationService.isPlayoffWeek(league: leagueWrapper, week: key.week) {
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
            
            // 🔥 STEP 6A: No matchup found - could be playoff elimination (using service)
            if playoffEliminationService.isPlayoffWeek(league: leagueWrapper, week: key.week) {
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
    
    /// Check if team is in winners bracket
    private func checkWinnersBracket(
        leagueWrapper: UnifiedLeagueManager.LeagueWrapper,
        week: Int,
        myTeamID: String
    ) async -> Bool {
        // 🔥 PHASE 2: Use PlayoffEliminationService instead of local methods
        switch leagueWrapper.source {
        case .espn:
            return await playoffEliminationService.isESPNTeamInWinnersBracket(league: leagueWrapper, week: week, myTeamID: myTeamID)
        case .sleeper:
            return await playoffEliminationService.isSleeperTeamInWinnersBracket(league: leagueWrapper, week: week, myTeamID: myTeamID)
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
            name: "Dreams Deferred",
            ownerName: "Dreams Deferred",
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
        // 🔥 PHASE 2: Delegate to TeamRosterFetchService
        guard let team = await teamRosterFetchService.fetchEliminatedTeamRoster(
            league: leagueWrapper,
            myTeamID: myTeamID,
            week: week
        ) else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not fetch eliminated team roster"])
        }
        return team
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
        if matchup.awayTeam.name == "Dreams Deferred" || 
           matchup.homeTeam.name == "Dreams Deferred" {
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
        // 🔥 PHASE 2.5: Delegate to DataConversionService
        return dataConversionService.buildPlayerSnapshot(from: player)
    }
    
    /// Format team record as string
    private func formatRecord(_ record: TeamRecord?) -> String {
        // 🔥 PHASE 2.5: Delegate to DataConversionService
        return dataConversionService.formatRecord(record)
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
    enum LoadState: Codable {
        case loadingBasic    // Initial skeleton load
        case loading         // Full refresh
        case loaded          // Data available
        case error(String)   // Failed to load
        
        // MARK: - Codable conformance
        enum CodingKeys: String, CodingKey {
            case type
            case errorMessage
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "loadingBasic":
                self = .loadingBasic
            case "loading":
                self = .loading
            case "loaded":
                self = .loaded
            case "error":
                let errorMessage = try container.decode(String.self, forKey: .errorMessage)
                self = .error(errorMessage)
            default:
                self = .loaded
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .loadingBasic:
                try container.encode("loadingBasic", forKey: .type)
            case .loading:
                try container.encode("loading", forKey: .type)
            case .loaded:
                try container.encode("loaded", forKey: .type)
            case .error(let message):
                try container.encode("error", forKey: .type)
                try container.encode(message, forKey: .errorMessage)
            }
        }
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

    enum TeamSide { case home, away }
    let homeTeam: TeamSnapshot
    let awayTeam: TeamSnapshot
    let myTeamSide: TeamSide

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
struct TeamSnapshot: Codable {
    let info: TeamInfo
    let score: ScoreInfo
    let roster: [PlayerSnapshot]
    
    struct TeamInfo: Codable {
        let teamID: String
        let ownerName: String
        let record: String
        let avatarURL: String?
    }
    
    struct ScoreInfo: Codable {
        let actual: Double
        let projected: Double
        let winProbability: Double?
        let margin: Double
    }
}

/// Snapshot of a player
struct PlayerSnapshot: Identifiable, Codable {
    let id: String
    let identity: PlayerIdentity
    let metrics: PlayerMetrics
    let context: PlayerContext
    
    struct PlayerIdentity: Codable {
        let playerID: String
        let sleeperID: String?
        let espnID: String?
        let firstName: String
        let lastName: String
        let fullName: String
    }
    
    struct PlayerMetrics: Codable {
        let currentScore: Double
        let projectedScore: Double
        let delta: Double
        let lastActivity: Date?
        let gameStatus: String?  // 🔁 FIX: Store as String, not enum
    }
    
    struct PlayerContext: Codable {
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