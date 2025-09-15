//
//  FantasyPlayerCard.swift
//  BigWarRoom
//
//  Clean, focused view for displaying fantasy player cards with minimal business logic
//

import SwiftUI

/// Clean fantasy player card view with business logic extracted to view model
struct FantasyPlayerCard: View {
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    let matchup: FantasyMatchup?
    let teamIndex: Int?
    let isBench: Bool
    
    @StateObject private var viewModel = FantasyPlayerViewModel()
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                // Background jersey number
                backgroundJerseyNumber
                
                // Team gradient background
                teamGradientBackground
                
                // Team logo
                teamLogo
                
                // Main content stack
                mainContentStack
                
                // Player name and position (right-justified)
                playerNameAndPosition
                
                // Game matchup (centered)
                gameMatchupSection
                
                // Stats section with reserved space
                statsSection
            }
            .frame(height: viewModel.cardHeight)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                viewModel.showingPlayerDetail = true
            }
            .onAppear {
                viewModel.configurePlayer(player)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh game data when app becomes active
            }
        }
        .sheet(isPresented: $viewModel.showingPlayerDetail) {
            NavigationView {
                if let sleeperPlayer = viewModel.getSleeperPlayerData(for: player) {
                    PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: player.team ?? "")
                    )
                } else {
                    PlayerDetailFallbackView(player: player)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundJerseyNumber: some View {
        VStack {
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Text(viewModel.nflPlayer?.jersey ?? player.jerseyNumber ?? "")
                        .font(.system(size: 90, weight: .black))
                        .italic()
                        .foregroundColor(viewModel.teamColor)
                        .opacity(0.65)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                }
            }
            .padding(.trailing, 8)
            Spacer()
        }
    }
    
    private var teamGradientBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [viewModel.teamColor, .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    private var teamLogo: some View {
        Group {
            if let team = player.team, let obj = NFLTeam.team(for: team) {
                if let image = UIImage(named: obj.logoAssetName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .offset(x: 20, y: -4)
                        .opacity(viewModel.isPlayerLive(player) ? 0.6 : 0.35)
                        .shadow(color: obj.primaryColor.opacity(0.5), radius: 10, x: 0, y: 0)
                } else {
                    AsyncImage(url: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "sportscourt.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .offset(x: 20, y: -4)
                    .opacity(viewModel.isPlayerLive(player) ? 0.6 : 0.35)
                    .shadow(color: viewModel.teamColor.opacity(0.5), radius: 10, x: 0, y: 0)
                }
            }
        }
    }
    
    private var mainContentStack: some View {
        HStack(spacing: 12) {
            // Player headshot
            playerHeadshot
            
            // Score display
            VStack(alignment: .trailing, spacing: 4) {
                Spacer()
                
                HStack(alignment: .bottom, spacing: 4) {
                    Spacer()
                    Text(player.currentPointsString)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .scaleEffect(viewModel.isPlayerLive(player) ? (viewModel.glowIntensity > 0.5 ? 1.15 : 1.0) : 1.0)
                        .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                }
                .padding(.bottom, 36)
                .padding(.trailing, 12)
            }
            .zIndex(3)
        }
    }
    
    private var playerHeadshot: some View {
        AsyncImage(url: player.headshotURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 95, height: 95)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 95, height: 95)
                    .clipped()
                    .opacity(viewModel.isPlayerLive(player) ? 1.0 : 0.85)
            case .failure:
                fallbackHeadshot
            @unknown default:
                EmptyView()
            }
        }
        .offset(x: -20, y: -8)
        .zIndex(2)
    }
    
    private var fallbackHeadshot: some View {
        Group {
            if let espnURL = player.espnHeadshotURL {
                AsyncImage(url: espnURL) { phase2 in
                    switch phase2 {
                    case .success(let image2):
                        image2
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 95, height: 95)
                            .clipped()
                            .opacity(viewModel.isPlayerLive(player) ? 1.0 : 0.85)
                    default:
                        defaultPlayerCircle
                    }
                }
            } else {
                defaultPlayerCircle
            }
        }
    }
    
    private var defaultPlayerCircle: some View {
        ZStack {
            Circle()
                .fill(viewModel.teamColor.opacity(0.8))
                .frame(width: 95, height: 95)
            
            Text(player.shortName.prefix(2))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .opacity(viewModel.isPlayerLive(player) ? 1.0 : 0.85)
    }
    
    private var playerNameAndPosition: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(player.fullName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                
                Text(viewModel.getPositionalRanking(for: player, in: matchup, teamIndex: teamIndex, isBench: isBench, fantasyViewModel: fantasyViewModel))
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .stroke(viewModel.teamColor.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
        .zIndex(4)
    }
    
    private var gameMatchupSection: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                MatchupTeamFinalView(player: player, scaleEffect: 1.2)
                Spacer()
            }
            .padding(.bottom, 45)
        }
        .zIndex(5)
    }
    
    private var statsSection: some View {
        VStack {
            Spacer()
            HStack {
                if player.currentPoints ?? 0.0 > 0, let statLine = viewModel.formatPlayerStatBreakdown(for: player) {
                    Text(statLine)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.7))
                                .stroke(viewModel.teamColor.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                } else {
                    // Invisible spacer to reserve space when no stats
                    Text(" ")
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.clear)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 9)
        }
        .zIndex(6)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(
                LinearGradient(
                    colors: [Color.black, viewModel.teamColor.opacity(0.1), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: viewModel.shadowColor(for: player),
                radius: viewModel.shadowRadius(for: player),
                x: 0,
                y: 0
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 15)
            .stroke(
                LinearGradient(
                    colors: viewModel.borderColors(for: player),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: viewModel.borderWidth(for: player)
            )
            .opacity(viewModel.borderOpacity(for: player))
            .shadow(
                color: viewModel.shadowColor(for: player),
                radius: viewModel.shadowRadius(for: player) * 0.5,
                x: 0,
                y: 0
            )
    }
}
