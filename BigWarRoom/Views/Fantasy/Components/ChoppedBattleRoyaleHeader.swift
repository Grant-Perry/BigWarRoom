//
//  ChoppedBattleRoyaleHeader.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Compact battle royale header matching Mission Control minimalism
struct ChoppedBattleRoyaleHeader: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let pulseAnimation: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact league name - like Mission Control
            HStack {
                Text("💀")
                    .font(.system(size: 16))
                
                Text(choppedLeaderboardViewModel.dramaticLeagueName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("🔥")
                    .font(.system(size: 16))
            }
            
            // Compact week and stats in one line
            HStack(spacing: 16) {
                // Week info
                Text("Week \(choppedLeaderboardViewModel.choppedSummary.week) • Elimination")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Compact survivor/eliminated stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("\(choppedLeaderboardViewModel.survivorsCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                        Text("alive")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(choppedLeaderboardViewModel.eliminatedCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                        Text("out")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Compact pre-game message if needed
            if !choppedLeaderboardViewModel.hasWeekStarted {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Games haven't started")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}