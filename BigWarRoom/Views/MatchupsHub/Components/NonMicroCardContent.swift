//
//  NonMicroCardContent.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Main card content for non-micro cards
struct NonMicroCardContent: View {
    let matchup: UnifiedMatchup
    let isWinning: Bool
    let dualViewMode: Bool
    let scoreAnimation: Bool
    
    // 🔥 CELEBRATION: New parameters for celebration border
    let isGamesFinished: Bool
    let celebrationBorderPulse: Bool
    
    var body: some View {
        VStack(spacing: dualViewMode ? 8 : 4) {
            // Compact header with league and status
            NonMicroCardHeader(matchup: matchup, dualViewMode: dualViewMode)
            
            // Main content
            if matchup.isChoppedLeague {
                NonMicroChoppedContent(matchup: matchup, isWinning: isWinning)
            } else {
                NonMicroMatchupContent(
                    matchup: matchup,
                    isWinning: isWinning,
                    dualViewMode: dualViewMode,
                    scoreAnimation: scoreAnimation
                )
            }
            
            // 🔥 FIXED: Add Spacer to ensure content fills the fixed height
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dualViewMode ? 14 : 8)
        .background(NonMicroCardBackground(matchup: matchup, backgroundColors: backgroundColors))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            // 🔥 CELEBRATION: Use celebration border if games finished, otherwise regular border
            Group {
                if isGamesFinished && !matchup.isMyManagerEliminated {
                    celebrationBorderOverlay
                } else {
                    regularBorderOverlay
                }
            }
        )
    }
    
    // MARK: - Game Start Detection
    
    /// Check if games haven't started yet (both scores are 0 and it's 50-50)
    private var gamesHaventStarted: Bool {
        guard let myScore = matchup.myTeam?.currentScore,
              let opponentScore = matchup.opponentTeam?.currentScore else {
            return true // If we can't get scores, assume games haven't started
        }
        
        // Games haven't started if both scores are 0.0 and it's essentially 50-50
        let bothScoresZero = myScore == 0.0 && opponentScore == 0.0
        let is50Percent = abs((myScore + opponentScore)) < 0.1 // Within 0.1 of zero total
        
        return bothScoresZero || is50Percent
    }
    
    // MARK: - 🔥 CELEBRATION: Border Overlays
    
    /// Celebration border overlay for the entire card
    private var celebrationBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: celebrationBorderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: celebrationBorderPulse ? 4 : 3
            )
            .opacity(celebrationBorderPulse ? 0.9 : 0.7)
            .shadow(
                color: celebrationBorderShadowColor,
                radius: celebrationBorderPulse ? 6 : 4,
                x: 0,
                y: 0
            )
            .animation(
                .easeInOut(duration: 1.3).repeatForever(autoreverses: true),
                value: celebrationBorderPulse
            )
    }
    
    /// Regular border overlay
    private var regularBorderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: overlayBorderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: overlayBorderWidth
            )
            .opacity(overlayBorderOpacity)
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
    
    /// Celebration border colors based on win/loss - works for both regular and chopped
    private var celebrationBorderColors: [Color] {
        if isCelebrationWin {
            // Winning/Survived: .gpGreen + teal with more variety
            return [
                .gpGreen,
                .teal,
                .cyan,
                .gpGreen.opacity(0.9),
                .teal.opacity(0.8),
                .gpGreen
            ]
        } else {
            // Losing/Chopped: .gpRedPink + yellow with more drama
            return [
                .gpRedPink,
                .yellow,
                .orange,
                .gpRedPink.opacity(0.9),
                .yellow.opacity(0.8),
                .gpRedPink
            ]
        }
    }
    
    /// Border shadow color for extra drama
    private var celebrationBorderShadowColor: Color {
        if isCelebrationWin {
            return .teal.opacity(0.6)
        } else {
            return .yellow.opacity(0.6)
        }
    }
    
    // MARK: - Computed Styling Properties
    
    private var overlayBorderColors: [Color] {
        if matchup.isChoppedLeague {
            // 🔥 SIMPLIFIED: Chopped league uses same win/loss colors as regular matchups
            if isWinning {
                return [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
            } else {
                return [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
            }
        } else if matchup.isLive {
            // 🔥 SIMPLIFIED: Live games use same win/loss colors
            if isWinning {
                return [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
            } else {
                return [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
            }
        } else {
            // 🔥 SIMPLIFIED: Non-live games use same win/loss colors
            if isWinning {
                return [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
            } else {
                return [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
            }
        }
    }
    
    private var overlayBorderWidth: CGFloat {
        if matchup.isChoppedLeague {
            return 2.5
        } else if matchup.isLive {
            return isWinning ? 2.0 : 2.4
        } else {
            return isWinning ? 1.5 : 2.2
        }
    }
    
    private var overlayBorderOpacity: Double {
        if matchup.isChoppedLeague {
            return 0.9
        } else if matchup.isLive {
            return isWinning ? 0.8 : 0.9
        } else {
            return isWinning ? 0.7 : 0.85
        }
    }
    
    private var shadowColor: Color {
        if matchup.isChoppedLeague {
            // 🔥 SIMPLIFIED: Chopped league uses same win/loss shadow colors
            return isWinning ? .gpGreen.opacity(0.4) : .gpRedPink.opacity(0.4)
        } else if matchup.isLive {
            return isWinning ? .gpGreen.opacity(0.3) : .gpRedPink.opacity(0.4)
        } else {
            return isWinning ? .gpGreen.opacity(0.3) : .gpRedPink.opacity(0.3)
        }
    }
    
    private var shadowRadius: CGFloat {
        if matchup.isChoppedLeague {
            return 8
        } else if matchup.isLive {
            return isWinning ? 6 : 7
        } else {
            return isWinning ? 3 : 5
        }
    }
    
    private var backgroundColors: [Color] {
        if matchup.isChoppedLeague {
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [
                    Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9), // Dark navy
                    dangerColor.opacity(0.03),
                    Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9) // Dark navy
                ]
            }
            return [
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9), // Dark navy
                Color.orange.opacity(0.03),
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9) // Dark navy
            ]
        } else if matchup.isLive {
            return [
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9), // Dark navy
                Color.gpGreen.opacity(0.05),
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.9) // Dark navy
            ]
        } else {
            return [
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.8), // Dark navy (regular cards)
                Color.gray.opacity(0.05),
                Color(red: 0.1, green: 0.15, blue: 0.3).opacity(0.8) // Dark navy (regular cards)
            ]
        }
    }
}