//
//  BigWarRoom.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct BigWarRoom: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    @State private var selectedTab = 0
    
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
                
                // All Live Players Tab - MOVED TO TAG 3
                AllLivePlayersView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Live Players")
                    }
                    .tag(3)
                
                // Live Draft Picks Tab - MOVED TO TAG 7
                LiveDraftPicksView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Live Picks")
                    }
                    .tag(7)
                
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
                
                // OnBoarding Tab (moved to position 8)
                OnBoardingView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(8)
            }
            .preferredColorScheme(.dark)
            
            // Version display in bottom safe area
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Text("Version: \(AppConstants.getVersion())")
					  .font(
						.system(size: 12, weight: .medium, design: .default)
					  )
                        .foregroundColor(.white)
                        .padding(.trailing, 31)
                        .padding(.bottom, 8)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}