//
//  DraftWarRoomApp.swift
//  DraftWarRoom
//
//  Created for Gp.
//
// MARK: -> App Entry

import SwiftUI

@main
struct DraftWarRoomApp: App {
    // MARK: -> Scene
    var body: some Scene {
        WindowGroup {
            CentralizedAppView()
        }
    }
}

// MARK: - Centralized App View with Proper Initialization
struct CentralizedAppView: View {
    @StateObject private var appLoader = CentralizedAppLoader.shared
    @StateObject private var viewModel = DraftRoomViewModel()
    @State private var selectedTab: Int = 0
    
    var body: some View {
        Group {
            if appLoader.isLoading || !appLoader.hasCompletedInitialization {
                // Show centralized loading screen until ALL data is loaded
                CentralizedLoadingView(loader: appLoader)
                    .onAppear {
                        if !appLoader.hasCompletedInitialization {
                            Task {
                                await appLoader.initializeApp()
                            }
                        }
                    }
            } else {
                // Main app with all data pre-loaded
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
                
                // INTELLIGENCE TAB - NEW OPPONENT ANALYSIS
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
                
                // All Live Players Tab - DATA ALREADY LOADED
                NavigationStack {
                    AllLivePlayersView()
                }
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Live Players")
                }
                .tag(3)
                
                // MORE TAB - Contains additional features AND settings
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
                selectedTab = 5
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