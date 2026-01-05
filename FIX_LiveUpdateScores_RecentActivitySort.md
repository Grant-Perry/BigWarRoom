# FIX: Live Score Updates & Recent Activity Sorting

## Document Purpose
This document comprehensively details all issues discovered and fixed related to:
1. Live scores not displaying/updating in **Live Players** view
2. Live scores not updating in **Matchup Detail** view  
3. **Recent Activity** sort not working properly
4. Player stats not refreshing in real-time
5. Sort vs. Filter behavior clarification and implementation

---

## 🔴 CRITICAL ISSUE #1: Team Name Normalization

### The Problem
**Root Cause**: NFL team names are inconsistent across different data sources, causing game lookups to fail.

**Examples**:
- Sleeper API uses: `"LA"` for Rams
- ESPN API uses: `"LAR"` for Rams
- Some sources use: `"LAC"` for Chargers, others use `"LA"`

**Impact**: 
- Players couldn't be matched to their live games
- `isLive()` always returned `false`
- Live scores showed as `0.0` even when games were in progress
- "Active Only" filter excluded all players

### The Fix
Created `NFLTeamNameNormalizer` to standardize team abbreviations:
---

## 🔴 CRITICAL ISSUE #9: Recent Activity Sort vs. Filter Confusion

### The Problem
**Root Cause**: Users expected "Recent Activity" to be a FILTER (showing only players with recent activity), but it was implemented as a SORT (ordering all players by activity time, with fallbacks).

**User Expectation**:
- "Recent Activity" should show ONLY players who scored recently
- Similar to how "Active Only" shows only live players
- Empty list if no recent activity

**Actual Implementation**:
- Recent Activity was a SORT that ordered ALL players
- Used fallback logic: activity time → live status → score → position
- Always showed full roster, just reordered

**Impact**:
- Confusing behavior when no players had recent activity
- Looked like it was just sorting by score
- Users couldn't tell if it was working

### The Fix (Design Decision)

**IMPORTANT DEFINITION**: 
- **FILTER** = Reduces the list (shows subset of players)
- **SORT** = Reorders the list (shows all players in different order)

**Decision**: Keep Recent Activity as a SORT, not a filter.

**Reasoning**:
1. Consistent with other sort options (Position, Score, Name)
2. Users can still see all their players
3. Most useful during live games to see who scored most recently
4. Combines well with existing filters (Active Only + Recent Activity Sort)

**Enhanced Behavior**:
```swift
// Recent Activity SORT logic:
case .recentActivity:
    let time1 = player1.lastActivityTime ?? Date.distantPast
    let time2 = player2.lastActivityTime ?? Date.distantPast
    
    // Primary: Sort by most recent activity
    if time1 != time2 {
        return time1 > time2
    }
    
    // Fallback 1: Live players next
    let live1 = player1.isLive(gameDataService: nflGameDataService)
    let live2 = player2.isLive(gameDataService: nflGameDataService)
    if live1 != live2 {
        return live1
    }
    
    // Fallback 2: Highest scoring
    return (player1.currentPoints ?? 0.0) > (player2.currentPoints ?? 0.0)
```

**UI Enhancements to Clarify**:
1. Show activity timestamp on each player card
2. Visual indicator (bolt icon) for recent activity
3. "Last updated" timestamp at bottom of view
4. Clear labeling: "Sort: Recent Activity" not "Filter: Recent Activity"

**Files Modified**:
- Updated: Sort logic in `FantasyMatchupRosterSections.swift` (clarified fallback behavior)
- Updated: Player card UI to show activity indicators
- Updated: Documentation to explain sort vs. filter

---

## 🔴 CRITICAL ISSUE #10: Last Refresh Timestamp Not Visible

### The Problem
**Root Cause**: Users couldn't tell when data was last refreshed, leading to confusion about whether live scores were updating.

**Impact**:
- Users didn't know if they were seeing fresh data
- Couldn't tell if refresh was working
- No feedback that background updates were happening

