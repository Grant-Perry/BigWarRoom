//
//  PlayerCardView.swift
//  BigWarRoom
//
//  Rich player card with headshot, team branding, and metadata
//
// MARK: -> Player Card View

import SwiftUI

struct PlayerCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    let showDetails: Bool
    let onTap: (() -> Void)?
    
    @Environment(TeamAssetManager.self) private var teamAssets
    
    init(player: SleeperPlayer, showDetails: Bool = true, onTap: (() -> Void)? = nil) {
        self.player = player
        self.team = NFLTeam.team(for: player.team ?? "")
        self.showDetails = showDetails
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                // Player headshot (primary image) - use component
                PlayerCardImageView(player: player, team: team)
                
                // Player info
                VStack(alignment: .leading, spacing: 4) {
                    // Name, position, and team logo
                    HStack(spacing: 8) {
                        Text(player.shortName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Position badge - use component
                        PlayerCardPositionBadgeView(player: player)
                        
                        // Team logo (after position)
                        if let team = team {
                            teamAssets.logoOrFallback(for: team.id)
                                .frame(width: 20, height: 20)
                        }
                        
                        Spacer()
                    }
                    
                    // Team name
                    if let team = team, showDetails {
                        Text(team.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Additional details + stats preview - use component
                    if showDetails {
                        PlayerCardStatsPreviewRowView(player: player)
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(PlayerCardBackgroundView(team: team))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: -> Compact Version
struct CompactPlayerCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @Environment(TeamAssetManager.self) private var teamAssets
    
    init(player: SleeperPlayer) {
        self.player = player
        self.team = NFLTeam.team(for: player.team ?? "")
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Small headshot
            AsyncImage(url: player.headshotURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(team?.primaryColor ?? .gray)
                    .overlay(
                        Text(player.firstName?.prefix(1).uppercased() ?? "?")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            
            // Name and position
            VStack(alignment: .leading, spacing: 2) {
                Text(player.shortName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(player.position ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Team logo
            if let team = team {
                teamAssets.logoOrFallback(for: team.id)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(team?.backgroundColor ?? Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}