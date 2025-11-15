//
//  NonMicroCardHeader.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Header component for non-micro cards
struct NonMicroCardHeader: View {
    let matchup: UnifiedMatchup
    let dualViewMode: Bool
    let onRXTap: (() -> Void)?  // 💊 RX button callback
    let isLineupOptimized: Bool  // 💊 RX: Optimization status
    
    var body: some View {
        HStack {
            // League name with platform logo
            HStack(spacing: 6) {
                Group {
                    switch matchup.league.source {
                    case .espn:
                        AppConstants.espnLogo
                            .scaleEffect(0.4)
                    case .sleeper:
                        AppConstants.sleeperLogo
                            .scaleEffect(0.4)
                    }
                }
                .frame(width: 16, height: 16)
                
                Text("\(matchup.league.league.name)")
                    .font(.system(size: dualViewMode ? 18 : 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Spacer()
            
            // 💊 RX indicator - replaces LIVE
            if !matchup.isChoppedLeague, let onRXTap = onRXTap {
                Button(action: onRXTap) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(buttonBackgroundColor)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // 💊 RX: Dynamic button color based on optimization status
    private var buttonBackgroundColor: Color {
        return isLineupOptimized ? .gpGreen : .gpRedPink
    }
}