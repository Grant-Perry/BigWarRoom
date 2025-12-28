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
    
    var body: some View {
        Group {
            if showingLoading {
                LoadingScreen(
                    onComplete: { needsOnboarding in
                        shouldShowOnboarding = needsOnboarding
                        showingLoading = false
                    },
                    espnCredentials: ESPNCredentialsManager.shared,
                    sleeperCredentials: SleeperCredentialsManager.shared,
                    matchupsHub: MatchupsHubViewModel.shared
                )
            } else {
                // Only show main app AFTER loading completes
                BigWarRoomWithConditionalStart(shouldShowOnboarding: shouldShowOnboarding)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingLoading)
    }
}

// Wrapper to show BigWarRoom with conditional starting tab
struct BigWarRoomWithConditionalStart: View {
    let shouldShowOnboarding: Bool
    
    var body: some View {
        BigWarRoomModified(startOnSettings: shouldShowOnboarding)
    }
}

// 🔥 SIMPLIFIED: Remove all the tab disabling bullshit - data is already loaded
struct BigWarRoomModified: View {
    @State private var viewModel = DraftRoomViewModel()
    @State private var matchupsHub = MatchupsHubViewModel.shared
    @State private var selectedTab: Int
    
    // 🔥 PHASE 3 DI: Create shared instances at app level to pass down
    @State private var allLivePlayersViewModel = AllLivePlayersViewModel.shared
    @State private var playerWatchService = PlayerWatchService.shared
    @State private var weekManager = WeekSelectionManager.shared
    @State private var smartRefreshManager = SmartRefreshManager.shared
    
    init(startOnSettings: Bool) {
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
                
                // TEAM ROSTERS TAB
                TeamRostersView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Team Rosters")
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
                
                // All Live Players Tab
                // 🔥 PHASE 3 DI: Pass dependencies instead of using .shared
                AllLivePlayersView(
                    allLivePlayersViewModel: allLivePlayersViewModel,
                    watchService: playerWatchService,
                    weekManager: weekManager
                )
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Rost Players")
                }
                .tag(3)
                
                // MORE TAB
                MoreTabView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                    .tag(4)
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

// MARK: - Preview
#Preview("Loading") {
    AppEntryView()
}

#Preview("Mission Control Default") {
    BigWarRoomWithConditionalStart(shouldShowOnboarding: false)
}

#Preview("Settings Default") {
    BigWarRoomWithConditionalStart(shouldShowOnboarding: true)
}
