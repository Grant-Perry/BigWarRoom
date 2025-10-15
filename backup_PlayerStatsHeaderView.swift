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
    // 🔥 NEW: Access to live player stats for PPR points
    @StateObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    
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
                    
                    // Team info with PPR
                    if let team = team {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                teamAssets.logoOrFallback(for: team.id)
                                    .frame(width: 24, height: 24)
                                
                                Text(team.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 🔥 NEW: PPR points display
                            if let pprPoints = getPPRPoints() {
                                Text("PPR: \(String(format: "%.1f", pprPoints))")
                                    .font(.callout)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Jersey number
                    if let number = player.number {
                        Text("\(number)")
                            .font(.bebas(size: 44))
                            .fontWeight(.black)
                            .foregroundColor(team?.primaryColor ?? .primary)
                            .shadow(color: team?.secondaryColor ?? .black, radius: 0, x: 2, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(team?.backgroundColor ?? Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(team?.borderColor ?? Color(.systemGray4), lineWidth: 2)
                                    )
                            )
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
    
    // 🔥 NEW: Get PPR points for this player from live stats
    private func getPPRPoints() -> Double? {
        // Get player stats from AllLivePlayersViewModel
        guard let playerStats = livePlayersViewModel.playerStats[player.playerID] else {
            return nil
        }
        
        // Try PPR points first, then half PPR, then standard as fallback
        if let pprPoints = playerStats["pts_ppr"], pprPoints > 0 {
            return pprPoints
        } else if let halfPprPoints = playerStats["pts_half_ppr"], halfPprPoints > 0 {
            return halfPprPoints
        } else if let stdPoints = playerStats["pts_std"], stdPoints > 0 {
            return stdPoints
        }
        
        return nil
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
