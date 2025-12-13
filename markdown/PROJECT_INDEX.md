# BigWarRoom Project Index

## 📱 Project Overview

**BigWarRoom** is a comprehensive iOS fantasy football companion app built with SwiftUI. It provides real-time monitoring, matchup analysis, and intelligence tools for both ESPN and Sleeper fantasy leagues.

**Current Version:** Displayed via `AppConstants.getVersion()` (e.g., "X.Y (Build)")
**Git Branch:** v8.57
**Platform:** iOS (SwiftUI + UIKit integration)

---

## 🏗️ Architecture Overview

### High-Level Structure
```
BigWarRoom/
├── App/                          # Entry points
├── Configuration/                # Global constants & secrets
├── Services/                     # Business logic & API clients
├── Models/                       # Data structures
├── ViewModels/                   # UI state management (47 files)
├── Views/                        # SwiftUI components (272 files)
├── Extensions/                   # Swift extensions
├── Helpers/                      # Utility functions
├── Engines/                      # Suggestion & AI engines
└── Assets/                       # Images, fonts, colors
```

### Design Pattern
- **MVVM** with @StateObject, @StateObject, @Published
- **Singleton Services** for shared state management
- **Centralized Loading** with progressive UI updates
- **Notification-based** tab switching
- **Dark theme** throughout (`preferredColorScheme(.dark)`)

---

## 🚀 App Entry Points

### 1. **DraftWarRoomApp.swift** - Main App Delegate
- Entry point with `@main` annotation
- Uses `ProgressiveAppView` for progressive loading
- Initializes `CentralizedAppLoader.shared`
- Shows `CentralizedLoadingView` during initialization

### 2. **BigWarRoom.swift** - Alternative Main Content View
- Alternate implementation with `AppInitializationManager`
- Uses `AppInitializationLoadingView`
- Currently has 5 tabs: Mission Control (0), Schedule (1), Fantasy (2), Live Players (3), Settings (4)

### 3. **ProgressiveAppView** (in DraftWarRoomApp)
- Modern implementation with progressive loading
- 5-tab system: Mission Control, Intelligence, Schedule, Live Players, More
- Supports partial data display while loading continues

---

## 🔌 Tab System

### Current Tab Structure
1. **Mission Control (Tab 0)**: `MatchupsHubView()` - Matchup command center
2. **Intelligence (Tab 1)**: `OpponentIntelligenceDashboardView()` - Opponent analysis
3. **Schedule (Tab 2)**: `NFLScheduleView()` - NFL schedule & game details
4. **Live Players (Tab 3)**: `AllLivePlayersView()` - Real-time player stats
5. **More (Tab 4)**: `MoreTabView()` - Additional features

### Tab Switching via Notifications
- `"SwitchToWarRoom"` → switches to Tab 4
- `"SwitchToMissionControl"` → switches to Tab 0
- Triggered via `NotificationCenter.default.publisher()`

---

## 📊 Configuration

### AppConstants.swift
**Key Global Settings:**
- `ESPNLeagueYear`: Current ESPN league year (@AppStorage)
- `debug`: Dynamic debug mode (toggleable in settings)
- `maxCacheDays`: 5.0
- `MatchupRefresh`: 15 seconds (fantasy matchup auto-refresh rate)

**League IDs:**
- ESPN: `["1241361400", "1739710242", "1003758336", "1486575797", "1471913910"]`
- Sleeper: Various manager IDs for default leagues

**Available Years:** `["2024", "2025", "2026"]`

**Credentials Management:**
- ESPN: SWID, ESPN_S2 tokens (with year-specific variants)
- Sleeper: Username "Gp0" (default)
- Managed via `ESPNCredentialsManager` & `SleeperCredentialsManager`

**Branding:**
- `appLogo`: Glowing animated brain icon (fallback)
- `espnLogo`: Red gradient ESPN badge
- `sleeperLogo`: Gray Sleeper badge
- Font: Bebas Neue (custom TTF)

---

## 🔄 Initialization Flow

