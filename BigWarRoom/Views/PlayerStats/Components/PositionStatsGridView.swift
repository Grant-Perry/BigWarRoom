//
//  PositionStatsGridView.swift
//  BigWarRoom
//
//  Position-specific stats grids using DRY StatBubbleView component
//

import SwiftUI

/// Position-specific stats display using reusable StatBubbleView
struct PositionStatsGridView: View {
    let statsData: PlayerStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            switch statsData.position {
            case "QB":
                quarterbackStatsView
            case "RB":
                runningBackStatsView
            case "WR", "TE":
                receiverStatsView
            case "K":
                kickerStatsView
            case "DEF", "DST":
                defenseStatsView
            default:
                genericStatsView
            }
        }
    }
    
    // MARK: - Position-Specific Views
    
    private var quarterbackStatsView: some View {
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
    
    private var runningBackStatsView: some View {
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
    
    private var receiverStatsView: some View {
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
    
    private var kickerStatsView: some View {
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
    
    private var defenseStatsView: some View {
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
    
    private var genericStatsView: some View {
        VStack(spacing: 8) {
            Text("Limited stats available")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    PositionStatsGridView(
        statsData: PlayerStatsData(
            playerID: "123",
            stats: [
                "pts_ppr": 25.6,
                "pass_cmp": 22,
                "pass_att": 35,
                "pass_yd": 287,
                "pass_td": 2
            ],
            position: "QB"
        )
    )
    .background(Color.black)
}