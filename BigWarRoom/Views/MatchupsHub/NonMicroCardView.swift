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
        .scaleEffect(cardScale)
        .background(
            // 🔥 CELEBRATION: Massive expanding glow as background - doesn't affect layout
            Group {
                if isGamesFinishedForWeek && !matchup.isMyManagerEliminated {
                    massiveCelebrationGlow
                }
            }
        )
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
            
            // 🔥 CELEBRATION: Start celebration if games are finished
            if isGamesFinishedForWeek {
                startMassiveCelebrationGlow()
            }
        }
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
    
    /// Massive expanding glow behind the larger card - LAYOUT-SAFE
    @ViewBuilder
    private var massiveCelebrationGlow: some View {
        ZStack {
            // Multiple layers of expanding glow - CONSTRAINED SIZE
            ForEach(0..<3, id: \.self) { layer in
                RoundedRectangle(cornerRadius: 16 + Double(layer) * 4)
                    .fill(
                        RadialGradient(
                            colors: [
                                celebrationGlowColor.opacity(0.6 - Double(layer) * 0.15),
                                celebrationGlowColor.opacity(0.4 - Double(layer) * 0.1),
                                celebrationSecondaryColor.opacity(0.3 - Double(layer) * 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80 + Double(layer) * 20
                        )
                    )
                    .frame(
                        width: 160 + Double(layer) * 30,
                        height: 130 + Double(layer) * 20
                    )
                    .scaleEffect(celebrationGlowScale + Double(layer) * 0.15)
                    .opacity(celebrationGlowOpacity * (1.0 - Double(layer) * 0.2))
                    .blur(radius: 8 + Double(layer) * 4)
                    .animation(
                        .easeInOut(duration: 2.2 + Double(layer) * 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.3),
                        value: celebrationGlowScale
                    )
                    .animation(
                        .easeInOut(duration: 1.8 + Double(layer) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.2),
                        value: celebrationGlowOpacity
                    )
            }
            
            // Central expanding aura - SMALLER
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            celebrationGlowColor.opacity(0.8),
                            celebrationSecondaryColor.opacity(0.5),
                            celebrationGlowColor.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 110)
                .scaleEffect(celebrationPulse ? 1.4 : 1.1)
                .opacity(celebrationPulse ? 0.7 : 0.3)
                .blur(radius: 8)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: celebrationPulse
                )
                
            // Subtle outer ripple - CONSTRAINED
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    celebrationGlowColor.opacity(0.5),
                    lineWidth: 2
                )
                .frame(width: 100, height: 80)
                .scaleEffect(celebrationSpread)
                .opacity(2.0 - celebrationSpread) // Fade as it expands
                .animation(
                    .easeOut(duration: 2.5).repeatForever(autoreverses: false),
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
    
    // 🔥 CELEBRATION: Start the celebration glow effects - LAYOUT-SAFE
    private func startMassiveCelebrationGlow() {
        // Controlled scale expansion - dramatic but not layout-breaking
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            celebrationGlowScale = 1.4
        }
        
        // Opacity pulsing - intense but controlled
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            celebrationGlowOpacity = 0.8
        }
        
        // Central pulse - dramatic
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            celebrationPulse = true
        }
        
        // Constrained spreading ripple effect
        withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
            celebrationSpread = 2.5
        }
        
        // 🔥 NEW: Border pulsing with shadow
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            celebrationBorderPulse = true
        }
    }
}