//
//  PlayerScoreBarCardPlayerImageView.swift
//  BigWarRoom
//
//  Player image component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardPlayerImageView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    // 🔥 NEW: State for player detail sheet
    @State private var showingPlayerDetail = false
    @StateObject private var playerDirectory = PlayerDirectoryStore.shared
    
    var body: some View {
        ZStack {
            // Main player image or team logo
            Group {
                // 🔥 NEW: For D/ST players, use team logo instead of player photo
                if isDefenseOrSpecialTeams {
                    // Show team logo for defense/special teams
                    if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                        TeamAssetManager.shared.logoOrFallback(for: team.id)
                            .frame(width: 150, height: 180)
                    } else {
                        // Fallback for defense without recognized team
                        Rectangle()
                            .fill(teamGradient)
                            .overlay(
                                VStack(spacing: 4) {
                                    Text(playerEntry.position)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(playerEntry.player.team ?? "")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )
                            .frame(width: 150, height: 180)
                    }
                } else {
                    // Regular player - show headshot
                    AsyncImage(url: playerEntry.player.headshotURL) { phase in
                        switch phase {
                        case .empty:
                            // Loading state
                            Rectangle()
                                .fill(teamGradient)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        case .success(let image):
                            // Successfully loaded image
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure(_):
                            // Failed to load - try alternative URL or show fallback
                            AsyncImage(url: alternativeImageURL) { altPhase in
                                switch altPhase {
                                case .success(let altImage):
                                    altImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                default:
                                    Rectangle()
                                        .fill(teamGradient)
                                        .overlay(
                                            Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        @unknown default:
                            Rectangle()
                                .fill(teamGradient)
                                .overlay(
                                    Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 150, height: 180)
                }
            }
        }
        .onTapGesture {
            showingPlayerDetail = true
        }
        .sheet(isPresented: $showingPlayerDetail) {
            NavigationView {
                if let sleeperPlayer = getSleeperPlayerData() {
                    PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: playerEntry.player.team ?? "")
                    )
                } else {
                    PlayerDetailFallbackView(player: playerEntry.player)
                }
            }
        }
    }
    
    // 🔥 NEW: Helper to identify defense/special teams players
    private var isDefenseOrSpecialTeams: Bool {
        let position = playerEntry.position.uppercased()
        return position == "DEF" || position == "DST" || position == "D/ST"
    }
    
    // 🔥 NEW: Get Sleeper player data for detailed stats
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName.lowercased()
        let shortName = playerEntry.player.shortName.lowercased()
        let team = playerEntry.player.team?.lowercased()
        
        return playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    /// Alternative image URL for retry logic
    private var alternativeImageURL: URL? {
        // Try ESPN headshot as fallback
        if let espnURL = playerEntry.player.espnHeadshotURL {
            return espnURL
        }
        
        // For defense/special teams, try a different approach
        if playerEntry.position == "DEF" || playerEntry.position == "DST" {
            if let team = playerEntry.player.team {
                // Try ESPN team logo as player image for defenses
                return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
            }
        }
        
        return nil
    }
}