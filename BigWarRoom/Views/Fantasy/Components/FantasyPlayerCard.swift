//
//  FantasyPlayerCard.swift
//  BigWarRoom
//
//  Clean, focused view for displaying fantasy player cards - CLEAN ARCHITECTURE
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
                buildBackgroundJerseyNumber()
                
                // Team gradient background
                buildTeamGradientBackground()
                
                // Team logo
                buildTeamLogo()
                
                // Main content stack
                buildMainContentStack()
                
                // Player name and position (right-justified)
                buildPlayerNameAndPosition()
                
                // Game matchup (centered)
                buildGameMatchupSection()
                
                // Stats section with reserved space
                buildStatsSection()
            }
            .frame(height: viewModel.cardHeight)
            .background(buildCardBackground())
            .overlay(buildCardBorder())
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
    
    // MARK: - Builder Functions (NO COMPUTED VIEW PROPERTIES)
    
    func buildBackgroundJerseyNumber() -> some View {
        FantasyPlayerCardBackgroundJerseyView(
            jerseyNumber: viewModel.nflPlayer?.jersey ?? player.jerseyNumber ?? "",
            teamColor: viewModel.teamColor
        )
    }
    
    func buildTeamGradientBackground() -> some View {
        FantasyPlayerCardTeamGradientView(teamColor: viewModel.teamColor)
    }
    
    func buildTeamLogo() -> some View {
        FantasyPlayerCardLogoView(
            player: player,
            teamColor: viewModel.teamColor,
            isPlayerLive: viewModel.isPlayerLive(player)
        )
    }
    
    func buildMainContentStack() -> some View {
        FantasyPlayerCardMainContentView(
            player: player,
            isPlayerLive: viewModel.isPlayerLive(player),
            glowIntensity: viewModel.glowIntensity
        )
    }
    
    func buildPlayerNameAndPosition() -> some View {
        FantasyPlayerCardNamePositionView(
            player: player,
            positionalRanking: viewModel.getPositionalRanking(
                for: player, 
                in: matchup, 
                teamIndex: teamIndex, 
                isBench: isBench, 
                fantasyViewModel: fantasyViewModel
            ),
            teamColor: viewModel.teamColor
        )
    }
    
    func buildGameMatchupSection() -> some View {
        FantasyPlayerCardMatchupView(player: player)
    }
    
    func buildStatsSection() -> some View {
        FantasyPlayerCardStatsView(
            player: player,
            statLine: viewModel.formatPlayerStatBreakdown(for: player),
            teamColor: viewModel.teamColor
        )
    }
    
    func buildCardBackground() -> some View {
        FantasyPlayerCardBackgroundStyleView(
            teamColor: viewModel.teamColor,
            shadowColor: viewModel.shadowColor(for: player),
            shadowRadius: viewModel.shadowRadius(for: player)
        )
    }
    
    func buildCardBorder() -> some View {
        FantasyPlayerCardBorderView(
            borderColors: viewModel.borderColors(for: player),
            borderWidth: viewModel.borderWidth(for: player),
            borderOpacity: viewModel.borderOpacity(for: player),
            shadowColor: viewModel.shadowColor(for: player),
            shadowRadius: viewModel.shadowRadius(for: player)
        )
    }
}