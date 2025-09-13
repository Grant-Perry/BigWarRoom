//
//  PlayerImageView.swift
//  BigWarRoom
//
//  Smart player image loader with multiple fallback sources
//
// MARK: -> Player Image View

import SwiftUI

struct PlayerImageView: View {
    let player: SleeperPlayer
    let size: CGFloat
    let team: NFLTeam?
    
    var body: some View {
        AsyncImage(url: player.headshotURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure, .empty:
                // Show team-colored fallback with player initials
                Circle()
                    .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Text(player.firstName?.prefix(1).uppercased() ?? "?")
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(team?.accentColor ?? .white)
                    )
            @unknown default:
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: size, height: size)
//        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(team?.primaryColor.opacity(0.3) ?? Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

