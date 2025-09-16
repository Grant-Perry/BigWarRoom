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

#Preview("BigWarRoom") {
    BigWarRoom()
        .preferredColorScheme(.dark)
}