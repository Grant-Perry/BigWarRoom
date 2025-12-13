# 📚 BigWarRoom Project Index - Summary

## ✅ Index Complete!

Your BigWarRoom project has been fully indexed and documented. Four comprehensive guides have been created:

### 📄 Documentation Files Created

1. **PROJECT_INDEX.md** (Main Reference)
   - Complete project overview
   - Architecture description
   - All 31 services documented
   - All 25 model files explained
   - All 47 view model files listed
   - Current git status
   - Key features breakdown

2. **QUICK_REFERENCE.md** (Developer Cheatsheet)
   - Navigation quick lookup table
   - Common task snippets
   - API integration points
   - UI component reuse patterns
   - Key singletons reference
   - Data flow examples
   - Persistence keys
   - Debugging tips

3. **ARCHITECTURE.md** (Technical Deep Dive)
   - Layered architecture diagram
   - Module dependency graph
   - Service interconnections
   - Data model relationships
   - Reactive update flows
   - Architectural patterns explained
   - Initialization sequence
   - Credential flow
   - View hierarchy
   - Performance considerations
   - Extension points for new features

4. **FILE_TREE.md** (File Organization)
   - Complete directory structure
   - All 380+ Swift files organized
   - File naming conventions
   - File size guidelines
   - Extension file purposes
   - Quick lookup table
   - Recent modifications summary

---

## 🎯 Project Overview

### 📱 App Purpose
BigWarRoom is a comprehensive **iOS fantasy football companion app** for real-time monitoring, matchup analysis, and intelligent player tracking across ESPN and Sleeper leagues.

### 🏗️ Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM + Singleton Services
- **Concurrency**: async/await + Combine
- **Persistence**: UserDefaults + local caching
- **Platform**: iOS (dark theme only)

### 📊 Project Statistics
- **Swift Files**: 380+
- **Views**: 272+
- **ViewModels**: 47
- **Services**: 31
- **Models**: 25
- **Git Branch**: v8.57
- **Current Focus**: Injury status badge integration

---

## 🎨 App Structure

### 5-Tab System
```
┌─────────────────────────────────────────┐
│ Mission     Intelligence  Schedule  Live  More │
│  Control                        Players       │
│ (0)         (1)           (2)      (3)    (4) │
└─────────────────────────────────────────┘
  Tab 0       Tab 1         Tab 2    Tab 3  Tab 4
```

### Core Components
- **Progressive Loading**: Load UI immediately, data in background
- **Dual Platform Support**: Seamless ESPN & Sleeper integration
- **Real-time Player Watch**: Track up to 25 opponent players
- **Matchup Intelligence**: Win probability, lineup optimization
- **Injury Tracking**: Color-coded status badges (NEW)

---

## 🔑 Key Files to Know

### Must-Know Files
| File | Purpose | Priority |
|---|---|---|
| `DraftWarRoomApp.swift` | App entry point | 🔴 CRITICAL |
| `AppConstants.swift` | Global configuration | 🔴 CRITICAL |
| `CentralizedAppLoader.swift` | App initialization | 🔴 CRITICAL |
| `ProgressiveAppView` | Tab system | 🔴 CRITICAL |
| `SharedStatsService.swift` | Stats SSOT | 🟠 HIGH |
| `UnifiedLeagueManager.swift` | League management | 🟠 HIGH |
| `PlayerWatchService.swift` | Watched players | 🟠 HIGH |
| `FantasyModels.swift` | Core data models | 🟠 HIGH |

### Recently Modified (Current Focus)
- `InjuryStatusBadgeView.swift` (NEW - staged)
- `PlayerImageView.swift` (injury badge integration)
- `PlayerWatchService.swift` (watched system updates)
- Multiple player card components

---

## 🚀 Quick Start Guide

### To Understand the Project
1. Start with **PROJECT_INDEX.md** for overview
2. Read **QUICK_REFERENCE.md** for common tasks
3. Review **ARCHITECTURE.md** for deep understanding
4. Use **FILE_TREE.md** for file navigation

### To Make Changes
1. Find the file in **FILE_TREE.md**
2. Check **ARCHITECTURE.md** for dependencies
3. Review **QUICK_REFERENCE.md** for patterns
4. Use **PROJECT_INDEX.md** for context

### To Add New Features
1. Check **ARCHITECTURE.md** > "Extension Points"
2. Follow the pattern in **QUICK_REFERENCE.md**
3. Use existing components from **FILE_TREE.md**
4. Reference **PROJECT_INDEX.md** for services

---

## 🎯 Current Development Focus

