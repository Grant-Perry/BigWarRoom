//
//  NonMicroCardHeader.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Header component for non-micro cards
struct NonMicroCardHeader: View {
    let league: UnifiedLeagueManager.LeagueWrapper
    let onRXTap: (() -> Void)?  // 💊 RX button callback
    let rxStatus: LineupRXStatus  // 💊 RX: 3-state optimization status
    
    // Backward compatibility init
    init(matchup: UnifiedMatchup, dualViewMode: Bool, onRXTap: (() -> Void)?, isLineupOptimized: Bool, rxStatus: LineupRXStatus = .critical) {
        self.league = matchup.league
        self.onRXTap = onRXTap
        self.rxStatus = rxStatus
    }
    
    // New 3-state init
    init(league: UnifiedLeagueManager.LeagueWrapper, onRXTap: (() -> Void)?, rxStatus: LineupRXStatus) {
        self.league = league
        self.onRXTap = onRXTap
        self.rxStatus = rxStatus
    }
    
    var body: some View {
        HStack {
            // League name with platform logo
            HStack(spacing: 6) {
                Group {
                    switch league.source {
                    case .espn:
                        AppConstants.espnLogo
                            .scaleEffect(0.4)
                    case .sleeper:
                        AppConstants.sleeperLogo
                            .scaleEffect(0.4)
                    }
                }
                .frame(width: 16, height: 16)
                
                Text("\(league.league.name)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Spacer()
            
            // 💊 RX indicator - replaces LIVE
            if !league.isChoppedLeague, let onRXTap = onRXTap {
                Button(action: onRXTap) {
                    Image("LineupRX")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white)
                        .padding(3)
                        .background(
                            Circle()
                                .fill(rxButtonGradient)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // 💊 RX: Dynamic button color based on 3-state optimization status
    private var rxButtonColor: Color {
        return rxStatus.color
    }
    
    // 💊 RX: Dynamic gradient based on 3-state optimization status
    private var rxButtonGradient: LinearGradient {
        switch rxStatus {
        case .optimized:
            return LinearGradient(
                colors: [.gpGreen, .green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warning:
            return LinearGradient(
                colors: [.gpYellow, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .critical:
            return LinearGradient(
                colors: [.gpRedPink, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}