//
//  NonMicroChoppedContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Chopped league content for non-micro cards
struct NonMicroChoppedContent: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Chopped status
            HStack {
                Text("🔥 CHOPPED")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let summary = matchup.choppedSummary {
                    Text("Week \(summary.week)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // My status with prominent delta and "yet to play"
            if let ranking = matchup.myTeamRanking {
                VStack(spacing: 6) {
                    // Top row: Rank, Score, and "to play"
                    HStack {
                        // Rank
                        VStack(spacing: 2) {
                            Text("#\(ranking.rank)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(ranking.eliminationStatus.color)
                            
                            Text(ranking.eliminationStatus.emoji)
                                .font(.system(size: 12))
                        }
                        
                        Spacer()
                        
                        // "to play" count (like regular matchup cards)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ranking.weeklyPointsString)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                            
                            // Add "to play" count
                            HStack(spacing: 4) {
                                Text("to play:")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("\(myTeamPlayersYetToPlay)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(myTeamPlayersYetToPlay > 0 ? .gpYellow : .gray)
                            }
                        }
                    }
                    
                    // Center: Prominent Delta Display
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 1) {
                            Text(ranking.safetyMarginDisplay)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 1, y: 1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(ranking.pointsFromSafety >= 0 ? Color.gpGreen : Color.gpRedPink, lineWidth: 1.5)
                                )
                        )
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ranking.eliminationStatus.color.opacity(0.1))
                )
            }
            
            // 🔥 FIXED: Add Spacer to fill remaining height so chopped cards match regular cards
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Calculate "yet to play" count for my team in chopped league
    private var myTeamPlayersYetToPlay: Int {
        guard let ranking = matchup.myTeamRanking else { return 0 }
        
        // Use the FantasyTeam's playersYetToPlay method with week context
        let currentWeek = WeekSelectionManager.shared.selectedWeek
        return ranking.team.playersYetToPlay(
            forWeek: currentWeek,
            weekSelectionManager: WeekSelectionManager.shared,
            gameStatusService: GameStatusService.shared
        )
    }
}