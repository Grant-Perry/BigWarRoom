# BigWarRoom Quick Reference Guide

## 📍 Navigation Cheatsheet

### Main Entry Point
**Start Here:** `DraftWarRoomApp.swift` → `ProgressiveAppView`

### File Lookup Patterns
| Need to Find... | Location |
|---|---|
| App configuration | `Configuration/AppConstants.swift` |
| Fantasy league data | `Models/FantasyModels.swift` |
| ESPN integration | `Services/ESPNAPIClient.swift` |
| Sleeper integration | `Services/SleeperAPIClient.swift` |
| Watched players feature | `Services/PlayerWatchService.swift` |
| Mission Control tab | `Views/MatchupsHub/MatchupsHubView.swift` |
| Live Players tab | `Views/AllLivePlayers/AllLivePlayersView.swift` |
| Player stats display | `Views/PlayerStatsCardView.swift` |
| Injury status badges | `Views/Shared/InjuryStatusBadgeView.swift` (NEW) |
| Onboarding/Settings | `Views/OnBoardingView.swift` |

---

## 🎯 Common Tasks

### Add a New Tab
```swift
// In ProgressiveAppView.mainAppTabs:
NavigationStack {
    YourNewView()
}
.tabItem {
    Image(systemName: "icon.name")
    Text("Tab Name")
}
.tag(5)  // Next available tag
```

### Access Current Week
```swift
let currentWeek = WeekSelectionManager.shared.selectedWeek
```

### Access Current Season Year
```swift
let year = AppConstants.currentSeasonYear  // "2024", "2025", "2026"
```

### Publish a State Update
```swift
@Published var myData: [String] = []
// Automatically triggers view updates
```

### Watch a Player
```swift
await PlayerWatchService.shared.addWatchedPlayer(...)
```

### Get Fantasy Matchups
```swift
let viewModel = MatchupsHubViewModel.shared
await viewModel.loadAllMatchups()
```

---

## 🔌 API Integration Points

### ESPN API
**Client:** `ESPNAPIClient.shared`
**Authentication:** SWID + ESPN_S2 token (year-specific)
**Key Methods:**
- Fetch leagues
- Get matchups
- Fetch player stats
- Get scoring settings

### Sleeper API
**Client:** `SleeperAPIClient.shared`
**Authentication:** Username (default: "Gp0")
**Key Methods:**
- Fetch user leagues
- Get matchups
- Get player stats
- Get draft info

### Unified Access
**Manager:** `UnifiedLeagueManager.shared`
**Returns:** Both Sleeper & ESPN leagues in one array

---

## 🎨 UI Component Reuse

### Player Cards
- **Base:** `PlayerCardView.swift`
- **Image:** `PlayerImageView.swift` (with fallback)
- **Injury Badge:** `InjuryStatusBadgeView.swift`
- **Stats:** Various stat components in `/Components/`

### Matchup Display
- **Builder:** `MatchupCardViewBuilder.swift`
- **Components:** 31+ specialized cards in `MatchupsHub/Components/`

### Loading States
- **Progress:** `MatchupsHubLoadingProgressBarView.swift`
- **Animation:** `MatchupsHubLoadingHeroAnimationView.swift`

---

## 📊 Key Singletons

| Singleton | Purpose | Access |
|---|---|---|
| `CentralizedAppLoader.shared` | App initialization | `@StateObject` |
| `MatchupsHubViewModel.shared` | Matchups state | `@StateObject` |
| `AllLivePlayersViewModel.shared` | Live player stats | `@StateObject` |
| `PlayerWatchService.shared` | Watched players | `@StateObject` |
| `WeekSelectionManager.shared` | Current week | Read via `.selectedWeek` |
| `SeasonYearManager.shared` | Season year | Read via `.selectedYear` |
| `SharedStatsService.shared` | All player stats | Read via published properties |
| `UnifiedLeagueManager.shared` | All leagues | Manual calls |
| `ESPNCredentialsManager.shared` | ESPN auth | Manual calls |
| `SleeperCredentialsManager.shared` | Sleeper auth | Manual calls |

---

## 🔄 Data Flow Examples

### Player Score Update Flow
```
SharedStatsService
  ↓ (weekly stats loaded)
AllLivePlayersViewModel
  ↓ (processes data)
PlayerScoreBarCardPlayerImageView
  ↓ (displays)
InjuryStatusBadgeView (shows badge)
```

### Watched Player Flow
```
PlayerWatchService (observable)
  ↓ (adds watched player)
WatchedPlayersSheet (listens)
  ↓ (displays list)
UserDefaults (persists)
  ↓ (survives app restart)
```

### League Fetch Flow
```
UnifiedLeagueManager
  ├─→ ESPNAPIClient (ESPN leagues)
  ├─→ SleeperAPIClient (Sleeper leagues)
  └─→ allLeagues (combined, sorted)
```

---

## 🏷️ Injury Status Colors

