//
//  TeamAvatarView.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Reusable team avatar component with consistent styling
struct TeamAvatarView: View {
    let team: FantasyTeam
    let size: CGSize
    let isGrayedOut: Bool
    
    init(team: FantasyTeam, size: CGSize = CGSize(width: 44, height: 44), isGrayedOut: Bool = false) {
        self.team = team
        self.size = size
        self.isGrayedOut = isGrayedOut
    }
    
    var body: some View {
        Group {
            if let avatarURL = team.avatarURL {
                // Sleeper leagues with real avatars
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        espnTeamAvatar
                    case .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                // ESPN leagues with custom team avatars
                espnTeamAvatar
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Circle())
        .grayscale(isGrayedOut ? 0.5 : 0.0)
    }
    
    /// Custom ESPN team avatar with unique colors and better styling
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        team.espnTeamColor.opacity(isGrayedOut ? 0.6 : 1.0),
                        team.espnTeamColor.opacity(isGrayedOut ? 0.4 : 0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(team.espnTeamColor.opacity(isGrayedOut ? 0.2 : 0.3), lineWidth: 2)
            )
            .overlay(
                Text(team.teamInitials)
                    .font(.system(size: size.width * 0.36, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(isGrayedOut ? 0.8 : 1.0))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
    }
}