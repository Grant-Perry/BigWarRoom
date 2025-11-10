//
//  MatchupCardViewBuilder.swift
//  BigWarRoom
//
//  Clean separation of matchup card view building logic
//

import SwiftUI

struct MatchupCardViewBuilder: View {
    let matchup: UnifiedMatchup
    let microMode: Bool
    let expandedCardId: String?
    let isWinning: Bool
    // 🏈 NAVIGATION FREEDOM: Remove callback - using NavigationLinks instead
    // let onShowDetail: () -> Void
    let onMicroCardTap: (String) -> Void
    
    // 🔥 NEW: Accept dualViewMode parameter to make cards compact in Single view
    var dualViewMode: Bool = true

    var body: some View {
        Group {
            if microMode {
                microCardView
            } else {
                nonMicroCardView
            }
        }
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
    
    // MARK: -> Micro Card
    
    private var microCardView: some View {
        let cardProperties = calculateMicroCardProperties()
        
        // 🔥 FIXED: Make MicroCardView work like NonMicroCardView - wrap with NavigationLink
        return NavigationLink(destination: MatchupDetailSheetsView(matchup: matchup)) {
            MicroCardView(
                leagueName: cardProperties.leagueName,
                avatarURL: cardProperties.avatarURL,
                managerName: cardProperties.managerName,
                score: cardProperties.score,
                scoreColor: cardProperties.scoreColor,
                percentage: cardProperties.percentage,
                borderColors: cardProperties.borderColors,
                borderWidth: cardProperties.borderWidth,
                borderOpacity: cardProperties.borderOpacity,
                shouldPulse: cardProperties.shouldPulse,
                shadowColor: cardProperties.shadowColor,
                shadowRadius: cardProperties.shadowRadius,
                onTap: {
                    // Not needed anymore - NavigationLink handles it
                },
                isEliminated: cardProperties.isEliminated,
                eliminationWeek: cardProperties.eliminationWeek,
                matchup: matchup,
                isWinning: isWinning
            )
        }
        .buttonStyle(CardPressButtonStyle()) // Same button style as NonMicroCardView
        .simultaneousGesture(
            // Add tap feedback like NonMicroCardView
            TapGesture().onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        )
        .frame(height: 120)
        .padding(.bottom, 4)
    }
    
    // MARK: -> Non-Micro Card
    
    private var nonMicroCardView: some View {
        // 🏈 NAVIGATION FREEDOM: Wrap with NavigationLink instead of using onTap callback
        NavigationLink(destination: MatchupDetailSheetsView(matchup: matchup)) {
            NonMicroCardView(
                matchup: matchup,
                isWinning: isWinning,
                // 🏈 NAVIGATION FREEDOM: Remove onTap parameter - NavigationLink handles navigation
                // onTap: { },
                dualViewMode: dualViewMode
            )
        }
        .buttonStyle(CardPressButtonStyle()) // 🔥 NEW: Custom button style with immediate feedback
        .simultaneousGesture(
            // 🏈 NAVIGATION FREEDOM: Add tap feedback to NavigationLink
            TapGesture().onEnded { _ in
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium) // Changed from light to medium
                impactFeedback.impactOccurred()
            }
        )
        .padding(.bottom, dualViewMode ? 0 : 12)
    }
    
    // MARK: -> Properties Calculation
    
