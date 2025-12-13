# BigWarRoom Architecture & Dependencies

## 🏢 Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Views (SwiftUI)                       │
│  - MatchupsHubView, AllLivePlayersView, FantasyViews, etc  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   ViewModels (@StateObject)                 │
│  - MatchupsHubViewModel, AllLivePlayersViewModel, etc      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Services (Singletons, Async/Await)             │
│  - API Clients, League Managers, Stat Services, etc        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Models (Data Structures)                   │
│  - FantasyModels, SleeperModels, ESPNModels, etc          │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Module Dependencies

### Core Initialization Chain
```
DraftWarRoomApp
    └─→ ProgressiveAppView
            └─→ @StateObject CentralizedAppLoader
                    ├─→ SharedStatsService
                    │   ├─→ ESPNAPIClient
                    │   ├─→ SleeperAPIClient
                    │   └─→ Models (FantasyModels, etc)
                    │
                    ├─→ MatchupsHubViewModel
                    │   ├─→ LeagueMatchupProvider
                    │   ├─→ UnifiedLeagueManager
                    │   └─→ Services
                    │
                    └─→ AllLivePlayersViewModel
                        ├─→ SharedStatsService
                        ├─→ NFLWeekService
                        └─→ Services
```

### View Model Dependency Graph

```
CentralizedAppLoader (initializer)
    ├─→ MatchupsHubViewModel (shared)
    │   ├─→ ESPNAPIClient
    │   ├─→ SleeperAPIClient
    │   ├─→ UnifiedLeagueManager
    │   ├─→ OpponentIntelligenceService
    │   └─→ GameStatusService
    │
    ├─→ AllLivePlayersViewModel (shared)
    │   ├─→ SharedStatsService
    │   ├─→ GameStatusService
    │   ├─→ NFLWeekService
    │   ├─→ PlayerWatchService
    │   └─→ StatsFacade
    │
    └─→ FantasyViewModel (various leagues)
        ├─→ ESPNAPIClient
        ├─→ SleeperAPIClient
        ├─→ ChoppedLeaderboardViewModel
        └─→ FantasyMatchupListViewModel
```

---

## 🔗 Service Interconnections

### Initialization Services
```
AppInitializationManager / CentralizedAppLoader
    ├─→ Calls all view model loaders
    ├─→ Sets initialization flags
    └─→ Enables UI rendering when ready

SharedStatsService (CRITICAL - prevents duplicates)
    ├─→ Loads weekly player stats once
    ├─→ Caches via PlayerStatsCache
    ├─→ Used by: AllLivePlayersViewModel, Others
    └─→ Key: Only loads current week stats
```

### API Layer
```
ESPNAPIClient
├─→ Uses ESPNCredentialsManager for auth
├─→ Returns: ESPNFantasyModels, ESPNModels
└─→ Handles year-specific tokens (2024/2025)

SleeperAPIClient
├─→ Uses SleeperCredentialsManager for auth
├─→ Returns: SleeperModels
└─→ Handles user resolution (username → ID)

EndpointValidationService
└─→ Health checks for both API endpoints
```

### Data Management Layer
```
UnifiedLeagueManager (League Discovery)
├─→ ESPNAPIClient (ESPN leagues)
├─→ SleeperAPIClient (Sleeper leagues)
└─→ Returns LeagueWrapper[] (combined)

LeagueMatchupProvider (Matchup Data)
├─→ Uses appropriate APIClient per league
└─→ Returns FantasyMatchup[] for week

PlayerDirectoryStore (Player Index)
├─→ Indexes all players from stats
├─→ Enables fast lookup
└─→ Used by: Search, Player Cards

PlayerMatchService (Player Matching)
├─→ Links NFL players to fantasy players
├─→ Handles name variations
└─→ Used by: Display, Watch system
```

### Feature Services
```
PlayerWatchService (Watched Opponents)
├─→ Stores: watchedPlayers[], recentNotifications[]
├─→ Persistence: UserDefaults
├─→ Subscribes to: AllLivePlayersViewModel updates
├─→ Publishes: Score changes, alerts
└─→ Used by: WatchedPlayersSheet, Views

GameStatusService (Real-time Games)
├─→ Tracks: live games, final scores
├─→ Updates: AllLivePlayersViewModel
└─→ Publishes: GameAlert notifications

OpponentIntelligenceService (Analysis)
├─→ Calculates: Win probability, matchup strength
├─→ Uses: League data, Stats
└─→ Displays in: Intelligence tab
```

### Utility Services
```
WeekSelectionManager
├─→ @Published selectedWeek: Int
├─→ Subscribers: PlayerWatchService, others
└─→ Synced with: NFLWeekService

SeasonYearManager (SSOT)
├─→ Single source for current year
├─→ Used by: AppConstants, all API calls
└─→ Updated in: Onboarding

NFLTeamRosterService (Roster Data)
├─→ Caches: Team rosters
├─→ Updates: On demand
└─→ Used by: Roster views, comparisons

TeamCodeNormalizer (Data Cleaning)
├─→ Normalizes: Team abbreviations
└─→ Example: "SF" → "SF", "SFO" → "SF"
```