### CentralizedAppLoader - Progressive Loading Strategy
1. **Step 1 (20%)**: Load core stats via `SharedStatsService`
2. **Step 2 (40%)**: Set `canShowPartialData = true` (allows UI to show)
3. **Step 3 (60%)**: Load matchups in background
4. **Step 4 (80%)**: Load player data in background
5. **Step 5 (100%)**: Finalization, set `hasCompletedInitialization = true`

**Key Methods:**
- `initializeAppProgressively()`: Async progressive initialization
- `loadSharedStats()`: Eliminates redundant API calls
- `loadMatchupsInBackground()`: Non-blocking matchup loading
- `loadPlayerDataInBackground()`: Non-blocking player data loading

### Related Services
- `AppInitializationManager`: Alternative initialization manager
- `SharedStatsService`: Centralized stats loading to prevent duplicates

---

## 🎮 Core Services (31 total)

### League Management
- **UnifiedLeagueManager**: Handles both Sleeper & ESPN leagues
  - `LeagueWrapper`: Wraps league + source (Sleeper/ESPN) + client
  - `fetchAllLeagues()`: Multi-platform league fetching
  
- **LeagueMatchupProvider**: Matchup data provision

### API Clients
- **ESPNAPIClient**: ESPN Fantasy API integration
- **SleeperAPIClient**: Sleeper Fantasy API integration
- **DraftAPIClient**: Protocol for draft API clients

### Credential & Auth Management
- **ESPNCredentialsManager**: ESPN token & SWID storage
- **SleeperCredentialsManager**: Sleeper token management
- **AppSecrets**: Secrets configuration

### Player & Stats Services
- **SharedStatsService**: Centralized weekly stats for all players
- **StatsFacade**: Unified stats interface
- **PlayerStatsCache**: Player stats caching layer
- **PlayerDirectoryStore**: Player directory indexing
- **PlayerWatchService** (BEING MODIFIED): Real-time opponent monitoring
  - Watched players list management
  - Score tracking & notifications
  - Sort methods: Delta (default), Threat, Name
  - Max 25 watched players
  - Week change handling

### Team & Roster Services
- **NFLTeamRosterService**: NFL team roster data
- **TeamRosterCoordinator**: Roster coordination
- **TeamAssetManager**: Team asset management
- **TeamCodeNormalizer**: Team code normalization

### League & Draft Services
- **DraftPollingService**: Real-time draft polling
- **WeekSelectionManager**: Current week selection
- **SeasonYearManager**: Season year SSOT (Single Source of Truth)
- **NFLWeekService**: NFL week calculations
- **NFLStandingsService**: NFL standings data

### Opponent Intelligence
- **OpponentIntelligenceService**: Opponent analysis engine
- **GameStatusService**: Real-time game status
- **GameAlertModels**: Game alert data structures

### Utilities
- **RefreshTimerService**: Auto-refresh management
- **EndpointValidationService**: API endpoint validation
- **ESPNIDMappingService**: ESPN ID mapping
- **ESPNScoringSettingsManager**: Scoring settings
- **PlayerMatchService**: Player matching logic
- **PlayerSortingService**: Player sorting
- **AIService**: AI-based suggestions

---

## 📦 Data Models (25 core model files)

### Fantasy Models
- **FantasyModels.swift**: Core fantasy structures
  - `FantasyMatchup`: Contains homeTeam, awayTeam, status, winProbability
  - `FantasyTeam`: Manager info, roster, score, projected score
  - `FantasyPlayer`: Player with position, stats, injury status
  - `MatchupStatus`: Enum (scheduled, live, completed)

- **SleeperModels.swift**: Sleeper API data structures
  - `SleeperMatchup`: roster_id, points, projected_points, starters, players
  - `SleeperLeague`: League metadata
  - `SleeperUser`: User information

- **ESPNFantasyModels.swift**: ESPN Fantasy data
- **ESPNModels.swift**: ESPN API responses

