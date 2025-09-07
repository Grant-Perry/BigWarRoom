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
    let onShowDetail: () -> Void
    let onMicroCardTap: (String) -> Void
    
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
        
        return MicroCardView(
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
            shadowRadius: cardProperties.shadowRadius
        ) {
            if matchup.isChoppedLeague {
                onShowDetail()
            } else {
                onMicroCardTap(matchup.id)
            }
        }
        .frame(height: 120)
        .padding(.bottom, 8)
    }
    
    // MARK: -> Non-Micro Card
    
    private var nonMicroCardView: some View {
        NonMicroCardView(
            matchup: matchup,
            isWinning: isWinning
        ) {
            onShowDetail()
        }
        .padding(.bottom, 44)
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
        
        // Calculate border properties based on matchup type and live status
        let borderColors: [Color]
        let borderWidth: CGFloat
        let borderOpacity: Double
        let shadowColor: Color
        let shadowRadius: CGFloat
        
        if matchup.isChoppedLeague {
            // Chopped league styling
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
            // Live game styling - more green!
            borderColors = [Color.gpGreen, Color.gpGreen.opacity(0.8), Color.cyan.opacity(0.6), Color.gpGreen.opacity(0.9), Color.gpGreen]
            borderWidth = 2
            borderOpacity = 0.8
            shadowColor = Color.gpGreen.opacity(0.3)
            shadowRadius = 4
        } else {
            // Regular game styling
            borderColors = [Color.blue.opacity(0.6), Color.cyan.opacity(0.4), Color.blue.opacity(0.6)]
            borderWidth = 1.5
            borderOpacity = 0.7
            shadowColor = Color.black.opacity(0.2)
            shadowRadius = 2
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
            shadowRadius: shadowRadius
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
        guard let myTeam = matchup.myTeam else { return false }
        let starters = myTeam.roster.filter { $0.isStarter }
        return starters.contains { player in
            isPlayerInLiveGame(player)
        }
    }
    
    private func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        guard let gameStatus = player.gameStatus else { return false }
        let timeString = gameStatus.timeString.lowercased()
        
        // ULTRA PERMISSIVE LIVE DETECTION - if there's ANY indication of activity, consider it live
        
        // 1. Direct live indicators
        let directLivePatterns = [
            "live", "1st", "2nd", "3rd", "4th", "ot", "overtime", 
            "quarter", "halftime", "half", "end 1st", "end 2nd", "end 3rd", "end 4th"
        ]
        
        for pattern in directLivePatterns {
            if timeString.contains(pattern) {
                return true
            }
        }
        
        // 2. Time patterns (any colon suggests active timing)
        if timeString.contains(":") && !timeString.contains("final") && !timeString.contains("bye") {
            return true
        }
        
        // 3. Score patterns (if there are numbers, might be live)
        let hasNumbers = timeString.rangeOfCharacter(from: .decimalDigits) != nil
        if hasNumbers && !timeString.contains("final") && !timeString.contains("bye") && timeString != "" {
            return true
        }
        
        // 4. Non-conclusive states (anything that's not explicitly finished/bye)
        let nonLiveIndicators = ["final", "bye", "postponed", "canceled"]
        let isDefinitelyNotLive = nonLiveIndicators.contains { timeString.contains($0) }
        
        if !isDefinitelyNotLive && !timeString.isEmpty {
            return true
        }
        
        return false
    }
}

// MARK: -> Supporting Structures

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
}