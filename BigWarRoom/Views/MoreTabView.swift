//
//  MoreTabView.swift
//  BigWarRoom
//
//  Dedicated More tab view to avoid NavigationView conflicts
//

import SwiftUI

struct MoreTabView: View {
    let viewModel: DraftRoomViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    // MARK: - Menu Data Configuration
    private let menuItems: [MenuItem] = [
        MenuItem(
            icon: "eye.circle.fill",
            iconColor: .cyan,
            title: "Intelligence",
            subtitle: "Opponent analysis and strategic insights",
            destination: .intelligence
        ),
        MenuItem(
            icon: "magnifyingglass.circle.fill",
            iconColor: .blue,
            title: "Player Search",
            subtitle: "Search NFL players and stats",
            destination: .playerSearch
        ),
        MenuItem(
            icon: "gearshape.fill",
            iconColor: .gray,
            title: "Settings",
            subtitle: "App configuration and setup",
            destination: .settings
        ),
        MenuItem(
            icon: "star.circle.fill",
            iconColor: .gpPostBot,
            title: "App Features",
            subtitle: "Complete feature overview",
            destination: .features
        ),
        MenuItem(
            icon: "pills.fill",
            iconColor: .gpGreen,
            title: "Lineup RX",
            subtitle: "AI-powered lineup optimization",
            destination: .lineupRX
        ),
        MenuItem(
            icon: "person.3.fill",
            iconColor: .green,
            title: "Team Rosters",
            subtitle: "NFL team depth charts",
            destination: .teamRosters
        ),

        MenuItem(
            icon: "brain.head.profile",
            iconColor: .purple,
            title: "AI Picks",
            subtitle: "Smart draft recommendations",
            destination: .aiPicks
        ),
        MenuItem(
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            iconColor: .yellow,
            title: "Betting Odds - SOON",
            subtitle: "Test The Odds API integration",
            destination: .bettingOddsTest
        ),
		MenuItem(
		 icon: "shield.fill",
		 iconColor: .orange,
		 title: "War Room - DEPRECATED",
		 subtitle: "Draft preparation and strategy",
		 destination: .warRoom
		),
        MenuItem(
            icon: "clock.fill",
            iconColor: .red,
            title: "Live Picks - DEPRECATED",
            subtitle: "Real-time draft tracking",
            destination: .livePicks
        ),
		MenuItem(
		 icon: "list.clipboard.fill",
		 iconColor: .cyan,
		 title: "Draft Board - DEPRECATED",
		 subtitle: "Track draft picks and rankings",
		 destination: .draftBoard
		),
		MenuItem(
		 icon: "list.clipboard.fill",
		 iconColor: .cyan,
		 title: "Draft Board - DEPRECATED",
		 subtitle: "Track draft picks and rankings",
		 destination: .draftBoard
		),
        MenuItem(
            icon: "person.crop.circle.fill",
            iconColor: .gpGreen,
			title: "My Roster - DEPRECATED",
            subtitle: "Your fantasy team analysis",
            destination: .myRoster
        ),
        MenuItem(
            icon: "sportscourt.fill",
            iconColor: .gpBlue,
			title: "Fantasy - DEPRECATED",
            subtitle: "League matchups and lineups",
            destination: .fantasy
        )
    ]
    
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
                    
                    // Data-Driven Features List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(menuItems) { menuItem in
                                NavigationLink(destination: destinationView(for: menuItem.destination)) {
                                    MoreRowView(
                                        icon: menuItem.icon,
                                        iconColor: menuItem.iconColor,
                                        title: menuItem.title,
                                        subtitle: menuItem.subtitle
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
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
    
    // MARK: - Destination View Builder
    @ViewBuilder
    private func destinationView(for destination: MenuDestination) -> some View {
        switch destination {
        case .playerSearch:
            PlayerSearchView()
        case .features:
            FeaturesView()
        case .settings:
            AppSettingsView(nflWeekService: nflWeekService)
        case .teamRosters:
            TeamRostersView()
        case .warRoom:
            DraftRoomView(viewModel: viewModel, selectedTab: .constant(4))
        case .aiPicks:
            AIPickSuggestionsView(viewModel: viewModel)
        case .draftBoard:
            LeagueDraftView(viewModel: viewModel)
        case .livePicks:
            LiveDraftPicksView(viewModel: viewModel)
        case .myRoster:
            MyRosterView(draftRoomViewModel: viewModel)
        case .fantasy:
            FantasyMatchupListView(draftRoomViewModel: viewModel)
        case .bettingOddsTest:
            BettingOddsTestView()
        case .intelligence:
            OpponentIntelligenceDashboardView()
        case .lineupRX:
            LineupRXLeaguePickerView()
        }
    }
}

// MARK: - Menu Data Models

struct MenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let destination: MenuDestination
}

enum MenuDestination: CaseIterable {
    case playerSearch, features, settings, teamRosters, warRoom, aiPicks, draftBoard, livePicks, myRoster, fantasy, bettingOddsTest, intelligence, lineupRX
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