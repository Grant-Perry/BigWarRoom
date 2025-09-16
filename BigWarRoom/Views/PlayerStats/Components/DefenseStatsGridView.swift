//
//  DefenseStatsGridView.swift
//  BigWarRoom
//
//  Defense stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DefenseStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            if statsData.sacks > 0 {
                StatBubbleView(
                    value: "\(statsData.sacks)",
                    label: "SACKS",
                    color: .red
                )
            }
            if statsData.defensiveInterceptions > 0 {
                StatBubbleView(
                    value: "\(statsData.defensiveInterceptions)",
                    label: "INTS",
                    color: .red
                )
            }
            if statsData.fumbleRecoveries > 0 {
                StatBubbleView(
                    value: "\(statsData.fumbleRecoveries)",
                    label: "FUM REC",
                    color: .red
                )
            }
        }
    }
}