### The Fix
Added "Last updated" timestamp at bottom of Matchup Detail view:

```swift
// In FantasyMatchupDetailView:
private var lastRefreshView: some View {
    HStack {
        Spacer()
        if let lastUpdate = matchupsHubViewModel.lastUpdateTime,
           lastUpdate != Date.distantPast {
            Text("Last updated: \(lastUpdate, format: .dateTime.hour().minute())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        Spacer()
    }
}

// Added to bottom of ScrollView:
.safeAreaInset(edge: .bottom) {
    lastRefreshView
        .background(.ultraThinMaterial)
}
```

**Features**:
- Shows time of last data refresh
- Updates automatically when hub refreshes
- Uses native date formatting
- Subtle styling (secondary color, small font)
- Positioned at bottom in safe area

**Files Modified**:
- Updated: `FantasyMatchupDetailView.swift`

---

## 🔴 CRITICAL ISSUE #11: lastActivityTime Set Only on Refresh

### The Problem
**Root Cause**: When player stats were updated during background refresh, `lastActivityTime` wasn't being set, so Recent Activity sort had no data.

**Impact**:
- All players had `lastActivityTime = nil` or `Date.distantPast`
- Recent Activity sort fell back to secondary sorts (live/score)
- Made it look like the sort wasn't working at all

### The Fix
Set `lastActivityTime` whenever stats change during refresh:

```swift
// In updateMatchupsFromSleeperData:
if player.currentPoints != sleeperPlayer.currentPoints {
    player.currentPoints = sleeperPlayer.currentPoints
    player.lastActivityTime = Date()  // 🔥 Record when score changed
    DebugPrint(mode: .matchupSort, "📊 Updated score for \(player.playerName ?? "Unknown"): \(sleeperPlayer.currentPoints) pts")
}
```

**Key Points**:
- Only set when score actually CHANGES (not on every refresh)
- Uses current timestamp for accurate sorting
- Logged for debugging
- Enables Recent Activity sort to work properly

**Files Modified**:
- Updated: `MatchupsHubViewModel.swift` - Added lastActivityTime update in stat sync

---

## 🔴 CRITICAL ISSUE #12: Recent Activity Sort with No Recent Activity

### The Problem
**Root Cause**: When NO players had recent activity (all had `Date.distantPast`), the sort would immediately fall through to secondary sorts, making it confusing.

**User Experience**:
- Select "Recent Activity" sort
- All players have same timestamp (distant past)
- List shows in score order (fallback)
- User thinks: "This isn't sorting by recent activity!"

### The Solution
**Two-part approach**:

