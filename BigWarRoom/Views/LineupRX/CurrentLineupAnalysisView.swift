//
//  CurrentLineupAnalysisView.swift
//  BigWarRoom
//
//  Displays current lineup analysis with optimization status
//

import SwiftUI

struct CurrentLineupAnalysisView: View {
    let result: LineupOptimizerService.OptimizationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status
            HStack {
                SectionHeader(icon: "chart.bar.fill", title: "Current Lineup Analysis", color: .gpBlue)
                
                Spacer()
                
                // 🔥 CRITICAL: Check for bye week players FIRST
                if hasActiveByeWeekPlayers {
                    statusBadge(
                        icon: "exclamationmark.triangle.fill",
                        text: "BYE WEEK EMERGENCY!",
                        color: .gpRedPink,
                        isOptimized: false
                    )
                } else if result.improvement >= 0.5 {
                    statusBadge(
                        icon: "wrench.and.screwdriver.fill",
                        text: "Needs Optimization",
                        color: .gpYellow,
                        isOptimized: false
                    )
                } else {
                    statusBadge(
                        icon: "checkmark.seal.fill",
                        text: "Lineup Optimized!",
                        color: .gpGreen,
                        isOptimized: true
                    )
                }
            }
            
            // Status message with emoji
            if hasActiveByeWeekPlayers {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.gpRedPink)
                        .font(.system(size: 20))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⚠️ EMERGENCY: Active Bye Week Player(s)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gpRedPink)
                        
                        Text("You have rostered players on BYE in your active lineup! They will score 0.0 points.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gpRedPink.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gpRedPink, lineWidth: 2)
                        )
                )
            } else if result.improvement >= 0.5 {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.gpYellow)
                    
                    Text("We found lineup optimizations for you")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.gpGreen)
                    
                    Text("Your lineup is at maximum projected points")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // Score breakdown
            HStack(spacing: 20) {
                ScoreCard(
                    title: "Current Score",
                    value: result.currentPoints,
                    color: .white
                )
                
                ScoreCard(
                    title: "Optimal Score",
                    value: result.projectedPoints,
                    color: .gpGreen
                )
                
                if result.improvement != 0 {
                    ScoreCard(
                        title: "Improvement",
                        value: result.improvement,
                        color: result.improvement > 0 ? .gpGreen : .gpRedPink,
                        showPlus: true
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // 🔥 FIXED: Check if any CURRENT starters have bye week (0.0 projection)
    private var hasActiveByeWeekPlayers: Bool {
        // Get current starters from the roster
        let currentStarters = result.currentRoster.filter { $0.isStarter }
        
        // Check if any starter has 0.0 projection (bye week)
        for starter in currentStarters {
            if let sleeperID = starter.sleeperID,
               let projection = result.playerProjections[sleeperID],
               projection == 0.0 {
                return true
            }
        }
        
        return false
    }
    
    private func statusBadge(icon: String, text: String, color: Color, isOptimized: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            
            Text(text)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(isOptimized ? color : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(isOptimized ? 0.2 : 0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 1.5)
                )
        )
    }
}

struct ScoreCard: View {
    let title: String
    let value: Double
    let color: Color
    var showPlus: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Text(showPlus && value > 0 ? "+\(value.formatted(.number.precision(.fractionLength(1))))" : value.formatted(.number.precision(.fractionLength(1))))
                .font(.system(size: 22, weight: .black))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
        )
    }
}
