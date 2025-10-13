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
        .padding(.bottom, 8)
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
        .padding(.bottom, dualViewMode ? 44 : 20)
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
            // Chopped league styling (but still alive)
            if let ranking = matchup.myTeamRanking {
                let dangerColor = ranking.eliminationStatus.color
                borderColors = [dangerColor, dangerColor.opacity(0.7), dangerColor]
                borderWidth = 2.5
                borderOpacity = 0.9
                shadowColor = dangerColor.opacity(0.4)
                shadowRadius = 6
            } else {
                borderColors = [.orange, .orange.opacity(0.7), .orange]
                borderWidth = 2.5
                borderOpacity = 0.9
                shadowColor = .orange.opacity(0.4)
                shadowRadius = 6
            }
        } else if isLive {
            // 🔥 FIXED: Check win/loss status even for live games
            if isWinning {
                // Winning LIVE game: Keep the original live green theme
                borderColors = [Color.gpGreen, Color.gpGreen.opacity(0.8), Color.cyan.opacity(0.6), Color.gpGreen.opacity(0.9), Color.gpGreen]
                borderWidth = 2
                borderOpacity = 0.8
                shadowColor = Color.gpGreen.opacity(0.3)
                shadowRadius = 4
            } else {
                // 🔥 LOSING LIVE game: Cool gradient from gpPink to gpRed with light blue accents
                borderColors = [
                    Color.gpPink, 
                    Color.gpRedPink.opacity(0.8),
                    Color.cyan.opacity(0.4), // Light blue accent
                    Color.gpRed.opacity(0.9),
                    Color.gpPink.opacity(0.7),
                    Color.gpRed
                ]
                borderWidth = 2.4
                borderOpacity = 0.9
                shadowColor = Color.gpRedPink.opacity(0.4)
                shadowRadius = 7
            }
        } else {
            // Non-live games
            if isWinning {
                // Winning: Keep the original blue theme
                borderColors = [Color.blue.opacity(0.6), Color.cyan.opacity(0.4), Color.blue.opacity(0.6)]
                borderWidth = 1.5
                borderOpacity = 0.7
                shadowColor = Color.black.opacity(0.2)
                shadowRadius = 2
            } else {
                // 🔥 LOSING: Cool gradient from gpPink to gpRed with light blue accents
                borderColors = [
                    Color.gpPink, 
                    Color.gpRedPink.opacity(0.8),
                    Color.cyan.opacity(0.3), // Light blue accent
                    Color.gpRed.opacity(0.9),
                    Color.gpPink.opacity(0.7),
                    Color.gpRed
                ]
                borderWidth = 2.2
                borderOpacity = 0.85
                shadowColor = Color.gpRedPink.opacity(0.35)
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