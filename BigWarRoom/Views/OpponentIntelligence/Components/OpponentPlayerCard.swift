//
//  OpponentPlayerCard.swift
//  BigWarRoom
//
//  🔥 PHASE 2 SIMPLIFIED MIGRATION: Use existing UnifiedPlayerCardBackground
//

import SwiftUI

/// **Opponent Player Card - SIMPLIFIED MIGRATION**
/// 
/// **Strategy:** Keep threat assessment logic, eliminate background duplication
/// **Before:** 250+ lines with custom threat styling
/// **After:** Use UnifiedPlayerCardBackground + existing components
struct OpponentPlayerCard: View {
    let player: OpponentPlayer
    @State private var watchService = PlayerWatchService.shared
    @State private var fantasyPlayerViewModel = FantasyPlayerViewModel()
    
    var body: some View {
        HStack(spacing: 12) {
            // Player image and position
            VStack(spacing: 4) {
                buildPlayerImage()
                buildPositionBadge()
            }
            .frame(width: 50)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                buildPlayerInfo()
                buildPerformanceStats()
            }
            
            // Watch toggle and threat level
            buildControls()
                .frame(width: 70)
        }
        .padding(12)
        .background(
            // 🔥 UNIFIED: Use UnifiedPlayerCardBackground instead of custom blur effects
            UnifiedPlayerCardBackground(
                configuration: .simple(
                    team: NFLTeam.team(for: player.player.team ?? ""),
                    cornerRadius: 12
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isWatching ? Color.gpOrange.opacity(0.5) : player.threatLevel.color.opacity(0.3),
                        lineWidth: isWatching ? 2 : 1
                    )
            )
        )
    }
    
    // MARK: - Component Builders
    
    @ViewBuilder
    private func buildPlayerImage() -> some View {
        if let sleeperPlayer = fantasyPlayerViewModel.getSleeperPlayerData(for: player.player) {
            NavigationLink(destination: PlayerStatsCardView(
                player: sleeperPlayer,
                team: NFLTeam.team(for: player.player.team ?? "")
            )) {
                playerImageView
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            playerImageView
        }
    }
    
    @ViewBuilder
    private var playerImageView: some View {
        AsyncImage(url: player.player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
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
    
    @ViewBuilder
    private func buildPositionBadge() -> some View {
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
    
    @ViewBuilder
    private func buildPlayerInfo() -> some View {
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
    }
    
    @ViewBuilder
    private func buildPerformanceStats() -> some View {
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
            buildPerformanceStatus()
        }
    }
    
    @ViewBuilder
    private func buildControls() -> some View {
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
            buildThreatIndicator()
        }
    }
    
    @ViewBuilder
    private func buildPerformanceStatus() -> some View {
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
    
    @ViewBuilder
    private func buildThreatIndicator() -> some View {
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
    
    // MARK: - Helper Properties and Methods
    
    private var isWatching: Bool {
        watchService.isWatching(player.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(player.player.id)
        } else {
            let opponentRefs = [OpponentReference(
                id: "temp_opponent",
                opponentName: "Opponent",
                leagueName: "League",
                leagueSource: "sleeper"
            )]
            
            let _ = watchService.watchPlayer(player, opponentReferences: opponentRefs)
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