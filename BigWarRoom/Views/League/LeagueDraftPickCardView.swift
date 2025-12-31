//
//  LeagueDraftPickCardView.swift
//  BigWarRoom
//
//  Enhanced pick card component for league draft display
//

import SwiftUI

/// Enhanced pick card component with player details and team styling
struct LeagueDraftPickCardView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let pick: EnhancedPick
    let viewModel: LeagueDraftViewModel
    
    private var isMyPick: Bool {
        viewModel.isMyPick(pick)
    }
    
    private var realSleeperPlayer: SleeperPlayer? {
        viewModel.findRealSleeperPlayer(for: pick)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Top row: Player name and position badge
            PickCardHeaderRow(
                displayName: pick.displayName,
                position: pick.position,
                player: pick.player
            )
            
            // Middle row: Player image, team logo, pick number
            PickCardMiddleRow(
                pick: pick,
                realSleeperPlayer: realSleeperPlayer,
                isMyPick: isMyPick
            )
            
            // Bottom row: Fantasy rank and manager name
            PickCardBottomRow(
                pick: pick,
                realSleeperPlayer: realSleeperPlayer,
                managerName: viewModel.teamDisplayName(for: pick.draftSlot)
            )
        }
        .padding(10)
        .background(pickCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(pickCardBorder)
        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
        .onTapGesture {
            handlePlayerTap()
        }
    }
    
    // MARK: - Background & Border Styling
    
    private var pickCardBackground: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: isMyPick ? Color.gpGreen.opacity(0.4) : Color.black.opacity(0.7), location: 0.0),
                .init(color: PositionColorHelper.color(for: pick.position).opacity(0.2), location: 0.5),
                .init(color: isMyPick ? Color.gpGreen.opacity(0.2) : Color.black.opacity(0.8), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var pickCardBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                isMyPick ? Color.gpGreen.opacity(0.8) : PositionColorHelper.color(for: pick.position).opacity(0.4), 
                lineWidth: isMyPick ? 2 : 1
            )
    }
    
    // MARK: - Actions
    
    private func handlePlayerTap() {
        if let realSleeperPlayer {
            viewModel.presentPlayerStats(for: realSleeperPlayer)
        }
    }
}

// MARK: - Supporting Components

/// Header row component with player name and position
private struct PickCardHeaderRow: View {
    let displayName: String
    let position: String
    let player: SleeperPlayer
    
    var body: some View {
        HStack {
            Text(displayName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            PositionBadgeView(position: position, player: player)
        }
    }
}

/// Middle row component with player image, team logo, and pick number
private struct PickCardMiddleRow: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let pick: EnhancedPick
    let realSleeperPlayer: SleeperPlayer?
    let isMyPick: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Player image with styling
            PlayerImageSection(
                pick: pick,
                realSleeperPlayer: realSleeperPlayer
            )
            
            // Team logo
            teamAssets.logoOrFallback(for: pick.teamCode)
                .frame(width: 28, height: 28)
            
            Spacer()
            
            // Pick number badge
            PickNumberBadge(pickNumber: pick.pickNumber)
        }
    }
}

/// Bottom row component with fantasy rank and manager info
private struct PickCardBottomRow: View {
    let pick: EnhancedPick
    let realSleeperPlayer: SleeperPlayer?
    let managerName: String
    
    var body: some View {
        HStack {
            // Fantasy rank (left side)
            FantasyRankDisplay(
                realSleeperPlayer: realSleeperPlayer,
                fallbackPlayer: pick.player
            )
            
            Spacer()
            
            // Manager name (right side)
            Text(managerName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Position badge component with conditional display
private struct PositionBadgeView: View {
    let position: String
    let player: SleeperPlayer
    
    var body: some View {
        Group {
            if let positionRank = player.positionalRank {
                Text(positionRank)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(PositionColorHelper.color(for: position))
                    )
            } else {
                Text(position)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(PositionColorHelper.color(for: position))
                    )
            }
        }
    }
}

/// Player image section with background styling
private struct PlayerImageSection: View {
    let pick: EnhancedPick
    let realSleeperPlayer: SleeperPlayer?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(PositionColorHelper.color(for: pick.position).opacity(0.3))
                .frame(width: 58, height: 58)
                .blur(radius: 1)
            
            PlayerImageView(
                player: realSleeperPlayer ?? pick.player,
                size: 36,
                team: pick.team
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(PositionColorHelper.color(for: pick.position).opacity(0.6), lineWidth: 1.5)
            )
        }
    }
}

/// Pick number badge component
private struct PickNumberBadge: View {
    let pickNumber: Int
    
    var body: some View {
        Text("\(pickNumber)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 32, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
            )
    }
}

/// Fantasy rank display component
private struct FantasyRankDisplay: View {
    let realSleeperPlayer: SleeperPlayer?
    let fallbackPlayer: SleeperPlayer
    
    var body: some View {
        Group {
            if let realPlayer = realSleeperPlayer,
               let searchRank = realPlayer.searchRank {
                Text("FR: \(searchRank)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gpYellow)
            } else if let searchRank = fallbackPlayer.searchRank {
                Text("FR: \(searchRank)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gpYellow)
            } else {
                Text("")
            }
        }
    }
}

// MARK: - Position Color Helper

/// Helper struct for consistent position colors across components
struct PositionColorHelper {
    static func color(for position: String) -> Color {
        switch position.uppercased() {
        case "QB": return Color(red: 0.6, green: 0.3, blue: 0.9) // Purple
        case "RB": return Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        case "WR": return Color(red: 0.3, green: 0.6, blue: 1.0) // Blue
        case "TE": return Color(red: 1.0, green: 0.6, blue: 0.2) // Orange
        case "K": return Color(red: 0.7, green: 0.7, blue: 0.7) // Gray
        case "DEF", "DST": return Color(red: 0.9, green: 0.3, blue: 0.3) // Red
        default: return Color(red: 0.6, green: 0.6, blue: 0.6) // Default Gray
        }
    }
}