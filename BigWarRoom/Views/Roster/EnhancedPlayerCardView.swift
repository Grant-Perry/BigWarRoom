//
//  EnhancedPlayerCardView.swift
//  BigWarRoom
//
//  Enhanced player card component matching Draft War Room styling
//

import SwiftUI

/// Enhanced player card component with team styling and detailed player information
struct EnhancedPlayerCardView: View {
    let player: Player
    let sleeperPlayer: SleeperPlayer?
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Player headshot with fallback
            playerImageView
            
            // Player info section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Player name and position
                    PlayerNameAndPositionView(
                        player: player,
                        sleeperPlayer: sleeperPlayer
                    )
                    
                    // Tier badge
                    TierBadgeView(tier: player.tier)
                    
                    // Team logo
                    TeamAssetManager.shared.logoOrFallback(for: player.team)
                        .frame(width: 42, height: 42)
                    
                    Spacer()
                }
                
                // Player details row
                PlayerDetailsRowView(
                    player: player,
                    sleeperPlayer: sleeperPlayer
                )
            }
        }
        .padding(12)
        .background(TeamAssetManager.shared.teamBackground(for: player.team))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Player Image View
    
    @ViewBuilder
    private var playerImageView: some View {
        if let sleeperPlayer {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: player.team)
            )
        } else {
            // Fallback with team colors
            Circle()
                .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(player.firstInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                )
                .frame(width: 60, height: 60)
        }
    }
}

// MARK: - Supporting Components

/// Component for displaying player name and positional information
private struct PlayerNameAndPositionView: View {
    let player: Player
    let sleeperPlayer: SleeperPlayer?
    
    var body: some View {
        HStack(spacing: 6) {
            // Player name
            Text("\(player.firstInitial) \(player.lastName)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Position or positional rank
            if let sleeperPlayer,
               let positionRank = sleeperPlayer.positionalRank {
                Text("- \(positionRank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } else {
                Text("- \(player.position.rawValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Component for displaying player tier badge
private struct TierBadgeView: View {
    let tier: Int
    
    var body: some View {
        Text("T\(tier)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(tierColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private var tierColor: Color {
        switch tier {
        case 1: return .purple        // Elite players
        case 2: return .blue          // Very good players
        case 3: return .orange        // Decent players
        default: return .gray         // Deep/bench players
        }
    }
}

/// Component for displaying detailed player statistics and information
private struct PlayerDetailsRowView: View {
    let player: Player
    let sleeperPlayer: SleeperPlayer?
    
    var body: some View {
        HStack(spacing: 8) {
            if let sleeperPlayer {
                // Fantasy rank
                if let searchRank = sleeperPlayer.searchRank {
                    DetailChip(text: "FantRnk: \(searchRank)", color: .blue)
                }
                
                // Jersey number
                if let number = sleeperPlayer.number {
                    DetailChip(text: "#: \(number)", color: .blue)
                }
                
                // Years of experience
                if let yearsExp = sleeperPlayer.yearsExp {
                    DetailChip(text: "Yrs: \(yearsExp)", color: .blue)
                }
                
                // Injury status
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                    DetailChip(text: String(injuryStatus.prefix(5)), color: .red)
                }
            } else {
                // Fallback when no Sleeper data
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

/// Small detail chip component for player information
private struct DetailChip: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(color)
            .fontWeight(.medium)
    }
}