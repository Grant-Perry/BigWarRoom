//
//  AppEntryView.swift
//  BigWarRoom
//
//  Entry point that handles loading screen and navigation based on user credentials
//  🔥 PHASE 3 DI: Updated to create and pass dependencies properly
//

import SwiftUI

struct AppEntryView: View {
    @State private var showingLoading = true // 🔥 CHANGED: Start with loading screen
    @State private var shouldShowOnboarding = false
    
    // 🔥 PHASE 3 DI: Create dependency instances at app root to pass down
    @State private var espnCredentials = ESPNCredentialsManager.shared
    @State private var sleeperCredentials = SleeperCredentialsManager.shared
    @State private var playerDirectory = PlayerDirectoryStore.shared
    @State private var gameStatusService = GameStatusService.shared
    @State private var sharedStatsService = SharedStatsService.shared
    @State private var weekSelectionManager = WeekSelectionManager.shared
    @State private var nflGameDataService = NFLGameDataService.shared
    
    // 🔥 PHASE 3 DI: Create UnifiedLeagueManager with proper dependencies
    @State private var unifiedLeagueManager: UnifiedLeagueManager?
    
    // 🔥 PHASE 3 DI: Create MatchupDataStore with all required dependencies
    @State private var matchupDataStore: MatchupDataStore?
    
    // 🔥 PHASE 3 DI: Create ViewModels with proper dependency injection
    @State private var matchupsHub: MatchupsHubViewModel?
    @State private var allLivePlayersViewModel: AllLivePlayersViewModel?
    
    var body: some View {
        Group {
            if showingLoading {
                // 🔥 PHASE 3 DI: Pass dependencies to LoadingScreen
                LoadingScreen(
                    onComplete: { needsOnboarding in
                        DebugPrint(mode: .appLoad, "🎬 AppEntryView: LoadingScreen completed, transitioning to main app")
                        shouldShowOnboarding = needsOnboarding
                        showingLoading = false
                    },
                    espnCredentials: espnCredentials,
                    sleeperCredentials: sleeperCredentials,
                    matchupsHub: getOrCreateMatchupsHub()
                )
            } else {
                // Only show main app AFTER loading completes
                BigWarRoomWithConditionalStart(
                    shouldShowOnboarding: shouldShowOnboarding,
                    matchupsHub: getOrCreateMatchupsHub(),
                    allLivePlayersViewModel: getOrCreateAllLivePlayersViewModel()
                )
                .onAppear {
                    DebugPrint(mode: .appLoad, "🎬 AppEntryView: BigWarRoom appeared on screen")
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingLoading)
    }
    
    // 🔥 PHASE 3 DI: Lazy initialization helpers
    private func getOrCreateUnifiedLeagueManager() -> UnifiedLeagueManager {
        if unifiedLeagueManager == nil {
            let sleeperClient = SleeperAPIClient()
            let espnClient = ESPNAPIClient(credentialsManager: espnCredentials)
            unifiedLeagueManager = UnifiedLeagueManager(
                sleeperClient: sleeperClient,
                espnClient: espnClient,
                espnCredentials: espnCredentials
            )
        } else {
        }
        return unifiedLeagueManager!
    }
    
    private func getOrCreateMatchupDataStore() -> MatchupDataStore {
        if matchupDataStore == nil {
            matchupDataStore = MatchupDataStore(
                unifiedLeagueManager: getOrCreateUnifiedLeagueManager(),
                sharedStatsService: sharedStatsService,
                gameStatusService: gameStatusService,
                weekSelectionManager: weekSelectionManager,
                playoffEliminationService: PlayoffEliminationService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials)
                ),
                teamRosterFetchService: TeamRosterFetchService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials),
                    playerDirectory: playerDirectory,
                    gameStatusService: gameStatusService,
                    seasonYearManager: SeasonYearManager.shared
                ),
                choppedLeagueService: ChoppedLeagueService(
                    sleeperClient: SleeperAPIClient(),
                    playerDirectory: playerDirectory,
                    gameStatusService: gameStatusService,
                    sharedStatsService: sharedStatsService,
                    weekSelectionManager: weekSelectionManager,
                    seasonYearManager: SeasonYearManager.shared,
                    sleeperCredentials: sleeperCredentials
                ),
                teamIdentificationService: TeamIdentificationService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials),
                    sleeperCredentials: sleeperCredentials
                )
            )
        }
        return matchupDataStore!
    }
    
    private func getOrCreateMatchupsHub() -> MatchupsHubViewModel {
        if matchupsHub == nil {
            matchupsHub = MatchupsHubViewModel(
                espnCredentials: espnCredentials,
                sleeperCredentials: sleeperCredentials,
                playerDirectory: playerDirectory,
                gameStatusService: gameStatusService,
                sharedStatsService: sharedStatsService,
                matchupDataStore: getOrCreateMatchupDataStore(),
                gameDataService: nflGameDataService,
                unifiedLeagueManager: getOrCreateUnifiedLeagueManager(),
                playoffEliminationService: PlayoffEliminationService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials)
                ),
                choppedLeagueService: ChoppedLeagueService(
                    sleeperClient: SleeperAPIClient(),
                    playerDirectory: playerDirectory,
                    gameStatusService: gameStatusService,
                    sharedStatsService: sharedStatsService,
                    weekSelectionManager: weekSelectionManager,
                    seasonYearManager: SeasonYearManager.shared,
                    sleeperCredentials: sleeperCredentials
                ),
                teamRosterFetchService: TeamRosterFetchService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials),
                    playerDirectory: playerDirectory,
                    gameStatusService: gameStatusService,
                    seasonYearManager: SeasonYearManager.shared
                ),
                teamIdentificationService: TeamIdentificationService(
                    sleeperClient: SleeperAPIClient(),
                    espnClient: ESPNAPIClient(credentialsManager: espnCredentials),
                    sleeperCredentials: sleeperCredentials
                )
            )
        }
        return matchupsHub!
    }
    
    private func getOrCreateAllLivePlayersViewModel() -> AllLivePlayersViewModel {
        if allLivePlayersViewModel == nil {
            allLivePlayersViewModel = AllLivePlayersViewModel(
                matchupsHubViewModel: getOrCreateMatchupsHub(),
                playerDirectory: playerDirectory,
                gameStatusService: gameStatusService,
                sharedStatsService: sharedStatsService,
                weekSelectionManager: weekSelectionManager,
                nflGameDataService: nflGameDataService
            )
        }
        return allLivePlayersViewModel!
    }
}

