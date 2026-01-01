//
//  DraftWarRoomApp.swift
//  DraftWarRoom
//
//  🔥 PURE DI: All dependencies injected via @Observable and @Environment
//

import SwiftUI

@main
struct DraftWarRoomApp: App {
    // 🔋 BATTERY FIX: Monitor app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifecycleManager = AppLifecycleManager.shared
    
    // 🔥 PHASE 5: Store all dependencies for pure DI
    @State private var appContainer: AppContainer
    
    init() {
        // 🔥 CRITICAL: Clean up corrupted UserDefaults at startup
        AppConstants.cleanupCorruptedUserDefaults()
        
        // Initialize app container with all dependencies
        _appContainer = State(wrappedValue: AppContainer())
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                // 🔥 PHASE 5: Inject ALL dependencies via environment (PURE DI - NO .shared IN VIEWS)
                // ViewModels
                .environment(appContainer.matchupsHubViewModel)
                .environment(appContainer.fantasyViewModel)
                .environment(appContainer.matchupDataStore)
                .environment(appContainer.allLivePlayersViewModel)
                // API Clients & Credentials
                .environment(appContainer.espnCredentials)
                .environment(appContainer.sleeperCredentials)
                // Week/Season
                .environment(appContainer.nflWeekService)
                .environment(appContainer.weekSelectionManager)
                .environment(appContainer.seasonYearManager)
                // Player Data
                .environment(appContainer.playerDirectory)
                // Game Services
                .environment(appContainer.nflGameDataService)
                .environment(appContainer.gameStatusService)
                .environment(appContainer.nflStandingsService)
                // Stats
                .environment(appContainer.sharedStatsService)
                .environment(appContainer.projectedPointsManager)
                // Supporting
                .environment(appContainer.playerWatchService)
                .environment(appContainer.teamAssetManager)
                .environment(appContainer.bettingOddsService)
                .environment(appContainer.oprKService)
        }
        // 🔋 BATTERY FIX: Update lifecycle manager when scene phase changes
        .onChange(of: scenePhase) { oldPhase, newPhase in
            lifecycleManager.updatePhase(newPhase)
        }
    }
}

// MARK: - App Container (Dependency Injection Container)

/// Holds all app-level dependencies with proper initialization order
@MainActor
final class AppContainer {
    // 🔥 PHASE 5: Store ALL services for pure DI (NO .shared IN VIEWS)
    // ViewModels
    let matchupDataStore: MatchupDataStore
    let matchupsHubViewModel: MatchupsHubViewModel
    let fantasyViewModel: FantasyViewModel
    let allLivePlayersViewModel: AllLivePlayersViewModel
    
    // API Clients & Credentials
    let sleeperAPIClient: SleeperAPIClient
    let espnAPIClient: ESPNAPIClient
    let espnCredentials: ESPNCredentialsManager
    let sleeperCredentials: SleeperCredentialsManager
    
    // Week/Season
    let nflWeekService: NFLWeekService
    let weekSelectionManager: WeekSelectionManager
    let seasonYearManager: SeasonYearManager
    
    // Player Data
    let playerDirectory: PlayerDirectoryStore
    let idCanonicalizer: ESPNSleeperIDCanonicalizer
    
    // Game Services
    let nflGameDataService: NFLGameDataService
    let gameStatusService: GameStatusService
    let nflStandingsService: NFLStandingsService
    
    // Stats
    let playerStatsCache: PlayerStatsCache
    let sharedStatsService: SharedStatsService
    let projectedPointsManager: ProjectedPointsManager
    
    // Supporting Services
    let playerWatchService: PlayerWatchService
    let teamAssetManager: TeamAssetManager
    let bettingOddsService: BettingOddsService
    let oprKService: OPRKService
    let playoffEliminationService: PlayoffEliminationService  // 🔥 NEW: Phase 2 service
    let choppedLeagueService: ChoppedLeagueService  // 🔥 NEW: Phase 2 service
    let teamRosterFetchService: TeamRosterFetchService  // 🔥 NEW: Phase 2 service
    
    // App Management
    let appInitManager: AppInitializationManager
    let centralizedLoader: CentralizedAppLoader
    
    init() {
        
        // MARK: - Core API Clients
        self.sleeperAPIClient = SleeperAPIClient()
        SleeperAPIClient.setSharedInstance(sleeperAPIClient)
        
        // MARK: - Credentials (handle circular dependency)
        self.espnCredentials = ESPNCredentialsManager()
        self.espnAPIClient = ESPNAPIClient(credentialsManager: espnCredentials)
        espnCredentials.setAPIClient(espnAPIClient)
        ESPNCredentialsManager.setSharedInstance(espnCredentials)
        ESPNAPIClient.setSharedInstance(espnAPIClient)
        
        self.sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        SleeperCredentialsManager.setSharedInstance(sleeperCredentials)
        
        // MARK: - Week/Season Services
        self.nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
        
        self.weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService)
        WeekSelectionManager.setSharedInstance(weekSelectionManager)
        
