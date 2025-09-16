//
//  ChoppedSurvivalStats.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Survival stats section with compact stat cards
struct ChoppedSurvivalStats: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let pulseAnimation: Bool
    @Binding var showingMyRoster: Bool
    
    var body: some View {
        Group {
            if choppedLeaderboardViewModel.shouldShowSurvivalStats {
                // Single row with all 5 compact stat cards
                HStack(spacing: 6) {
                    // Your personal stats card (COMPACT!)
                    ChoppedPersonalStatCard(
                        choppedLeaderboardViewModel: choppedLeaderboardViewModel,
                        pulseAnimation: pulseAnimation,
                        showingMyRoster: $showingMyRoster
                    )
                    
                    // SWAPPED: Cutoff first, then Delta
                    ChoppedCompactStatCard(
                        title: "CUTOFF",
                        value: choppedLeaderboardViewModel.eliminationLineDisplay,
                        subtitle: "LINE",
                        color: .red
                    )
                    
                    ChoppedCompactStatCard(
                        title: "DELTA",
                        value: choppedLeaderboardViewModel.myEliminationDelta ?? "--",
                        subtitle: "POINTS",
                        color: choppedLeaderboardViewModel.myEliminationDeltaColor
                    )
                    
                    ChoppedCompactStatCard(
                        title: "AVG",
                        value: choppedLeaderboardViewModel.averageScoreDisplay,
                        subtitle: "MEAN",
                        color: .blue
                    )
                    
                    ChoppedCompactStatCard(
                        title: "HIGH",
                        value: choppedLeaderboardViewModel.topScoreDisplay,
                        subtitle: "WEEK",
                        color: .yellow
                    )
                }
                .padding(.vertical, 8)
            } else {
                // Show pre-game message instead of stats
                VStack(spacing: 12) {
                    Text("📊 BATTLE STATS UNAVAILABLE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text("Rankings and survival percentages will appear once games begin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}