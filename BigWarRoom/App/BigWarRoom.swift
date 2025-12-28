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
    @State private var sleeperAPIClient = SleeperAPIClient()
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
    @State private var servicesInitialized = false
    
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
                    .onAppear {
                        setupServices()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupServices()
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
    
    private func setupServices() {
        guard !servicesInitialized else { return }
        
        // 🔥 PHASE 3 DI: Create services in dependency order
        
        // 1. Core Data Services
        playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient)
        idCanonicalizer = ESPNSleeperIDCanonicalizer(playerDirectory: playerDirectory!)
        
        // 2. NFL Game Services
        nflGameDataService = NFLGameDataService()
        gameStatusService = GameStatusService(nflGameDataService: nflGameDataService!)
        
        // 3. Week/Season Management
        nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
        weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService!)
        seasonYearManager = SeasonYearManager()
        
        // 4. Stats Services
        playerStatsCache = PlayerStatsCache()
        sharedStatsService = SharedStatsService(
            weekSelectionManager: weekSelectionManager!,
            seasonYearManager: seasonYearManager!,
            playerStatsCache: playerStatsCache!
        )
        
        // 5. Credential Management
        sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        
        // Break circular dependency: Create ESPN credentials first, then API client
        let espnCreds = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCreds)
        espnCreds.setAPIClient(espnAPIClient)
        espnCredentials = espnCreds
        
        // 6. ViewModels with dependencies
        matchupsHubViewModel = MatchupsHubViewModel(
            espnCredentials: espnCreds,
            sleeperCredentials: sleeperCredentials!,
            playerDirectory: playerDirectory!,
            gameStatusService: gameStatusService!,
            sharedStatsService: sharedStatsService!
        )
        
        // Create AllLivePlayersViewModel with dependencies
        allLivePlayersViewModel = AllLivePlayersViewModel(
            matchupsHubViewModel: matchupsHubViewModel!,
            playerDirectory: playerDirectory!,
            gameStatusService: gameStatusService!,
            sharedStatsService: sharedStatsService!,
            weekSelectionManager: weekSelectionManager!
        )
        
        playerWatchService = PlayerWatchService(
            weekManager: weekSelectionManager!,
            allLivePlayersViewModel: allLivePlayersViewModel
        )
        
        // 7. Initialization Manager
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
                Group {
                    if let weekManager = weekSelectionManager,
                       let espnCreds = espnCredentials,
                       let sleeperCreds = sleeperCredentials,
                       let matchupsVM = matchupsHubViewModel {
                        MatchupsHubView(
                            weekManager: weekManager,
                            espnCredentials: espnCreds,
                            sleeperCredentials: sleeperCreds,
                            matchupsHubViewModel: matchupsVM
                        )
                    } else {
                        Text("Loading services...")
                    }
                }
                .tabItem {
                    Image(systemName: "target")
                    Text("Matchups")
                }
                .tag(0)
                
                // NFL SCHEDULE TAB - PRIORITIZED FOR VISIBILITY
                Group {
                    NFLScheduleView()
                }
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Schedule")
                }
                .tag(1)
                
                // Fantasy Tab 
                FantasyMatchupListView(draftRoomViewModel: draftRoomViewModel)
                    .tabItem {
                        Image(systemName: "football")
                        Text("Fantasy")
                    }
                    .tag(2)
                
                // All Live Players Tab
                Group {
                    if let watchService = playerWatchService,
                       let weekManager = weekSelectionManager,
                       let viewModel = allLivePlayersViewModel {
                        AllLivePlayersView(
                            allLivePlayersViewModel: viewModel,
                            watchService: watchService,
                            weekManager: weekManager
                        )
                    } else {
                        Text("Loading services...")
                    }
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Live Players")
                }
                .tag(3)
                
                // Settings Tab
                OnBoardingView()
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
}

#Preview("BigWarRoom") {
    BigWarRoom()
        .preferredColorScheme(.dark)
}
