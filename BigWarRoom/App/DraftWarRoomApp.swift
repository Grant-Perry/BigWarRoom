//
//  DraftWarRoomApp.swift
//  DraftWarRoom
//
//  🔥 UNIFIED: Single app entry point with spinning orbs loading
//

import SwiftUI

@main
struct DraftWarRoomApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
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

// MARK: - Spinning Orbs Loading Screen (Image1 Layout Style)
struct SpinningOrbsLoadingScreen: View {
    let onComplete: (Bool) -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var textOpacity: Double = 0.0
    @State private var loadingMessage = "Loading your fantasy empire..."
    @State private var loadingProgress: Double = 0.0
    @State private var isDataLoading = false
    
    // 🔥 PHASE 2 CORRECTED: Create services with proper @State + dependency injection
    @State private var sleeperAPIClient = SleeperAPIClient()
    @State private var espnCredentials: ESPNCredentialsManager?
    @State private var sleeperCredentials: SleeperCredentialsManager?
    
    var body: some View {
        ZStack {
            // Background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.4)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top section with title
                VStack(spacing: 8) {
                    // 🔥 BIGWARROOM - Large title like your screenshot
                    Text("BigWarRoom")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textOpacity)
                        .padding(.top, 60) // Position below dynamic island
                    
                    // 🔥 LOADING MESSAGE - Subtitle like your screenshot
                    Text(loadingMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)
                }
                
                Spacer()
                
                // 🔥 SPINNING ORBS - Centered in middle area
                SpinningOrbsView()
                    .opacity(0.6)
                    .scaleEffect(1.15)
                
                Spacer()
                
                // Bottom section with progress
                VStack(spacing: 16) {
                    // 🔥 DYNAMIC ORB COLOR PROGRESS BAR
                    ProgressView(value: loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: dynamicProgressColor(for: loadingProgress)))
                        .frame(height: 8)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                        .padding(.horizontal, 40)
                        .opacity(textOpacity)
                    
                    // 🔥 DYNAMIC ORB COLOR PERCENTAGE
                    Text("\(Int(loadingProgress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicProgressColor(for: loadingProgress))
                        .opacity(textOpacity)
                    
                    // 🔥 DYNAMIC STATUS MESSAGE - Shows current loading stage
                    Text(loadingProgress >= 1.0 ? "Ready to show data" : loadingMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(loadingProgress >= 1.0 ? .green.opacity(0.8) : .white.opacity(0.8))
                        .opacity(textOpacity)
                        .padding(.bottom, 40)
                    
                    // 🔥 SPACER to push everything closer together
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            setupServices()
            startLoadingSequence()
        }
        .onTapGesture {
            if !isDataLoading {
                completeLoading()
            }
        }
    }
    
    private func setupServices() {
        // 🔥 PHASE 2 CORRECTED: Create @Observable services with proper dependency injection
        // Break circular dependency by creating services in proper order
        sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        
        // Create ESPN credentials manager first without API client
        let espnCredentials = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCredentials)
        // Then set the API client to complete the dependency injection
        espnCredentials.setAPIClient(espnAPIClient)
        self.espnCredentials = espnCredentials
    }
    
    private func startLoadingSequence() {
        // Show content immediately
        withAnimation(.easeIn(duration: 0.8)) {
            textOpacity = 1.0
        }
        
        // Start data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startDataLoading()
        }
    }
    
    private func startDataLoading() {
        isDataLoading = true
        
        Task {
            // Simulate loading stages with progress updates
            await updateProgress(0.2, "Checking credentials...")
            await loadCredentials()
            
            await updateProgress(0.4, "Finding your leagues...")
            await loadLeagues()
            
            await updateProgress(0.6, "Loading matchup data...")
            await loadMatchups()
            
            await updateProgress(0.8, "Processing players...")
            await loadPlayers()
            
            await updateProgress(1.0, "Ready to show data")
            
            // Small delay before completion
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
        
        // Small delay for visual feedback
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
        guard let espnCredentials = espnCredentials,
              let sleeperCredentials = sleeperCredentials else {
            // Handle error case
            onComplete(true)
            return
        }
        
        let hasESPNCredentials = espnCredentials.hasValidCredentials
        let hasSleeperCredentials = sleeperCredentials.hasValidCredentials
        let hasAnyCredentials = hasESPNCredentials || hasSleeperCredentials
        
        let shouldShowOnboarding = !hasAnyCredentials
        
        logInfo("Loading complete - showing onboarding: \(shouldShowOnboarding)", category: "LoadingScreen")
        
        onComplete(shouldShowOnboarding)
    }
    
    // MARK: - Dynamic Orb Colors
    
    /// Get dynamic color based on loading progress using orb colors
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
    
    /// Interpolate between two colors
    private func interpolateColor(from: Color, to: Color, factor: Double) -> Color {
        let clampedFactor = max(0, min(1, factor))
        // For SwiftUI, we'll create a gradient and sample it
        return Color(
            red: lerp(from: from.components.red, to: to.components.red, factor: clampedFactor),
            green: lerp(from: from.components.green, to: to.components.green, factor: clampedFactor),
            blue: lerp(from: from.components.blue, to: to.components.blue, factor: clampedFactor)
        )
    }
    
    /// Linear interpolation
    private func lerp(from: Double, to: Double, factor: Double) -> Double {
        return from + (to - from) * factor
    }
}

