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
    
    // 🔥 CELEBRATION: States for massive expanding glow effects
    @State private var celebrationGlowScale: Double = 1.0
    @State private var celebrationGlowOpacity: Double = 0.0
    @State private var celebrationPulse: Bool = false
    @State private var celebrationSpread: Double = 1.0
    @State private var celebrationBorderPulse: Bool = false
    
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
                    scoreAnimation: scoreAnimation,
                    isGamesFinished: isGamesFinishedForWeek,
                    celebrationBorderPulse: celebrationBorderPulse
                )
            }
        }
        // 🔥 NUCLEAR FIXED SIZE: Set both width AND height explicitly
        .frame(
            width: dualViewMode ? 180 : 350,  // Fixed width based on mode
            height: dualViewMode ? 150 : 120  // Fixed height
        )
        .fixedSize() // 🔥 CRITICAL: Prevent any size changes
        .scaleEffect(cardScale)
        // 🏈 NAVIGATION FREEDOM: Remove onTapGesture - conflicts with NavigationLink
        // BEFORE: .onTapGesture { handleTapFeedback() }
        // AFTER: NavigationLink handles all tap interactions
        // 🔥 TEMP: Remove celebration glow entirely to test layout
        // .overlay(
        //     Group {
        //         if isGamesFinishedForWeek && !matchup.isMyManagerEliminated {
        //             constrainedCelebrationGlow
        //                 .clipped()
        //                 .allowsHitTesting(false)
        //         }
        //     }
        // )
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
            
            if matchup.isMyManagerEliminated {
                startEliminatedAnimation()
            }
            
            // 🔥 TEMP: Don't start celebration glow
            // if isGamesFinishedForWeek {
            //     startMassiveCelebrationGlow()
            // }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8)) // Back to original 0.8
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gpRedPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 🔥 CELEBRATION: Week-End Celebration Logic
    
    /// Check if it's Tuesday or Wednesday (games are finished)
    private var isGamesFinishedForWeek: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 3 || weekday == 4 // Tuesday = 3, Wednesday = 4
    }
    
    /// 🔥 SIMPLE CHOPPED LOGIC: Win/Loss logic - not in last place = winning
    private var isCelebrationWin: Bool {
        if matchup.isChoppedLeague {
            // 🔥 SIMPLE CHOPPED LOGIC: Win if NOT in chopping block (last place or bottom 2)
            guard let ranking = matchup.myTeamRanking,
                  let choppedSummary = matchup.choppedSummary else {
                return isWinning // Fallback to regular logic
            }
            
            // If I'm already eliminated from this league, it's definitely a loss
            if matchup.isMyManagerEliminated {
                return false
            }
            
            let totalTeams = choppedSummary.rankings.count
            let myRank = ranking.rank
            
            // 🔥 SIMPLE RULE:
            // - 32+ player leagues: Bottom 2 get chopped = ranks (totalTeams-1) and totalTeams are losing
            // - All other leagues: Bottom 1 gets chopped = rank totalTeams is losing
            if totalTeams >= 32 {
                // Bottom 2 positions are losing (last 2 places)
                return myRank <= (totalTeams - 2)
            } else {
                // Bottom 1 position is losing (last place)
                return myRank < totalTeams
            }
            
        } else {
            // Regular matchup logic - use existing win/loss determination
            return isWinning
        }
    }
    
    /// 🔥 CONSTRAINED: Celebration glow that respects card bounds
    @ViewBuilder
    private var constrainedCelebrationGlow: some View {
        ZStack {
            // 🔥 CONSTRAINED: Much smaller glow layers that fit within card bounds
            ForEach(0..<2, id: \.self) { layer in
                RoundedRectangle(cornerRadius: 10 + Double(layer) * 2)
                    .fill(
                        RadialGradient(
                            colors: [
                                celebrationGlowColor.opacity(0.4 - Double(layer) * 0.1),
                                celebrationGlowColor.opacity(0.2 - Double(layer) * 0.05),
                                celebrationSecondaryColor.opacity(0.15 - Double(layer) * 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + Double(layer) * 15
                        )
                    )
                    .frame(
                        width: 90 + Double(layer) * 15, // Much smaller - stays within card
                        height: 70 + Double(layer) * 10  // Much smaller - stays within card
                    )
                    .scaleEffect(1.0 + celebrationGlowScale * 0.15 + Double(layer) * 0.1) // Reduced scaling
                    .opacity(celebrationGlowOpacity * (0.8 - Double(layer) * 0.2))
                    .blur(radius: 4 + Double(layer) * 2) // Reduced blur
                    .animation(
                        .easeInOut(duration: 2.0 + Double(layer) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.2),
                        value: celebrationGlowScale
                    )
                    .animation(
                        .easeInOut(duration: 1.6 + Double(layer) * 0.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.1),
                        value: celebrationGlowOpacity
                    )
            }
            
            // 🔥 CONSTRAINED: Central pulse - much smaller
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            celebrationGlowColor.opacity(0.6),
                            celebrationSecondaryColor.opacity(0.3),
                            celebrationGlowColor.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 60) // Much smaller
                .scaleEffect(celebrationPulse ? 1.15 : 1.0) // Reduced scaling
                .opacity(celebrationPulse ? 0.5 : 0.2) // Reduced opacity
                .blur(radius: 4) // Reduced blur
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: celebrationPulse
                )
                
            // 🔥 CONSTRAINED: Subtle border pulse - stays within bounds
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    celebrationGlowColor.opacity(0.4),
                    lineWidth: 1
                )
                .frame(width: 60, height: 45) // Much smaller
                .scaleEffect(1.0 + celebrationSpread * 0.3) // Reduced expansion
                .opacity(max(0.1, 1.0 - celebrationSpread * 0.4)) // Controlled fade
                .animation(
                    .easeOut(duration: 2.0).repeatForever(autoreverses: false),
                    value: celebrationSpread
                )
        }
        .allowsHitTesting(false) // Don't interfere with taps or layout
    }
    
    /// Celebration glow color based on win/loss - works for both regular and chopped
    private var celebrationGlowColor: Color {
        isCelebrationWin ? .gpGreen : .gpRedPink
    }
    
    /// Secondary celebration color for mixed gradients
    private var celebrationSecondaryColor: Color {
        if isCelebrationWin {
            // Winning/Survived: Teal blue mixed with green
            return .cyan
        } else {
            // Losing/Chopped: Pink mixed with red
            return .pink
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
    
    // 🔥 CELEBRATION: Updated animation values for constrained effects
    private func startMassiveCelebrationGlow() {
        // Reduced scale expansion
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            celebrationGlowScale = 0.8 // Reduced from 1.4
        }
        
        // Controlled opacity pulsing
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            celebrationGlowOpacity = 0.6 // Reduced from 0.8
        }
        
        // Subtle central pulse
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            celebrationPulse = true
        }
        
        // Constrained spreading ripple effect
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            celebrationSpread = 1.8 // Reduced from 2.5
        }
        
        // Border pulsing
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            celebrationBorderPulse = true
        }
    }
}