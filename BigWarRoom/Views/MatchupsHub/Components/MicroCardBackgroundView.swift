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
                // 🔥 SIMPLIFIED: Just use regular border always, no celebration logic
                regularBorderOverlay
            )
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
    
    // Regular border overlay
    private var regularBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                LinearGradient(
                    colors: isEliminated ? [.red, .black, .red] : simplifiedBorderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isEliminated ? 2.0 : borderWidth
            )
            .opacity(shouldPulse ? pulseOpacity : borderOpacity)
    }
    
    /// 🔥 SIMPLIFIED: Just use .gpGreen for winning, .gpRedPink for losing
    private var simplifiedBorderColors: [Color] {
        if isWinning {
            return [.gpGreen, .gpGreen, .gpGreen]
        } else {
            return [.gpRedPink, .gpRedPink, .gpRedPink]
        }
    }
}