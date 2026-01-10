//
//  PlayoffGameCardView.swift
//  BigWarRoom
//
//  Individual playoff game card showing teams in bracket style
//

import SwiftUI

struct PlayoffGameCardView: View {
    let game: PlayoffGame
    let showFantasyHighlight: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Away Team (Left)
                PlayoffTeamCard(
                    team: game.awayTeam,
                    isWinning: isTeamWinning(game.awayTeam),
                    isGameCompleted: game.isCompleted
                )
                
                // VS Divider
                Text("vs")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                
                // Home Team (Right)
                PlayoffTeamCard(
                    team: game.homeTeam,
                    isWinning: isTeamWinning(game.homeTeam),
                    isGameCompleted: game.isCompleted
                )
            }
            .padding(12)
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    /// Determines if the given team is currently winning
    private func isTeamWinning(_ team: PlayoffTeam) -> Bool {
        guard let teamScore = team.score else { return false }
        
        let opponentScore: Int
        if team.abbreviation == game.homeTeam.abbreviation {
            opponentScore = game.awayTeam.score ?? 0
        } else {
            opponentScore = game.homeTeam.score ?? 0
        }
        
        return teamScore > opponentScore
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.1)
    }
    
    private var borderColor: Color {
        if showFantasyHighlight {
            return .blue
        }
        return game.isLive ? .red.opacity(0.5) : Color.secondary.opacity(0.2)
    }
    
    private var borderWidth: CGFloat {
        showFantasyHighlight ? 2 : 1
    }
}