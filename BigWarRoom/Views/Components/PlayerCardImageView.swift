//
//  PlayerCardImageView.swift
//  BigWarRoom
//
//  Player image component for PlayerCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerCardImageView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    var body: some View {
        AsyncImage(url: player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Fallback: Team colors with player initials
            PlayerCardFallbackView(player: player, team: team)
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(team?.primaryColor.opacity(0.3) ?? Color.gray, lineWidth: 1)
        )
    }
}