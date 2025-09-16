//
//  DepthChartPlayerRowBorderView.swift
//  BigWarRoom
//
//  Border component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowBorderView: View {
    let depthPlayer: DepthChartPlayer
    let positionColor: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        depthPlayer.isCurrentPlayer ? Color.gpGreen : Color.white.opacity(0.2),
                        depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.6) : positionColor.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: depthPlayer.isCurrentPlayer ? 2 : 1
            )
    }
}