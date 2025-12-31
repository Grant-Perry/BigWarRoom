//
//  NonMicroTeamSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Team section with avatar, name, score for non-micro cards
struct NonMicroTeamSection: View {
    let team: FantasyTeam
    let isMyTeam: Bool
    let isWinning: Bool
    let dualViewMode: Bool
    let scoreAnimation: Bool
    let isLiveGame: Bool
    
    // 🔥 NEW: Team roster navigation callback
    var onTeamLogoTap: ((String) -> Void)? = nil
    
    // 🔥 REMOVED: Don't need FantasyViewModel here
    
    private var isTeamWinning: Bool {
        if isMyTeam {
            return isWinning
        } else {
            return !isWinning
        }
    }
    
    // 🔥 NEW: Extract NFL team code from fantasy team roster for team logo tapping
    private var nflTeamCode: String? {
        // Get the most common NFL team from the roster
        let teamCounts = Dictionary(grouping: team.roster) { player in
            player.team?.uppercased() ?? "UNK"
        }.mapValues { $0.count }
        
        // Find the team with the most players
        return teamCounts.max(by: { $0.value < $1.value })?.key
    }
    
    var body: some View {
        VStack(spacing: dualViewMode ? 6 : 3) {
            // Use AsyncTeamAvatarView for proper ESPN logo rendering
            AsyncTeamAvatarView(
                team: team,
                size: dualViewMode ? 38 : 28
            )
            .overlay(
                Circle()
                    .stroke(
                        isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                        lineWidth: isTeamWinning ? 2 : 1
                    )
            )
            .onTapGesture {
                handleTeamTap()
            }
            
            // Team name
            Text(team.ownerName)
                .font(.system(size: dualViewMode ? 14 : 12, weight: .bold))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: dualViewMode ? 85 : 65)
            
            // Manager record (only show if available)
            if let record = team.record {
                Text(record.displayString)
                    .font(.system(size: dualViewMode ? 12 : 11, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Score
            Text(team.currentScoreString)
                .font(.system(size: dualViewMode ? 18 : 14, weight: .black, design: .rounded))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(scoreAnimation && isLiveGame ? 1.1 : 1.0)
            
            // 🔥 OLD: Record (only show in Dual view AND only if not empty - Sleeper only)
        }
        .frame(maxWidth: .infinity)
    }
    
    // 🔥 NEW: Handle team tap with intelligent NFL team detection
    private func handleTeamTap() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Determine which NFL team to show
        if let teamCode = nflTeamCode {
            onTeamLogoTap?(teamCode)
        } else {
            // For fallback, try the first starter's team
            if let firstStarterTeam = team.roster.first(where: { $0.isStarter })?.team?.uppercased() {
                onTeamLogoTap?(firstStarterTeam)
            }
        }
    }
}