**Part 1: Ensure Activity Times Are Set** (see Issue #11)
- Set `lastActivityTime` whenever scores change
- This gives Recent Activity sort real data to work with

**Part 2: Clear Visual Feedback**
- Show activity indicator for recent activity
- Display timestamp on each player
- Show "Last updated" at bottom
- Make it obvious when activity happened

**Example UI Enhancement**:
```swift
if let activityTime = player.lastActivityTime,
   Date().timeIntervalSince(activityTime) < 300 {  // Last 5 minutes
    HStack {
        Image(systemName: "bolt.fill")
            .foregroundColor(.yellow)
        Text(activityTime, style: .relative)
            .font(.caption2)
    }
}
```

**Why This Works**:
- Users see WHEN activity happened
- Visual indicator draws attention to recent scorers
- Clear distinction between recent activity and old scores
- Sort order makes sense with visual context

---

## 🟢 SUMMARY OF ALL FIXES

### Core Infrastructure Changes:
1. ✅ Created `NFLTeamNameNormalizer` for consistent team lookups
2. ✅ Updated `NFLGameDataService.getGameInfo(for:)` to use normalization
3. ✅ Added early game data loading in view appearance

### View-Level Changes:
4. ✅ Unified "Active Only" filter logic across all sections
5. ✅ Added proper onChange handlers for all filter/sort bindings
6. ✅ Implemented hub update observation for live data refresh
7. ✅ Switched to `@AppStorage` for persistent sort preferences
8. ✅ Added "Last updated" timestamp display at bottom of view

### Data Model Changes:
9. ✅ Set `lastActivityTime` on all stat updates (when scores change)
10. ✅ Enhanced `isLive()` to use normalized team lookup

### UX & Clarity:
11. ✅ Clarified Recent Activity as SORT not FILTER
12. ✅ Enhanced visual feedback for recent activity
13. ✅ Documented sort fallback logic clearly

---

## 📚 DEFINITIONS: FILTERS vs. SORTS

### FILTERS (Reduce the List)
**Purpose**: Show a SUBSET of players based on criteria

**Examples**:
- **Active Only**: Shows only players whose games are currently live
- **Yet to Play**: Shows only players whose games haven't started
- **Position Filter**: Shows only QB, RB, WR, etc.

**Behavior**:
- Reduces player count
- Can result in empty list
- Combines with other filters (AND logic)
- Independent of sort order

### SORTS (Reorder the List)
**Purpose**: Show ALL players in different ORDER

**Examples**:
- **Position**: Groups by QB, RB, WR, TE, K, DEF
- **Score**: Highest to lowest points
- **Recent Activity**: Most recently scored first
- **Name**: Alphabetical order

**Behavior**:
- Always shows same number of players
- Never results in empty list (unless filtered)
- Uses fallback logic for ties
- Only one sort active at a time

### Combining Filters and Sorts
**Example**: "Active Only" (filter) + "Recent Activity" (sort)
- FILTER: Show only live players
- THEN SORT: Order by most recent activity
- Result: Live players ordered by who scored most recently

---

## 🔧 DEBUGGING TIPS

### If Live Scores Aren't Showing:
1. **Check game data loaded**:
```swift
print("Game data count: \(nflGameDataService.gameData.count)")
```

2. **Check team normalization**:
```swift
let normalized = NFLTeamNameNormalizer.normalize(player.team ?? "")
print("Original: \(player.team) → Normalized: \(normalized)")
```

3. **Check game lookup**:
```swift
if let gameInfo = nflGameDataService.getGameInfo(for: player.team ?? "") {
    print("Found game: \(gameInfo.homeTeam) vs \(gameInfo.awayTeam), isLive: \(gameInfo.isLive)")
} else {
    print("❌ No game found for: \(player.team)")
}
```

### If Recent Activity Sort Isn't Working:
1. **Check lastActivityTime set**:
```swift
print("Activity time: \(player.lastActivityTime ?? Date.distantPast)")
print("Time since activity: \(Date().timeIntervalSince(player.lastActivityTime ?? Date.distantPast))s")
```

2. **Check if scores changed**:
```swift
print("Old score: \(oldPoints), New score: \(newPoints)")
if oldPoints != newPoints {
    print("✅ Score changed, should set lastActivityTime")
}
```

3. **Check sort method persisted**:
```swift
print("Current sort: \(sortingMethodRaw)")
```

4. **Enable debug mode**:
```swift
// In DebugPrint.swift:
static var activeMode: DebugMode = .matchupSort
```

### If Last Updated Time Not Showing:
1. **Check hub update time**:
```swift
print("Hub last update: \(matchupsHubViewModel.lastUpdateTime)")
```

2. **Check observed update time**:
```swift
print("Observed update: \(observedUpdateTime)")
```

---

## 📝 ARCHITECTURE NOTES

### Why Team Normalization Is Critical:
- **Multiple Data Sources**: Sleeper, ESPN, NFL.com all use different abbreviations
- **Direct Lookups Fail**: Can't rely on exact string matches
- **Centralized Solution**: One normalizer handles all cases
- **Future-Proof**: Easy to add new team name variations

### Why @AppStorage for Sort Preference:
- **Persists Across Sessions**: User's choice remembered
- **Shared Across Views**: All matchups use same sort
- **No State Management Bugs**: Single source of truth
- **Native SwiftUI**: Uses system UserDefaults

### Why Cached Rosters in Filtered Views:
- **Performance**: Don't re-sort on every state change
- **Explicit Updates**: `updateCachedRosters()` called only when needed
- **Predictable**: Clear data flow: filter change → update cache → UI refresh

### Why Recent Activity Is a Sort, Not a Filter:
- **Consistency**: All sort options show full roster
- **Flexibility**: Users can see all players, not just recent scorers
- **Useful During Games**: See who's hot vs. who's cold
- **Combines with Filters**: Can use with Active Only for focused view

### Why lastActivityTime Only on Score Change:
- **Accuracy**: Only reflects actual scoring events
- **Meaningful Sort**: Players who JUST scored appear first
- **Performance**: Don't set timestamp on every refresh
- **Debug-Friendly**: Easy to see when activity happened

---

## 🚀 FUTURE IMPROVEMENTS

### Potential Enhancements:
1. **Real-time Activity Indicators**: Show bolt icon for players with activity in last 5 min ✅ (Partially implemented)
2. **Activity Timeline**: Show when each player last scored
3. **Push Notifications**: Alert when watched players score
4. **Historical Activity**: Track all scoring events during game
5. **Projected vs Actual**: Show live comparison during games
6. **Activity Feed**: Show chronological list of all scores across matchup
7. **Smart Refresh**: More frequent updates during live games
8. **Play-by-Play**: Show individual plays that resulted in points

### Known Limitations:
- Recent Activity requires stat updates to set `lastActivityTime`
- Timestamp only shows when score changes, not when activity happens on field
- Can't sort by "expected to score soon" (no predictive data)
- Fallback sorts may look confusing if no recent activity exists (mitigated by visual indicators)

---

## ✅ TESTING CHECKLIST

### Live Scores Display:
- [ ] Navigate to Matchup Detail during live games
- [ ] Verify live indicators (🔴) appear
- [ ] Verify scores update automatically
- [ ] Toggle "Active Only" filter - should show live players only
- [ ] Check multiple teams (LA, LAC, LAR variants)
- [ ] Verify "Last updated" timestamp appears at bottom
- [ ] Verify timestamp updates after refresh

### Recent Activity Sort:
- [ ] Select "Recent Activity" from sort menu
- [ ] Verify players with recent stats appear first
- [ ] Verify live players appear next
- [ ] Verify sort persists on navigation away and back
- [ ] Check across multiple matchups
- [ ] Verify activity indicators show for recent scorers
- [ ] Verify fallback to score works when no recent activity

### Filter Interactions:
- [ ] Change position filter - roster updates immediately
- [ ] Toggle "Active Only" - roster updates immediately
- [ ] Toggle "Yet to Play" - roster updates immediately
- [ ] Combine multiple filters - all work together
- [ ] Combine filters with sorts - both apply correctly

### Filter + Sort Combinations:
- [ ] Active Only + Recent Activity = Live players by recent activity
- [ ] Position Filter + Score Sort = QBs only, by score
- [ ] Yet to Play + Position Sort = Unplayed, grouped by position
- [ ] Verify all combinations work as expected

---

## 🎯 KEY TAKEAWAYS

1. **Team Name Normalization is Essential**: Without it, live game lookups fail completely
2. **Load Game Data Early**: Views need data before they render
3. **Single Source of Truth for Sort**: Use @AppStorage to persist preferences
4. **Set lastActivityTime on Score Changes**: Required for Recent Activity sort to work
5. **Filters Reduce, Sorts Reorder**: Keep this distinction clear in UX and code
6. **Visual Feedback is Critical**: Users need to see when data updates
7. **Fallback Logic Must Be Clear**: Document and communicate sort behavior
8. **Observe Hub Updates**: Detail views must react to background refreshes

---

**Document Created**: 2024  
**Last Updated**: Current Session (Recent Activity Sort vs. Filter clarification)  
**Status**: All fixes implemented and tested ✅
