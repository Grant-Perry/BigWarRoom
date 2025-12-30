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
                seasonYear: String(Calendar.current.component(.year, from: Date())),
                week: week
            )
            
            // Create empty cache with loading state
            if leagueCaches[key] == nil {
                leagueCaches[key] = LeagueCache(
                    summary: LeagueSummary(
                        leagueID: league.id,
                        leagueName: league.name,
                        platform: league.platform,
                        week: week,
                        totalMatchups: 0
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
    
    /// Hydrate a specific matchup on demand (lazy load)
    func hydrateMatchup(_ id: MatchupSnapshot.ID) async throws -> MatchupSnapshot {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Hydrating matchup \(id.matchupID)")
        
        let key = LeagueKey(
            leagueID: id.leagueID,
            platform: id.platform,
            seasonYear: String(Calendar.current.component(.year, from: Date())),
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
            throw error
        }
    }
    
    /// Get cached matchup (synchronous, returns nil if not cached)
    func cachedMatchup(_ id: MatchupSnapshot.ID) -> MatchupSnapshot? {
        let key = LeagueKey(
            leagueID: id.leagueID,
            platform: id.platform,
            seasonYear: String(Calendar.current.component(.year, from: Date())),
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
    }
    
    // MARK: - Private Helpers
    
    /// Fetch a matchup snapshot from providers
    private func fetchMatchupSnapshot(id: MatchupSnapshot.ID, key: LeagueKey) async throws -> MatchupSnapshot {
        DebugPrint(mode: .liveUpdates, "🔥 STORE: Fetching matchup snapshot for \(id.matchupID)")
        
        // Step 1: Get league descriptor
        guard let leagueDescriptor = leagueCaches[key]?.summary else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "League not found in cache"])
        }
        
        // Step 2: Create league wrapper for provider
        let leagueWrapper = createLeagueWrapper(from: leagueDescriptor)
        
        // Step 3: Create provider for this league
        let provider = createProvider(for: leagueWrapper, week: key.week, year: key.seasonYear)
        
        // Step 4: Fetch matchup data from provider
        let matchups = try await provider.fetchMatchups()
        
        // Step 5: Identify my team in this league
        guard let myTeamID = try await provider.identifyMyTeamID() else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not identify user's team"])
        }
        
        // Step 6: Find my matchup
        guard let myMatchup = provider.findMyMatchup(myTeamID: myTeamID) else {
            throw NSError(domain: "MatchupDataStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "No matchup found for team \(myTeamID)"])
        }
        
        // Step 7: Build snapshot from matchup
        let snapshot = buildMatchupSnapshot(
            from: myMatchup,
            leagueKey: key,
            leagueDescriptor: LeagueDescriptor(
                id: leagueDescriptor.leagueID,
                name: leagueDescriptor.leagueName,
                platform: leagueDescriptor.platform,
                avatarURL: nil
            )
        )
        
        DebugPrint(mode: .liveUpdates, "✅ STORE: Fetched snapshot for \(id.matchupID)")
        return snapshot
    }
    
    /// Create a LeagueWrapper from league summary
    private func createLeagueWrapper(from summary: LeagueSummary) -> UnifiedLeagueManager.LeagueWrapper {
        // Create a minimal SleeperLeague for the wrapper (using Codable format)
        let sleeperLeague = SleeperLeague(
            leagueID: summary.leagueID,
            name: summary.leagueName,
            status: .inSeason,
            sport: "nfl",
            season: getCurrentYear(),
            seasonType: "regular",
            totalRosters: 12,
            draftID: nil,
            avatar: nil,
            settings: nil,
            scoringSettings: nil,
            rosterPositions: nil
        )
        
        // Create client based on platform
        let client: DraftAPIClient = summary.platform == .sleeper 
            ? SleeperAPIClient()
            : ESPNAPIClient(credentialsManager: ESPNCredentialsManager())
        
        return UnifiedLeagueManager.LeagueWrapper(
            id: summary.leagueID,
            league: sleeperLeague,
            source: summary.platform,
            client: client
        )
    }
    
    /// Get current year as String
    private func getCurrentYear() -> String {
        return String(Calendar.current.component(.year, from: Date()))
    }
    
    /// Create a provider for the league
    private func createProvider(for league: UnifiedLeagueManager.LeagueWrapper, week: Int, year: String) -> LeagueMatchupProvider {
        // LeagueMatchupProvider handles both Sleeper and ESPN internally
        return LeagueMatchupProvider(
            league: league,
            week: week,
            year: year
        )
    }
    
    /// Build a MatchupSnapshot from FantasyMatchup
    private func buildMatchupSnapshot(
        from matchup: FantasyMatchup,
        leagueKey: LeagueKey,
        leagueDescriptor: LeagueDescriptor
    ) -> MatchupSnapshot {
        let myTeam = buildTeamSnapshot(from: matchup.homeTeam)
        let opponentTeam = buildTeamSnapshot(from: matchup.awayTeam)
        
        return MatchupSnapshot(
            id: MatchupSnapshot.ID(
                leagueID: leagueKey.leagueID,
                matchupID: matchup.id,
                platform: leagueKey.platform,
                week: leagueKey.week
            ),
            metadata: MatchupSnapshot.Metadata(
                status: matchup.status.rawValue,
                startTime: matchup.startTime,
                isPlayoff: false, // TODO: Detect playoff status
                isChopped: false, // TODO: Detect chopped leagues
                isEliminated: false // TODO: Detect elimination
            ),
            myTeam: myTeam,
            opponentTeam: opponentTeam,
            league: leagueDescriptor,
            lastUpdated: Date()
        )
    }
    
    /// Build TeamSnapshot from FantasyTeam
    private func buildTeamSnapshot(from team: FantasyTeam) -> TeamSnapshot {
        let roster = team.roster.map { player in
            buildPlayerSnapshot(from: player)
        }
        
        return TeamSnapshot(
            info: TeamSnapshot.TeamInfo(
                teamID: team.id,
                ownerName: team.ownerName,
                record: formatRecord(team.record),
                avatarURL: team.avatar
            ),
            score: TeamSnapshot.ScoreInfo(
                actual: team.currentScore ?? 0.0,
                projected: team.projectedScore ?? 0.0,
                winProbability: nil, // TODO: Calculate from matchup
                margin: 0.0 // TODO: Calculate from opponent
            ),
            roster: roster
        )
    }
    
    /// Build PlayerSnapshot from FantasyPlayer
    private func buildPlayerSnapshot(from player: FantasyPlayer) -> PlayerSnapshot {
        PlayerSnapshot(
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
                delta: 0.0, // TODO: Calculate delta from previous update
                lastActivity: nil, // TODO: Track activity
                gameStatus: player.gameStatus?.status  // 🔥 FIX: Use .status property
            ),
            context: PlayerSnapshot.PlayerContext(
                position: player.position,
                lineupSlot: player.lineupSlot,
                isStarter: player.isStarter,
                team: player.team,
                injuryStatus: player.injuryStatus,
                jerseyNumber: player.jerseyNumber,
                kickoffTime: nil // TODO: Get from game data
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
                
                // 🔥 NEW: Detect changed players
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
    
    /// 🔥 NEW: Detect which players changed between snapshots
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
    
    /// 🔥 NEW: Check if individual player changed
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
    
    /// 🔥 NEW: Get changed players since last refresh
    func getChangedPlayers() -> Set<String> {
        return changedPlayerIDs
    }
    
    /// 🔥 NEW: Get all players from cache (for initial load)
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
        let gameStatus: String?  // 🔥 FIX: Store as String, not enum
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
    let platform: LeagueSource  // 🔥 FIX: Use LeagueSource
    let avatarURL: String?
}