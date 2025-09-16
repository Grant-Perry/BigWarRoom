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
                
                // WAR ROOM TAB (was Draft Room)
                DraftRoomView(viewModel: viewModel, selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("War Room")
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
                
                // Settings Tab
                AppSettingsView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(4)
                
                // MORE TAB - Contains additional features
                NavigationView {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("More")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // More options list
                        List {
                            NavigationLink(destination: LeagueDraftView(viewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "list.bullet.clipboard")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Draft Board")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            NavigationLink(destination: AIPickSuggestionsView(viewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    Text("AI Picks")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            NavigationLink(destination: MyRosterView(draftRoomViewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "person.crop.circle")
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    Text("My Roster")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            NavigationLink(destination: FantasyMatchupListView(draftRoomViewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "football")
                                        .foregroundColor(.orange)
                                        .frame(width: 24)
                                    Text("Fantasy")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            
                            NavigationLink(destination: LiveDraftPicksView(viewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Live Picks")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.black)
                        .scrollContentBackground(.hidden)
                        
                        Spacer()
                    }
                    .background(Color.black)
                }
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("More")
                }
                .tag(5)
            }
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToWarRoom"))) { _ in
                // Switch to War Room tab
                selectedTab = 1
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