### Player Data Models
- **NFLPlayer.swift**: NFL player entity
- **PlayerData.swift**: Player statistics
- **PlayerStatsData.swift**: Player stats container
- **PlayerStats2024.swift**: 2024 season stats
- **PlayerNewsModels.swift**: Player news & alerts

### Team/Roster Models
- **NFLTeam.swift**: NFL team info
- **TeamRosterModels.swift**: Team roster structures
- **ChoppedTeamRosterModels.swift**: "Chopped" team rosters (eliminated players tracking)
- **DraftRosterInfo.swift**: Draft roster tracking

### Game & Matchup Models
- **NFLGameModels.swift**: NFL game data
- **GameDisplayInfo.swift**: Game display formatting
- **GameAlertModels.swift**: Game alert structures
- **ScoreBreakdownModels.swift**: Score breakdown details

### League & Management Models
- **LeagueContext.swift**: League context data
- **ManagerInfo.swift**: Manager/Owner information
- **LineupSlots.swift**: Lineup slot definitions
- **FantasyPosition.swift**: Fantasy position enums

### Utility Models
- **EnhancedPick.swift**: Enhanced pick data
- **OpponentIntelligenceModels.swift**: Opponent intelligence data
- **PlayerWatchModels.swift**: Watched player data structures
- **MatchupSortingMethod.swift**: Matchup sorting options

### Legacy Models
- **Models.swift** (root): Basic domain models
  - `Position`: QB, RB, WR, TE, K, DST
  - `Team`: code, name
  - `Player`: id, position, team, tier
  - `Pick`: overall, player, timestamp
  - `Roster`: Position slots + bench
  - `LeagueSettings`: PPR, roster spots

---

## 👁️ Views Structure (272+ files)

### Main Hub Views
- **MatchupsHubView**: Command center matchups
  - Components: 31 files
  - Key: `MatchupCardViewBuilder`, `ChoppedPlayerCard`
  - Helpers: UI, Actions, Helpers extension files
  
- **OpponentIntelligenceDashboardView**: Opponent analysis
  - Components: 12 files
  
- **AllLivePlayersView**: Real-time player stats
  - Components: 21 files
  - Key: `PlayerScoreBarCardView`, `PlayerImageView`

### Fantasy Views
- **FantasyMatchupListView**: League matchup list
- **FantasyMatchupDetailView**: Matchup detail view
- **ChoppedLeaderboardView**: Eliminated players leaderboard
- **ChoppedTeamRosterView**: Team roster display
- **Components**: 47 files (player cards, stats, etc.)

### Schedule & Standings
- **NFLScheduleView**: NFL game schedule
- **GameDetailView**: Individual game details
- **TeamFilteredMatchupsView**: Team-filtered matchups

### Roster & Draft
- **RosterView**: Roster display
- **TeamRostersView**: Multi-team rosters
- **LeagueDraftView**: League draft view
- **Components**: Team cards, position groups, headers

### Player Information
- **PlayerStatsCardView**: Player stats display
- **PlayerCardView**: Player card with image & stats
- **PlayerImageView**: Player image with fallback
- **PlayerSearchView**: Player search interface
- **PlayerNewsView**: Player news feed

### Settings & Onboarding
- **OnBoardingView**: Initial setup (also called "WarRoom" internally)
- **ESPNDraftPickSelectionView**: Manual ESPN pick selection
- **Settings directory**: 18 files (credentials, league setup, etc.)

### Shared Components
- **InjuryStatusBadgeView** (NEW): Small injury status badge
  - Maps injury statuses to colored circles with abbreviations
  - Statuses: Questionable (Q/yellow), Doubtful (D/orange), Out (O/red), etc.
  
- **PlayerImageView** (MODIFIED): Player image with injury badge
- **Other**: 7 files for reusable UI components

### Loading & Initialization
- **CentralizedLoadingView**: Progressive loading display
- **AppInitializationLoadingView**: Alternative loading view
- **Components**: Progress bars, loading indicators

---

## 🎬 ViewModels (47 files)

### Primary ViewModels
- **DraftRoomViewModel** (9 extension files):
  - Core: Connection, DraftSelection, ManualDraft, PickTracking
  - Management: RosterManagement, Suggestions, ViewHelpers
  
