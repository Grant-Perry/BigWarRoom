//
//  MatchupBarCardBackgroundView.swift
//  BigWarRoom
//
//  Background for horizontal bar-style matchup cards
//

import SwiftUI

struct MatchupBarCardBackgroundView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    var body: some View {
        ZStack {
            // Solid base layer with slight transparency
		   LinearGradient(
			colors: [.gpBlueDark, .clear],
			startPoint: .top,
			endPoint: .bottom
		   )                .opacity(0.85)

            // Optional accent gradient overlay for live states
            if matchup.isLive {
                LinearGradient(
                    colors: [
                        Color.clear,
                        (isWinning ? Color.gpGreen : Color.gpRedPink).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Subtle texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}
