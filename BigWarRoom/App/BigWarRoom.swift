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
                // Draft War Room Tab
                DraftRoomView(viewModel: viewModel, selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("War Room")
                    }
                    .tag(0)
                
                // Fantasy Tab (moved to position 1)
                FantasyMatchupListView()
                    .tabItem {
                        Image(systemName: "football")
                        Text("Fantasy")
                    }
                    .tag(1)
                
                // Live Draft Picks Tab
                LiveDraftPicksView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Live Picks")
                    }
                    .tag(2)
                
                // Draft Board Tab
                LeagueDraftView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Draft Board")
                    }
                    .tag(3)
                
                // AI Pick Suggestions Tab (moved to position 4)
                AIPickSuggestionsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "wand.and.stars")
                        Text("AI Picks")
                    }
                    .tag(4)
                
                // My Roster Tab
                MyRosterView(draftRoomViewModel: viewModel)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("My Roster")
                    }
                    .tag(5)
                
                // OnBoarding Tab
                OnBoardingView()
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .tag(6)
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