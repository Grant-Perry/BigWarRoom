//
//  PlayerScoreBarCardBackgroundView.swift
//  BigWarRoom
//
//  Team background component for PlayerScoreBarCardView
//

import SwiftUI

/// Team background with score bar overlay
struct PlayerScoreBarCardBackgroundView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    
    private let scoreBarOpacity: Double = 0.35 // Score bar transparency
    
    var body: some View {
        ZStack {
            // BASE TEAM BACKGROUND - Applied to ALL cards
            ZStack {
                // MAIN GRADIENT BACKGROUND - Team colored base for all cards
                LinearGradient(
                    gradient: Gradient(colors: [
                        playerCardGradColor.opacity(0.9), // STRONGER opacity
                        Color.black.opacity(0.7),
                        playerCardGradColor.opacity(0.8) // STRONGER opacity
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // SUBTLE OVERLAY PATTERN
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        playerCardGradColor.opacity(0.1) // Add more team color tint
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // SCORE BAR OVERLAY - Only for players with points
            if playerEntry.currentScore > 0 {
                buildScoreBarOverlay()
            }
            
            // Team-specific background overlay
            Group {
                if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(team.backgroundColor.opacity(0.05))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(0.05))
                }
            }
            
            // Only show performance indicator if player has points
            if playerEntry.currentScore > 0 {
                HStack {
                    Spacer()
                    VStack {
                        buildPerformanceIndicator()
                        Spacer()
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 6)
                }
            }
        }
    }
    
    private func buildScoreBarOverlay() -> some View {
        // Score bar with sharp trailing edge for clear value representation
        HStack(spacing: 0) {
            ZStack {
                // Main gradient background with abrupt trailing edge
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0.0),                    // Start clear
                                .init(color: originalScoreBarColor.opacity(0.3), location: 0.3), // Build up color
                                .init(color: originalScoreBarColor.opacity(0.5), location: 0.7), // Peak color
                                .init(color: originalScoreBarColor.opacity(0.6), location: 0.95), // Strong at edge
                                .init(color: originalScoreBarColor.opacity(0.6), location: 1.0)   // Sharp cutoff
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Subtle overlay (toned down brightness)
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.03),  // Much more subtle
                                Color.clear,
                                Color.white.opacity(0.01)   // Very subtle
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: calculateScoreBarWidth())
            .clipShape(RoundedRectangle(cornerRadius: 12)) // Ensure sharp edge
            
            Spacer()
        }
    }
    
    private func buildPerformanceIndicator() -> some View {
        let percentage = playerEntry.scoreBarWidth
        let color: Color = {
            if percentage >= 0.8 { return .gpGreen }
            else if percentage >= 0.5 { return .blue }
            else if percentage >= 0.25 { return .orange }
            else { return .red }
        }()
        
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(0.7)
    }
    
    // MARK: - Helper Properties
    
    private var playerCardGradColor: Color {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.primaryColor
        }
        return .nyyDark // Fallback to original color if no team found
    }
    
    /// Original score bar colors (back to .gpGreen and blue)
    private var originalScoreBarColor: Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen.opacity(scoreBarOpacity) }        // Elite - Green
        else if percentage >= 0.5 { return .blue.opacity(scoreBarOpacity) }       // Good - Blue  
        else if percentage >= 0.25 { return .orange.opacity(scoreBarOpacity) }    // Okay - Orange
        else { return .red.opacity(scoreBarOpacity) }                             // Poor - Red
    }
    
    private func calculateScoreBarWidth() -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 32 // Account for padding
        let minimumWidth = screenWidth * 0.15 // 15% minimum
        let calculatedWidth = screenWidth * scoreBarWidth
        
        // Ensure we always have at least the minimum width if player has any score
        if playerEntry.currentScore > 0 {
            return max(minimumWidth, calculatedWidth)
        } else {
            return max(minimumWidth, calculatedWidth)
        }
    }
}