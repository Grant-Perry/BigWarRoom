# Debug Print Retrofit Plan

## DCO Analysis & DebugMode Mapping

Based on the console output, here are all the debug statement categories and their appropriate `DebugMode` assignments:

---

### 1. **Loading/Initialization** → `.viewModelLifecycle`
**Files:**
- `BigWarRoom/ViewModels/MatchupsHubViewModel.swift`

**Statements:**
```
🔥 CREDENTIALS OBSERVATION: Setting up @Observable-based credential monitoring
ℹ️ [LoadingScreen] Loading complete - showing onboarding: false
```

**Action:** 
```swift
debugPrint(mode: .viewModelLifecycle, "Setting up @Observable-based credential monitoring")
```

---

### 2. **NFL Data Fetching** → `.nflData` (NEW MODE NEEDED)
**Files:**
- `BigWarRoom/Models/NFLGameModels.swift`

**Statements:**
```
🔥 NFL FETCH: Fetching fresh data for week 9, year 2025
🔥 NFL SUCCESS: Received fresh data with 14 games
🔥 ESPN RAW DATA for LAC vs TEN: [details]
```

**Action:**
```swift
// Add new mode in DebugLogger.swift:
static let nflData = DebugMode(rawValue: 1 << 11)

// Replace prints:
debugPrint(mode: .nflData, "Fetching fresh data for week \(week), year \(year)")
debugPrint(mode: .nflData, limit: 2, "ESPN RAW DATA for \(game)...")  // Limit verbose game data
```

---

### 3. **Matchups Hub Loading** → `.matchupLoading`
**Files:**
- `BigWarRoom/ViewModels/MatchupsHubViewModel+Loading.swift`
- `BigWarRoom/ViewModels/MatchupsHubViewModel.swift`

**Statements:**
```
🔥🔥🔥 PUBLIC API: MatchupsHubViewModel.loadAllMatchups() called
🔥🔥🔥 MATCHUPS HUB: performLoadAllMatchups STARTING
🔥🔥🔥 MATCHUPS HUB: performLoadAllMatchups COMPLETE
🔥🔥🔥 MATCHUPS HUB: loadSingleLeague called for [league name]
✅ Step 0: NFL data loaded
✅ Step 1: Found 16 leagues
✅ Step 2: Matchups loaded
```

**Action:**
```swift
debugPrint(mode: .matchupLoading, "MatchupsHubViewModel.loadAllMatchups() called from \(source)")
debugPrint(mode: .matchupLoading, "performLoadAllMatchups STARTING")
debugPrint(mode: .matchupLoading, "performLoadAllMatchups COMPLETE")
debugPrint(mode: .matchupLoading, limit: 5, "loadSingleLeague called for \(leagueName)")  // Limit repeats
```

---

### 4. **League Provider Operations** → `.leagueProvider`
**Files:**
- `BigWarRoom/Services/LeagueMatchupProvider.swift`
- `BigWarRoom/ViewModels/MatchupsHubViewModel+Loading.swift`

**Statements:**
```
🎯 LeagueMatchupProvider.fetchMatchups() called for [id], league.source=[source]
→ Identifying team ID for [league]...
✅ Found team ID: [id]
→ Fetching matchups via provider.fetchMatchups()...
→ Fetching Sleeper data
→ Fetching ESPN data
← Returning [n] matchups
✅ Fetched [n] matchups
```

**Action:**
```swift
debugPrint(mode: .leagueProvider, "fetchMatchups() called for \(leagueID), source=\(source)")
debugPrint(mode: .leagueProvider, limit: 10, "Identifying team ID for \(leagueName)...")
debugPrint(mode: .leagueProvider, "Found team ID: \(teamID)")
debugPrint(mode: .leagueProvider, "Returning \(matchups.count) matchups")
```

---

### 5. **Roster/Manager Mapping** → `.dataSync`
**Files:**
- `BigWarRoom/ViewModels/FantasyViewModel+Sleeper.swift`

**Statements:**
```
Populated rosterIDToManagerID with [n] entries
```

**Action:**
```swift
debugPrint(mode: .dataSync, limit: 5, "Populated rosterIDToManagerID with \(count) entries")
```

---

### 6. **ESPN Data Processing** → `.espnAPI`
**Files:**
- `BigWarRoom/Services/ESPNAPIClient.swift`
- `BigWarRoom/ViewModels/FantasyViewModel+ESPN.swift` (likely)

