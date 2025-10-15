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
    
    // Default initializer for backward compatibility
    init(winProb: Double, scoreDelta: Double? = nil, isWinning: Bool = false, matchup: UnifiedMatchup? = nil) {
        self.winProb = winProb
        self.scoreDelta = scoreDelta
        self.isWinning = isWinning
        self.matchup = matchup
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // To play counts for each team
            if let matchup = matchup,
               let homeTeam = matchup.fantasyMatchup?.homeTeam,
               let awayTeam = matchup.fantasyMatchup?.awayTeam {
                
                let currentWeek = WeekSelectionManager.shared.selectedWeek
                let homeToPlay = homeTeam.playersYetToPlay(forWeek: currentWeek)
                let awayToPlay = awayTeam.playersYetToPlay(forWeek: currentWeek)
                
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
                
                Text("\(myPercentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                // Score delta in center - match percentage font exactly
                if let delta = scoreDelta {
                    Text(formatScoreDelta(delta))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                Text("\(opponentPercentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
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