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
    let dualViewMode: Bool
    let isLineupOptimized: Bool
    
    @State private var myProjected: Double = 0.0
    @State private var opponentProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    @State private var cardScale: CGFloat = 1.0
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    var body: some View {
        let _ = DebugPrint(mode: .winProb, limit: 2, "🎴 CARD: Rendering NonMicroCardView for \(matchup.league.league.name)")
        
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
                    isGamesFinished: false,
                    celebrationBorderPulse: false,
                    onRXTap: nil,
                    isLineupOptimized: isLineupOptimized,
                    myProjected: myProjected,
                    opponentProjected: opponentProjected,
                    projectionsLoaded: projectionsLoaded
                )
            }
        }
        .frame(
            width: dualViewMode ? 170 : 340,
            height: 190
        )
        .fixedSize(horizontal: true, vertical: true)
        .scaleEffect(cardScale)
        .onAppear {
            DebugPrint(mode: .liveUpdates, "🎯 CARD APPEARED: \(matchup.fantasyMatchup?.leagueID ?? "Unknown")")
            
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
        .task {
            DebugPrint(mode: .liveUpdates, "🎯 TASK TRIGGERED: Starting projection load")
            await loadProjectedScores()
        }
    }
    
    private func loadProjectedScores() async {
        let leagueName = matchup.fantasyMatchup?.leagueID ?? "Unknown"
        DebugPrint(mode: .liveUpdates, "🎯 PROJECTIONS: Loading for matchup \(leagueName)")
        let projections = await matchup.getProjectedScores()
        await MainActor.run {
            self.myProjected = projections.myTeam
            self.opponentProjected = projections.opponent
            self.projectionsLoaded = true
            DebugPrint(mode: .liveUpdates, "🎯 PROJECTIONS: Loaded - My: \(projections.myTeam), Opp: \(projections.opponent)")
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