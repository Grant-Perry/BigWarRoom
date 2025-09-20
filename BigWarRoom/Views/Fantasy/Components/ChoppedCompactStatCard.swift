//
//  ChoppedCompactStatCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Compact stat card for chopped leaderboard stats
struct ChoppedCompactStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(subtitle)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.gray)
                .tracking(0.3)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
		.frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.15),
                            color.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: color.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}