// MARK: - Color Extension for Component Access
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
    
    // 🔥 PHASE 2 CORRECTED: Create services with proper @State + dependency injection
    @State private var sleeperAPIClient = SleeperAPIClient()
    @State private var nflWeekService: NFLWeekService?
    @State private var weekSelectionManager: WeekSelectionManager?
    @State private var espnCredentials: ESPNCredentialsManager?
    @State private var sleeperCredentials: SleeperCredentialsManager?
    
    init(startOnSettings: Bool = false) {
        _selectedTab = State(initialValue: startOnSettings ? 4 : 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER
                NavigationStack {
                    if let weekManager = weekSelectionManager,
                       let espnCreds = espnCredentials,
                       let sleeperCreds = sleeperCredentials {
                        // 🔥 PHASE 2.5: Create MatchupsHubViewModel with proper dependencies
                        let matchupsHubVM = MatchupsHubViewModel(
                            espnCredentials: espnCreds,
                            sleeperCredentials: sleeperCreds
                        )
                        MatchupsHubView(
                            weekManager: weekManager,
                            espnCredentials: espnCreds,
                            sleeperCredentials: sleeperCreds,
                            matchupsHubViewModel: matchupsHubVM
                        )
                    } else {
                        Text("Loading services...")
                            .onAppear {
                                setupServices()
                            }
                    }
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
                    if let weekManager = weekSelectionManager,
                       let espnCreds = espnCredentials,
                       let sleeperCreds = sleeperCredentials {
                        // 🔥 PHASE 2.5: Create AllLivePlayersView with proper dependencies
                        let matchupsHubVM = MatchupsHubViewModel(
                            espnCredentials: espnCreds,
                            sleeperCredentials: sleeperCreds
                        )
                        let allLivePlayersVM = AllLivePlayersViewModel(
                            matchupsHubViewModel: matchupsHubVM
                        )
                        let watchService = PlayerWatchService.shared
                        
                        AllLivePlayersView(
                            allLivePlayersViewModel: allLivePlayersVM,
                            watchService: watchService,
                            weekManager: weekManager
                        )
                    } else {
                        Text("Loading services...")
                            .onAppear {
                                setupServices()
                            }
                    }
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
                // 🔥 PERFORMANCE FIX: Initialize DraftRoomViewModel data after UI appears
                if !hasInitialized {
                    hasInitialized = true
                    Task {
                        await draftRoomViewModel.initializeDataAsync()
                    }
                }
            }
            
            // Version display
            AppVersionOverlay()
        }
    }
    
    private func setupServices() {
        // 🔥 PHASE 2 CORRECTED: Proper @Observable service creation with dependency injection
        guard nflWeekService == nil else { return }
        
        // Create services in proper dependency order and set shared instances for bridge pattern
        SleeperAPIClient.setSharedInstance(sleeperAPIClient)
        
        sleeperCredentials = SleeperCredentialsManager(apiClient: sleeperAPIClient)
        SleeperCredentialsManager.setSharedInstance(sleeperCredentials!)
        
        // Break circular dependency: Create ESPN credentials first, then API client
        let espnCreds = ESPNCredentialsManager()
        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCreds)
        espnCreds.setAPIClient(espnAPIClient) // Complete the circular dependency
        espnCredentials = espnCreds
        ESPNCredentialsManager.setSharedInstance(espnCreds)
        ESPNAPIClient.setSharedInstance(espnAPIClient)
        
        // Create NFL week service and week selection manager
        nflWeekService = NFLWeekService(apiClient: sleeperAPIClient)
        NFLWeekService.setSharedInstance(nflWeekService!)
        
        weekSelectionManager = WeekSelectionManager(nflWeekService: nflWeekService!)
        WeekSelectionManager.setSharedInstance(weekSelectionManager!)
        
        // Create other services
        let playerDirectory = PlayerDirectoryStore(apiClient: sleeperAPIClient)
        PlayerDirectoryStore.setSharedInstance(playerDirectory)
        
        let nflGameService = NFLGameDataService()
        NFLGameDataService.setSharedInstance(nflGameService)
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

// MARK: - Preview
#Preview("MainTabView") {
    MainTabView()
        .preferredColorScheme(.dark)
}