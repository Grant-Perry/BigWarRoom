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
    
    @State private var pulseOpacity: Double = 0.3
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    // 🔥 CELEBRATION: States for massive expanding glow effects
    @State private var celebrationGlowScale: Double = 1.0
    @State private var celebrationGlowOpacity: Double = 0.0
    @State private var celebrationPulse: Bool = false
    @State private var celebrationBorderPulse: Bool = false
    
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
        isWinning: Bool
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
    }
    
    var body: some View {
        Button(action: onTap) {
            // Use the extracted base content component
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
                isGamesFinished: isGamesFinishedForWeek,
                celebrationBorderPulse: celebrationBorderPulse,
                matchup: matchup,
                isWinning: isWinning
            )
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            // 🔥 CELEBRATION: Massive expanding glow as background overlay - doesn't affect layout
            Group {
                if isGamesFinishedForWeek && !isEliminated {
                    hugeCelebrationGlow
                }
            }
        )
        .onAppear {
            if shouldPulse {
                startPulseAnimation()
            }
            if isEliminated {
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
    
    /// 🔥 CELEBRATION: Win/Loss logic for both regular and chopped leagues
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
            // Regular matchup logic - use scoreColor to determine win/loss
            return scoreColor == .gpGreen
        }
    }
    
    /// Massive expanding glow behind the card - CONSTRAINED to not affect layout
    @ViewBuilder
    private var hugeCelebrationGlow: some View {
        ZStack {
            // Multiple layers of expanding glow for depth - FIXED SIZE
            ForEach(0..<3, id: \.self) { layer in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                celebrationGlowColor.opacity(0.6 - Double(layer) * 0.2),
                                celebrationGlowColor.opacity(0.3 - Double(layer) * 0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 + Double(layer) * 15
                        )
                    )
                    .frame(width: 120 + Double(layer) * 30, height: 120 + Double(layer) * 30)
                    .scaleEffect(celebrationGlowScale + Double(layer) * 0.1)
                    .opacity(celebrationGlowOpacity * (1.0 - Double(layer) * 0.3))
                    .blur(radius: 6 + Double(layer) * 3)
                    .animation(
                        .easeInOut(duration: 2.0 + Double(layer) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.2),
                        value: celebrationGlowScale
                    )
                    .animation(
                        .easeInOut(duration: 1.5 + Double(layer) * 0.2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(layer) * 0.1),
                        value: celebrationGlowOpacity
                    )
            }
            
            // Central pulsing core - SMALLER
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            celebrationGlowColor.opacity(0.8),
                            celebrationGlowColor.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
                .scaleEffect(celebrationPulse ? 1.2 : 0.8)
                .opacity(celebrationPulse ? 0.8 : 0.4)
                .blur(radius: 4)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: celebrationPulse
                )
        }
        .allowsHitTesting(false) // Don't interfere with taps
    }
    
    /// Celebration glow color based on win/loss - works for both regular and chopped
    private var celebrationGlowColor: Color {
        isCelebrationWin ? .gpGreen : .gpRedPink
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
    
    // 🔥 CELEBRATION: Start the massive expanding glow effects - CONSTRAINED
    private func startMassiveCelebrationGlow() {
        // Controlled scale expansion - not too massive
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            celebrationGlowScale = 1.3
        }
        
        // Opacity pulsing
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            celebrationGlowOpacity = 0.7
        }
        
        // Central pulse
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            celebrationPulse = true
        }
        
        // 🔥 NEW: Border pulsing
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            celebrationBorderPulse = true
        }
    }
}