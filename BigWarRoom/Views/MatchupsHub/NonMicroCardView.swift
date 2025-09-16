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
    let onTap: () -> Void
    
    // Accept dualViewMode parameter to make cards more compact in Single view
    var dualViewMode: Bool = true
    
    @State private var cardScale: CGFloat = 1.0
    @State private var scoreAnimation: Bool = false
    @State private var glowIntensity: Double = 0.0
    @State private var eliminatedPulse: Bool = false
    
    var body: some View {
        Button(action: {
            handleTap()
        }) {
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
                    overlayBorderColors: overlayBorderColors,
                    overlayBorderWidth: overlayBorderWidth,
                    overlayBorderOpacity: overlayBorderOpacity,
                    shadowColor: shadowColor,
                    shadowRadius: shadowRadius,
                    backgroundColors: backgroundColors
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(cardScale)
        .onAppear {
            if matchup.isLive {
                startLiveAnimations()
            }
            
            if matchup.isMyManagerEliminated {
                startEliminatedAnimation()
            }
        }
    }
    
    // MARK: - Computed Properties for Styling
    
    private var overlayBorderColors: [Color] {
        if matchup.isChoppedLeague {
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                return [dangerColor, dangerColor.opacity(0.7), dangerColor]
            }
            return [.orange, .orange.opacity(0.7), .orange]
        } else if matchup.isLive {
            return [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen]
        } else {
            return [.blue.opacity(0.6), .cyan.opacity(0.4), .blue.opacity(0.6)]
        }
    }
    
    private var overlayBorderWidth: CGFloat {
        if matchup.isChoppedLeague {
            return 2.5
        } else if matchup.isLive {
            return 2
        } else {
            return 1.5
        }
    }
    
    private var overlayBorderOpacity: Double {
        if matchup.isChoppedLeague {
            return 0.9
        } else if matchup.isLive {
            return max(0.6, glowIntensity * 0.8 + 0.2)
        } else {
            return 0.7
        }
    }
    
    private var shadowColor: Color {
        if matchup.isChoppedLeague {
            if let ranking = matchup.myTeamRanking {
                return ranking.eliminationStatus.color.opacity(0.4)
            }
            return .orange.opacity(0.4)
        } else if matchup.isLive {
            return .gpGreen.opacity(glowIntensity * 0.3)
        } else {
            return .black.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        if matchup.isChoppedLeague {
            return 8
        } else if matchup.isLive {
            return 6
        } else {
            return 3
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

    // MARK: - Animation & Interaction
    
    private func handleTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            cardScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                cardScale = 1.0
            }
            onTap()
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