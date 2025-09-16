//
//  FantasyMatchupCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Fantasy Matchup Card component
struct FantasyMatchupCard: View {
    let matchup: FantasyMatchup
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with week info
            HStack {
                Text("Week \(matchup.week)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(matchup.winProbabilityString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main matchup content
            HStack(spacing: 0) {
                // Away team (left side)
                MatchupTeamSectionView(
                    team: matchup.awayTeam,
                    score: matchup.awayTeam.currentScoreString,
                    isHome: false
                )
                
                // VS divider  
                VStack {
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Week \(matchup.week)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(matchup.winProbabilityString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .frame(width: 60)
                
                // Home team (right side)
                MatchupTeamSectionView(
                    team: matchup.homeTeam,
                    score: matchup.homeTeam.currentScoreString,
                    isHome: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Team section within a matchup card
struct MatchupTeamSectionView: View {
    let team: FantasyTeam
    let score: String
    let isHome: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Team avatar - Enhanced for ESPN teams
            TeamAvatarView(team: team)
            
            // Team info
            VStack(spacing: 2) {
                Text(team.ownerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Text("PF: \(team.record?.wins ?? 0)nd • PA: \(team.record?.losses ?? 0)nd")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Score
            Text(score)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isHome ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}