### Active Work
- **Feature**: Injury Status Badge Integration
- **Files Modified**: 6 files across different tabs
- **Status**: In progress (InjuryStatusBadgeView staged for commit)
- **Impact**: Displays player injury status on all player cards

### Changes Summary
- ✅ Created: `InjuryStatusBadgeView.swift` (reusable component)
- 🔥 Modified: Player image views to include badges
- 🔥 Modified: Player card components to display badges
- 🔥 Modified: Watched players sheet for badge support

---

## 📈 Project Statistics

### Code Organization
```
Services:           31 files   (business logic)
ViewModels:         47 files   (state management)
Views:             272+ files  (UI components)
Models:             25 files   (data structures)
Extensions:          4 files   (utilities)
Assets:            30+ files   (images, fonts, colors)
```

### API Integration
```
ESPN:    OAuth2 + SWID authentication
         Year-specific tokens (2024/2025)
         Multiple league support
         
Sleeper: Username-based resolution
         Multi-league support
         User-specific data
```

### Data Management
```
Cache Duration:  5 days (configurable)
Watched Players: Max 25 (configurable)
Notification Cooldown: 5 minutes
Available Seasons: 2024, 2025, 2026
```

---

## 🔗 Key Concepts

### SSOT (Single Source of Truth)
- **SeasonYearManager.shared**: Current season year
- **SharedStatsService.shared**: Weekly player stats (prevents duplicates)
- **WeekSelectionManager.shared**: Currently selected week
- **AppConstants**: Global configuration

### Reactive Updates
- All services use `@Published` for automatic UI updates
- Subscribers notified when data changes
- Views observe via `@StateObject` and `@ObservedObject`

### Singleton Pattern
- All major services implemented as singletons
- Accessible via `.shared` static property
- Persist across app lifetime
- Thread-safe via `@MainActor`

### Progressive Loading
- Data loads in background
- UI shows as soon as partial data available
- No app freezing during initialization
- Non-critical data loads after UI ready

---

## 🔒 Authentication Management

### ESPN
- **Method**: OAuth2 with SWID + S2 token
- **Storage**: ESPNCredentialsManager
- **Default**: Built-in credentials for testing
- **User Override**: Settings/OnBoardingView
- **Multi-Year**: Year-specific tokens in AppConstants

### Sleeper
- **Method**: Username resolution to ID
- **Storage**: SleeperCredentialsManager
- **Default**: "Gp0" username
- **User Override**: Settings/SleeperSetupView
- **ID Caching**: ESPNIDMappingService (for ESPN)

---

## 🎮 User Interface

### Navigation
- Tab-based primary navigation (5 tabs)
- NavigationStack for drill-down views
- Sheet-based modals for filters/options
- Notification-based cross-tab navigation

### Visual Design
- **Theme**: Dark mode only
- **Font**: Bebas Neue (custom) + System fonts
- **Colors**: 9 background options, custom accent colors
- **Icons**: SF Symbols system icons
- **Badges**: Colored injury status indicators

### Key UI Patterns
- **Cards**: Modular, reusable player/matchup cards
- **Loading**: Progress bars, animation indicators
- **Badges**: Colored status indicators
- **Sheets**: Modal overlays for detailed info
- **Lists**: Lazy loading where applicable

---

## 📱 Data Flow

### App Launch
```
DraftWarRoomApp
  ↓
ProgressiveAppView
  ↓
CentralizedAppLoader.initializeAppProgressively()
  ├─ Load core stats (prevents duplicate API calls)
  ├─ Show UI immediately (canShowPartialData)
  ├─ Load matchups in background
  ├─ Load player data in background
  └─ Complete initialization
  ↓
User sees app immediately with partial data
```

### User Interaction
```
User selects player to watch
  ↓
PlayerWatchService.addWatchedPlayer()
  ├─ Adds to watchedPlayers array
  ├─ Persists to UserDefaults
  └─ Updates UI
  ↓
Player score updates
  ↓
SharedStatsService notifies subscribers
  ↓
PlayerWatchService calculates delta
  ↓
If conditions met:
  ├─ Create notification
  ├─ Add to recentNotifications
  └─ Show alert in WatchedPlayersSheet
```

---

## 🛠️ Development Workflow

### Adding a View
1. Create `YourView.swift` in appropriate Views/ subdirectory
2. Create `YourViewModel.swift` in ViewModels/
3. Add @StateObject to parent view
4. Wire up to navigation or tab system

### Adding a Service
1. Create `YourService.swift` in Services/
2. Make it `@MainActor` for thread safety
3. Use `@Published` properties for reactivity
4. Implement as singleton with `.shared`

