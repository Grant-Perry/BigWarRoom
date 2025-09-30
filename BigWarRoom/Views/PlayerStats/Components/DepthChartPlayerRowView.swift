//
//  DepthChartPlayerRowView.swift
//  BigWarRoom
//
//  Individual depth chart player row component
//

import SwiftUI

/// Individual player row in team depth chart
struct DepthChartPlayerRowView: View {
    let depthPlayer: DepthChartPlayer
    let team: NFLTeam?
    // 🏈 PLAYER NAVIGATION: Use callback instead of NavigationLink to prevent nested navigation
    let onTap: (() -> Void)?
    
    var body: some View {
        // 🏈 PLAYER NAVIGATION: Use Button with callback instead of NavigationLink
        // BEFORE: NavigationLink to PlayerStatsCardView (caused navigation stack issues)
        // AFTER: Button with callback to update parent view's player state
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 14) {
                // Enhanced depth position number with gradient - use component
                DepthChartPlayerRowDepthCircleView(depthPlayer: depthPlayer)
                
                // Enhanced player headshot with glow - use component
                DepthChartPlayerRowImageView(depthPlayer: depthPlayer, team: team)
                
                // Enhanced player info section - use component
                DepthChartPlayerRowInfoSectionView(depthPlayer: depthPlayer)
                
                Spacer(minLength: 0)
                
                // 🏈 PLAYER NAVIGATION: Keep navigation indicator for visual consistency
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                DepthChartPlayerRowBackgroundView(
                    depthPlayer: depthPlayer,
                    positionColor: positionColor
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                DepthChartPlayerRowBorderView(
                    depthPlayer: depthPlayer,
                    positionColor: positionColor
                )
            )
            .shadow(
                color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.3) : Color.black.opacity(0.2),
                radius: depthPlayer.isCurrentPlayer ? 6 : 3,
                x: 0,
                y: depthPlayer.isCurrentPlayer ? 3 : 2
            )
            .scaleEffect(depthPlayer.isCurrentPlayer ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: depthPlayer.isCurrentPlayer)
        }
        .buttonStyle(PlainButtonStyle()) // 🏈 PLAYER NAVIGATION: Keep plain style for clean appearance
        .disabled(onTap == nil) // 🏈 PLAYER NAVIGATION: Disable if no callback provided
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var positionColor: Color {
        guard let position = depthPlayer.player.position else { return .gray }
        
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
}

#Preview {
    // Create a mock player with minimal required data
    let mockPlayerData = """
    {
        "player_id": "123",
        "first_name": "Josh",
        "last_name": "Allen",
        "position": "QB",
        "team": "BUF",
        "number": 17,
        "search_rank": 15
    }
    """.data(using: .utf8)!
    
    let mockPlayer = try! JSONDecoder().decode(SleeperPlayer.self, from: mockPlayerData)
    
    return NavigationView {
        DepthChartPlayerRowView(
            depthPlayer: DepthChartPlayer(
                player: mockPlayer,
                depth: 1,
                isCurrentPlayer: true
            ),
            team: nil,
            onTap: nil
        )
        .padding()
    }
}