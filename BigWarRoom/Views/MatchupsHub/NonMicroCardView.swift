//
//  NonMicroCardView.swift
//  BigWarRoom
//
//  Independent non-micro matchup card view - Clean MVVM Coordinator
//

import SwiftUI

struct NonMicroCardView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    // 🏈 NAVIGATION FREEDOM: Remove onTap parameter - NavigationLink handles navigation
    // let onTap: () -> Void
    
    // Accept dualViewMode parameter to make cards more compact in Single view
    var dualViewMode: Bool = true
    
    // 💊 RX: Optimization status
    let isLineupOptimized: Bool
    
    @State private var cardScale: CGFloat = 1.0
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    // 💊 RX Sheet state
    @State private var showingLineupRX = false
    
    var body: some View {
        VStack {
            // Conditional content: Show eliminated state or regular card
            if matchup.isMyManagerEliminated {
                NonMicroEliminatedContent(
                    matchup: matchup,
                    dualViewMode: dualViewMode,
                    eliminatedPulse: eliminatedPulse
                )
            } else {
                NonMicroCardContent(
                    matchup: matchup,
                    isWinning: isWinning,
                    dualViewMode: dualViewMode,
                    scoreAnimation: scoreAnimation,
                    isGamesFinished: false, // 🔥 SIMPLIFIED: Always false, no celebration logic
                    celebrationBorderPulse: false, // 🔥 SIMPLIFIED: Always false
                    onRXTap: { showingLineupRX = true },
                    isLineupOptimized: isLineupOptimized
                )
            }
        }
	   // MARK: master frame dimensions for matchup cards
        .frame(
            width: dualViewMode ? 170 : 340,
            height: 190
        )
        .fixedSize(horizontal: true, vertical: true)
        .scaleEffect(cardScale)
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
            
            if matchup.isMyManagerEliminated {
                startEliminatedAnimation()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gpRedPink.opacity(0.3), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingLineupRX) {
            LineupRXView(matchup: matchup)
        }
    }
    
    // MARK: - Animation & Interaction
    
    // 🏈 NAVIGATION FREEDOM: Simplified tap feedback without preventing NavigationLink
    private func handleTapFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            cardScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                cardScale = 1.0
            }
            // 🏈 NAVIGATION FREEDOM: Don't call onTap() - NavigationLink handles navigation
        }
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                scoreAnimation.toggle()
            }
        }
    }
    
    private func startEliminatedAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            eliminatedPulse = true
        }
    }
}