//
//  DraftWarRoomApp.swift
//  DraftWarRoom
//
//  🔥 UPDATED: Using progressive loading to eliminate redundant API calls
//

import SwiftUI

@main
struct DraftWarRoomApp: App {
    var body: some Scene {
        WindowGroup {
            ProgressiveAppView()
        }
    }
}

// MARK: - Progressive App View with Smart Loading

struct ProgressiveAppView: View {
    @StateObject private var appLoader = CentralizedAppLoader.shared
    @StateObject private var viewModel = DraftRoomViewModel()
    @State private var selectedTab: Int = 0
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        Group {
            if appLoader.isLoading || !appLoader.hasCompletedInitialization {
                // 🔥 FIX: Use progressive loading instead of blocking "load everything"
                CentralizedLoadingView(loader: appLoader)
                    .onAppear {
                        if !appLoader.hasCompletedInitialization {
                            Task {
                                // 🔥 NEW: Use progressive loading method
                                await appLoader.initializeAppProgressively()
                            }
                        }
                    }
            } else if appLoader.canShowPartialData || appLoader.hasCompletedInitialization {
                // 🔥 NEW: Show main app as soon as we have partial data
                mainAppTabs
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var mainAppTabs: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (MAIN TAB)
                NavigationStack {
                    MatchupsHubView()
                }
                .tabItem {
                    Image(systemName: "target")
                    Text("Mission Control")
                }
                .tag(0)
                
                // INTELLIGENCE TAB
                NavigationStack {
                    OpponentIntelligenceDashboardView()
                }
                .tabItem {
                    Image(systemName: "eye.circle.fill")
                    Text("Intelligence")
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
                
                // ALL LIVE PLAYERS TAB - Shows partial data as it loads
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
                    MoreTabView(viewModel: viewModel)
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
            
            // Version display
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