//
//  FantasyPlayerCardLogoView.swift
//  BigWarRoom
//
//  Team logo component for FantasyPlayerCard
//

import SwiftUI

/// Team logo component
struct FantasyPlayerCardLogoView: View {
    let player: FantasyPlayer
    let teamColor: Color
    let isPlayerLive: Bool
    
    var body: some View {
        Group {
            if let team = player.team, let obj = NFLTeam.team(for: team) {
                if let image = UIImage(named: obj.logoAssetName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .offset(x: 20, y: -4)
                        .opacity(isPlayerLive ? 0.6 : 0.35)
                        .shadow(color: obj.primaryColor.opacity(0.5), radius: 10, x: 0, y: 0)
                } else {
                    AsyncImage(url: URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "sportscourt.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .offset(x: 20, y: -4)
                    .opacity(isPlayerLive ? 0.6 : 0.35)
                    .shadow(color: teamColor.opacity(0.5), radius: 10, x: 0, y: 0)
                }
            }
        }
    }
}