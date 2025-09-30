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
    
    @State private var cardScale: CGFloat = 1.0
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove Button wrapper - NavigationLink handles taps
        // BEFORE: Button(action: { handleTap() }) { ... }
        // AFTER: Direct content - NavigationLink in parent handles navigation
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
                    scoreAnimation: scoreAnimation
                )
            }
        }
        .scaleEffect(cardScale)
        // 🏈 NAVIGATION FREEDOM: Remove onTapGesture - conflicts with NavigationLink
        // BEFORE: .onTapGesture { handleTapFeedback() }
        // AFTER: NavigationLink handles all tap interactions
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
            
            if matchup.isMyManagerEliminated {
                startEliminatedAnimation()
            }
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