//
//  PlayerCardStatsPreviewRowView.swift
//  BigWarRoom
//
//  Stats preview row component for PlayerCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerCardStatsPreviewRowView: View {
    let player: SleeperPlayer
    
    var body: some View {
        HStack(spacing: 8) {
            // Player details
            if let number = player.number {
                Text("#\(number)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let yearsExp = player.yearsExp {
                Text("Y\(yearsExp)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Stats preview from PlayerStatsStore
            // if let stats = PlayerStatsStore.shared.stats(for: player.playerID) {
            //     if let ppg = stats.pprPointsPerGame {
            //         Text(String(format: "%.1f PPG", ppg))
            //             .font(.caption2)
            //             .foregroundColor(.blue)
            //             .fontWeight(.medium)
            //     }
            // }
            
            // Injury status
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
			   Text(String(injuryStatus.prefix(5)))
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}