### Adding a Model
1. Create `YourModels.swift` in Models/
2. Make structures conform to `Codable`
3. Add `Identifiable` if needed for lists
4. Add `Hashable` for Sets/comparisons

### Modifying Existing Feature
1. Locate in FILE_TREE.md
2. Check dependencies in ARCHITECTURE.md
3. Review impact on other files
4. Test across all related views

---

## 🐛 Debugging

### Enable Debug Logging
- UserDefaults key: `debugModeEnabled`
- Check `AppConstants.debug` property
- Add print statements prefixed with emoji (✅ ❌ 🔥 etc)

### Check API Connectivity
- Use `EndpointValidationService`
- Verify credentials in CredentialsManager
- Check network requests in Xcode console
- Test with different seasons/weeks

### Verify Caching
- Cache duration: `AppConstants.maxCacheDays`
- Managed by: `PlayerStatsCache`
- Clear by restarting app or manual code
- Check cache hit/miss in logs

### Test Different Scenarios
- Week selection: Change week in settings
- League switching: Select different league
- Multi-platform: Test ESPN and Sleeper
- Network: Test offline behavior

---

## 📚 Learning Path

### For New Developers
1. **Day 1**: Read PROJECT_INDEX.md overview
2. **Day 1**: Run app, explore UI
3. **Day 2**: Read QUICK_REFERENCE.md patterns
4. **Day 2**: Trace data flow from Views → ViewModels → Services
5. **Day 3**: Read ARCHITECTURE.md deep dive
6. **Day 3**: Make small UI modification
7. **Day 4**: Make small service modification
8. **Day 5**: Add new view/viewmodel pair

### For Feature Development
1. Check ARCHITECTURE.md > Extension Points
2. Use QUICK_REFERENCE.md for code patterns
3. Reference FILE_TREE.md for file locations
4. Review PROJECT_INDEX.md for service details
5. Implement feature following patterns
6. Test across all affected areas
7. Check git status for modified files

---

## 📞 Quick Reference Index

| Question | Answer File | Section |
|---|---|---|
| Where's the app entry point? | QUICK_REFERENCE.md | Navigation Cheatsheet |
| How do I add a new tab? | QUICK_REFERENCE.md | Common Tasks |
| What are the 5 tabs? | PROJECT_INDEX.md | Tab System |
| How's the data structured? | ARCHITECTURE.md | Data Model Relationships |
| What's the file layout? | FILE_TREE.md | Complete Structure |
| How do services work? | ARCHITECTURE.md | Service Interconnections |
| What's being modified now? | FILE_TREE.md | Recent Modifications |
| How's data loaded? | ARCHITECTURE.md | Initialization Sequence |
| What singletons exist? | QUICK_REFERENCE.md | Key Singletons |
| How do views update? | ARCHITECTURE.md | Reactive Update Flow |

---

## ✨ Index Features

### What's Included
✅ Complete project overview
✅ Architecture documentation
✅ File organization guide
✅ Quick reference handbook
✅ Common task patterns
✅ API integration points
✅ Data model diagrams
✅ Dependency graphs
✅ Service descriptions
✅ Git status summary
✅ Component reuse guide
✅ Authentication flow
✅ Initialization sequence
✅ Performance notes
✅ Extension points for new features

### How to Use
1. **Quick lookup**: Use QUICK_REFERENCE.md
2. **File finding**: Use FILE_TREE.md
3. **Understanding**: Use PROJECT_INDEX.md
4. **Architecture**: Use ARCHITECTURE.md
5. **Integration**: Cross-reference all docs

---

## 🎓 Additional Resources

### In-Code References
- **Comments**: Throughout codebase with 🔥, ✅, ❌ emoji
- **MARK**: Used for section organization
- **TODO**: Tracked items for future work
- **Previews**: SwiftUI preview code in views

### Xcode Integration
- Project builds successfully
- Dark scheme enforced
- Asset catalog organized
- Info.plist configured
- Schemes available for debugging

### Git Information
- **Current Branch**: v8.57
- **Staged**: InjuryStatusBadgeView.swift
- **Modified**: 5 player-related files
- **Status**: Active development

---

## 🎉 Project is Fully Indexed!

You now have comprehensive documentation covering:
- ✅ Project structure and organization
- ✅ Architecture and design patterns
- ✅ All services, viewmodels, and views
- ✅ File locations and purposes
- ✅ Quick reference patterns
- ✅ Data flow and dependencies
- ✅ Git status and current work

**Ready to develop!** 🚀

---

**Documentation Generated**: October 23, 2025
**Project Version**: 8.57
**Files Indexed**: 380+
**Services Documented**: 31
**ViewModels Documented**: 47
**Status**: Complete
