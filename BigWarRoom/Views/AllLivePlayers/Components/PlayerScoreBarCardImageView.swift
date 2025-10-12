//
//  PlayerScoreBarCardImageView.swift
//  BigWarRoom
//
//  Player image component for PlayerScoreBarCardView
//

import SwiftUI

/// Player image view with fallback logic
struct PlayerScoreBarCardImageView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    var body: some View {
        AsyncImage(url: playerEntry.player.headshotURL) { phase in
            switch phase {
            case .empty:
                // Loading state
                buildPlayerFallbackView()
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            case .success(let image):
                // Successfully loaded image
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Failed to load - try alternative URL or show fallback
                AsyncImage(url: alternativeImageURL) { altPhase in
                    switch altPhase {
                    case .success(let altImage):
                        altImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        buildPlayerFallbackView()
                    }
                }
            @unknown default:
                buildPlayerFallbackView()
            }
        }
        .frame(width: 80, height: 100)
    }
    
    private func buildPlayerFallbackView() -> some View {
        Rectangle()
            .fill(teamGradient)
            .overlay(
                Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    /// Alternative image URL for retry logic
    private var alternativeImageURL: URL? {
        // Try ESPN headshot as fallback
        if let espnURL = playerEntry.player.espnHeadshotURL {
            return espnURL
        }
        
        // For defense/special teams, try a different approach
        if playerEntry.position == "DEF" || playerEntry.position == "DST" {
            if let team = playerEntry.player.team {
                // Try ESPN team logo as player image for defenses
                return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
            }
        }
        
        return nil
    }
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
}