// Wrapper to show BigWarRoom with conditional starting tab
struct BigWarRoomWithConditionalStart: View {
    let shouldShowOnboarding: Bool
    let matchupsHub: MatchupsHubViewModel
    let allLivePlayersViewModel: AllLivePlayersViewModel
    
    var body: some View {
        BigWarRoomModified(
            startOnSettings: shouldShowOnboarding,
            matchupsHub: matchupsHub,
            allLivePlayersViewModel: allLivePlayersViewModel
        )
    }
}

// 🔥 SIMPLIFIED: Remove all the tab disabling bullshit - data is already loaded
struct BigWarRoomModified: View {
    @State private var viewModel = DraftRoomViewModel()
    let matchupsHub: MatchupsHubViewModel
    let allLivePlayersViewModel: AllLivePlayersViewModel
    @State private var selectedTab: Int
    
    // 🔥 PHASE 3 DI: Other shared singletons
    @State private var playerWatchService = PlayerWatchService.shared
    @State private var weekManager = WeekSelectionManager.shared
    @State private var smartRefreshManager = SmartRefreshManager.shared
    
    init(startOnSettings: Bool, matchupsHub: MatchupsHubViewModel, allLivePlayersViewModel: AllLivePlayersViewModel) {
        self.matchupsHub = matchupsHub
        self.allLivePlayersViewModel = allLivePlayersViewModel
        _selectedTab = State(initialValue: startOnSettings ? 4 : 0)
    }
    
    /// Dynamic tab label based on live game status
    private var livePlayersTabLabel: String {
        SmartRefreshManager.shared.hasLiveGames ? "LIVE Players" : "Rost Players"
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (MAIN TAB)
                MatchupsHubView()
                    .tabItem {
                        Image(systemName: "target")
                        Text("Matchups")
                    }
                    .tag(0)
                    .environment(matchupsHub)
                
                // TEAM ROSTERS TAB
                TeamRostersView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Team Rosters")
                    }
                    .tag(1)
                    .environment(matchupsHub)
                
                // NFL SCHEDULE TAB
                NavigationStack {
                    NFLScheduleView()
                        .environment(matchupsHub)
                }
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Schedule")
                }
                .tag(2)
                
                // All Live Players Tab
                // 🔥 PURE DI: AllLivePlayersView now uses @Environment injection
                AllLivePlayersView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Rost Players")
                    }
                    .tag(3)
                    .environment(allLivePlayersViewModel)
                    .environment(playerWatchService)
                    .environment(weekManager)
                    .environment(matchupsHub)
                
                // MORE TAB
                MoreTabView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                    .tag(4)
                    .environment(matchupsHub)
            }
            .id("tabview-\(SmartRefreshManager.shared.hasLiveGames)")
            .tint(SmartRefreshManager.shared.hasLiveGames ? .gpGreen : .blue)
            .padding(.horizontal, 16)
            .preferredColorScheme(.dark)
            .onAppear {
                smartRefreshManager.calculateOptimalRefresh()
                DebugPrint(mode: .globalRefresh, "📺 TAB LABEL: hasLiveGames=\(smartRefreshManager.hasLiveGames), label=\(livePlayersTabLabel)")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
                selectedTab = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSchedule"))) { _ in
                selectedTab = 2
            }
            
            // Version display
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Version: \(AppConstants.getVersion())")
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundColor(.white)
                        .padding(.trailing, 31)
                        .padding(.bottom, 8)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}