---

## 📊 Data Model Relationships

```
FantasyLeague
├─→ contains: FantasyManager[] (owners)
└─→ contains: FantasyMatchup[] (per week)
         ├─→ homeTeam: FantasyTeam
         │   ├─→ manager: FantasyManager
         │   └─→ roster: FantasyPlayer[]
         │       ├─→ player: FantasyPlayer
         │       │   ├─→ nflPlayer: NFLPlayer
         │       │   ├─→ position: FantasyPosition
         │       │   └─→ stats: PlayerStats
         │       └─→ starters: FantasyPlayer[]
         └─→ awayTeam: FantasyTeam (same structure)

SleeperMatchup
├─→ roster_id: Int
├─→ points: Double
├─→ projected_points: Double
├─→ starters: [PlayerID]
└─→ players: [PlayerID]

NFLGame
├─→ homeTeam: NFLTeam
├─→ awayTeam: NFLTeam
├─→ homeScore: Int
├─→ awayScore: Int
├─→ status: GameStatus
└─→ displayInfo: GameDisplayInfo
```

---

## 🔄 Reactive Update Flow

### Week Change Event
```
User Changes Week in Settings
    ↓
WeekSelectionManager.$selectedWeek published
    ↓
Subscribers notified:
    ├─→ PlayerWatchService: handleWeekChange()
    ├─→ AllLivePlayersViewModel: loadPlayerDataForWeek()
    ├─→ MatchupsHubViewModel: loadWeeklyMatchups()
    └─→ SharedStatsService: loadCurrentWeekStats()
    ↓
Views refresh (due to @StateObject updates)
```

### Player Watch Event
```
Player Score Updates
    ↓
SharedStatsService publishes updated stats
    ↓
AllLivePlayersViewModel updates published @Published
    ↓
PlayerWatchService: calculateDelta()
    ↓
Conditions checked:
    ├─→ Is player watched? → Yes
    ├─→ Did score change? → Yes
    ├─→ Past cooldown? → Yes
    └─→ Alert enabled? → Yes
    ↓
PlayerWatchService.recentNotifications updated
    ↓
WatchedPlayersSheet listens and updates UI
```

### Game Status Event
```
GameStatusService detects game starting/ending
    ↓
GameAlert created
    ↓
AllLivePlayersViewModel.gameAlerts published
    ↓
Views subscribe and update displays
    ↓
Injury updates triggered
    ↓
InjuryStatusBadgeView refreshes
```

---

## 🎯 Key Architectural Patterns

### 1. Singleton Pattern (Services)
```swift
@MainActor
final class MyService: ObservableObject {
    static let shared = MyService()
    private init() { }
    
    @Published var data: [String] = []
    
    // Other code...
}
```
**Why:** Single source of truth, easy access, state persistence

### 2. MVVM Pattern
```
View (SwiftUI) 
    ↓ (observes)
ViewModel (@StateObject)
    ↓ (calls)
Service (business logic)
    ↓ (transforms)
Model (data)
```

### 3. Dependency Injection (Services)
```swift
init(
    apiClient: ESPNAPIClient = .shared,
    credentialsManager: ESPNCredentialsManager = .shared
) {
    self.apiClient = apiClient
    self.credentialsManager = credentialsManager
}
```

### 4. Async/Await Concurrency
```swift
// Fetch both ESPN and Sleeper leagues concurrently
await withTaskGroup(of: Void.self) { group in
    group.addTask { await fetchESPNLeagues() }
    group.addTask { await fetchSleeperLeagues() }
}
```

### 5. Publisher-Subscriber Pattern
```swift
@Published var selectedWeek: Int = 1

// Subscribers automatically update on change
$selectedWeek
    .removeDuplicates()
    .sink { newWeek in
        // React to change
    }
```

### 6. Cache Pattern
```swift
final class PlayerStatsCache {
    private var cache: [String: PlayerStats] = [:]
    private var cacheDate: Date?
    
    func isCacheValid() -> Bool {
        // Check age against AppConstants.maxCacheDays
    }
}
```

---

## 🚦 Initialization Sequence

### App Launch
```
1. DraftWarRoomApp starts
   ↓
2. ProgressiveAppView renders
   ↓
3. CentralizedAppLoader.initializeAppProgressively()
   ├─ 20%: loadSharedStats() - CRITICAL for preventing duplicates
   ├─ 40%: canShowPartialData = true → UI shows immediately
   ├─ 60%: loadMatchupsInBackground() - doesn't block UI
   ├─ 80%: loadPlayerDataInBackground() - doesn't block UI
   └─ 100%: hasCompletedInitialization = true
   ↓
4. CentralizedLoadingView displays progress
   ↓
5. When canShowPartialData = true, mainAppTabs becomes visible
   ↓
6. User sees live app while data continues loading
   ↓
7. Additional data appears as loading completes
```

