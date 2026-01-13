//
//  PlayoffBracketTeamCard.swift
//  BigWarRoom
//
//  Team card component for playoff bracket portrait view
//

import SwiftUI

struct PlayoffBracketTeamCard: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let team: PlayoffTeam
    let seed: Int
    let game: PlayoffGame?
    let isWinner: Bool
    let determineWinner: (PlayoffGame?) -> String?
    
    private var isLoser: Bool {
        game?.isCompleted == true && !isWinner && determineWinner(game) != nil
    }
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 8)
                .fill(teamColor(for: team.abbreviation))
            
            // Watermark - show score if game is completed, otherwise seed
            if let game = game, game.isCompleted, let score = team.score {
                // Show score as watermark for completed games
                let scoreOpacity: Double = isWinner ? 0.8 : 0.25
                Text("\(score)")
                    .font(.system(size: 50, weight: .black))
                    .foregroundColor(.white.opacity(scoreOpacity))
                    .offset(x: -35)
            } else {
                // Show seed as watermark for scheduled/live games
                SeedNumberView(seed: seed)
                    .offset(x: -35)
            }
            
            // Content layer
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    // Seed number (always shown under team name)
                    Text("#\(seed)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                
                // Team logo
                if let logoImage = teamAssets.logo(for: team.abbreviation) {
                    let logoSize: CGFloat = 90.0
                    logoImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: logoSize, height: logoSize)
                        .padding(.trailing, 6)
                } else {
                    // Fallback
                    Text(team.abbreviation)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                }
            }
        }
        .frame(width: 180, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isWinner ?
                        AnyShapeStyle(Color.gpGreen) :
                        AnyShapeStyle(LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )),
                    lineWidth: isWinner ? 3 : 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .opacity(isLoser ? 0.8 : 1.0)
    }
    
    private func teamColor(for teamCode: String) -> Color {
        teamAssets.team(for: teamCode)?.primaryColor ?? Color.blue.opacity(0.6)
    }
}

/// Displays a formatted seed number (e.g., #1) for watermarks
struct SeedNumberView: View {
    let seed: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("#")
                .font(.system(size: 35, weight: .black))
            Text("\(seed)")
                .font(.system(size: 70, weight: .black))
        }
        .foregroundColor(.white.opacity(0.25))
    }
}