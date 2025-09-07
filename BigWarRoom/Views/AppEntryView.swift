//
//  AppEntryView.swift
//  BigWarRoom
//
//  Entry point that handles loading screen and navigation based on user credentials
//

import SwiftUI

struct AppEntryView: View {
    @State private var showingLoading = true
    @State private var shouldShowOnboarding = false
    
    var body: some View {
        Group {
            if showingLoading {
                LoadingScreen { needsOnboarding in
                    shouldShowOnboarding = needsOnboarding
                    showingLoading = false
                }
            } else {
                // Show main app - start on appropriate tab based on onboarding status
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
        // If user needs onboarding → start on Settings (7)
        // If user has credentials → start on Mission Control (0)
        _selectedTab = State(initialValue: startOnSettings ? 7 : 0)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                // MATCHUPS HUB - THE COMMAND CENTER (NEW MAIN TAB)
                MatchupsHubView()
                    .tabItem {
                        Image(systemName: "target")
                        Text("Mission Control")
                    }
                    .tag(0)
                
                // Draft War Room Tab
                DraftRoomView(viewModel: viewModel, selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("War Room")
                    }
                    .tag(1)
                
                // Fantasy Tab (moved to position 2)
                FantasyMatchupListView(draftRoomViewModel: viewModel)
                    .tabItem {
                        Image(systemName: "football")
                        Text("Fantasy")
                    }
                    .tag(2)
                
                // Live Draft Picks Tab
                LiveDraftPicksView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Live Picks")
                    }
                    .tag(3)
                
                // Draft Board Tab
                LeagueDraftView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Draft Board")
                    }
                    .tag(4)
                
                // AI Pick Suggestions Tab (moved to position 5)
                AIPickSuggestionsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "wand.and.stars")
                        Text("AI Picks")
                    }
                    .tag(5)
                
                // My Roster Tab
                MyRosterView(draftRoomViewModel: viewModel)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("My Roster")
                    }
                    .tag(6)
                
                // Settings Tab - New proper Settings view
                AppSettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(7)
            }
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                // 🔥 FIX: Switch to War Room tab when Continue button is pressed
                selectedTab = 1
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMissionControl"))) { _ in
                // 🔥 NEW: Switch to Mission Control tab when Continue button is pressed
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