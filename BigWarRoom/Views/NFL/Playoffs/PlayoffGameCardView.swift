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
                teamCard(team: game.awayTeam, isWinning: isTeamWinning(game.awayTeam))
                
                // VS Divider
                Text("vs")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                
                // Home Team (Right)
                teamCard(team: game.homeTeam, isWinning: isTeamWinning(game.homeTeam))
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
    
    // MARK: - Team Card
    
    @ViewBuilder
    private func teamCard(team: PlayoffTeam, isWinning: Bool) -> some View {
        VStack(spacing: 8) {
            // Team Logo with Seed Badge
            ZStack(alignment: .topLeading) {
                // Team Logo Background
                Circle()
                    .fill(teamLogoBackground(team.abbreviation))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(team.abbreviation)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Seed Badge (Top Left Corner)
                if let seed = team.seed {
                    Text("\(seed)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(seedColor(for: seed))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: -2, y: -2)
                }
            }
            
            // Team Name
            Text(team.abbreviation)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isWinning ? .primary : .secondary)
            
            // Score (if available)
            if let score = team.score {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isWinning ? .green : .secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isWinning && game.isCompleted ? winningBackground : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
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
    
    private func seedColor(for seed: Int) -> Color {
        switch seed {
        case 1:
            return Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        case 2:
            return Color(red: 0.75, green: 0.75, blue: 0.75)  // Silver
        case 3:
            return Color(red: 0.8, green: 0.5, blue: 0.2)  // Bronze
        default:
            return .blue
        }
    }
    
    private func teamLogoBackground(_ abbreviation: String) -> Color {
        // Get actual team color
        if let team = NFLTeam.team(for: abbreviation) {
            return team.primaryColor
        }
        
        // Fallback
        let hash = abbreviation.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var winningBackground: Color {
        Color.green.opacity(0.1)
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

// MARK: - Preview

#Preview("Bracket Style") {
    VStack(spacing: 16) {
        PlayoffGameCardView(
            game: PlayoffGame(
                id: "1",
                round: .wildCard,
                conference: .afc,
                homeTeam: PlayoffTeam(
                    abbreviation: "KC",
                    name: "Kansas City Chiefs",
                    seed: 2,
                    score: nil,
                    logoURL: nil
                ),
                awayTeam: PlayoffTeam(
                    abbreviation: "MIA",
                    name: "Miami Dolphins",
                    seed: 7,
                    score: nil,
                    logoURL: nil
                ),
                gameDate: Date().addingTimeInterval(86400),
                status: .scheduled
            ),
            showFantasyHighlight: false,
            onTap: {}
        )
        
        PlayoffGameCardView(
            game: PlayoffGame(
                id: "2",
                round: .wildCard,
                conference: .afc,
                homeTeam: PlayoffTeam(
                    abbreviation: "BUF",
                    name: "Buffalo Bills",
                    seed: 3,
                    score: 31,
                    logoURL: nil
                ),
                awayTeam: PlayoffTeam(
                    abbreviation: "PIT",
                    name: "Pittsburgh Steelers",
                    seed: 6,
                    score: 27,
                    logoURL: nil
                ),
                gameDate: Date(),
                status: .final
            ),
            showFantasyHighlight: false,
            onTap: {}
        )
    }
    .padding()
    .frame(width: 350)
    .background(Color.black)
}