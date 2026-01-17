//
//  PlayoffRoundView.swift
//  BigWarRoom
//
//  Displays a single round of playoff games in bracket format
//

import SwiftUI

struct PlayoffRoundView: View {
    let round: PlayoffRound
    let games: [PlayoffGame]
    let conference: PlayoffGame.Conference
    let highlightedGames: Set<String>  // Game IDs with fantasy players
    let onGameTap: (PlayoffGame) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Round Header
            roundHeader
            
            // Games
            VStack(spacing: 20) {
                ForEach(games) { game in
                    PlayoffGameCardView(
                        game: game,
                        showFantasyHighlight: highlightedGames.contains(game.id),
                        onTap: { onGameTap(game) }
                    )
                }
            }
            .padding(.top, 12)
        }
    }
    
    private var roundHeader: some View {
        HStack {
            // Round icon
            Image(systemName: roundIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(roundColor)
            
            Text(round.displayName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Game count badge
            Text("\(games.count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(roundColor))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var roundIcon: String {
        switch round {
        case .wildCard:
            return "flag.fill"
        case .divisional:
            return "trophy.fill"
        case .conference:
            return "star.fill"
        case .superBowl:
            return "crown.fill"
        }
    }
    
    private var roundColor: Color {
        switch round {
        case .wildCard:
            return .blue
        case .divisional:
            return .green
        case .conference:
            return .orange
        case .superBowl:
            return .purple
        }
    }
}