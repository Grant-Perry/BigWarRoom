//
//  DepthChartPlayerRowDepthCircleView.swift
//  BigWarRoom
//
//  Depth circle component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowDepthCircleView: View {
    let depthPlayer: DepthChartPlayer
    
    var body: some View {
        ZStack {
            // Glow effect behind number
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            depthPlayer.depthColor.opacity(0.8),
                            depthPlayer.depthColor.opacity(0.3)
                        ]),
                        center: .center,
                        startRadius: 2,
                        endRadius: 15
                    )
                )
                .frame(width: 28, height: 28)
                .blur(radius: 1)
            
            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            depthPlayer.depthColor,
                            depthPlayer.depthColor.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: depthPlayer.depthColor.opacity(0.4), radius: 3, x: 0, y: 2)
            
            Text("\(depthPlayer.depth)")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white)
        }
    }
}