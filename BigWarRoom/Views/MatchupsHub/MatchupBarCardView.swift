//
//  MatchupBarCardView.swift
//  BigWarRoom
//
//  Horizontal bar-style matchup card - Clean, scannable, Apple HIG compliant
//

import SwiftUI

struct MatchupBarCardView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let isLineupOptimized: Bool
    
    @State private var cardScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        MatchupBarCardContentView(
            matchup: matchup,
            isWinning: isWinning,
            isLineupOptimized: isLineupOptimized
        )
        .frame(height: 95)
        .scaleEffect(cardScale)
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
        }
        .contentShape(Rectangle())
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
}