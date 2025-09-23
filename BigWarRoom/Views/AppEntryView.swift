//
//  AppEntryView.swift
//  BigWarRoom
//
//  Entry point that handles loading screen and navigation based on user credentials
//

import SwiftUI

struct AppEntryView: View {
    @State private var showingLoading = false
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        Group {
            if showingLoading {
                LoadingScreen { needsOnboarding in
                    shouldShowOnboarding = needsOnboarding
                    showingLoading = false
                }
            } else {
                // BYPASS: Go directly to Mission Control (tab 0)
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

// Modified BigWarRoom that conditionally starts on Settings or Mission Control
struct BigWarRoomModified: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    @State private var selectedTab: Int
    
    // Initialize with conditional starting tab
    init(startOnSettings: Bool) {
        // If user needs onboarding → start on Settings (4)
        // If user has credentials → start on Mission Control (0)
        _selectedTab = State(initialValue: startOnSettings ? 4 : 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (MAIN TAB)
                MatchupsHubView()
                    .tabItem {
                        Image(systemName: "target")
                        Text("Mission Control")
                    }
                    .tag(0)
                
                // TEAM ROSTERS TAB (replaces War Room)
                TeamRostersView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Team Rosters")
                    }
                    .tag(1)
                
                // NFL SCHEDULE TAB
                NFLScheduleView()
                    .tabItem {
                        Image(systemName: "calendar.circle.fill")
                        Text("Schedule")
                    }
                    .tag(2)
                
                // All Live Players Tab
                AllLivePlayersView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Live Players")
                    }
                    .tag(3)
                
                // MORE TAB - Contains additional features AND settings (now includes War Room)
                MoreTabView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "ellipsis")
                        Text("More")
                    }
                    .tag(4)
            }
            .padding(.horizontal, 16) // FINALLY! This should add padding to ALL tab content
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                // Switch to More tab (where War Room now lives)
                selectedTab = 4
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