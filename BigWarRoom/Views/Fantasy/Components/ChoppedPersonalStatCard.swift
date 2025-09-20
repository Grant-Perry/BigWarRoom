//
//  ChoppedPersonalStatCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Personal stat card for the current user
struct ChoppedPersonalStatCard: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let pulseAnimation: Bool
    @Binding var showingMyRoster: Bool
    
    var body: some View {
        Button(action: {
            // Show your roster using SwiftUI sheet navigation
            showingMyRoster = true
        }) {
            VStack(spacing: 2) {
                // Your rank badge (smaller)
                HStack(spacing: 2) {
                    Text(choppedLeaderboardViewModel.myRankDisplay)
					  .font(.system(size: 8, weight: .medium))
					  .foregroundColor(choppedLeaderboardViewModel.myForeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(choppedLeaderboardViewModel.myStatusColor)
                        )
                    
//                    Text("YOU")
//                        .font(.system(size: 7, weight: .bold))
//                        .foregroundColor(.gray)
//                        .tracking(0.3)
                }
                
                // Your score (smaller)
                Text(choppedLeaderboardViewModel.myScoreDisplay)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(choppedLeaderboardViewModel.myStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Your status (compact) - REMOVED elimination delta
                HStack(spacing: 2) {
                    Text(choppedLeaderboardViewModel.myStatusEmoji)
                        .font(.system(size: 8))
                    
                    Text(choppedLeaderboardViewModel.myStatusText)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(choppedLeaderboardViewModel.myStatusColor)
                        .tracking(0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
			.frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(choppedLeaderboardViewModel.myStatusColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(choppedLeaderboardViewModel.myStatusColor.opacity(0.3), lineWidth: 1.5)
                            .shadow(color: choppedLeaderboardViewModel.myStatusColor.opacity(0.2), radius: 2)
                    )
            )
            .scaleEffect(pulseAnimation && choppedLeaderboardViewModel.isMyTeamInDanger ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
        }
        .buttonStyle(PlainButtonStyle()) // Prevents default button styling
    }
}
