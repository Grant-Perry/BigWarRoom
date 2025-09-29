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
    
    // 🔥 FIXED: Get fantasy view model reference without state observation to prevent re-render loops
    private var fantasyViewModel: FantasyViewModel {
        FantasyViewModel.shared
    }
    
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
            // Avatar with optional team logo tap
            Group {
                if let avatarURL = team.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show team initials immediately while avatar loads
                        NonMicroTeamInitials(team: team, isWinning: isTeamWinning)
                    }
                    .frame(width: dualViewMode ? 45 : 32, height: dualViewMode ? 45 : 32)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                lineWidth: isTeamWinning ? 2 : 1
                            )
                    )
                    .onTapGesture {
                        // 🔥 NEW: Handle avatar tap for team roster
                        handleTeamTap()
                    }
                } else {
                    NonMicroTeamInitials(team: team, isWinning: isTeamWinning)
                        .frame(width: dualViewMode ? 45 : 32, height: dualViewMode ? 45 : 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    isTeamWinning ? Color.gpGreen : Color.gpRedPink.opacity(0.6),
                                    lineWidth: isTeamWinning ? 2 : 1
                                )
                        )
                        .onTapGesture {
                            // 🔥 NEW: Handle initials tap for team roster
                            handleTeamTap()
                        }
                }
            }
            
            // Team name
            Text(team.ownerName)
                .font(.system(size: dualViewMode ? 13 : 11, weight: .bold))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .lineLimit(1)
                .frame(maxWidth: dualViewMode ? 60 : 50)
            
            // Score
            Text(team.currentScoreString)
                .font(.system(size: dualViewMode ? 16 : 13, weight: .black, design: .rounded))
                .foregroundColor(isTeamWinning ? .gpGreen : .gpRedPink)
                .scaleEffect(scoreAnimation && isLiveGame ? 1.1 : 1.0)
            
            // 🔥 NEW: Record (only show in Dual view AND only if not empty - Sleeper only)
            if dualViewMode {
                let teamRecord = fantasyViewModel.getManagerRecord(managerID: team.id)
                if !teamRecord.isEmpty {
                    Text(teamRecord)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
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
            print("🏈 TEAM TAP: Opening roster for NFL team \(teamCode) (detected from \(team.ownerName)'s roster)")
            onTeamLogoTap?(teamCode)
        } else {
            print("🏈 TEAM TAP: Could not determine NFL team for \(team.ownerName)")
            // For fallback, try the first starter's team
            if let firstStarterTeam = team.roster.first(where: { $0.isStarter })?.team?.uppercased() {
                print("🏈 TEAM TAP: Fallback to first starter's team: \(firstStarterTeam)")
                onTeamLogoTap?(firstStarterTeam)
            }
        }
    }
}