//
//  ContentView.swift
//  DraftWarRoom
//
//  MARK: -> Main App Content View

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DraftRoomViewModel()
    
    var body: some View {
        TabView {
            // Draft War Room Tab
            NavigationView {
                DraftRoomView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "brain.head.profile")
                Text("War Room")
            }
            
            // League Draft Board Tab
            NavigationView {
                LeagueDraftView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "sportscourt")
                Text("Draft Board")
            }
            
            NavigationView {
                MyRosterView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("My Roster")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}