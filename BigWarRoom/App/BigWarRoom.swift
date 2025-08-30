//
//  BigWarRoom.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct BigWarRoom: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                // Draft War Room Tab
                DraftRoomView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("War Room")
                    }
                
                // Live Draft Picks Tab
                LiveDraftPicksView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("Live Picks")
                    }
                
                // Draft Board Tab
                LeagueDraftView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Draft Board")
                    }
                
                // My Roster Tab
                MyRosterView(draftRoomViewModel: viewModel)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("My Roster")
                    }
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

#Preview {
    BigWarRoom()
}
