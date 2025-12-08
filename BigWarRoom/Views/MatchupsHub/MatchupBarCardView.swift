//
//  MatchupBarCardView.swift
//  BigWarRoom
//
//  Horizontal bar-style matchup card - Clean, scannable, Apple HIG compliant
//

import SwiftUI

struct MatchupBarCardView: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let isLineupOptimized: Bool
    
    @State private var cardScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0.0
    @State private var myProjected: Double = 0.0
    @State private var opponentProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    var body: some View {
        MatchupBarCardContentView(
            matchup: matchup,
            isWinning: isWinning,
            isLineupOptimized: isLineupOptimized,
            myProjected: myProjected,
            opponentProjected: opponentProjected,
            projectionsLoaded: projectionsLoaded
        )
        .frame(height: 110)
        .scaleEffect(cardScale)
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
        }
        .task {
            await loadProjectedScores()
        }
        .contentShape(Rectangle())
    }
    
    private func loadProjectedScores() async {
        let projections = try? await matchup.getProjectedScores()
        await MainActor.run {
            self.myProjected = projections?.myTeam ?? 0.0
            self.opponentProjected = projections?.opponent ?? 0.0
            self.projectionsLoaded = true
            DebugPrint(mode: .liveUpdates, "🎯 BAR CARD: Loaded projections - My: \(projections?.myTeam ?? 0.0), Opp: \(projections?.opponent ?? 0.0)")
        }
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
}