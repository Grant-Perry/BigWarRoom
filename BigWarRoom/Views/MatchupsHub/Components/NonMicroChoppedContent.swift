//
//  NonMicroChoppedContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Chopped league content for non-micro cards
struct NonMicroChoppedContent: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Chopped status
            HStack {
                Text("🔥 CHOPPED")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let summary = matchup.choppedSummary {
                    Text("Week \(summary.week)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // My status
            if let ranking = matchup.myTeamRanking {
                HStack {
                    // Rank
                    VStack(spacing: 2) {
                        Text("#\(ranking.rank)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(ranking.eliminationStatus.color)
                        
                        Text(ranking.eliminationStatus.emoji)
                            .font(.system(size: 12))
                    }
                    
                    Spacer()
                    
                    // Score
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ranking.weeklyPointsString)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                        
                        Text(ranking.safetyMarginDisplay)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ranking.pointsFromSafety >= 0 ? .green : .red)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ranking.eliminationStatus.color.opacity(0.1))
                )
            }
        }
    }
}