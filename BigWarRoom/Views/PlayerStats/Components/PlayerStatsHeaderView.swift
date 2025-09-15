//
//  PlayerStatsHeaderView.swift
//  BigWarRoom
//
//  Header view for PlayerStatsCardView with player image and basic info
//

import SwiftUI

/// Header section with player image, name, position, and basic info
struct PlayerStatsHeaderView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Large player image
            PlayerImageView(
                player: player,
                size: 120,
                team: team
            )
            
            // Player info
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    // Position badge
                    positionBadge
                    
                    // Team info
                    if let team = team {
                        HStack(spacing: 6) {
                            teamAssets.logoOrFallback(for: team.id)
                                .frame(width: 24, height: 24)
                            
                            Text(team.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Jersey number
                    if let number = player.number {
                        Text("#\(number)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Additional info using our DRY PlayerInfoItem component
            HStack(spacing: 20) {
                if let age = player.age {
                    PlayerInfoItem("Age", "\(age)", style: .compact)
                }
                if let yearsExp = player.yearsExp {
                    PlayerInfoItem("Exp", "Y\(yearsExp)", style: .compact)
                }
                if let height = player.height {
                    PlayerInfoItem("Height", height.formattedHeight, style: .compact)
                }
                if let weight = player.weight {
                    PlayerInfoItem("Weight", "\(weight) lbs", style: .compact)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(teamBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Views
    
    private var positionBadge: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
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
    
    private var teamBackgroundView: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 16)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            }
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
        "age": 28,
        "height": "77",
        "weight": 237,
        "years_exp": 6,
        "college": "Wyoming"
    }
    """.data(using: .utf8)!
    
    let mockPlayer = try! JSONDecoder().decode(SleeperPlayer.self, from: mockPlayerData)
    
    return PlayerStatsHeaderView(player: mockPlayer, team: nil)
}