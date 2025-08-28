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
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(team?.primaryColor.opacity(0.3) ?? Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: -> Preview
//#Preview {
//    VStack {
//        PlayerImageView(
//            player: SleeperPlayer(
//                playerID: "wr-chase",
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
//            ),
//            size: 100,
//            team: NFLTeam.team(for: "CIN")
//        )
//    }
//    .padding()
//}
