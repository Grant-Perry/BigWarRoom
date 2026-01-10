//
//  PlayoffTeamCard.swift
//  BigWarRoom
//
//  Individual team display within a playoff game card
//

import SwiftUI

struct PlayoffTeamCard: View {
    let team: PlayoffTeam
    let isWinning: Bool
    let isGameCompleted: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            // Team Logo with Seed Badge
            ZStack(alignment: .topLeading) {
                // Team Logo Background
                Circle()
                    .fill(teamLogoBackground)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(team.abbreviation)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Seed Badge (Top Left Corner)
                if let seed = team.seed {
                    PlayoffSeedBadge(seed: seed)
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
        .background(isWinning && isGameCompleted ? winningBackground : Color.clear)
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var teamLogoBackground: Color {
        // Get actual team color
        if let team = NFLTeam.team(for: team.abbreviation) {
            return team.primaryColor
        }
        
        // Fallback to hash-based color
        let hash = team.abbreviation.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    private var winningBackground: Color {
        Color.green.opacity(0.1)
    }
}