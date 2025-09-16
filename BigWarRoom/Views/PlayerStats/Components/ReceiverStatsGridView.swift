//
//  ReceiverStatsGridView.swift
//  BigWarRoom
//
//  Receiver (WR/TE) stats component for PositionStatsGridView - CLEAN ARCHITECTURE
//

import SwiftUI

struct ReceiverStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            // Receiving stats
            if statsData.receptions > 0 {
                VStack(spacing: 5) {
                    HStack {
                        Text("Receiving")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                        StatBubbleView(
                            value: "\(statsData.receptions)/\(statsData.targets)",
                            label: "REC/TGT",
                            color: .purple
                        )
                        StatBubbleView(
                            value: "\(statsData.receivingYards)",
                            label: "REC YD",
                            color: .purple
                        )
                        StatBubbleView(
                            value: "\(statsData.receivingTouchdowns)",
                            label: "REC TD",
                            color: .gpGreen
                        )
                        if statsData.receivingFirstDowns > 0 {
                            StatBubbleView(
                                value: "\(statsData.receivingFirstDowns)",
                                label: "REC FD",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Rushing stats (if significant for WRs)
            if statsData.position == "WR" && statsData.rushingYards > 0 {
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
                        Spacer()
                    }
                }
            }
        }
    }
}