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
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
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
                // Player headshot (primary image)
                playerImageView
                
                // Player info
                VStack(alignment: .leading, spacing: 4) {
                    // Name, position, and team logo
                    HStack(spacing: 8) {
                        Text(player.shortName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Position badge
                        positionBadge
                        
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
                    
                    // Additional details + stats preview
                    if showDetails {
                        statsPreviewRow
                    }
                }
                
                Spacer()
            }
            .padding(12)
            .background(teamBackgroundView)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: -> Subviews
    
    private var playerImageView: some View {
        AsyncImage(url: player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            // Fallback: Team colors with player initials
            playerFallbackView
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(team?.primaryColor.opacity(0.3) ?? Color.gray, lineWidth: 1)
        )
    }
    
    private var playerFallbackView: some View {
        Circle()
            .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
            .overlay(
                Text(player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(team?.accentColor ?? .white)
            )
    }
    
    private var positionBadge: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
    
    private var statsPreviewRow: some View {
        HStack(spacing: 8) {
            // Player details
            if let number = player.number {
                Text("#\(number)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let yearsExp = player.yearsExp {
                Text("Y\(yearsExp)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Stats preview from PlayerStatsStore
            // if let stats = PlayerStatsStore.shared.stats(for: player.playerID) {
            //     if let ppg = stats.pprPointsPerGame {
            //         Text(String(format: "%.1f PPG", ppg))
            //             .font(.caption2)
            //             .foregroundColor(.blue)
            //             .fontWeight(.medium)
            //     }
            // }
            
            // Injury status
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
			   Text(String(injuryStatus.prefix(5)))
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
    
    private var teamBackgroundView: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 12)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: -> Compact Version
struct CompactPlayerCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
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