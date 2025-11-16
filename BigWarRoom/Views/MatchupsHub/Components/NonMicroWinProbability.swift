//
//  NonMicroWinProbability.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Win probability display for non-micro cards
struct NonMicroWinProbability: View {
    let winProb: Double
    let scoreDelta: Double?
    let isWinning: Bool
    let matchup: UnifiedMatchup?
    let onRXTap: (() -> Void)?  // 💊 RX button callback
    let isLineupOptimized: Bool  // 💊 RX: Optimization status
    
    // Default initializer for backward compatibility
    init(winProb: Double, scoreDelta: Double? = nil, isWinning: Bool = false, matchup: UnifiedMatchup? = nil, onRXTap: (() -> Void)? = nil, isLineupOptimized: Bool = false) {
        self.winProb = winProb
        self.scoreDelta = scoreDelta
        self.isWinning = isWinning
        self.matchup = matchup
        self.onRXTap = onRXTap
        self.isLineupOptimized = isLineupOptimized
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // To play counts for each team
            if let matchup = matchup,
               let homeTeam = matchup.fantasyMatchup?.homeTeam,
               let awayTeam = matchup.fantasyMatchup?.awayTeam {
                
                let currentWeek = WeekSelectionManager.shared.selectedWeek
                let homeToPlay = homeTeam.playersYetToPlay(
                    forWeek: currentWeek,
                    weekSelectionManager: WeekSelectionManager.shared,
                    gameStatusService: GameStatusService.shared
                )
                let awayToPlay = awayTeam.playersYetToPlay(
                    forWeek: currentWeek,
                    weekSelectionManager: WeekSelectionManager.shared,
                    gameStatusService: GameStatusService.shared
                )
                
                HStack {
                    Text("to play: \(homeToPlay)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("to play: \(awayToPlay)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Probability text with score delta
            HStack {
                // Calculate percentages using same logic as MatchupCardViewBuilder for consistency
                let (myPercentage, opponentPercentage) = calculateScorePercentages()
                
                // GP: Considering turning win percentage text back on
//                Text("\(myPercentage)% win")
//                    .font(.system(size: 12, weight: .bold))
//                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                // 💊 RX Button and Score delta in center
                VStack(spacing: 4) {
                    // RX Button above delta
                    if let onRXTap = onRXTap {
                        Button(action: onRXTap) {
                            HStack(spacing: 4) {
                                Image("LineupRX")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .foregroundColor(.white)
                                Text("Rx")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(rxButtonColor.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(rxButtonColor, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Score delta below RX button
                    if let delta = scoreDelta {
                        Text(formatScoreDelta(delta))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                            .frame(width: 70, height: 28)  // Fixed size for consistency
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isWinning ? Color.gpGreen : Color.gpRedPink, lineWidth: 1.5)
                                    )
                            )
                    }
                }
                
                Spacer()
                
                // GP: Considering turning win percentage text back on
//                Text("\(opponentPercentage)% win")
//                    .font(.system(size: 12, weight: .bold))
//                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Probability bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gpGreen)
                        .frame(width: geometry.size.width * winProb, height: 4)
                        .animation(.easeInOut(duration: 1.0), value: winProb)
                }
            }
            .frame(height: 4)
        }
    }
    
    // MARK: - Helper Functions
    
    // 💊 RX: Dynamic button color based on optimization status
    private var rxButtonColor: Color {
        return isLineupOptimized ? .gpGreen : .gpRedPink
    }
    
    /// Calculate score percentages using reliable score-based method (same as MatchupCardViewBuilder)
    private func calculateScorePercentages() -> (Int, Int) {
        // For chopped leagues, use survival probability if available
        if let matchup = matchup, matchup.isChoppedLeague {
            if let teamRanking = matchup.myTeamRanking {
                let myPercentage = Int(teamRanking.survivalProbability * 100)
                return (myPercentage, 100 - myPercentage)
            }
        }
        
        // For regular matchups, use score-based percentage calculation
        if let matchup = matchup,
           let myScore = matchup.myTeam?.currentScore,
           let opponentScore = matchup.opponentTeam?.currentScore {
            
            let totalScore = myScore + opponentScore
            if totalScore == 0 { 
                return (50, 50) 
            }
            
            let myPercentage = Int((myScore / totalScore) * 100.0)
            let opponentPercentage = 100 - myPercentage
            
            return (myPercentage, opponentPercentage)
        }
        
        // Fallback
        return (50, 50)
    }
    
    /// Format score delta with proper sign and formatting
    private func formatScoreDelta(_ delta: Double) -> String {
        if delta > 0 {
            return "+\(String(format: "%.1f", delta))"
        } else {
            return String(format: "%.1f", delta)
        }
    }
}