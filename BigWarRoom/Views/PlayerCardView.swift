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
//
//#Preview {
//    VStack(spacing: 16) {
//        PlayerCardView(
//            player: SleeperPlayer(
//                playerID: "123",
//                firstName: "Ja'Marr",
//                lastName: "Chase",
//                position: "WR",
//                team: "CIN",
//                number: 1,
//                status: "Active",
//                height: "6'0\"",
//                weight: "201",
//                age: 24,
//                college: "LSU",
//                yearsExp: 3,
//                fantasyPositions: ["WR"],
//                injuryStatus: nil,
//                depthChartOrder: 1,
//                depthChartPosition: 1,
//                searchRank: 5,
//                hashtag: "#JaMarrChase",
//                birthCountry: "United States",
//                espnID: 4362628,
//                yahooID: 32700,
//                rotowireID: 14885,
//                rotoworldID: 5479,
//                fantasyDataID: 21688,
//                sportradarID: "123",
//                statsID: 123
//            )
//        )
//        
//        CompactPlayerCardView(
//            player: SleeperPlayer(
//                playerID: "456",
//                firstName: "Joe",
//                lastName: "Burrow",
//                position: "QB",
//                team: "CIN",
//                number: 9,
//                status: "Active",
//                height: "6'4\"",
//                weight: "221",
//                age: 27,
//                college: "LSU",
//                yearsExp: 4,
//                fantasyPositions: ["QB"],
//                injuryStatus: nil,
//                depthChartOrder: 1,
//                depthChartPosition: 1,
//                searchRank: 12,
//                hashtag: "#JoeBurrow",
//                birthCountry: "United States",
//                espnID: 3915511,
//                yahooID: 31002,
//                rotowireID: 13604,
//                rotoworldID: 5479,
//                fantasyDataID: 21688,
//                sportradarID: "456",
//                statsID: 456
//            )
//        )
//    }
//    .padding()
//}