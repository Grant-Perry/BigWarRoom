//
//  PlayerCardPositionBadgeView.swift
//  BigWarRoom
//
//  Position badge component for PlayerCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerCardPositionBadgeView: View {
    let player: SleeperPlayer
    
    var body: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var positionColor: Color {
        guard let position = player.position else { return .gray }
        
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