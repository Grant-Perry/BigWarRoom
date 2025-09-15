//
//  DangerZoneCard.swift
//  BigWarRoom
//
//  ⚠️ DANGER ZONE CARD COMPONENT ⚠️
//  For teams on the chopping block
//

import SwiftUI

/// **DangerZoneCard**
/// 
/// Displays teams in the danger zone with:
/// - Pulsing warning animations
/// - Orange warning glow effects
/// - Safety margin indicators
/// - Animated survival percentage display
/// - 🔥 NEW: Tap to view team roster
struct DangerZoneCard: View {
    let ranking: FantasyTeamRanking
    let leagueID: String? // 🔥 NEW: For roster navigation
    let week: Int? // 🔥 NEW: For roster navigation
    @State private var warningPulse = false
    @State private var showTeamRoster = false // 🔥 NEW: Sheet state
    
    var body: some View {
        HStack(spacing: 16) {
            // Warning rank with pulse
            VStack {
                Text(ranking.rankDisplay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                    .scaleEffect(warningPulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                
                Text("DANGER")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
                    .tracking(0.5)
            }
            .frame(width: 50)
            .onAppear { warningPulse = true }
            
            // Team avatar with warning glow
            teamAvatar
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(warningPulse ? 0.8 : 0.4), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                )
            
            // Team info with danger indicators
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 4) {
                    Text("⚠️")
                    Text("ON THE\nCHOPPING\nBLOCK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(0.5)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 🎯 PROMINENT SLEEPER-STYLE SAFE % DISPLAY FOR DANGER ZONE - FIXED LAYOUT
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("SAFE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .fixedSize()
                        
                        Text(ranking.survivalPercentage)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.3))
                    )
                    .scaleEffect(warningPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                    
                    Text("From Safety: \(ranking.safetyMarginDisplay)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                        .fixedSize()
                }
            }
            
            Spacer()
            
            // Points with warning styling
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.orange)
                    .fixedSize()
                    .minimumScaleFactor(0.8)
                
                // Show current vs projected status
                scoringStatusText
                
                // 🔥 NEW: Tap indicator
                Text("👆 TAP")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange.opacity(0.7))
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(warningPulse ? 0.6 : 0.1), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
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
    
    @ViewBuilder
    private var scoringStatusText: some View {
        if let current = ranking.team.currentScore, current > 0 {
            Text("CURRENT")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.orange)
                .tracking(0.5)
                .fixedSize()
        } else if let projected = ranking.team.projectedScore, projected > 0 {
            Text("PROJECTED")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.orange)
                .tracking(0.5)
                .fixedSize()
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
                        ranking.team.espnTeamColor.opacity(0.7)
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