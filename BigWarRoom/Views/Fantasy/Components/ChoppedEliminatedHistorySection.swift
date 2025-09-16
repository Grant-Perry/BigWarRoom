//
//  ChoppedEliminatedHistorySection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Historical eliminations section (The Graveyard)
struct ChoppedEliminatedHistorySection: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Graveyard header
            HStack {
                Text("🪦")
                    .font(.system(size: 20))
                
                Text("THE GRAVEYARD")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text("💀")
                    .font(.system(size: 20))
                
                Spacer()
                
                Text("\(choppedLeaderboardViewModel.fallenCount) FALLEN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text("\"They fought valiantly, but could not survive the chopping block...\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
            
            // 🔥 GRAVEYARD DISCLAIMER
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("Elimination weeks estimated - Sleeper doesn't chronicle the fallen")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                    .italic()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Historical eliminations in chronological order
            ForEach(choppedLeaderboardViewModel.choppedSummary.eliminationHistory) { elimination in
                HistoricalEliminationCard(elimination: elimination)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}