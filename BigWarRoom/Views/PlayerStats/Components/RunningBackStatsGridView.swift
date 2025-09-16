//
//  RunningBackStatsGridView.swift
//  BigWarRoom
//
//  Running back stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct RunningBackStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            // Rushing stats
            if statsData.rushingAttempts > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Rushing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        StatBubbleView(
                            value: "\(statsData.rushingAttempts)",
                            label: "CARRIES",
                            color: .green
                        )
                        StatBubbleView(
                            value: "\(statsData.rushingYards)",
                            label: "RUSH YD",
                            color: .green
                        )
                        StatBubbleView(
                            value: "\(statsData.rushingTouchdowns)",
                            label: "RUSH TD",
                            color: .gpGreen
                        )
                        if statsData.rushingFirstDowns > 0 {
                            StatBubbleView(
                                value: "\(statsData.rushingFirstDowns)",
                                label: "RUSH FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Receiving stats (if significant)
            if statsData.receptions > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Receiving")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
                        StatBubbleView(
                            value: "\(statsData.receptions)",
                            label: "REC",
                            color: .purple
                        )
                        StatBubbleView(
                            value: "\(statsData.receivingYards)",
                            label: "REC YD",
                            color: .purple
                        )
                        if statsData.receivingTouchdowns > 0 {
                            StatBubbleView(
                                value: "\(statsData.receivingTouchdowns)",
                                label: "REC TD",
                                color: .gpGreen
                            )
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}