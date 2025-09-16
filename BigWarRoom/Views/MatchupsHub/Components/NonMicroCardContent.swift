//
//  NonMicroCardContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Main card content for non-micro cards
struct NonMicroCardContent: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let dualViewMode: Bool
    let scoreAnimation: Bool
    let overlayBorderColors: [Color]
    let overlayBorderWidth: CGFloat
    let overlayBorderOpacity: Double
    let shadowColor: Color
    let shadowRadius: CGFloat
    let backgroundColors: [Color]
    
    var body: some View {
        VStack(spacing: dualViewMode ? 8 : 4) {
            // Compact header with league and status
            NonMicroCardHeader(matchup: matchup, dualViewMode: dualViewMode)
            
            // Main content
            if matchup.isChoppedLeague {
                NonMicroChoppedContent(matchup: matchup, isWinning: isWinning)
            } else {
                NonMicroMatchupContent(
                    matchup: matchup,
                    isWinning: isWinning,
                    dualViewMode: dualViewMode,
                    scoreAnimation: scoreAnimation
                )
            }
            
            // Compact footer
            NonMicroCardFooter(matchup: matchup, dualViewMode: dualViewMode)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dualViewMode ? 14 : 8)
        .background(NonMicroCardBackground(matchup: matchup, backgroundColors: backgroundColors))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: overlayBorderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: overlayBorderWidth
                )
                .opacity(overlayBorderOpacity)
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 2
        )
        .frame(height: dualViewMode ? 142 : 120)
    }
}