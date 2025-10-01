//
//  MoreTabView.swift
//  BigWarRoom
//
//  Dedicated More tab view to avoid NavigationView conflicts
//

import SwiftUI

struct MoreTabView: View {
    let viewModel: DraftRoomViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
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
                    
                    // Features List
                    ScrollView {
                        VStack(spacing: 12) {
                            // Player Search
                            NavigationLink(destination: PlayerSearchView()) {
                                MoreRowView(
                                    icon: "person.crop.circle",
                                    iconColor: .gpGreen,
                                    title: "Player Search",
                                    subtitle: "Search and view detailed player stats"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // War Room
                            NavigationLink(destination: DraftRoomView(viewModel: viewModel, selectedTab: .constant(4))) {
                                MoreRowView(
                                    icon: "person.2.fill",
                                    iconColor: .gpPostBot,
                                    title: "War Room",
                                    subtitle: "Draft room and live draft tracking"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // App Features
                            NavigationLink(destination: FeaturesView()) {
                                MoreRowView(
                                    icon: "star.circle.fill",
                                    iconColor: .gpPostBot,
                                    title: "App Features",
                                    subtitle: "Complete feature overview"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Settings
                            NavigationLink(destination: AppSettingsView()) {
                                MoreRowView(
                                    icon: "gearshape.fill",
                                    iconColor: .gray,
                                    title: "Settings",
                                    subtitle: "App configuration and setup"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Draft Board
                            NavigationLink(destination: LeagueDraftView(viewModel: viewModel)) {
                                MoreRowView(
                                    icon: "list.bullet.clipboard",
                                    iconColor: .blue,
                                    title: "Draft Board",
                                    subtitle: "Interactive draft tracking"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // AI Picks
                            NavigationLink(destination: AIPickSuggestionsView(viewModel: viewModel)) {
                                MoreRowView(
                                    icon: "brain.head.profile",
                                    iconColor: .purple,
                                    title: "AI Picks",
                                    subtitle: "Smart draft recommendations"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // My Roster
                            NavigationLink(destination: MyRosterView(draftRoomViewModel: viewModel)) {
                                MoreRowView(
                                    icon: "person.crop.circle",
                                    iconColor: .green,
                                    title: "My Roster",
                                    subtitle: "Roster management and analysis"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Fantasy
                            NavigationLink(destination: FantasyMatchupListView(draftRoomViewModel: viewModel)) {
                                MoreRowView(
                                    icon: "football",
                                    iconColor: .orange,
                                    title: "Fantasy",
                                    subtitle: "League matchups and analysis"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Live Picks
                            NavigationLink(destination: LiveDraftPicksView(viewModel: viewModel)) {
                                MoreRowView(
                                    icon: "clock.fill",
                                    iconColor: .red,
                                    title: "Live Picks",
                                    subtitle: "Real-time draft updates"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // Extra space for tab bar
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Enhanced More Row Component
struct MoreRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    
    init(icon: String, iconColor: Color, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview("More Tab") {
    MoreTabView(viewModel: DraftRoomViewModel())
        .preferredColorScheme(.dark)
}