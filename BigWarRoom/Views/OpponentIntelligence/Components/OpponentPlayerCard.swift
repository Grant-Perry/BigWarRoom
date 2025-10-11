//
//  OpponentPlayerCard.swift
//  BigWarRoom
//
//  Individual opponent player card with performance analysis
//

import SwiftUI

/// Card displaying opponent player performance and threat assessment
struct OpponentPlayerCard: View {
    let player: OpponentPlayer
    @StateObject private var watchService = PlayerWatchService.shared
    @StateObject private var fantasyPlayerViewModel = FantasyPlayerViewModel()
    
    var body: some View {
        HStack(spacing: 12) {
            // Player image (clickable with NavigationLink) and position
            VStack(spacing: 4) {
                // Player headshot with NavigationLink to stats
                if let sleeperPlayer = fantasyPlayerViewModel.getSleeperPlayerData(for: player.player) {
                    NavigationLink(destination: PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: player.player.team ?? "")
                    )) {
                        playerImageView
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Fallback - show image but not clickable if no SleeperPlayer data
                    playerImageView
                }
                
                // Position badge
                Text(player.position)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(positionColor)
                    )
            }
            .frame(width: 50)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                // Name and team
                HStack {
                    Text(player.playerName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(player.team)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // Performance indicators
                HStack(spacing: 8) {
                    // Current score
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.gray)
                        
                        Text(player.scoreDisplay)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(player.threatLevel.color)
                    }
                    
                    // Projected score
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROJ")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.gray)
                        
                        Text(player.projectionDisplay)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Performance status
                    performanceStatus
                }
            }
            
            // Watch toggle and threat level
            VStack(spacing: 8) {
                // Watch toggle button
                Button(action: toggleWatch) {
                    Image(systemName: isWatching ? "eye.fill" : "eye")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isWatching ? .gpOrange : .gray)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(isWatching ? Color.gpOrange.opacity(0.2) : Color.gray.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Threat level indicator
                VStack(spacing: 2) {
                    Image(systemName: player.threatLevel.sfSymbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(player.threatLevel.color)
                    
                    Text(player.threatLevel.rawValue)
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(player.threatLevel.color)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(player.threatLevel.color.opacity(0.2))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: 70)
        }
        .padding(12)
        .background(
            // Blur backdrop layer
            RoundedRectangle(cornerRadius: 12)
                .fill(.thinMaterial) // iOS blur material
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.2)) // Light tint for transparency
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isWatching ? Color.gpOrange.opacity(0.5) : player.threatLevel.color.opacity(0.3), lineWidth: isWatching ? 2 : 1)
                )
        )
        .background(
            // Outer glow effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            (isWatching ? Color.gpOrange : player.threatLevel.color).opacity(0.08),
                            (isWatching ? Color.gpOrange : player.threatLevel.color).opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 1)
        )
    }
    
    // MARK: - Helper Views
    
    private var playerImageView: some View {
        AsyncImage(url: player.player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Fallback with player initials (current implementation)
            ZStack {
                Circle()
                    .fill(positionColor.opacity(0.3))
                
                Text(String(player.playerName.prefix(2)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(positionColor)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(positionColor.opacity(0.6), lineWidth: 1.5)
        )
    }
    
    // MARK: - Helper Properties and Methods
    
    private var isWatching: Bool {
        watchService.isWatching(player.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(player.player.id)
        } else {
            // Create opponent references (simplified for now)
            let opponentRefs = [OpponentReference(
                id: "temp_opponent",
                opponentName: "Opponent",
                leagueName: "League",
                leagueSource: "sleeper"
            )]
            
            let success = watchService.watchPlayer(player, opponentReferences: opponentRefs)
            if !success {
                // TODO: Show alert about watch limit or other issues
                print("Failed to watch player - possibly at limit")
            }
        }
    }
    
    private var performanceStatus: some View {
        Group {
            if player.isExploding {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("HOT")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundColor(.red)
            } else if player.isStruggling {
                HStack(spacing: 4) {
                    Image(systemName: "snow")
                        .font(.system(size: 10))
                    Text("COLD")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundColor(.blue)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.system(size: 8))
                    Text("AVG")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundColor(.gray)
            }
        }
    }
    
    private var positionColor: Color {
        switch player.position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}