### Critical Optimization
- **SharedStatsService loads first** - prevents 5+ duplicate calls
- **Partial data display enabled** - app feels responsive
- **Background loading** - doesn't freeze UI
- **Progressive enhancement** - data appears smoothly

---

## 🔐 Credential Flow

### ESPN Authentication
```
AppConstants (stores hardcoded example)
    ↓
ESPNCredentialsManager (override via settings)
    ↓
ESPNSetupViewModel (user input)
    ↓
OnBoardingView (settings UI)
    ↓
ESPNAPIClient.fetchLeagues(using: token)
```

### Sleeper Authentication
```
AppConstants (stores default username)
    ↓
SleeperCredentialsManager (stored username)
    ↓
SleeperSetupViewModel (user input)
    ↓
OnBoardingView (settings UI)
    ↓
SleeperAPIClient.fetchLeagues(username: "custom")
    ↓
SleeperAPIClient.resolveUsername(to: ID)
```

---

## 📱 View Hierarchy

### TabView Structure
```
ProgressiveAppView
└─→ TabView
    ├─→ Tab 0: NavigationStack → MatchupsHubView
    │   ├─→ Header components
    │   ├─→ Matchup cards (31+ component variations)
    │   └─→ Interactive elements
    │
    ├─→ Tab 1: NavigationStack → OpponentIntelligenceDashboardView
    │   ├─→ Watched players sheet
    │   ├─→ Opponent insights
    │   └─→ Analysis displays
    │
    ├─→ Tab 2: NavigationStack → NFLScheduleView
    │   ├─→ Game list
    │   ├─→ GameDetailView (navigable)
    │   └─→ Team-filtered matchups
    │
    ├─→ Tab 3: NavigationStack → AllLivePlayersView
    │   ├─→ Live player cards (21+ components)
    │   ├─→ Score bar displays
    │   ├─→ Injury badges (NEW)
    │   └─→ Matchup detail sheet
    │
    └─→ Tab 4: NavigationStack → MoreTabView
        ├─→ Settings/Onboarding
        ├─→ League selection
        ├─→ Fantasy views
        └─→ Additional features
```

---

## 🔍 Search & Lookup Optimization

### Player Search Flow
```
PlayerSearchView
    ↓
User types query
    ↓
PlayerDirectoryStore.search(query)
    ├─→ Indexes loaded at init
    ├─→ Fast in-memory search
    └─→ Returns [FantasyPlayer]
    ↓
PlayerMatchService
    ├─→ Links to NFLPlayer
    ├─→ Fetches stats
    └─→ Returns enhanced result
    ↓
Results displayed with images, stats, injury status
```

---

## ⚙️ Performance Considerations

### Caching Strategy
- **PlayerStatsCache**: 5-day cache (configurable)
- **Team Rosters**: Cached per season
- **League Data**: Cached until refresh
- **Player Directory**: Built once, used for all searches

### Memory Management
- Singletons persist across app lifetime
- Large views wrapped in NavigationStack
- Images loaded asynchronously with fallbacks
- Collections use lazy loading where possible

### Network Optimization
- **SharedStatsService**: Eliminates duplicate API calls
- **Batch requests**: Multiple leagues fetched concurrently
- **Progressive loading**: Don't wait for all data
- **Conditional updates**: Only refresh when needed

---

## 🔄 Extension Points

### Adding New Feature
```
1. Create Model in Models/
2. Create Service in Services/
3. Create ViewModel in ViewModels/
4. Create Views in Views/
5. Add to MainView or create new Tab
6. Wire up in CentralizedAppLoader if needed
7. Add to initialization sequence
```

### Adding New API Client
```
1. Create *APIClient.swift conforming to DraftAPIClient
2. Create *CredentialsManager.swift for auth
3. Add to UnifiedLeagueManager.fetchAllLeagues()
4. Create corresponding Models/*
5. Update CentralizedAppLoader
```

### Adding New Tab
```
1. Create YourTabView.swift
2. Create YourTabViewModel.swift
3. Add to ProgressiveAppView.mainAppTabs
4. Create NavigationStack wrapper
5. Add tabItem with Image + Text
6. Assign new tag number
7. Add notification handler if needed
```

---

## 📈 Scaling Considerations

### Current Limits
- Max watched players: 25
- Notification cooldown: 5 minutes
- Cache duration: 5 days
- Available seasons: 3 (2024, 2025, 2026)

### Future Scaling
- Move to Core Data for persistent cache
- Add Realm database for offline support
- Implement background sync
- Add push notifications service
- Create CloudKit sync

---

**Last Updated:** October 23, 2025 | **Version:** 8.57
**Architecture Style:** MVVM + Singleton Services
**Concurrency Model:** async/await + Combine
