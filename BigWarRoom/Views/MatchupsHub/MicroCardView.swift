//
//  MicroCardView.swift
//  BigWarRoom
//
//  DUMB micro card - just displays passed data, no lookups or calculations
//

import SwiftUI

struct MicroCardView: View {
    // DUMB parameters - all data passed in
    let leagueName: String
    let avatarURL: String?
    let managerName: String
    let score: String
    let scoreColor: Color
    let percentage: String
    let borderColors: [Color]
    let borderWidth: CGFloat
    let borderOpacity: Double
    let shouldPulse: Bool
    let shadowColor: Color
    let shadowRadius: CGFloat
    let onTap: () -> Void
    
    // 🔥 NEW: Eliminated status parameters (renamed from chopped)
    let isEliminated: Bool
    let eliminationWeek: Int?
    
    // 🔥 CELEBRATION: New parameters for chopped-aware celebration logic
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    // 💊 RX: Optimization status
    let isLineupOptimized: Bool
    let rxStatus: LineupRXStatus  // 💊 RX: 3-state status
    
    @State private var pulseOpacity: Double = 0.3
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    // 💊 RX Sheet state
    @State private var showingLineupRX = false
    
    // Initializer with all parameters including new eliminated ones
    init(
        leagueName: String,
        avatarURL: String?,
        managerName: String,
        score: String,
        scoreColor: Color,
        percentage: String,
        borderColors: [Color],
        borderWidth: CGFloat,
        borderOpacity: Double,
        shouldPulse: Bool,
        shadowColor: Color,
        shadowRadius: CGFloat,
        onTap: @escaping () -> Void,
        isEliminated: Bool = false,
        eliminationWeek: Int? = nil,
        matchup: UnifiedMatchup,
        isWinning: Bool,
        isLineupOptimized: Bool = false,
        rxStatus: LineupRXStatus = .critical
    ) {
        self.leagueName = leagueName
        self.avatarURL = avatarURL
        self.managerName = managerName
        self.score = score
        self.scoreColor = scoreColor
        self.percentage = percentage
        self.borderColors = borderColors
        self.borderWidth = borderWidth
        self.borderOpacity = borderOpacity
        self.shouldPulse = shouldPulse
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.onTap = onTap
        self.isEliminated = isEliminated
        self.eliminationWeek = eliminationWeek
        self.matchup = matchup
        self.isWinning = isWinning
        self.isLineupOptimized = isLineupOptimized
        self.rxStatus = rxStatus
    }
    
    var body: some View {
        // 🔥 SIMPLIFIED: Just show the card content, no celebration effects
        MicroCardBaseContentView(
            leagueName: leagueName,
            avatarURL: avatarURL,
            managerName: managerName,
            score: score,
            scoreColor: scoreColor,
            percentage: percentage,
            isEliminated: isEliminated,
            eliminationWeek: eliminationWeek,
            eliminatedPulse: eliminatedPulse,
            borderColors: borderColors,
            borderWidth: borderWidth,
            borderOpacity: borderOpacity,
            shouldPulse: shouldPulse,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            pulseOpacity: pulseOpacity,
            isGamesFinished: false, // 🔥 SIMPLIFIED: Always false, no celebration logic
            celebrationBorderPulse: false, // 🔥 SIMPLIFIED: Always false
            matchup: matchup,
            isWinning: isWinning,
            onRXTap: isEliminated ? nil : { showingLineupRX = true },
            isLineupOptimized: isLineupOptimized,
            rxStatus: rxStatus
        )
        .frame(width: 85, height: 160)
        .fixedSize()
        .onAppear {
            if shouldPulse {
                startPulseAnimation()
            }
            if isEliminated {
                startEliminatedAnimation()
            }
        }
        .sheet(isPresented: $showingLineupRX) {
            LineupRXView(matchup: matchup)
        }
    }
    
    // MARK: - Animations (kept in main view for state management)
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.8
            glowIntensity = 0.8
        }
    }
    
    private func startEliminatedAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            eliminatedPulse = true
        }
    }
}