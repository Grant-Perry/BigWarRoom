//
//  BigWarRoom.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct BigWarRoom: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    @StateObject private var initManager = AppInitializationManager.shared
    @State private var selectedTab = 3 // Changed from 0 to 3 - Start on Live Players tab
    
    var body: some View {
        ZStack {
            if initManager.isInitialized && !initManager.isLoading {
                // 🔥 MAIN APP: Only show after initialization is complete
                mainAppContent
            } else {
                // 🔥 LOADING: Show loading screen during initialization
                AppInitializationLoadingView(initManager: initManager)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
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
    
    // MARK: - Main App Content
    private var mainAppContent: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (MAIN TAB)
                MatchupsHubView()
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
                FantasyMatchupListView(draftRoomViewModel: viewModel)
                    .tabItem {
                        Image(systemName: "football")
                        Text("Fantasy")
                    }
                    .tag(2)
                
                // All Live Players Tab
                AllLivePlayersView()
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