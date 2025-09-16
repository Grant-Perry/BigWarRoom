//
//  DepthChartPlayerRowBackgroundView.swift
//  BigWarRoom
//
//  Background component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowBackgroundView: View {
    let depthPlayer: DepthChartPlayer
    let positionColor: Color
    
    var body: some View {
        ZStack {
            // Main gradient background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.4) : Color.black.opacity(0.6), location: 0.0),
                    .init(color: positionColor.opacity(0.15), location: 0.5),
                    .init(color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.2) : Color.black.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle overlay pattern
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.white.opacity(0.02)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}