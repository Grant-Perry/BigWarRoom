//
//  NonMicroMatchupContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Matchup content for regular fantasy leagues
struct NonMicroMatchupContent: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let dualViewMode: Bool
    let scoreAnimation: Bool
    
    // 🔥 NEW: Team roster navigation callback
    var onTeamLogoTap: ((String) -> Void)? = nil
    
    // 💊 RX button callback
    var onRXTap: (() -> Void)? = nil
    
    // 💊 RX: Optimization status
    var isLineupOptimized: Bool = false
    var rxStatus: LineupRXStatus = .critical  // 💊 RX: 3-state status
    
    private var isLiveGame: Bool {
        return matchup.isLive
    }
    
    private func getHomeTeam() -> FantasyTeam? {
        return matchup.fantasyMatchup?.homeTeam
    }
    
    private func getAwayTeam() -> FantasyTeam? {
        return matchup.fantasyMatchup?.awayTeam
    }
    
    var body: some View {
        VStack(spacing: dualViewMode ? 8 : 4) {
            // Teams row - HOME on LEFT, AWAY on RIGHT
            HStack(spacing: 8) {
                // Home team on LEFT
                if let homeTeam = getHomeTeam() {
                    NonMicroTeamSection(
                        team: homeTeam,
                        isMyTeam: homeTeam.id == matchup.myTeam?.id,
                        isWinning: isWinning,
                        dualViewMode: dualViewMode,
                        scoreAnimation: scoreAnimation,
                        isLiveGame: isLiveGame,
                        onTeamLogoTap: onTeamLogoTap
                    )
                }
                
                // VS separator
//                Text("VS")
//                    .font(.system(size: dualViewMode ? 10 : 8, weight: .black))
//                    .foregroundColor(.white.opacity(0.6))
//                    .frame(width: dualViewMode ? 24 : 20)
                
                // Away team on RIGHT
                if let awayTeam = getAwayTeam() {
                    NonMicroTeamSection(
                        team: awayTeam,
                        isMyTeam: awayTeam.id == matchup.myTeam?.id,
                        isWinning: isWinning,
                        dualViewMode: dualViewMode,
                        scoreAnimation: scoreAnimation,
                        isLiveGame: isLiveGame,
                        onTeamLogoTap: onTeamLogoTap
                    )
                }
            }
            
            // Win probability with score delta
            if let winProb = matchup.myWinProbability {
                NonMicroWinProbability(
                    winProb: winProb,
                    scoreDelta: matchup.scoreDifferential,
                    isWinning: isWinning,
                    matchup: matchup,
                    onRXTap: onRXTap,
                    rxStatus: rxStatus
                )
            }
            
            // 🔥 FIXED: Add Spacer to fill remaining height
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Format score delta with proper sign and formatting
    private func formatScoreDelta(_ delta: Double) -> String {
        if delta > 0 {
            return "+\(String(format: "%.1f", delta))"
        } else {
            return String(format: "%.1f", delta)
        }
    }
}