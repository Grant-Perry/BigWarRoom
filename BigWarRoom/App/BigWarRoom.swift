//
//  BigWarRoom.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct BigWarRoom: View {
    @State private var draftRoomViewModel = DraftRoomViewModel()
    @State private var initManager: AppInitializationManager? // Created after services
    @State private var selectedTab = 3 // Changed from 0 to 3 - Start on Live Players tab
    
    // 🔥 PHASE 3 DI: Core services created in dependency order
    @State private var sleeperAPIClient: SleeperAPIClient?
    @State private var playerDirectory: PlayerDirectoryStore?
    @State private var idCanonicalizer: ESPNSleeperIDCanonicalizer?
    @State private var nflGameDataService: NFLGameDataService?
    @State private var gameStatusService: GameStatusService?
    @State private var nflWeekService: NFLWeekService?
    @State private var weekSelectionManager: WeekSelectionManager?
    @State private var seasonYearManager: SeasonYearManager?
    @State private var playerStatsCache: PlayerStatsCache?
    @State private var sharedStatsService: SharedStatsService?
    @State private var espnCredentials: ESPNCredentialsManager?
    @State private var sleeperCredentials: SleeperCredentialsManager?
    @State private var playerWatchService: PlayerWatchService?
    @State private var matchupsHubViewModel: MatchupsHubViewModel?
    @State private var allLivePlayersViewModel: AllLivePlayersViewModel?
    @State private var fantasyViewModel: FantasyViewModel?
    @State private var nflStandingsService: NFLStandingsService?
    @State private var teamAssetManager: TeamAssetManager?
    @State private var servicesInitialized = false
    @State private var playoffEliminationService: PlayoffEliminationService?  // 🔥 NEW: Phase 2 service
    
    // 🔥 FIX: Initialize services IMMEDIATELY in init, not in onAppear
    init() {
        setupServicesSync()
    }
    
    var body: some View {
        ZStack {
            if let initManager = initManager,
               initManager.isInitialized && !initManager.isLoading && servicesInitialized {
                // 🔥 MAIN APP: Only show after initialization is complete
                mainAppContent
            } else if let initManager = initManager {
                // 🔥 LOADING: Show loading screen during initialization
                AppInitializationLoadingView(initManager: initManager)
            } else {
                // Initial setup loading
                ProgressView("Initializing...")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 🔥 INITIALIZE: Start centralized initialization on app start
            if let manager = initManager,
               !manager.isInitialized && !manager.isLoading {
                Task {
                    await manager.initializeApp()
                }
            }
        }
        // 🔥 NOTIFICATION: Handle tab switching from other views
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
            selectedTab = 0
        }
    }
    
    // 🔥 FIX: Synchronous setup that runs in init()
    private func setupServicesSync() {
        guard !servicesInitialized else { return }
        
        // 🔥 PHASE 3 DI: Create services in dependency order
        
        // 1. Core Data Services
        sleeperAPIClient = SleeperAPIClient()
        playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient!)
        idCanonicalizer = ESPNSleeperIDCanonicalizer(playerDirectory: playerDirectory!)
        
        // 2. NFL Game Services
        nflGameDataService = NFLGameDataService(
            weekSelectionManager: weekSelectionManager!,
            appLifecycleManager: AppLifecycleManager.shared
        )
        gameStatusService = GameStatusService(nflGameDataService: nflGameDataService!)
        nflStandingsService = NFLStandingsService()
        teamAssetManager = TeamAssetManager()
        
        // 3. Week/Season Management
        nflWeekService = NFLWeekService(apiClient: sleeperAPIClient!)
        weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService!)
        WeekSelectionManager.setSharedInstance(weekSelectionManager!)  // 🔥 SET .shared INSTANCE
        seasonYearManager = SeasonYearManager()
        
        // 4. Stats Services
        playerStatsCache = PlayerStatsCache()
        sharedStatsService = SharedStatsService(
            weekSelectionManager: weekSelectionManager!,
            seasonYearManager: seasonYearManager!,
            playerStatsCache: playerStatsCache!
        )
        
        // 5. Credential Management
        sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient!)
        
        // Break circular dependency: Create ESPN credentials first, then API client
        let espnCreds = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCreds)
        espnCreds.setAPIClient(espnAPIClient)
        espnCredentials = espnCreds
        
        // 6. Create UnifiedLeagueManager and MatchupDataStore
        let unifiedLeagueManager = UnifiedLeagueManager(
            sleeperClient: sleeperAPIClient!,
            espnClient: espnAPIClient,
            espnCredentials: espnCreds
        )
        
        // 🔥 NEW: Phase 2 - Create PlayoffEliminationService
        playoffEliminationService = PlayoffEliminationService(
            sleeperClient: sleeperAPIClient!,
            espnClient: espnAPIClient
        )
        
        let matchupDataStore = MatchupDataStore(
            unifiedLeagueManager: unifiedLeagueManager,
            sharedStatsService: sharedStatsService!,
            gameStatusService: gameStatusService!,
            weekSelectionManager: weekSelectionManager!,
            playoffEliminationService: playoffEliminationService!  // 🔥 NEW: Pass service
        )
        
        // 7. ViewModels with dependencies
        matchupsHubViewModel = MatchupsHubViewModel(
            espnCredentials: espnCreds,
            sleeperCredentials: sleeperCredentials!,
            playerDirectory: playerDirectory!,
            gameStatusService: gameStatusService!,
            sharedStatsService: sharedStatsService!,
            matchupDataStore: matchupDataStore,
            gameDataService: nflGameDataService!,
            unifiedLeagueManager: unifiedLeagueManager,
            playoffEliminationService: playoffEliminationService!  // 🔥 NEW: Pass service
        )
        
        // Create FantasyViewModel with dependencies
        fantasyViewModel = FantasyViewModel(
            matchupDataStore: matchupDataStore,
            unifiedLeagueManager: unifiedLeagueManager,
            sleeperCredentials: sleeperCredentials!,
            playerDirectoryStore: playerDirectory!,
            nflGameService: nflGameDataService!,
            nflWeekService: nflWeekService!
        )
        
        // Create AllLivePlayersViewModel with dependencies
        allLivePlayersViewModel = AllLivePlayersViewModel(
            matchupsHubViewModel: matchupsHubViewModel!,
            playerDirectory: playerDirectory!,
            gameStatusService: gameStatusService!,
            sharedStatsService: sharedStatsService!,
            weekSelectionManager: weekSelectionManager!,
            nflGameDataService: nflGameDataService!
        )
        
        playerWatchService = PlayerWatchService(
            weekManager: weekSelectionManager!,
            gameDataService: nflGameDataService!,
            allLivePlayersViewModel: allLivePlayersViewModel
        )
        
        // 8. Initialization Manager
        initManager = AppInitializationManager(
            matchupsHubViewModel: matchupsHubViewModel!,
            allLivePlayersViewModel: allLivePlayersViewModel!,
            playerDirectory: playerDirectory!,
            sharedStatsService: sharedStatsService!
        )
        
        servicesInitialized = true
    }
    
    // MARK: - Main App Content
    private var mainAppContent: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (MAIN TAB)
                // 🔥 FIX: Remove Group wrapper - TabView requires direct children with .tabItem()
                matchupsHubTab
                    .tabItem {
                        Image(systemName: "target")
                        Text("Matchups")
                    }
                    .tag(0)
                
                // NFL SCHEDULE TAB - PRIORITIZED FOR VISIBILITY
                nflScheduleTab
                    .tabItem {
                        Image(systemName: "calendar.circle.fill")
                        Text("Schedule")
                    }
                    .tag(1)
                
                // Fantasy Tab 
                fantasyTab
                    .tabItem {
                        Image(systemName: "football")
                        Text("Fantasy")
                    }
                    .tag(2)
                
                // All Live Players Tab
                allLivePlayersTab
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Live Players")
                    }
                    .tag(3)
                
                // Settings Tab
                settingsTab
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(4)
            }
            
            // Version display in bottom safe area
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
    
    // MARK: - Tab Views
    
    @ViewBuilder
    private var matchupsHubTab: some View {
        if let weekManager = weekSelectionManager,
           let espnCreds = espnCredentials,
           let sleeperCreds = sleeperCredentials,
           let matchupsVM = matchupsHubViewModel,
           let allLiveVM = allLivePlayersViewModel {
            MatchupsHubView(
                weekManager: weekManager,
                espnCredentials: espnCreds,
                sleeperCredentials: sleeperCreds
            )
            .environment(matchupsVM)
            .environment(allLiveVM)
            .environment(weekManager)
        } else {
            Text("Loading services...")
        }
    }
    
    @ViewBuilder
    private var nflScheduleTab: some View {
        if let matchupsVM = matchupsHubViewModel,
           let weekManager = weekSelectionManager,
           let standingsService = nflStandingsService,
           let teamAssets = teamAssetManager,
           let nflGameData = nflGameDataService,
           let nflWeek = nflWeekService,
           let espnCreds = espnCredentials {
            NFLScheduleView()
                .environment(matchupsVM)
                .environment(weekManager)
                .environment(standingsService)
                .environment(teamAssets)
                .environment(nflGameData)
                .environment(nflWeek)
                .environment(espnCreds)
        } else {
            Text("Loading services...")
        }
    }
    
    @ViewBuilder
    private var fantasyTab: some View {
        if let matchupsVM = matchupsHubViewModel,
           let fantasyVM = fantasyViewModel,
           let weekManager = weekSelectionManager {
            FantasyMatchupListView(draftRoomViewModel: draftRoomViewModel)
                .environment(matchupsVM)
                .environment(fantasyVM)
                .environment(weekManager)
        } else {
            Text("Loading services...")
        }
    }
    
    @ViewBuilder
    private var allLivePlayersTab: some View {
        if let watchService = playerWatchService,
           let weekManager = weekSelectionManager,
           let viewModel = allLivePlayersViewModel,
           let matchupsVM = matchupsHubViewModel {
            // 🔥 PURE DI: AllLivePlayersView now uses @Environment injection - NO PARAMETERS
            AllLivePlayersView()
                .environment(viewModel)
                .environment(watchService)
                .environment(weekManager)
                .environment(matchupsVM)
        } else {
            Text("Loading services...")
        }
    }
    
    @ViewBuilder
    private var settingsTab: some View {
        if let matchupsVM = matchupsHubViewModel,
           let weekManager = weekSelectionManager {
            OnBoardingView()
                .environment(matchupsVM)
                .environment(weekManager)
        } else {
            Text("Loading services...")
        }
    }
}

#Preview("BigWarRoom") {
    BigWarRoom()
        .preferredColorScheme(.dark)
}