    private func calculateMicroCardProperties() -> MicroCardProperties {
        // Prepare all data for DUMB micro card
        let myTeam = matchup.myTeam
        let leagueName = matchup.league.league.name
        let avatarURL = myTeam?.avatar
        let managerName = myTeam?.ownerName ?? "Unknown"
        let score = myTeam?.currentScoreString ?? "0.0"
        let scoreColor = isWinning ? Color.gpGreen : Color.gpRedPink
        let percentage = calculateWinPercentageString()
        let isLive = isMatchupLive()
        
        // 🔥 FIXED LOGIC: Use computed property to check if MY MANAGER is eliminated
        let isEliminated = matchup.isMyManagerEliminated
        let eliminationWeek = matchup.myEliminationWeek
        
        // Calculate border properties based on matchup type and live status
        let borderColors: [Color]
        let borderWidth: CGFloat
        let borderOpacity: Double
        let shadowColor: Color
        let shadowRadius: CGFloat
        
        if isEliminated {
            // 🔥 ELIMINATED STYLING - Dark and dramatic
            borderColors = [.red, .black, .red]
            borderWidth = 2.0
            borderOpacity = 0.8
            shadowColor = .black.opacity(0.6)
            shadowRadius = 8
        } else if matchup.isChoppedLeague {
            // 🔥 SIMPLIFIED: Chopped league uses same win/loss colors as regular matchups
            if isWinning {
                borderColors = [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
                borderWidth = 2.5
                borderOpacity = 0.9
                shadowColor = .gpGreen.opacity(0.4)
                shadowRadius = 6
            } else {
                borderColors = [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
                borderWidth = 2.5
                borderOpacity = 0.9
                shadowColor = .gpRedPink.opacity(0.4)
                shadowRadius = 6
            }
        } else if isLive {
            // 🔥 SIMPLIFIED: Live games use same win/loss colors
            if isWinning {
                borderColors = [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
                borderWidth = 2
                borderOpacity = 0.8
                shadowColor = .gpGreen.opacity(0.3)
                shadowRadius = 4
            } else {
                borderColors = [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
                borderWidth = 2.4
                borderOpacity = 0.9
                shadowColor = .gpRedPink.opacity(0.4)
                shadowRadius = 7
            }
        } else {
            // 🔥 SIMPLIFIED: Non-live games use same win/loss colors
            if isWinning {
                borderColors = [.gpGreen, .gpGreen.opacity(0.8), .gpGreen]
                borderWidth = 1.5
                borderOpacity = 0.7
                shadowColor = .gpGreen.opacity(0.2)
                shadowRadius = 2
            } else {
                borderColors = [.gpRedPink, .gpRedPink.opacity(0.8), .gpRedPink]
                borderWidth = 2.2
                borderOpacity = 0.85
                shadowColor = .gpRedPink.opacity(0.35)
                shadowRadius = 5
            }
        }
        
        return MicroCardProperties(
            leagueName: leagueName,
            avatarURL: avatarURL,
            managerName: managerName,
            score: score,
            scoreColor: scoreColor,
            percentage: percentage,
            borderColors: borderColors,
            borderWidth: borderWidth,
            borderOpacity: borderOpacity,
            shouldPulse: isLive,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            isEliminated: isEliminated, // 🔥 Use computed property
            eliminationWeek: eliminationWeek // 🔥 Use computed property
        )
    }
    
    // MARK: -> Helper Functions
    
    private func calculateWinPercentageString() -> String {
        if matchup.isChoppedLeague {
            guard let teamRanking = matchup.myTeamRanking else { return "0%" }
            return "\(Int(teamRanking.survivalProbability * 100))%"
        }
        
        guard let myScore = matchup.myTeam?.currentScore,
              let opponentScore = matchup.opponentTeam?.currentScore else { return "50%" }
        
        let totalScore = myScore + opponentScore
        if totalScore == 0 { return "50%" }
        
        let percentage = (myScore / totalScore) * 100.0
        return "\(Int(percentage))%"
    }

    private func isMatchupLive() -> Bool {
        return matchup.isLive
    }
}

// MARK: -> Supporting Structures

// 🔥 NEW: Custom button style for immediate visual feedback
private struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: configuration.isPressed ? Color.gpGreen.opacity(0.6) : Color.black.opacity(0.3),
                radius: configuration.isPressed ? 12 : 4,
                x: 0,
                y: configuration.isPressed ? 8 : 2
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct MicroCardProperties {
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
    let isEliminated: Bool // 🔥 Renamed from isChopped
    let eliminationWeek: Int? // 🔥 Renamed from choppedWeek
}