//
//  PlayerCardFallbackView.swift
//  BigWarRoom
//
//  Player fallback image component for PlayerCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerCardFallbackView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    var body: some View {
        Circle()
            .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
            .overlay(
                Text(player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(team?.accentColor ?? .white)
            )
    }
}