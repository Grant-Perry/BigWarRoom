//
//  DraftWarRoomApp.swift
//  DraftWarRoom
//
//  🔥 HYBRID APPROACH: DI at app root + Bridge pattern for backward compatibility
//

import SwiftUI

@main
struct DraftWarRoomApp: App {
    
    init() {
        // 🔥 HYBRID APPROACH: Create all services with DI at app root, then set .shared
        setupServicesWithDI()
    }
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
    }
    
    /// Setup all services with proper dependency injection, then set shared instances
    private func setupServicesWithDI() {
        // 🔥 CRITICAL: Clean up corrupted UserDefaults at startup
        AppConstants.cleanupCorruptedUserDefaults()
        
        // MARK: - Core API Clients
        let sleeperAPIClient = SleeperAPIClient()
        SleeperAPIClient.setSharedInstance(sleeperAPIClient)
        
        // MARK: - Credentials (handle circular dependency)
        let espnCredentials = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCredentials)
        espnCredentials.setAPIClient(espnAPIClient)
        ESPNCredentialsManager.setSharedInstance(espnCredentials)
        ESPNAPIClient.setSharedInstance(espnAPIClient)
        
        let sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        SleeperCredentialsManager.setSharedInstance(sleeperCredentials)
        
        // MARK: - Week/Season Services
        let nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
        NFLWeekService.setSharedInstance(nflWeekService)
        
        let weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService)
        WeekSelectionManager.setSharedInstance(weekSelectionManager)
        
        let seasonYearManager = SeasonYearManager()
        SeasonYearManager.setSharedInstance(seasonYearManager)
        
        // MARK: - Player Data Services
        let playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient)
        PlayerDirectoryStore.setSharedInstance(playerDirectory)
        
        let idCanonicalizer = ESPNSleeperIDCanonicalizer(playerDirectory: playerDirectory)
        ESPNSleeperIDCanonicalizer.setSharedInstance(idCanonicalizer)
        
        // MARK: - Game Services
        let nflGameDataService = NFLGameDataService()
        NFLGameDataService.setSharedInstance(nflGameDataService)
        
        let gameStatusService = GameStatusService(nflGameDataService: nflGameDataService)
        GameStatusService.setSharedInstance(gameStatusService)
        
        // MARK: - Stats Services
        let playerStatsCache = PlayerStatsCache()
        PlayerStatsCache.setSharedInstance(playerStatsCache)
        
        let sharedStatsService = SharedStatsService(
            weekSelectionManager: weekSelectionManager,
            seasonYearManager: seasonYearManager,
            playerStatsCache: playerStatsCache
        )
        SharedStatsService.setSharedInstance(sharedStatsService)
        
        // MARK: - ViewModels
        let matchupsHubViewModel = MatchupsHubViewModel(
            espnCredentials: espnCredentials,
            sleeperCredentials: sleeperCredentials,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            sharedStatsService: sharedStatsService
        )
        MatchupsHubViewModel.setSharedInstance(matchupsHubViewModel)
        
        let allLivePlayersViewModel = AllLivePlayersViewModel(
            matchupsHubViewModel: matchupsHubViewModel,
            playerDirectory: playerDirectory,
            gameStatusService: gameStatusService,
            sharedStatsService: sharedStatsService,
            weekSelectionManager: weekSelectionManager
        )
        AllLivePlayersViewModel.setSharedInstance(allLivePlayersViewModel)
        
        let playerWatchService = PlayerWatchService(
            weekManager: weekSelectionManager,
            allLivePlayersViewModel: allLivePlayersViewModel
        )
        PlayerWatchService.setSharedInstance(playerWatchService)
        
        // MARK: - App Initialization
        let appInitManager = AppInitializationManager(
            matchupsHubViewModel: matchupsHubViewModel,
            allLivePlayersViewModel: allLivePlayersViewModel,
            playerDirectory: playerDirectory,
            sharedStatsService: sharedStatsService
        )
        AppInitializationManager.setSharedInstance(appInitManager)
        
        let centralizedLoader = CentralizedAppLoader(
            matchupsHubViewModel: matchupsHubViewModel,
            allLivePlayersViewModel: allLivePlayersViewModel,
            sharedStatsService: sharedStatsService
        )
        CentralizedAppLoader.setSharedInstance(centralizedLoader)
        
        print("✅ HYBRID DI: All services initialized with proper dependency injection")
    }
}

// MARK: - Main App View with Spinning Orbs Loading
struct MainAppView: View {
    @State private var showingLoading = true
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        Group {
            if showingLoading {
                SpinningOrbsLoadingScreen { needsOnboarding in
                    shouldShowOnboarding = needsOnboarding
                    showingLoading = false
                }
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
                        .padding(.bottom, 40)
                    
                    Spacer()
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
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func loadMatchups() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func loadPlayers() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
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
    @State private var draftRoomViewModel = DraftRoomViewModel()
    @State private var selectedTab: Int
    @State private var hasInitialized = false
    
    init(startOnSettings: Bool = false) {
        _selectedTab = State(initialValue: startOnSettings ? 4 : 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER
                NavigationStack {
                    MatchupsHubView()
                }
                .tabItem {
                    Image(systemName: "target")
                    Text("Mission Control")
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
                
                // ALL LIVE PLAYERS TAB
                NavigationStack {
                    AllLivePlayersView()
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Live Players")
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
                selectedTab = 0
            }
            .onAppear {
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
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .padding(.trailing, 31)
                    .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview("MainTabView") {
    MainTabView()
        .preferredColorScheme(.dark)
}