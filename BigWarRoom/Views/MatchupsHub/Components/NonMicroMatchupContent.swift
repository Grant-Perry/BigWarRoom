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
    
    var onTeamLogoTap: ((String) -> Void)? = nil
    var onRXTap: (() -> Void)? = nil
    var isLineupOptimized: Bool = false
    
    let myProjected: Double
    let opponentProjected: Double
    let projectionsLoaded: Bool
    
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
            .onAppear {
                DebugPrint(mode: .liveUpdates, "🎯 CONTENT: projectionsLoaded=\(projectionsLoaded), my=\(myProjected), opp=\(opponentProjected)")
            }
            
            // Projected scores (if loaded)
            if projectionsLoaded && myProjected > 0 && opponentProjected > 0 {
                ProjectedScoreView(
                    myProjected: myProjected,
                    opponentProjected: opponentProjected,
                    alignment: .center,
                    size: dualViewMode ? .small : .medium
                )
                .padding(.vertical, 2)
                .onAppear {
                    DebugPrint(mode: .liveUpdates, "🎯 RENDERING: Projected scores visible - My: \(myProjected), Opp: \(opponentProjected)")
                }
            }
            
            // Win probability with score delta
            if let winProb = matchup.myWinProbability {
                let _ = DebugPrint(mode: .winProb, limit: 2, "📊 RENDERING WIN PROB: \(Int(winProb * 100))% for \(matchup.league.league.name)")
                NonMicroWinProbability(
                    winProb: winProb,
                    scoreDelta: matchup.scoreDifferential,
                    isWinning: isWinning,
                    matchup: matchup,
                    onRXTap: onRXTap,
                    isLineupOptimized: isLineupOptimized
                )
            } else {
                let _ = DebugPrint(mode: .winProb, limit: 2, "⚠️ WIN PROB IS NIL for \(matchup.league.league.name)")
            }
            
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