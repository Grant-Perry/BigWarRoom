# BigWarRoom File Tree & Organization

## 📂 Complete Project Structure

```
BigWarRoom/
│
├── App/                                    # Entry points
│   ├── BigWarRoom.swift                   # ⚠️ LEGACY: Main view (not recommended)
│   └── DraftWarRoomApp.swift              # ✅ CURRENT: App entry point
│
├── Configuration/                         # Global configuration
│   ├── AppConstants.swift                 # Global constants, credentials, logos
│   └── Secrets.swift                      # Secret management
│
├── Services/                              # Business logic layer (31 files)
│   │
│   ├── Initialization
│   │   ├── CentralizedAppLoader.swift     # Progressive app initialization
│   │   └── AppInitializationManager.swift # Alternative initializer
│   │
│   ├── API Clients
│   │   ├── ESPNAPIClient.swift           # ESPN Fantasy API
│   │   ├── SleeperAPIClient.swift        # Sleeper Fantasy API
│   │   └── EndpointValidationService.swift
│   │
│   ├── Credentials & Auth
│   │   ├── ESPNCredentialsManager.swift
│   │   ├── SleeperCredentialsManager.swift
│   │   └── AppSecrets.swift
│   │
│   ├── League Management
│   │   ├── UnifiedLeagueManager.swift    # 🔑 Handles both ESPN & Sleeper
│   │   ├── LeagueMatchupProvider.swift
│   │   └── ESPNIDMappingService.swift
│   │
│   ├── Player & Stats
│   │   ├── SharedStatsService.swift      # 🔑 CRITICAL: Prevents duplicate API calls
│   │   ├── StatsFacade.swift
│   │   ├── PlayerStatsCache.swift        # 5-day caching
│   │   ├── PlayerDirectoryStore.swift
│   │   ├── PlayerWatchService.swift      # 🔥 Watched opponents tracking
│   │   └── PlayerSortingService.swift
│   │
│   ├── Team & Roster
│   │   ├── NFLTeamRosterService.swift
│   │   ├── TeamRosterCoordinator.swift
│   │   ├── TeamAssetManager.swift
│   │   └── TeamCodeNormalizer.swift
│   │
│   ├── NFL & Schedule
│   │   ├── NFLWeekService.swift
│   │   ├── NFLStandingsService.swift
│   │   └── GameStatusService.swift       # Real-time game tracking
│   │
│   ├── Feature Services
│   │   ├── OpponentIntelligenceService.swift
│   │   ├── DraftPollingService.swift
│   │   ├── AIService.swift               # AI suggestions
│   │   └── PlayerMatchService.swift
│   │
│   ├── Utilities
│   │   ├── WeekSelectionManager.swift
│   │   ├── SeasonYearManager.swift       # 🔑 SSOT for current year
│   │   ├── ESPNScoringSettingsManager.swift
│   │   └── RefreshTimerService.swift
│   │
│   └── Configuration
│       └── SuggestionEngine.swift
│
├── Models/                               # Data structures (25 files)
│   │
│   ├── Core Domain
│   │   ├── Models.swift                  # Position, Team, Player, Pick, Roster
│   │   └── FantasyPosition.swift
│   │
│   ├── Fantasy Models
│   │   ├── FantasyModels.swift           # 🔑 Main fantasy structures
│   │   ├── FantasyModels.swift           # SleeperMatchup, FantasyMatchup, FantasyTeam
│   │   ├── SleeperModels.swift
│   │   ├── ESPNFantasyModels.swift
│   │   └── ESPNModels.swift
│   │
│   ├── Player Data
│   │   ├── NFLPlayer.swift               # NFL player entity
│   │   ├── PlayerData.swift
│   │   ├── PlayerStatsData.swift
│   │   ├── PlayerStats2024.swift
│   │   ├── PlayerNewsModels.swift
│   │   └── PlayerWatchModels.swift       # Watched player data
│   │
│   ├── Team & Roster
│   │   ├── NFLTeam.swift
│   │   ├── TeamRosterModels.swift
│   │   ├── ChoppedTeamRosterModels.swift # Eliminated teams tracking
│   │   ├── DraftRosterInfo.swift
│   │   └── LineupSlots.swift
│   │
│   ├── Game & Matchup
│   │   ├── NFLGameModels.swift
│   │   ├── GameDisplayInfo.swift
│   │   ├── GameAlertModels.swift         # Game alert structures
│   │   └── ScoreBreakdownModels.swift
│   │
│   ├── League & Management
│   │   ├── LeagueContext.swift
│   │   ├── ManagerInfo.swift             # Owner/Manager information
│   │   └── MatchupSortingMethod.swift
│   │
│   └── Utilities
│       ├── EnhancedPick.swift
│       └── OpponentIntelligenceModels.swift
│
├── ViewModels/                          # UI State Management (47 files)
│   │
│   ├── Primary ViewModels
│   │   ├── DraftRoomViewModel.swift
│   │   ├── DraftRoomViewModel+Connection.swift
│   │   ├── DraftRoomViewModel+DraftSelection.swift
│   │   ├── DraftRoomViewModel+ManualDraft.swift
│   │   ├── DraftRoomViewModel+PickTracking.swift
│   │   ├── DraftRoomViewModel+RosterManagement.swift
│   │   ├── DraftRoomViewModel+Suggestions.swift
│   │   └── DraftRoomViewModel+ViewHelpers.swift
│   │
│   ├── Matchups ViewModels
│   │   ├── MatchupsHubViewModel.swift
│   │   ├── MatchupsHubViewModel+ChoppedLeagues.swift
│   │   ├── MatchupsHubViewModel+Helpers.swift
│   │   ├── MatchupsHubViewModel+Loading.swift
│   │   ├── MatchupsHubViewModel+Refresh.swift
│   │   └── MatchupsHubViewModel+WeekSpecific.swift
│   │
│   ├── Live Players ViewModels
│   │   ├── AllLivePlayersViewModel.swift
│   │   ├── AllLivePlayersViewModel+DataLoading.swift
│   │   ├── AllLivePlayersViewModel+Filtering.swift
│   │   ├── AllLivePlayersViewModel+GameAlerts.swift
│   │   ├── AllLivePlayersViewModel+LiveGames.swift
│   │   ├── AllLivePlayersViewModel+PlayerProcessing.swift
│   │   └── AllLivePlayersViewModel+StateManagement.swift
│   │
│   ├── Fantasy ViewModels
│   │   ├── FantasyViewModel.swift
│   │   ├── FantasyViewModel+Chopped.swift
│   │   ├── FantasyViewModel+ESPN.swift
│   │   ├── FantasyViewModel+Refresh.swift
│   │   ├── FantasyViewModel+Sleeper.swift
│   │   ├── FantasyViewModel+UIHelpers.swift
│   │   ├── FantasyMatchupListViewModel.swift
│   │   ├── FantasyPlayerViewModel.swift
│   │   ├── ESPNFantasyViewModel.swift
│   │   ├── ChoppedLeaderboardViewModel.swift
│   │   ├── ChoppedPlayerCardViewModel.swift
│   │   └── ChoppedTeamRosterViewModel.swift
│   │
│   ├── Schedule & Roster ViewModels
│   │   ├── NFLScheduleViewModel.swift
│   │   ├── LeagueDraftViewModel.swift
│   │   ├── TeamFilteredMatchupsViewModel.swift
│   │   ├── TeamRostersViewModel.swift
│   │   ├── MyRosterViewModel.swift
│   │   ├── RosterViewModel.swift
│   │   └── NFLTeamRosterViewModel.swift
│   │
│   ├── Player & Analysis ViewModels
│   │   ├── PlayerStatsViewModel.swift
│   │   ├── PlayerNewsViewModel.swift
│   │   ├── OpponentIntelligenceViewModel.swift
│   │   └── NFLGameMatchupViewModel.swift
│   │
│   ├── Setup ViewModels
│   │   ├── ESPNSetupViewModel.swift
│   │   ├── SleeperSetupViewModel.swift
│   │   └── SettingsViewModel.swift
│   │
│   └── Other
│       └── MoreTabView
│
├── Views/                               # SwiftUI Components (272+ files)
│   │
│   ├── App Initialization
│   │   ├── AppEntryView.swift
│   │   ├── AppInitializationLoadingView.swift
│   │   └── AppInitialization/
│   │       └── CentralizedLoadingView.swift
│   │
│   ├── Components/                      # Shared components (30+ files)
│   │   ├── DraftPickCard.swift
│   │   ├── DraftSelectionCard.swift
│   │   ├── PlayerCardImageView.swift
│   │   ├── PlayerCardBackgroundView.swift
│   │   ├── PlayerCardPositionBadgeView.swift
│   │   ├── PlayerCardStatsPreviewRowView.swift
│   │   ├── ScheduleGameCard.swift
│   │   ├── CompactLeagueCard.swift
│   │   ├── RosterPositionGroupCard.swift
│   │   ├── RosterCollapsibleTeamCard.swift
│   │   ├── PollingCountdownDial.swift
│   │   ├── MatchupsHubLoadingHeroAnimationView.swift
│   │   ├── MatchupsHubLoadingIndicator.swift
│   │   ├── MatchupsHubLoadingProgressBarView.swift
│   │   ├── MatchupsHubLoadingProgressSectionView.swift
│   │   ├── FantasyLoadingIndicator.swift
│   │   ├── ESPNInstructionStep.swift
│   │   ├── AdaptiveNotificationBadge.swift
│   │   ├── MissionSplashView.swift
│   │   ├── RosterEmptyStateView.swift
│   │   └── More...
│   │
│   ├── MatchupsHub/                    # Mission Control (0+ components)
│   │   ├── MatchupsHubView.swift
│   │   ├── MatchupsHubView+Actions.swift
│   │   ├── MatchupsHubView+Helpers.swift
│   │   ├── MatchupsHubView+UI.swift
│   │   ├── MatchupCardViewBuilder.swift # 🔑 Card builder
│   │   ├── MicroCardView.swift
│   │   ├── NonMicroCardView.swift
│   │   ├── ChoppedPlayerCard.swift
│   │   └── Components/                 # 31 specialized cards
│   │       ├── MatchupCardCompact.swift
│   │       ├── MatchupCardExpanded.swift
│   │       ├── MatchupCardDetailed.swift
│   │       └── ...
│   │
│   ├── OpponentIntelligence/           # Intelligence (1)
│   │   ├── OpponentIntelligenceDashboardView.swift
│   │   └── Components/                 # 12 components
│   │       ├── WatchedPlayersSheet.swift
│   │       └── ...
│   │
│   ├── Schedule/                       # Schedule (2)
│   │   ├── NFLScheduleView.swift
│   │   ├── GameDetailView.swift
│   │   └── TeamFilteredMatchupsView.swift
│   │
│   ├── AllLivePlayers/                 # Live Players (3)
│   │   ├── AllLivePlayersView.swift
│   │   ├── MatchupDetailSheet.swift
│   │   ├── PlayerScoreBarCardView.swift
│   │   └── Components/                 # 21 components
│   │       ├── PlayerScoreBarCardPlayerImageView.swift
│   │       ├── LivePlayerCard.swift
│   │       └── ...
│   │
│   ├── Fantasy/                        # More Tab (4)
│   │   ├── FantasyMatchupListView.swift
│   │   ├── FantasyMatchupDetailView.swift
│   │   ├── AsyncChoppedLeaderboardView.swift
│   │   ├── ChoppedLeaderboardView.swift
│   │   ├── ChoppedTeamRosterView.swift
│   │   ├── LeaguePickerOverlay.swift
│   │   ├── FantasyRedirectView.swift
│   │   ├── LeagueMatchupsTabView.swift
│   │   └── Components/                 # 47 components
│   │       ├── FantasyPlayerCardContentView.swift
│   │       ├── FantasyPlayerCard.swift
│   │       ├── ChoppedPlayerStatsCard.swift
│   │       └── ...
│   │
│   ├── Roster/                        # Roster views
│   │   ├── RosterView.swift
│   │   ├── TeamRostersView.swift
│   │   ├── MyRosterView.swift
│   │   ├── EnhancedNFLTeamRosterView.swift
│   │   ├── NFLTeamRosterView.swift
│   │   └── ...
│   │
│   ├── Draft/
│   │   ├── LeagueDraftView.swift
│   │   ├── LiveDraftPicksView.swift
│   │   ├── ESPNDraftPickSelectionView.swift
│   │   ├── DraftRoomView.swift
│   │   └── DraftRoom/
│   │       ├── ActiveDraftSection.swift
│   │       ├── DraftQuickActionsSection.swift
│   │       ├── DraftSelectionSection.swift
│   │       ├── ManualPositionPicker.swift
│   │       ├── QuickConnectSection.swift
│   │       ├── TopSuggestionsSection.swift
│   │       ├── CompactSuggestionCard.swift
│   │       ├── Components/             # 23 components
│   │       └── Sheets/
│   │
│   ├── Player/
│   │   ├── PlayerCardView.swift
│   │   ├── PlayerImageView.swift        # 🔥 MODIFIED: With injury badge
│   │   ├── PlayerStatsCardView.swift
│   │   ├── PlayerSearchView.swift
│   │   ├── PlayerNewsView.swift
│   │   ├── PlayerNotFoundView.swift
│   │   └── PlayerStats/
│   │       └── Components/             # 20 components
│   │
│   ├── Shared/                        # Reusable components
│   │   ├── InjuryStatusBadgeView.swift # ✅ NEW: Injury status badge
│   │   └── ...
│   │
│   ├── Settings/                      # Settings & Onboarding
│   │   ├── OnBoardingView.swift
│   │   ├── Components/                # 18 components
│   │   └── ...
│   │
│   ├── MoreTabView.swift              # Main More tab
│   ├── AIPickSuggestionsView.swift
│   ├── FeaturesView.swift
│   ├── LoadingScreen.swift
│   └── Sheets/                        # Modal sheets
│       └── ...
│
├── Extensions/                        # Swift extensions
│   ├── View+Badge.swift               # Badge modifiers
│   ├── font+ext.swift                 # Font definitions
│   ├── color.swift                    # Color definitions
│   └── String+NameParsing.swift       # String utilities
│
├── Helpers/
│   └── NFLWeekCalculator.swift        # NFL week calculations
│
├── Engines/
│   └── SuggestionEngine.swift         # Suggestion engine
│
├── Utils/
│   └── DebugLogger.swift              # Debug logging
│
├── Assets.xcassets/                  # Image & color assets
│   ├── AccentColor.colorset/
│   ├── AppIcon.appiconset/            # App icons
│   ├── AppIcon_Clean_1024.png
│   ├── Bebas.dataset/                 # Custom font
│   │   ├── BebasNeue-Regular.ttf
│   │   └── Contents.json
│   ├── BG1-BG9.imageset/             # Background images (9 options)
│   ├── espnLogo.imageset/
│   ├── sleeperLogo.imageset/
│   └── Contents.json
│
├── Fonts/
│   └── BebasNeue-Regular.ttf          # Custom font file
│
├── Resources/
│   ├── NewInfo.plist
│   └── Secrets.example.plist
│
├── Configuration/
│   └── (duplicate of config section above)
│
├── Info.plist                         # App configuration
├── Models.swift                       # Core domain models (root)
└── DraftRoomView.swift                # Draft room view (root)

```

