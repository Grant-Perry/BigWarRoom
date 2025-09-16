//
//  DepthChartPlayerRowImageView.swift
//  BigWarRoom
//
//  Player image component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowImageView: View {
    let depthPlayer: DepthChartPlayer
    let team: NFLTeam?
    
    var body: some View {
        ZStack {
            // Position-colored glow behind image
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            positionColor.opacity(0.6),
                            positionColor.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .blur(radius: 2)
            
            PlayerImageView(
                player: depthPlayer.player,
                size: 34,
                team: team
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                positionColor.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
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