        self.seasonYearManager = SeasonYearManager()
        SeasonYearManager.setSharedInstance(seasonYearManager)
        
        // MARK: - Player Data Services
        self.playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient)
        PlayerDirectoryStore.setSharedInstance(playerDirectory)
        
        self.idCanonicalizer = ESPNSleeperIDCanonicalizer(playerDirectory: playerDirectory)
        ESPNSleeperIDCanonicalizer.setSharedInstance(idCanonicalizer)
        
        // MARK: - Game Services
        self.nflGameDataService = NFLGameDataService(
            weekSelectionManager: weekSelectionManager,
            appLifecycleManager: AppLifecycleManager.shared
        )
        NFLGameDataService.setSharedInstance(nflGameDataService)
        
        self.gameStatusService = GameStatusService(nflGameDataService: nflGameDataService)
        GameStatusService.setSharedInstance(gameStatusService)
        
        self.nflStandingsService = NFLStandingsService()
        NFLStandingsService.setSharedInstance(nflStandingsService)
        
        // MARK: - Stats Services
        self.playerStatsCache = PlayerStatsCache()
        PlayerStatsCache.setSharedInstance(playerStatsCache)
        
        self.sharedStatsService = SharedStatsService(
            weekSelectionManager: weekSelectionManager,
            seasonYearManager: seasonYearManager,
            playerStatsCache: playerStatsCache
        )
        SharedStatsService.setSharedInstance(sharedStatsService)
        
        self.projectedPointsManager = ProjectedPointsManager(
            sleeperProjectionsService: SleeperProjectionsService(),
            weekManager: weekSelectionManager,
            gameDataService: nflGameDataService
        )
        ProjectedPointsManager.setSharedInstance(projectedPointsManager)
        
        // MARK: - Supporting Services
        self.teamAssetManager = TeamAssetManager()
        TeamAssetManager.setSharedInstance(teamAssetManager)
        
        self.bettingOddsService = BettingOddsService()
        
        self.oprKService = OPRKService()
        
        // 🔥 NEW: Phase 2 - PlayoffEliminationService
        self.playoffEliminationService = PlayoffEliminationService(
            sleeperClient: sleeperAPIClient,
            espnClient: espnAPIClient
        )
        
        // 🔥 NEW: Phase 2 - ChoppedLeagueService
        self.choppedLeagueService = ChoppedLeagueService(
            sleeperClient: sleeperAPIClient,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            sharedStatsService: sharedStatsService,
            weekSelectionManager: weekSelectionManager,
            seasonYearManager: seasonYearManager,
            sleeperCredentials: sleeperCredentials
        )
        
        // 🔥 NEW: Phase 2 - TeamRosterFetchService
        self.teamRosterFetchService = TeamRosterFetchService(
            sleeperClient: sleeperAPIClient,
            espnClient: espnAPIClient,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            seasonYearManager: seasonYearManager
        )
        
        // 🔥 NEW: Phase 2 - TeamIdentificationService
        let teamIdentificationService = TeamIdentificationService(
            sleeperClient: sleeperAPIClient,
            espnClient: espnAPIClient,
            sleeperCredentials: sleeperCredentials
        )
        
        // MARK: - 🔥 PHASE 5: MatchupDataStore with DI
        let unifiedLeagueManagerForStore = UnifiedLeagueManager(
            sleeperClient: sleeperAPIClient,
            espnClient: espnAPIClient,
            espnCredentials: espnCredentials
        )
        
        self.matchupDataStore = MatchupDataStore(
            unifiedLeagueManager: unifiedLeagueManagerForStore,
            sharedStatsService: sharedStatsService,
            gameStatusService: gameStatusService,
            weekSelectionManager: weekSelectionManager,
            playoffEliminationService: playoffEliminationService,
            teamRosterFetchService: teamRosterFetchService,
            choppedLeagueService: choppedLeagueService,
            teamIdentificationService: teamIdentificationService
        )
        
        // MARK: - 🔥 PHASE 5: MatchupsHubViewModel with DI
        self.matchupsHubViewModel = MatchupsHubViewModel(
            espnCredentials: espnCredentials,
            sleeperCredentials: sleeperCredentials,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            sharedStatsService: sharedStatsService,
            matchupDataStore: matchupDataStore,
            gameDataService: nflGameDataService,
            unifiedLeagueManager: unifiedLeagueManagerForStore,
            playoffEliminationService: playoffEliminationService,
            choppedLeagueService: choppedLeagueService,
            teamRosterFetchService: teamRosterFetchService,
            teamIdentificationService: teamIdentificationService
        )
        
        // MARK: - 🔥 PHASE 5: FantasyViewModel with DI
        let unifiedLeagueManagerForFantasy = UnifiedLeagueManager(
            sleeperClient: SleeperAPIClient(),
            espnClient: ESPNAPIClient(credentialsManager: espnCredentials),
            espnCredentials: espnCredentials
        )
        
        self.fantasyViewModel = FantasyViewModel(
            matchupDataStore: matchupDataStore,
            unifiedLeagueManager: unifiedLeagueManagerForFantasy,
            sleeperCredentials: sleeperCredentials,
            playerDirectoryStore: playerDirectory,
            nflGameService: nflGameDataService,
            nflWeekService: nflWeekService
        )
        
        // MARK: - AllLivePlayersViewModel with DI
        self.allLivePlayersViewModel = AllLivePlayersViewModel(
            matchupsHubViewModel: matchupsHubViewModel,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            sharedStatsService: sharedStatsService,
            weekSelectionManager: weekSelectionManager,
            nflGameDataService: nflGameDataService
        )
        AllLivePlayersViewModel.setSharedInstance(allLivePlayersViewModel)
        
        // MARK: - PlayerWatchService with DI
        self.playerWatchService = PlayerWatchService(
            weekManager: weekSelectionManager,
            gameDataService: nflGameDataService,
            allLivePlayersViewModel: allLivePlayersViewModel
        )
        PlayerWatchService.setSharedInstance(playerWatchService)
        
        // MARK: - App Initialization
        self.appInitManager = AppInitializationManager(
            matchupsHubViewModel: matchupsHubViewModel,
            allLivePlayersViewModel: allLivePlayersViewModel,
            playerDirectory: playerDirectory,
            sharedStatsService: sharedStatsService
        )
        AppInitializationManager.setSharedInstance(appInitManager)
        
        self.centralizedLoader = CentralizedAppLoader(
            matchupsHubViewModel: matchupsHubViewModel,
            allLivePlayersViewModel: allLivePlayersViewModel,
            sharedStatsService: sharedStatsService
        )
        CentralizedAppLoader.setSharedInstance(centralizedLoader)
        
        // Mark services as ready for AppLifecycleManager idle timer logic
        AppLifecycleManager.shared.markServicesReady()
    }
}