- **MatchupsHubViewModel** (5 extension files):
  - Core: Helpers, Loading, Refresh, WeekSpecific
  - Special: ChoppedLeagues tracking

- **AllLivePlayersViewModel** (7 extension files):
  - Core: DataLoading, Filtering, GameAlerts, LiveGames
  - Processing: PlayerProcessing, StateManagement

- **FantasyViewModel** (5 extension files):
  - Integration: Chomp, ESPN, Refresh, Sleeper, UIHelpers

### Supporting ViewModels
- **LeagueDraftViewModel**: Draft tracking
- **FantasyMatchupListViewModel**: Matchup list management
- **NFLScheduleViewModel**: Schedule management
- **ChoppedLeaderboardViewModel**: Eliminated players
- **OpponentIntelligenceViewModel**: Opponent analysis
- **PlayerStatsViewModel**: Player statistics
- **PlayerNewsViewModel**: Player news
- **TeamFilteredMatchupsViewModel**: Filtered matchups
- Plus 22+ more for specific views

---

## 🔄 Current Git Status

### Staged for Commit
- `BigWarRoom/Views/Shared/InjuryStatusBadgeView.swift` (NEW)

### Modified (Not Staged)
- `BigWarRoom.xcodeproj/project.pbxproj` - Xcode project file
- `BigWarRoom/Services/PlayerWatchService.swift` - Player watch system
- `BigWarRoom/Views/AllLivePlayers/Components/PlayerScoreBarCardPlayerImageView.swift`
- `BigWarRoom/Views/Fantasy/Components/FantasyPlayerCardContentView.swift`
- `BigWarRoom/Views/OpponentIntelligence/Components/WatchedPlayersSheet.swift`
- `BigWarRoom/Views/PlayerImageView.swift`

**Current Focus:** Adding injury status badge display to player views across multiple tabs.

---

## 🎨 Key Extensions

### View Extensions (`View+Badge.swift`)
- Custom badge view modifiers

### Font Extensions (`font+ext.swift`)
- Custom font definitions (including Bebas Neue)

### Color Extensions (`color.swift`)
- Custom color definitions (e.g., `Color.gpGreen`)

### String Extensions (`String+NameParsing.swift`)
- Player name parsing utilities

---

## 📱 Key Features

### 1. Real-Time Player Watching
- `PlayerWatchService` tracks up to 25 monitored opponents
- Real-time score updates with delta tracking
- Multiple sort methods: Delta (default), Threat level, Name
- Week-aware (clears watched players on week change if enabled)
- Persistent storage via UserDefaults

### 2. Dual-Platform League Support
- Seamless ESPN & Sleeper league integration
- Unified league wrapper system
- Multi-season support (2024, 2025, 2026)

### 3. Progressive App Loading
- Shows UI as soon as partial data available
- Background loading of non-critical data
- Loading progress display
- No redundant API calls via SharedStatsService

### 4. Comprehensive Opponent Intelligence
- Win probability calculations
- Matchup analysis
- Lineup optimization suggestions
- Real-time game status tracking

### 5. Injury Status Indicators
- Visual badges for player injury status (NEW)
- Integrated into player cards across all tabs
- Color-coded by severity (yellow=Q, orange=D, red=O, etc.)

---

## 🛠️ Build Configuration

### Required Files
- **Info.plist**: App configuration
- **Secrets.swift**: Secret management
- **AppConstants.swift**: Global constants

### Assets
- **Assets.xcassets**: Images & colors
  - Multiple background options (BG1-BG9)
  - App icons
  - Logo images (ESPN, Sleeper)
- **Fonts**: BebasNeue-Regular.ttf (custom font)

### Certificates
- App icon: AppIcon.appiconset (1024px base)

---

## 🔐 Authentication