| Status | Badge Color | Text | Code |
|---|---|---|---|
| Questionable | Yellow | Q | "QUESTIONABLE" |
| Doubtful | Orange | D | "DOUBTFUL" |
| Out | Red | O | "OUT" |
| Injured Reserve | Red | IR | "INJURED_RESERVE" / "IR" |
| Probable | Green | P | "PROBABLE" |
| Bye | Blue | BYE | "BYE" |
| Suspended | Purple | S | "SUSPENDED" |
| PUP | Gray | PUP | "PHYSICALLY_UNABLE_TO_PERFORM" |
| NFI | Gray | NFI | "NON_FOOTBALL_INJURY" |

---

## 💾 Persistence Keys

| Data | UserDefaults Key | Service |
|---|---|---|
| Watched Players | `BigWarRoom_WatchedPlayers` | PlayerWatchService |
| Watch Settings | `BigWarRoom_WatchSettings` | PlayerWatchService |
| Sort Direction | `BigWarRoom_WatchedPlayers_SortDirection` | PlayerWatchService |
| Sort Method | `BigWarRoom_WatchedPlayers_SortMethod` | PlayerWatchService |
| Manual Ordering | `BigWarRoom_WatchedPlayers_ManualOrder` | PlayerWatchService |
| Debug Mode | `debugModeEnabled` | AppConstants |
| ESPN Year | `selectedESPNYear` | AppConstants (via @AppStorage) |

---

## 🎬 Tab Tags Reference

| Tab | Tag | View | ViewModel |
|---|---|---|---|
| Mission Control | 0 | MatchupsHubView | MatchupsHubViewModel |
| Intelligence | 1 | OpponentIntelligenceDashboardView | OpponentIntelligenceViewModel |
| Schedule | 2 | NFLScheduleView | NFLScheduleViewModel |
| Live Players | 3 | AllLivePlayersView | AllLivePlayersViewModel |
| More | 4 | MoreTabView | Various |

---

## 🚨 Modified Files (Current Session)

Files with uncommitted changes:
- `BigWarRoom.xcodeproj/project.pbxproj` (project config)
- `PlayerWatchService.swift` (watched player tracking)
- `PlayerScoreBarCardPlayerImageView.swift` (live player card)
- `FantasyPlayerCardContentView.swift` (fantasy tab)
- `WatchedPlayersSheet.swift` (watched players display)
- `PlayerImageView.swift` (player image + badge)

**Staged for Commit:**
- `InjuryStatusBadgeView.swift` (new reusable badge component)

---

## 🔗 Useful Patterns

### Subscribe to Week Changes
```swift
@StateObject private var weekManager = WeekSelectionManager.shared

// In view init or onAppear:
weekManager.$selectedWeek
    .sink { newWeek in
        print("Week changed to: \(newWeek)")
    }
```

### Loading Multiple Items
```swift
await withTaskGroup(of: Void.self) { group in
    group.addTask { await loadESPNLeagues() }
    group.addTask { await loadSleeperLeagues() }
    group.addTask { await loadPlayerStats() }
    // All run concurrently
}
```

### Safe Optional Image Loading
```swift
Image(uiImage: playerImage ?? UIImage(named: "placeholder") ?? UIImage())
    .resizable()
    .scaledToFit()
```

### Formatted Number Display
```swift
String(format: "%.2f", statValue)  // "123.45"
String(format: "%.1f", projectedPoints)  // "98.7"
```

---

## 🐛 Debugging Tips

### Enable Debug Logs
1. Go to Settings/OnBoardingView
2. Toggle `debugModeEnabled` in UserDefaults
3. Check `AppConstants.debug` (defaults to true if not set)

### Test with Different Weeks
- Use `WeekSelectionManager.shared.selectedWeek`
- Change in onboarding/settings view
- Data auto-refreshes

### Verify API Calls
- Check `EndpointValidationService` for endpoint health
- Log in respective APIClient (ESPN/Sleeper)
- Check credentials via CredentialsManager

### Check Cached Data
- `PlayerStatsCache.swift` manages caching
- Cache duration: `AppConstants.maxCacheDays` (5 days)
- Clear via app restart or manual clearance

---

## 🎯 Next Steps for Development

### If Working on Player Display
1. Update `PlayerImageView.swift` for image changes
2. Update `InjuryStatusBadgeView.swift` for badge styling
3. Test in all 4 tabs: MatchupsHub, Fantasy, AllLivePlayers, Intelligence
4. Check `PlayerCardImageView.swift` variants

### If Adding New Data
1. Define model in appropriate `Models/*.swift` file
2. Add decoding in API client
3. Add to ViewModel @Published property
4. Create UI component in Views/
5. Add tests/previews

### If Modifying Services
1. Keep singleton pattern
2. Use @Published for reactive updates
3. Handle errors gracefully
4. Avoid blocking UI (use Task, async/await)
5. Cache when appropriate

---

**Last Updated:** October 23, 2025 | **Version:** 8.57
