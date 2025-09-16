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
                QuarterbackStatsGridView(statsData: statsData)
            case "RB":
                RunningBackStatsGridView(statsData: statsData)
            case "WR", "TE":
                ReceiverStatsGridView(statsData: statsData)
            case "K":
                KickerStatsGridView(statsData: statsData)
            case "DEF", "DST":
                DefenseStatsGridView(statsData: statsData)
            default:
                GenericStatsGridView(statsData: statsData)
            }
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