---

## 📍 File Organization Notes

### Naming Conventions
- **Services**: `*Service.swift` or `*Manager.swift`
- **ViewModels**: `*ViewModel.swift`, extensions as `*ViewModel+Section.swift`
- **Views**: `*View.swift`, shared in `Views/Shared/`
- **Models**: `*Models.swift` or `*Model.swift`
- **Extensions**: `Type+Purpose.swift`

### File Size Guidelines
- **ViewModels**: Large files split into logical extension files
  - Example: `DraftRoomViewModel.swift` + 7 extension files
  - Each extension handles specific responsibility
  
- **Services**: Keep around 500-1000 lines, split if larger
  - Example: `AllLivePlayersViewModel` has 7 related files
  
- **Views**: Keep around 300-400 lines, move components to Components/
  - Example: `MatchupsHub/Components/` contains 31 specialized cards

### Extension File Purposes
```
ViewModel+Connection      → API/Network connectivity
ViewModel+DataLoading     → Data fetching logic
ViewModel+Filtering       → Filtering & search logic
ViewModel+GameAlerts      → Game/alert handling
ViewModel+Helpers         → Helper functions & utilities
ViewModel+Refresh         → Refresh logic
ViewModel+StateManagement → @Published properties & state
ViewModel+UIHelpers       → UI-related helpers
ViewModel+ViewHelpers     → View-specific helpers
```

