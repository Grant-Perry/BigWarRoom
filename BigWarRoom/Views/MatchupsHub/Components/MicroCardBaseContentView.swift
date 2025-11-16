//
//  MicroCardBaseContentView.swift
//  BigWarRoom
//
//  Base content component for MicroCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct MicroCardBaseContentView: View {
    let leagueName: String
    let avatarURL: String?
    let managerName: String
    let score: String
    let scoreColor: Color
    let percentage: String
    let isEliminated: Bool
    let eliminationWeek: Int?
    let eliminatedPulse: Bool
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shouldPulse: Bool
    let shadowColor: Color
    let shadowRadius: CGFloat
    let pulseOpacity: Double
    
    // 🔥 CELEBRATION: New parameters for celebration
    let isGamesFinished: Bool
    let celebrationBorderPulse: Bool
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    // 💊 RX button callback
    let onRXTap: (() -> Void)?
    
    // 💊 RX: Optimization status
    let isLineupOptimized: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // League name
            Text(leagueName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isEliminated ? .gray.opacity(0.6) : .gray)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            
            // 🔥 CONDITIONAL CONTENT: Show eliminated OR regular content (same structure)
            if isEliminated {
                MicroCardEliminatedContentView(
                    managerName: managerName,
                    eliminationWeek: eliminationWeek,
                    eliminatedPulse: eliminatedPulse
                )
            } else {
                MicroCardRegularContentView(
                    avatarURL: avatarURL,
                    managerName: managerName,
                    score: score,
                    scoreColor: scoreColor,
                    percentage: percentage,
                    record: matchup.myTeam?.record?.displayString,
                    onRXTap: onRXTap,
                    isLineupOptimized: isLineupOptimized
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            MicroCardBackgroundView(
                isEliminated: isEliminated,
                borderColors: borderColors,
                borderWidth: borderWidth,
                borderOpacity: borderOpacity,
                shouldPulse: shouldPulse,
                pulseOpacity: pulseOpacity,
                isGamesFinished: isGamesFinished,
                scoreColor: scoreColor,
                celebrationBorderPulse: celebrationBorderPulse,
                matchup: matchup,
                isWinning: isWinning
            )
        )
        .shadow(
            color: isEliminated ? Color.black.opacity(0.5) : shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 2
        )
    }
}