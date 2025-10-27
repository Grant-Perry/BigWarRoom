//
//  BigWarRoom.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct BigWarRoom: View {
    @State private var draftRoomViewModel = DraftRoomViewModel()
    @State private var initManager = AppInitializationManager.shared
    @State private var selectedTab = 3 // Changed from 0 to 3 - Start on Live Players tab
    
    // 🔥 PHASE 2: Create services with proper @State + dependency injection
    @State private var sleeperAPIClient = SleeperAPIClient()
    @State private var nflWeekService: NFLWeekService?
    @State private var weekSelectionManager: WeekSelectionManager?
    @State private var espnCredentials: ESPNCredentialsManager?
    @State private var sleeperCredentials: SleeperCredentialsManager?
    @State private var playerWatchService: PlayerWatchService?
    @State private var matchupsHubViewModel: MatchupsHubViewModel?
    @State private var allLivePlayersViewModel: AllLivePlayersViewModel?
    @State private var servicesInitialized = false
    
    var body: some View {
        ZStack {
            if initManager.isInitialized && !initManager.isLoading && servicesInitialized {
                // 🔥 MAIN APP: Only show after initialization is complete
                mainAppContent
            } else {
                // 🔥 LOADING: Show loading screen during initialization
                AppInitializationLoadingView(initManager: initManager)
                    .onAppear {
                        setupServices()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupServices()
            // 🔥 INITIALIZE: Start centralized initialization on app start
            if !initManager.isInitialized && !initManager.isLoading {
                Task {
                    await initManager.initializeApp()
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
        
        // 🔥 PHASE 2 CORRECTED: Proper @Observable service creation with dependency injection
        sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        
        // Break circular dependency: Create ESPN credentials first, then API client
        let espnCreds = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCreds)
        espnCreds.setAPIClient(espnAPIClient) // Complete the circular dependency
        espnCredentials = espnCreds
        
        // Create NFL week service and week selection manager
        nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
        weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService!)
        
        // Create watch service
        playerWatchService = PlayerWatchService()
        
        // 🔥 PHASE 2.5: Create MatchupsHubViewModel with proper dependencies
        matchupsHubViewModel = MatchupsHubViewModel(
            espnCredentials: espnCreds,
            sleeperCredentials: sleeperCredentials!
        )
        
        // 🔥 PHASE 2.5: Set the shared instance for bridge compatibility
        MatchupsHubViewModel.setSharedInstance(matchupsHubViewModel!)
        
        // Create AllLivePlayersViewModel with dependencies
        allLivePlayersViewModel = AllLivePlayersViewModel(
            matchupsHubViewModel: matchupsHubViewModel!
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
                    Text("Mission Control")
                }
                .tag(0)
                
                // NFL SCHEDULE TAB - PRIORITIZED FOR VISIBILITY
                NFLScheduleView()
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
                        .font(.system(size: 12, weight: .medium, design: .default))
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