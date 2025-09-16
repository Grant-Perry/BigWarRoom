//
//  KickerStatsGridView.swift
//  BigWarRoom
//
//  Kicker stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct KickerStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        HStack(spacing: 12) {
            if statsData.fieldGoalsMade > 0 {
                StatBubbleView(
                    value: "\(statsData.fieldGoalsMade)/\(statsData.fieldGoalsAttempted)",
                    label: "FIELD GOALS",
                    color: .yellow
                )
            }
            if statsData.extraPointsMade > 0 {
                StatBubbleView(
                    value: "\(statsData.extraPointsMade)",
                    label: "EXTRA PTS",
                    color: .orange
                )
            }
            Spacer()
        }
    }
}