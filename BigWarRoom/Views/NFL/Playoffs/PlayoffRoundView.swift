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

// MARK: - Preview

#Preview {
    let mockGames = [
        PlayoffGame(
            id: "1",
            round: .wildCard,
            conference: .afc,
            homeTeam: PlayoffTeam(abbreviation: "KC", name: "Kansas City Chiefs", seed: 1, score: 27, logoURL: nil),
            awayTeam: PlayoffTeam(abbreviation: "MIA", name: "Miami Dolphins", seed: 6, score: 24, logoURL: nil),
            gameDate: Date(),
            status: .final,
            venue: PlayoffGame.Venue(fullName: "Arrowhead Stadium", city: "Kansas City", state: "MO"),
            broadcasts: ["CBS", "Paramount+"]
        ),
        PlayoffGame(
            id: "2",
            round: .wildCard,
            conference: .afc,
            homeTeam: PlayoffTeam(abbreviation: "BUF", name: "Buffalo Bills", seed: 2, score: nil, logoURL: nil),
            awayTeam: PlayoffTeam(abbreviation: "PIT", name: "Pittsburgh Steelers", seed: 7, score: nil, logoURL: nil),
            gameDate: Date().addingTimeInterval(7200),
            status: .scheduled,
            venue: PlayoffGame.Venue(fullName: "Highmark Stadium", city: "Buffalo", state: "NY"),
            broadcasts: ["NBC", "Peacock"]
        )
    ]
    
    ScrollView {
        PlayoffRoundView(
            round: .wildCard,
            games: mockGames,
            conference: .afc,
            highlightedGames: ["1"],
            onGameTap: { _ in }
        )
        .padding()
    }
}