// MARK: - Main App View with Spinning Orbs Loading
struct MainAppView: View {
    @Environment(MatchupsHubViewModel.self) private var matchupsHubViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    @State private var showingLoading = true
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        Group {
            if showingLoading {
                SpinningOrbsLoadingScreen(
                    matchupsHubViewModel: matchupsHubViewModel,
                    onComplete: { needsOnboarding in
                        shouldShowOnboarding = needsOnboarding
                        showingLoading = false
                    }
                )
            } else {
                MainTabView(startOnSettings: shouldShowOnboarding)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.5), value: showingLoading)
    }
}

// MARK: - Spinning Orbs Loading Screen
struct SpinningOrbsLoadingScreen: View {
    let matchupsHubViewModel: MatchupsHubViewModel
    let onComplete: (Bool) -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var textOpacity: Double = 0.0
    @State private var loadingMessage = "Loading your fantasy empire..."
    @State private var loadingProgress: Double = 0.0
    @State private var isDataLoading = false
    
    var body: some View {
        ZStack {
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("BigWarRoom")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textOpacity)
                        .padding(.top, 60)
                    
                    Text(loadingMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                SpinningOrbsView()
                    .opacity(0.6)
                    .scaleEffect(1.15)
                
                Spacer()
                
                VStack(spacing: 16) {
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: dynamicProgressColor(for: loadingProgress)))
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                        .padding(.horizontal, 40)
                        .opacity(textOpacity)
                    
                    Text("\(Int(loadingProgress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicProgressColor(for: loadingProgress))
                        .opacity(textOpacity)
                    
                    Text(loadingProgress >= 1.0 ? "Ready to show data" : loadingMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(loadingProgress >= 1.0 ? .green.opacity(0.8) : .white.opacity(0.8))
                        .opacity(textOpacity)

				   Spacer()

					  // 🔥 VERSION TEXT
                    Text("Version: \(AppConstants.getVersion())")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(textOpacity)
                        .padding(.top, 20)

                    Text("Copyright © \(String(Calendar.current.component(.year, from: Date()))) Cre8vPlanet Studios. All rights reserved.")
					  .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(textOpacity)
                        .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            startLoadingSequence()
        }
        .onTapGesture {
            if !isDataLoading {
                completeLoading()
            }
        }
    }
    
    private func startLoadingSequence() {
        withAnimation(.easeIn(duration: 0.8)) {
            textOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startDataLoading()
        }
    }
    
    private func startDataLoading() {
        isDataLoading = true
        
        Task {
            await updateProgress(0.2, "Checking credentials...")
            await loadCredentials()
            
            await updateProgress(0.4, "Finding your leagues...")
            await loadLeagues()
            
            await updateProgress(0.6, "Loading matchup data...")
            await loadMatchups()
            
            await updateProgress(0.8, "Processing players...")
            await loadPlayers()
            
            await updateProgress(1.0, "Ready to show data")
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                completeLoading()
            }
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double, _ message: String) async {
        loadingProgress = progress
        loadingMessage = message
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
    
    private func loadCredentials() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func loadLeagues() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func loadMatchups() async {
        await matchupsHubViewModel.loadAllMatchups()
    }
    
    private func loadPlayers() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func completeLoading() {
        let espnCredentials = ESPNCredentialsManager.shared
        let sleeperCredentials = SleeperCredentialsManager.shared
        
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials
        let hasAnyCredentials = hasESPNCredentials || hasSleeperCredentials
        
        let shouldShowOnboarding = !hasAnyCredentials
        
        logInfo("Loading complete - showing onboarding: \(shouldShowOnboarding)", category: "LoadingScreen")
        
        onComplete(shouldShowOnboarding)
    }
    
    private func dynamicProgressColor(for progress: Double) -> Color {
        let orbColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan]
        let clampedProgress = max(0, min(1, progress))
        
        if clampedProgress >= 1.0 {
            return orbColors.last ?? .cyan
        }
        
        let colorIndex = clampedProgress * Double(orbColors.count - 1)
        let lowerIndex = Int(floor(colorIndex))
        let upperIndex = min(lowerIndex + 1, orbColors.count - 1)
        
        if lowerIndex == upperIndex {
            return orbColors[lowerIndex]
        }
        
        let interpolationFactor = colorIndex - Double(lowerIndex)
        return interpolateColor(from: orbColors[lowerIndex], to: orbColors[upperIndex], factor: interpolationFactor)
    }
    
    private func interpolateColor(from: Color, to: Color, factor: Double) -> Color {
        let clampedFactor = max(0, min(1, factor))
        return Color(
            red: lerp(from: from.components.red, to: to.components.red, factor: clampedFactor),
            green: lerp(from: from.components.green, to: to.components.green, factor: clampedFactor),
            blue: lerp(from: from.components.blue, to: to.components.blue, factor: clampedFactor)
        )
    }
    
    private func lerp(from: Double, to: Double, factor: Double) -> Double {
        return from + (to - from) * factor
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}

// MARK: - Unified Main Tab View
struct MainTabView: View {
    @Environment(MatchupsHubViewModel.self) private var matchupsHubViewModel
    @State private var draftRoomViewModel = DraftRoomViewModel()
    @AppStorage("MainTabView_SelectedTab") private var storedSelectedTab: Int = 0
    @State private var hasInitialized = false
    
    let startOnSettings: Bool
    
    init(startOnSettings: Bool = false) {
        self.startOnSettings = startOnSettings
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: Binding(
                get: { storedSelectedTab },
                set: { storedSelectedTab = $0 }
            )) {
                // MATCHUPS HUB - THE COMMAND CENTER
                NavigationStack {
                    MatchupsHubView()
                }
                .tabItem {
                    Image(systemName: "target")
                    Text("Matchups")
                }
                .tag(0)
                
                // START/SIT TAB
                NavigationStack {
                    PlayerComparisonView()
                }
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Start/Sit")
                }
                .tag(1)
                
                // NFL SCHEDULE TAB
                NavigationStack {
                    NFLScheduleView()
                }
                .tabItem {
                    Image(systemName: "calendar.circle.fill")
                    Text("Schedule")
                }
                .tag(2)
                
                // ALL LIVE PLAYERS TAB - Dynamic label based on live game status
                NavigationStack {
                    AllLivePlayersView()
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(SmartRefreshManager.shared.hasLiveGames ? "LIVE Players" : "Rost Players")
                }
                .tag(3)
                
                // MORE TAB
                NavigationStack {
                    MoreTabView(viewModel: draftRoomViewModel)
                }
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("More")
                }
                .tag(4)
            }
            .id("tabview-\(SmartRefreshManager.shared.hasLiveGames)")
            .tint(SmartRefreshManager.shared.hasLiveGames ? .gpGreen : .blue)
            .onAppear {
                SmartRefreshManager.shared.calculateOptimalRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                storedSelectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
                storedSelectedTab = 0
            }
            .onAppear {
                if startOnSettings && !hasInitialized {
                    storedSelectedTab = 4
                }
                
                if !hasInitialized {
                    hasInitialized = true
                    Task {
                        await draftRoomViewModel.initializeDataAsync()
                    }
                }
            }
            
            AppVersionOverlay()
        }
    }
}

// MARK: - Reusable Version Overlay
struct AppVersionOverlay: View {
    var body: some View {
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