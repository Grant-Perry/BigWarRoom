# MatchupDataStore Architecture

## Why this exists
- Provide a **single source of truth** for all matchup + roster data (regular, chopped, playoffs).
- Eliminate duplicated fetch pipelines across Mission Control, Live Players, Matchup Detail, Lineup RX, etc.
- Reduce API thrash and main-thread churn by **hydrating data once** and fanning out lightweight snapshots to every surface.
- Enable lazy hydration: only load the matchups users actually view while keeping baseline league context cached.

## Design goals
1. **Canonical data ownership** – store owns hydration + cache lifecycle, view models become presentation layers.
2. **Lazy & incremental loading** – hydrate initial league summary fast, fetch individual matchups on demand.
3. **Real-time friendly** – support delta updates without blocking UI; allow fast snapshot reads on the main actor.
4. **Observable** – emit async snapshots so SwiftUI/Observation can react without polling.
5. **Extensible** – designed to plug in projections, score breakdowns, lineup intelligence later.

## Core data structures
- `MatchupDataStore.LeagueKey`: `(leagueID: String, platform: LeaguePlatform, seasonYear: String, week: Int)`
- `MatchupSnapshot.ID`: `(leagueID + matchupID + week)` – unique per matchup/week.
- `MatchupSnapshot`:
  - `metadata`: status, start time, isPlayoff, chopped flags, elimination state.
  - `myTeam`, `opponentTeam`: `TeamSnapshot` (roster, scores, projections, live flags).
  - `league`: lightweight descriptor (name, avatar, platform).
  - `lastUpdated`: timestamp when data was hydrated.
- `TeamSnapshot`:
  - `info`: ids, owner name, record, avatar.
  - `score`: actual/projection/win probability margin.
  - `roster`: `[PlayerSnapshot]` (starters + bench, sorted by slot).
- `PlayerSnapshot`:
  - `identity`: player IDs + names + platform IDs.
  - `metrics`: current score, projection, delta, last activity, game status.
  - `context`: position, lineup slot, injury, jersey number, team, kickoff time.

Internally the store holds:
```swift
actor MatchupDataStore {
    struct LeagueCache {
        var summary: LeagueSummary
        var matchups: [MatchupSnapshot.ID: MatchupSnapshot]
        var state: LoadState
        var pendingTasks: [MatchupSnapshot.ID: Task<MatchupSnapshot, Error>]
        var lastRefreshed: Date
    }
}
```

## Public interface (async-safe)
```swift
protocol MatchupDataStoreInterface {
    func warmLeagues(_ leagues: [LeagueDescriptor], week: Int) async
    func hydrateMatchup(_ id: MatchupSnapshot.ID) async throws -> MatchupSnapshot
    func cachedMatchup(_ id: MatchupSnapshot.ID) -> MatchupSnapshot?
    func cachedMatchups(for league: LeagueKey) -> [MatchupSnapshot]
    func observeLeague(_ league: LeagueKey) -> AsyncStream<LeagueSnapshot>
    func refresh(league: LeagueKey?, force: Bool) async
    func clearCaches() async
}
```
- **Async stream** emits `LeagueSnapshot` whenever we add/update/remove a matchup or change load state.
- Hydration requests dedupe via `pendingTasks` so multiple consumers await the same work.

## Loading workflow
1. **Initialization** – DI layer creates store with dependencies (`UnifiedLeagueManager`, `LeagueMatchupProviderFactory`, `SharedStatsService`, `GameStatusService`, etc.).
2. **warmLeagues** – Mission Control calls once per app start/refresh.
   - Fetch minimal league data (IDs, settings, chopped detection) via `UnifiedLeagueManager`.
   - Create caches with `state = .loadingBasic`.
   - Immediately emit baseline snapshot (for skeleton UI) so cards appear instantly.
3. **hydrateMatchup** – called when we need actual rosters (Mission Control hero cards, detail view, Live Players extraction).
   - Creates provider (`LeagueMatchupProvider`) and performs network fetch if roster not cached or `force`.
   - Builds `MatchupSnapshot` using shared services (stats, game status, projections).
   - Updates cache, emits new snapshot, returns to caller.
4. **Refresh** – triggered by SmartRefreshManager or manual pull-to-refresh.
   - Invalidates or delta-refreshes league caches.
   - Uses provider diffing to only rebuild changed matchups.
   - Emits updates for changed snapshots; leaves everything else untouched.

## Cache invalidation strategy
- Default TTL per league (e.g. 90 seconds) when games live; extended when no live games.
- Manual refresh (`force == true`) bypasses TTL.
- When week changes, we nuke caches for previous week (explicit API call from WeekSelectionManager).
- `clearCaches()` for debugging / logout flows.

## Consumers & responsibilities
| Consumer | Responsibilities | Store usage |
| -------- | ---------------- | ----------- |
| `MatchupsHubViewModel` | Present league cards, sorting, micro mode state | Subscribe to `observeLeague`, map snapshots to `UnifiedMatchup` view models. No network calls. |
| `AllLivePlayersViewModel` | Aggregate starters, filters, live deltas | Pull `cachedMatchups` and flatten rosters; subscribe for updates to recompute deltas. |
| `LeagueMatchupsTabView` / detail view | Show specific matchup + lazy neighbors | Call `hydrateMatchup` for selected + adjacent matchups; read cached data for fast display. |
| `LineupRX`, Start/Sit, Schedule overlays | Reuse the same snapshots for their analytics without re-fetching data | `cachedMatchup` / `hydrateMatchup` as needed. |

Each consumer must:
- Pass the correct `LeagueKey` (week-sensitive).
- Request lazy hydration instead of instantiating providers directly.
- Avoid mutating `MatchupSnapshot`; treat as immutable value types.

## Dependency injection
- `DraftWarRoomApp.setupServicesWithDI()` constructs `MatchupDataStore` once and registers via `.setSharedInstance` (until we fully remove the bridge).
- Update `MatchupsHubViewModel`, `AllLivePlayersViewModel`, etc. initializers to accept `MatchupDataStoreInterface`.
- Pull store from Environment in SwiftUI as needed for detail view / tab view.

## Instrumentation & telemetry
- Log load duration, cache hit ratio, pending task dedupe count.
- Report stale data warnings (if hydration > TTL) via `DebugPrint` limited mode.
- Hook into SmartRefreshManager to adjust intervals based on active leagues count.

## Future extensions
- Persist warm caches to disk between launches (once data contract is stable).
- Integrate projections and score breakdown enrichment in the store (rather than view-specific requests).
- Add write APIs (e.g., lineup swaps) once we support editing.
- Expose Combine/Observation bridges for older view models still using `@Published`.

---
This document is the source of truth for aligning every feature with the centralized matchup domain. Implementation changes must update this spec to avoid regressions.
