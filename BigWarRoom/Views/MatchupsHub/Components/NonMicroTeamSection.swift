//
//  NonMicroTeamSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Team section with avatar, name, score for non-micro cards
struct NonMicroTeamSection: View {
    let team: FantasyTeam
    let isMyTeam: Bool
    let isWinning: Bool
    let dualViewMode: Bool
    let scoreAnimation: Bool
    let isLiveGame: Bool
    
    private var isTeamWinning: Bool {
        if isMyTeam {
            return isWinning
        } else {
            return !isWinning
        }
    }
    
    var body: some View {
        VStack(spacing: dualViewMode ? 6 : 3) {
            // Avatar
            Group {
                if let avatarURL = team.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show team initials immediately while avatar loads
                        NonMicroTeamInitials(team: team, isWinning: isTeamWinning)
                    }
                    .frame(width: dualViewMode ? 45 : 32, height: dualViewMode ? 45 : 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                lineWidth: isTeamWinning ? 2 : 1
                            )
                    )
                } else {
                    NonMicroTeamInitials(team: team, isWinning: isTeamWinning)
                        .frame(width: dualViewMode ? 45 : 32, height: dualViewMode ? 45 : 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                    lineWidth: isTeamWinning ? 2 : 1
                                )
                        )
                }
            }
            
            // Team name
            Text(team.ownerName)
                .font(.system(size: dualViewMode ? 13 : 11, weight: .bold))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .frame(maxWidth: dualViewMode ? 60 : 50)
            
            // Score
            Text(team.currentScoreString)
                .font(.system(size: dualViewMode ? 16 : 13, weight: .black, design: .rounded))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .scaleEffect(scoreAnimation && isLiveGame ? 1.1 : 1.0)
            
            // Record (only show in Dual view)
            if dualViewMode, let record = team.record {
                Text(record.displayString)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}