### Component Organization
- **Components/** directories: Reusable, shared components
- **[Feature]/Components/**: Feature-specific variants
- Naming: `[Feature][Element]View.swift`
- Example: `PlayerScoreBarCardPlayerImageView.swift`

---

## 🎯 Quick File Lookup

| Task | File Location |
|---|---|
| Change app entry point | `App/DraftWarRoomApp.swift` or `App/BigWarRoom.swift` |
| Modify global constants | `Configuration/AppConstants.swift` |
| Add ESPN authentication | `Services/ESPNCredentialsManager.swift` |
| Add Sleeper authentication | `Services/SleeperCredentialsManager.swift` |
| Change initialization flow | `Services/CentralizedAppLoader.swift` |
| Modify watched players | `Services/PlayerWatchService.swift` |
| Add new fantasy model | `Models/FantasyModels.swift` |
| Add new tab | `Views/[YourFeature]/YourView.swift` |
| Add custom color | `Extensions/color.swift` |
| Add custom font | `Extensions/font+ext.swift` |
| Change player image display | `Views/PlayerImageView.swift` |
| Add injury badge styling | `Views/Shared/InjuryStatusBadgeView.swift` |
| Modify NFL schedule | `Views/Schedule/NFLScheduleView.swift` |
| Update player stats display | `Views/PlayerStats/PlayerStatsCardView.swift` |

---

## 🔄 Recent Modifications Summary

### Staged for Commit
- ✅ `BigWarRoom/Views/Shared/InjuryStatusBadgeView.swift` (NEW)

### Work In Progress
- 🔥 `BigWarRoom/Services/PlayerWatchService.swift`
- 🔥 `BigWarRoom/Views/AllLivePlayers/Components/PlayerScoreBarCardPlayerImageView.swift`
- 🔥 `BigWarRoom/Views/Fantasy/Components/FantasyPlayerCardContentView.swift`
- 🔥 `BigWarRoom/Views/OpponentIntelligence/Components/WatchedPlayersSheet.swift`
- 🔥 `BigWarRoom/Views/PlayerImageView.swift`

**Current Focus:** Integrating injury status badge display across multiple player card views.

---

**Last Updated:** October 23, 2025 | **Total Files:** 380+ Swift files
