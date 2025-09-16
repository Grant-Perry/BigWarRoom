//
//  NonMicroCardBackground.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Background component for non-micro cards
struct NonMicroCardBackground: View {
    let matchup: UnifiedMatchup
    let backgroundColors: [Color]
    private let cardGradTop: Color = .nyyDark // Use nyyDark color
   private let cardGradBottom: Color = .gpYellowD // Clear color for bottom
   private let cardOpacity: Double = 0.85

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                // TeamAssetManager-style gradient background using cardGradTop and cardGradBottom
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [cardGradTop.opacity(0.8), cardGradBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(cardGradTop.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(cardOpacity) // Add opacity to the entire card background
    }
}
