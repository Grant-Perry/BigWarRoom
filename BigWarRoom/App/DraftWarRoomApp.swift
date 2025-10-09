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
            DraftWarRoomMainView()
        }
    }
}

// MARK: - Main App View with Loading and Conditional Start
struct DraftWarRoomMainView: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    @State private var showingLoading = false // 🔥 FIX: Set to false to bypass the splash screen on launch.
    @State private var shouldShowOnboarding = false
    @State private var selectedTab: Int = 0
    
    var body: some View {
        Group {
            if showingLoading {
                LoadingScreen { needsOnboarding in
                    shouldShowOnboarding = needsOnboarding
                    selectedTab = needsOnboarding ? 4 : 0 // Settings tab if onboarding needed, Mission Control otherwise
                    showingLoading = false
                }
            } else {
                // Main TabView App
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
                        
                        // All Live Players Tab
                        NavigationStack {
                            AllLivePlayersView()
                        }
                        .tabItem {
                            Image(systemName: "chart.bar.fill")
                            Text("Live Players")
                        }
                        .tag(3)
                        
                        // MORE TAB - Contains additional features AND settings (now includes Team Rosters)
                        NavigationStack {
                            MoreTabView(viewModel: viewModel)
                        }
                        .tabItem {
                            Image(systemName: "ellipsis")
                            Text("More")
                        }
                        .tag(4)
                    }
                    .preferredColorScheme(.dark)
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                        // Switch to More tab (where War Room now lives)
                        selectedTab = 5
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
                        // Switch to Mission Control tab
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
        .animation(.easeInOut(duration: 0.5), value: showingLoading)
    }
}