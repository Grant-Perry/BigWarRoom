//
//  SurvivalCard.swift
//  BigWarRoom
//
//  🛡️ SURVIVAL CARD COMPONENT 🛡️
//  For teams in the Safe and Warning zones
//

import SwiftUI

/// **SurvivalCard**
/// 
/// Displays teams in safe or warning zones with:
/// - Rank badge and team avatar
/// - Elimination status with color coding
/// - Survival percentage display (Sleeper-style)
/// - Current vs projected scoring indicators
/// - Status-appropriate gradient backgrounds
/// - 🔥 NEW: Tap to view team roster
struct SurvivalCard: View {
    let ranking: FantasyTeamRanking
    let leagueID: String? // 🔥 NEW: For roster navigation
    let week: Int? // 🔥 NEW: For roster navigation
    @State private var showTeamRoster = false // 🔥 NEW: Sheet state
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            VStack {
                Text(ranking.rankDisplay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("RANK")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
            }
            .frame(width: 50)
            
            // Team avatar
            teamAvatar
            
            // Team info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 8) {
                    Text(ranking.eliminationStatus.emoji)
                    Text(ranking.eliminationStatus.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ranking.eliminationStatus.color)
                }
                
                // 🎯 PROMINENT SLEEPER-STYLE SAFE % DISPLAY - FIXED NO WRAP
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("SAFE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(survivalColor)
                            .fixedSize()
                        
                        Text(ranking.survivalPercentage)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(survivalColor)
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(survivalColor.opacity(0.2))
                    )
                    
                    // Show projected score if different from current
                    if let projected = ranking.team.projectedScore, 
                       let current = ranking.team.currentScore,
                       abs(projected - current) > 1.0 {
                        Text("PROJ: \(String(format: "%.1f", projected))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.cyan)
                            .fixedSize()
                    }
                }
            }
            
            Spacer()
            
            // Points with projected display
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Show "PROJ" or "PTS" based on scoring status
                if let current = ranking.team.currentScore, current > 0 {
                    Text("PTS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                } else if let projected = ranking.team.projectedScore, projected > 0 {
                    Text("PROJ")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                }
                
                // 🔥 NEW: Tap indicator
                Text("👆 TAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray.opacity(0.7))
                    .tracking(1)
            }
			.padding(.horizontal, 18)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            statusGradientColor.opacity(0.15),
                            statusGradientColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    statusGradientColor.opacity(0.4),
                                    statusGradientColor.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        // 🔥 NEW: Make entire card tappable
        .onTapGesture {
            if let leagueID = leagueID, let week = week {
                showTeamRoster = true
            }
        }
        // 🔥 NEW: Show roster sheet
        .sheet(isPresented: $showTeamRoster) {
            if let leagueID = leagueID, let week = week {
                ChoppedTeamRosterView(
                    teamRanking: ranking,
                    leagueID: leagueID,
                    week: week
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var survivalColor: Color {
        if ranking.survivalProbability > 0.6 {
            return Color.green
        } else if ranking.survivalProbability > 0.3 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    /// Status-appropriate gradient color based on elimination status
    private var statusGradientColor: Color {
        switch ranking.eliminationStatus {
        case .safe:
            return Color.green
        case .warning:
            return Color.blue
        case .danger:
            return Color.orange
        case .critical:
            return Color.red
        case .champion:
            return Color.yellow
        case .eliminated:
            return Color.gray
        }
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor,
                        ranking.team.espnTeamColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}
