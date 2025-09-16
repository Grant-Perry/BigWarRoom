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
    
    // NEW: Customizable card gradient color
    private let cardGrad: Color = .rockiesPrimary
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundGradient)
            .overlay(highlightOverlay)
            .overlay(darkenOverlay)
            .overlay(borderOverlay)
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var backgroundGradient: LinearGradient {
        if isEliminated {
            // 🔥 ELIMINATED GRADIENT: Use gpRedPink
            return LinearGradient(
                colors: [Color.gpRedPink.opacity(0.8), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Regular purple gradient
            return LinearGradient(
                colors: [cardGrad.opacity(0.6), cardGrad.opacity(0.9)],
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
            .fill(Color.black.opacity(isEliminated ? 0.3 : 0.3))
    }
    
    private var borderOverlay: some View {
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
}