### ESPN
- **SWID**: `{7D6C3526-D30A-4DBD-9849-3D9C03333E7C}`
- **Tokens**: Year-specific ESPN_S2 tokens stored in AppConstants
- **Primary Token (2025)**: ESPN_S2_2025
- **Fallback Token**: ESPN_S2
- **Handled by**: ESPNCredentialsManager, ESPNAPIClient

### Sleeper
- **Default User**: "Gp0"
- **Default Manager ID**: "1117588009542615040"
- **Alternative Managers**: rossManagerID, etc.
- **Handled by**: SleeperCredentialsManager, SleeperAPIClient

---

## 🚦 Notification System

### App Notifications
- **"SwitchToWarRoom"**: Navigate to More tab
- **"SwitchToMissionControl"**: Navigate to Mission Control tab
- Used for cross-view navigation

### Player Notifications
- Real-time score updates
- Game start notifications
- Injury alerts
- Cooldown: 5 minutes between same-type notifications

---

## 📈 Data Flow Diagram

```
CentralizedAppLoader
  ├─→ SharedStatsService (Load core stats)
  ├─→ MatchupsHubViewModel (Load matchups in background)
  ├─→ AllLivePlayersViewModel (Load player data in background)
  └─→ UI (Shown as canShowPartialData = true)
  
UI (TabView with 5 tabs)
  ├─→ MatchupsHubView ─→ MatchupsHubViewModel
  ├─→ OpponentIntelligenceDashboardView ─→ OpponentIntelligenceViewModel
  ├─→ NFLScheduleView ─→ NFLScheduleViewModel
  ├─→ AllLivePlayersView ─→ AllLivePlayersViewModel
  └─→ MoreTabView ─→ Various ViewModels
  
Services Layer
  ├─→ ESPNAPIClient / SleeperAPIClient
  ├─→ UnifiedLeagueManager
  ├─→ PlayerWatchService
  └─→ Credential Managers
```

---

## 🔑 Key Acronyms & Terms

- **SWID**: Star Wars ID (ESPN authentication)
- **S2**: ESPN session token
- **DST**: Defense/Special Teams (fantasy position)
- **PPR**: Points Per Reception (scoring format)
- **Chopped**: Eliminated/dropped players tracking
- **SSOT**: Single Source of Truth (SeasonYearManager)
- **DeltaTracking**: Score change tracking in PlayerWatch

---

## 📝 Important Notes

1. **Always check git status** before making major changes
2. **PlayerWatchService** is actively being modified (currently staged: InjuryStatusBadgeView)
3. **Injury badge integration** is current work-in-progress across multiple views
4. **Centralized loaders** prevent duplicate API calls
5. **Dark theme** is enforced throughout the app
6. **Year-aware**: Different tokens for 2024/2025 seasons

---

## 🎯 Quick Reference

### To Add a New View
1. Create in appropriate subdirectory of `Views/`
2. Create corresponding ViewModel in `ViewModels/`
3. Add as new tab or navigate from existing view
4. Use singleton services for data

### To Add a New Tab
1. Create new View & ViewModel
2. Add to TabView in `ProgressiveAppView` or `BigWarRoom`
3. Add appropriate tab item (Image + Text)
4. Increment tab count or reassign tags
5. Update notification handlers if needed

### To Modify Player Card Display
1. Check `PlayerImageView.swift` (base player image)
2. Update relevant component files in `Views/*/Components/`
3. Consider impact on: AllLivePlayers, Fantasy, MatchupsHub, OpponentIntelligence tabs
4. Test injury badge rendering

---

## 🔗 File Locations

**Critical Files:**
- Entry: `/App/DraftWarRoomApp.swift` (use this, not BigWarRoom.swift)
- Constants: `/Configuration/AppConstants.swift`
- Main Data: `/Models/FantasyModels.swift`, `SleeperModels.swift`
- Core Loading: `/Services/CentralizedAppLoader.swift`
- Watched Players: `/Services/PlayerWatchService.swift`

**Status Indicators:**
- `/Views/Shared/InjuryStatusBadgeView.swift` (new as of current session)

---

**Last Updated:** October 23, 2025
**Project Version:** 8.57
**Status:** Active Development
