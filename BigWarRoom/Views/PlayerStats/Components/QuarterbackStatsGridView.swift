//
//  QuarterbackStatsGridView.swift
//  BigWarRoom
//
//  Quarterback stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct QuarterbackStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            // Passing stats
            if statsData.passingAttempts > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Passing")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        StatBubbleView(
                            value: "\(statsData.passingCompletions)/\(statsData.passingAttempts)",
                            label: "CMP/ATT",
                            color: .blue
                        )
                        StatBubbleView(
                            value: "\(statsData.passingYards)",
                            label: "PASS YD",
                            color: .purple
                        )
                        StatBubbleView(
                            value: "\(statsData.passingTouchdowns)",
                            label: "PASS TD",
                            color: .gpGreen
                        )
                        if statsData.interceptions > 0 {
                            StatBubbleView(
                                value: "\(statsData.interceptions)",
                                label: "INTS",
                                color: .red
                            )
                        }
                        if statsData.passingFirstDowns > 0 {
                            StatBubbleView(
                                value: "\(statsData.passingFirstDowns)",
                                label: "PASS FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Rushing stats (if significant)
            if statsData.rushingAttempts > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Rushing")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
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
                        if statsData.rushingTouchdowns > 0 {
                            StatBubbleView(
                                value: "\(statsData.rushingTouchdowns)",
                                label: "RUSH TD",
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