**Statements:**
```
🔥 processESPNData called for [n] teams
```

**Action:**
```swift
debugPrint(mode: .espnAPI, "processESPNData called for \(teams.count) teams")
```

---

### 7. **Loading Sessions** → `.matchupLoading`
**Files:**
- `BigWarRoom/ViewModels/MatchupsHubViewModel+Loading.swift`

**Statements:**
```
🔥 LOADING SESSION [UUID]: Starting new loading session
🔥 LOADING SESSION [UUID]: Completed - myMatchups.count=[n]
```

**Action:**
```swift
debugPrint(mode: .matchupLoading, "LOADING SESSION \(sessionID): Starting new loading session")
debugPrint(mode: .matchupLoading, "LOADING SESSION \(sessionID): Completed - myMatchups.count=\(count)")
```

---

### 8. **Record/Standings Sync** → `.recordCalculation`
**Files:**
- `BigWarRoom/Services/LeagueMatchupProvider.swift`

**Statements:**
```
📊 Standings fetch with ?view=mStandings&view=mTeam: 10/10 teams have records
✅ Found records using view: ?view=mStandings&view=mTeam
📊 Synced [n] ESPN team records to FantasyViewModel
```

**Action:**
```swift
debugPrint(mode: .recordCalculation, "Standings fetch: \(teamsWithRecords.count)/\(totalTeams) teams have records")
debugPrint(mode: .recordCalculation, "Found records using view: \(viewParams)")
debugPrint(mode: .recordCalculation, "Synced \(count) ESPN team records to FantasyViewModel")
```

---

### 9. **Refresh Operations** → `.globalRefresh`
**Files:**
- `BigWarRoom/ViewModels/MatchupsHubViewModel+Refresh.swift`

**Statements:**
```
🔥 REFRESH: Cleared cached providers for fresh scores
```

**Action:**
```swift
debugPrint(mode: .globalRefresh, "Cleared cached providers for fresh scores")
```

---

### 10. **Opponent Intelligence** → `.opponentIntel` (NEW MODE NEEDED)
**Files:**
- `BigWarRoom/ViewModels/OpponentIntelligenceViewModel.swift`

**Statements:**
```
🔄 OpponentIntelligenceViewModel: Matchups changed from [n] to [m]
🔄 Background refresh - starting injury loading...
🔄 Background refresh complete - stopping injury loading
🎯 OpponentIntelligenceViewModel: Updated with [n] opponents, [n] conflicts, [n] recommendations
```

**Action:**
```swift
// Add new mode:
static let opponentIntel = DebugMode(rawValue: 1 << 12)

// Replace prints:
debugPrint(mode: .opponentIntel, "Matchups changed from \(oldCount) to \(newCount)")
debugPrint(mode: .opponentIntel, "Background refresh - starting injury loading...")
debugPrint(mode: .opponentIntel, "Updated with \(opponents) opponents, \(conflicts) conflicts, \(recommendations) recommendations")
```

---

## New DebugModes Needed

Add these to `DebugLogger.swift`:

```swift
static let nflData           = DebugMode(rawValue: 1 << 11)  // 2048
static let opponentIntel     = DebugMode(rawValue: 1 << 12)  // 4096
```

And update `.all`:
```swift
static let all: DebugMode = [
    .globalRefresh,
    .espnAPI,
    .sleeperAPI,
    .matchupLoading,
    .recordCalculation,
    .statsLookup,
    .navigation,
    .caching,
    .leagueProvider,
    .viewModelLifecycle,
    .dataSync,
    .nflData,           // NEW
    .opponentIntel      // NEW
]
```

---

## Implementation Order

1. ✅ Add new DebugMode flags
2. Convert MatchupsHub files (highest volume)
3. Convert LeagueMatchupProvider
4. Convert NFL data fetching
5. Convert smaller files

---

## Testing Strategy

```swift
// Test each mode individually:
DebugConfig.activeMode = .matchupLoading  // See only matchup loading
DebugConfig.activeMode = .leagueProvider  // See only provider operations
DebugConfig.activeMode = [.matchupLoading, .leagueProvider]  // See both
DebugConfig.activeMode = .all  // See everything (current behavior)
DebugConfig.activeMode = .none  // See nothing (production)
```



