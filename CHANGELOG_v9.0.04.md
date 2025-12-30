# Changelog - Version 9.0.04

**Release Date:** TBD  
**Focus:** NFLGameDataService Dependency Injection Migration (Phase 4 Completion)

---

## 🏗️ Architecture & Code Quality

### NFLGameDataService DI Migration - Phase 4 ✅

**Completed the migration from singleton pattern to proper dependency injection for NFLGameDataService**

#### Core Changes:

1. **FantasyPlayerViewModel**
   - Fixed missing `nflGameDataService` initialization in init
   - Made `nflGameDataService` internal for view access
   - Properly injects all required services (AllLivePlayersViewModel, PlayerDirectoryStore, NFLGameDataService, NFLWeekService)

2. **ScoreBreakdownFactory Updates**
   - Updated all `createBreakdown()` calls to pass required services:
     - `weekSelectionManager`
     - `idCanonicalizer`
     - `playerDirectoryStore`
     - `playerStatsCache`
     - `scoringSettingsManager`
   - Fixed in:
     - `PlayerScoreBarCardContentView` (regular & Modern)
     - `FantasyPlayerCard`
     - `ChoppedRosterPlayerCard`
     - `EnhancedNFLTeamRosterView`

3. **isLive/isOnBye Method Migration**
   - Converted from computed properties to methods requiring `NFLGameDataService` parameter
   - Updated all call sites (30+ occurrences) across:
     - `PlayerScoreBarCardView`
     - `PlayerScoreBarCardContentView_Modern`
     - `FantasyMatchupRosterSections` (4 occurrences)
     - `FantasyPlayerCard` (6 occurrences)
     - `ChoppedRosterPlayerCard` (10 occurrences)

4. **ViewModel & Service Updates**
   - `ChoppedTeamRosterViewModel`: Added `gameDataService` parameter to init
   - `PlayerWatchService`: Updated init in `FantasyMatchupDetailView` to include `gameDataService`
   - `FantasyDetailHeaderView`: Added `@Environment(NFLGameDataService.self)` for proper DI access

5. **UnifiedMatchup Creation**
   - Added `gameDataService` parameter to all UnifiedMatchup initializations:
     - `FantasyDetailHeaderView` (for win probability calculations)
     - `MatchupCardsGridView`

#### Benefits:

- ✅ **Proper MVVM Architecture**: Services injected through initializers, not accessed via singletons
- ✅ **Testability**: All dependencies can be mocked/stubbed for unit tests
- ✅ **Maintainability**: Clear dependency graph, easier to reason about data flow
- ✅ **Backward Compatibility**: Hybrid pattern maintained for gradual migration
- ✅ **Type Safety**: Compile-time verification of all dependencies

#### Files Modified:

**ViewModels:**
- `FantasyPlayerViewModel.swift`
- `ChoppedTeamRosterViewModel.swift`

**Views:**
- `PlayerScoreBarCardView.swift`
- `PlayerScoreBarCardContentView.swift`
- `PlayerScoreBarCardContentView_Modern.swift`
- `FantasyMatchupDetailView.swift`
- `FantasyMatchupRosterSections.swift`
- `FantasyPlayerCard.swift`
- `ChoppedRosterPlayerCard.swift`
- `FantasyDetailHeaderView.swift`
- `EnhancedNFLTeamRosterView.swift`
- `MatchupCardsGridView.swift`
- `ChoppedTeamRosterView.swift`

**Models:**
- `ScoreBreakdownModels.swift` (ScoreBreakdownFactory)

---

## 🐛 Bug Fixes

### Fixed Compilation Errors
- Resolved all missing parameter errors for service injection
- Fixed property vs method access for `isLive` and `isOnBye`
- Corrected all `ScoreBreakdownFactory.createBreakdown()` calls

---

## 📊 Technical Debt Reduction

### DI Migration Progress
- **Phase 1**: ✅ Model layer migration (NFLGameModels)
- **Phase 2**: ✅ ViewModel layer migration
- **Phase 3**: ✅ Service layer migration
- **Phase 4**: ✅ View layer migration (this release)
- **Remaining**: Cleanup of legacy .shared access patterns

---

## 🔧 Developer Notes

### Breaking Changes
None - All changes are internal architecture improvements. Hybrid pattern ensures backward compatibility.

### Migration Pattern
All services now follow this pattern: