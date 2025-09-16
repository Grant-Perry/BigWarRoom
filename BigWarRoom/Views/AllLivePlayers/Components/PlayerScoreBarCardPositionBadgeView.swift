//
//  PlayerScoreBarCardPositionBadgeView.swift
//  BigWarRoom
//
//  Position badge component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardPositionBadgeView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    var body: some View {
        Text(playerEntry.position)
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
        switch playerEntry.position {
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