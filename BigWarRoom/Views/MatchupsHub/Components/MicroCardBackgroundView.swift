//
//  MicroCardBackgroundView.swift
//  BigWarRoom
//
//  Background component for MicroCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct MicroCardBackgroundView: View {
    let isEliminated: Bool
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shouldPulse: Bool
    let pulseOpacity: Double
    
    // 🔥 CELEBRATION: New parameters for celebration effects
    let isGamesFinished: Bool
    let scoreColor: Color
    let celebrationBorderPulse: Bool
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    // NEW: Customizable card gradient color
    private let cardGrad: Color = .rockiesPrimary
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundGradient)
            .overlay(highlightOverlay)
            .overlay(darkenOverlay)
            .overlay(
                // 🔥 CELEBRATION: Use celebration border if games are finished, otherwise regular border
                Group {
                    if isGamesFinished && !isEliminated {
                        celebrationBorderOverlay
                    } else {
                        regularBorderOverlay
                    }
                }
            )
    }
    
    // MARK: - 🔥 CELEBRATION: Win/Loss logic for both regular and chopped leagues
    private var isCelebrationWin: Bool {
        if matchup.isChoppedLeague {
            // 🔥 CHOPPED LOGIC: Win if I survived (not eliminated), Loss if I got chopped
            guard let ranking = matchup.myTeamRanking,
                  let choppedSummary = matchup.choppedSummary else {
                return isWinning // Fallback to regular logic
            }
            
            // Check if I'm in the elimination zone (bottom spots)
            let totalTeams = choppedSummary.rankings.count
            let myRank = ranking.rank
            
            // Calculate elimination threshold - typically 1-2 players eliminated per week
            // For larger leagues (20+ teams), usually 2 eliminated
            // For smaller leagues (8-12 teams), usually 1 eliminated
            let eliminationCount = totalTeams >= 20 ? 2 : 1
            let eliminationThreshold = totalTeams - eliminationCount + 1 // Last N positions
            
            // 🔥 WIN: If I'm NOT in the elimination zone (survived)
            // 🔥 LOSS: If I'm in the elimination zone (got chopped)
            return myRank < eliminationThreshold
            
        } else {
            // Regular matchup logic - use existing win/loss determination
            return scoreColor == .gpGreen
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var backgroundGradient: LinearGradient {
        if isEliminated {
            // 🔥 ELIMINATED GRADIENT: Back to original opacity
            return LinearGradient(
                colors: [Color.gpRedPink.opacity(0.8), Color.black.opacity(0.9)], // Back to original 0.8/0.9
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Regular purple gradient - back to original opacity
            return LinearGradient(
                colors: [cardGrad.opacity(0.6), cardGrad.opacity(0.9)], // Back to original 0.6/0.9
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(isEliminated ? 0.05 : 0.15), Color.clear, Color.white.opacity(isEliminated ? 0.02 : 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var darkenOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.3)) // Back to original 0.3
    }
    
    // 🔥 CELEBRATION: Celebration border overlay
    private var celebrationBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                LinearGradient(
                    colors: celebrationBorderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: celebrationBorderPulse ? 3 : 2.5
            )
            .opacity(celebrationBorderPulse ? 0.9 : 0.7)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: celebrationBorderPulse
            )
    }
    
    // Regular border overlay
    private var regularBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                LinearGradient(
                    colors: isEliminated ? [.red, .black, .red] : borderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isEliminated ? 2.0 : borderWidth
            )
            .opacity(shouldPulse ? pulseOpacity : borderOpacity)
    }
    
    /// Celebration border colors based on win/loss - works for both regular and chopped
    private var celebrationBorderColors: [Color] {
        if isCelebrationWin {
            // Winning/Survived: .gpGreen + teal
            return [.gpGreen, .teal, .gpGreen.opacity(0.8), .cyan, .gpGreen]
        } else {
            // Losing/Chopped: .gpRedPink + yellow
            return [.gpRedPink, .yellow, .gpRedPink.opacity(0.8), .orange, .gpRedPink]
        }
    }
}