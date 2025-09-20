//
//  CriticalCard.swift
//  BigWarRoom
//
//  💀 CRITICAL CARD COMPONENT 💀
//  Death Row - Elimination Imminent
//

import SwiftUI

/// **CriticalCard**
/// 
/// The most dramatic card for teams facing elimination with:
/// - Intense death pulse animations
/// - Red aura and shadow effects
/// - Heartbeat-style scaling animations
/// - Ultra-dramatic survival percentage display
/// - Grayscale avatar treatment for impending doom
/// - 🔥 NEW: Tap to view team roster
struct CriticalCard: View {
    let ranking: FantasyTeamRanking
    let leagueID: String? // 🔥 NEW: For roster navigation
    let week: Int? // 🔥 NEW: For roster navigation
    @State private var deathPulse = false
    @State private var heartbeat = false
    @State private var showTeamRoster = false // 🔥 NEW: Sheet state
    
    var body: some View {
        HStack(spacing: 16) {
            // Death row rank with intense pulse
            VStack {
                Text("💀")
                    .font(.system(size: 24))
                    .scaleEffect(deathPulse ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
                
                Text("LAST")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.red)
                    .tracking(1)
            }
            .frame(width: 50)
            .onAppear { 
                deathPulse = true
                heartbeat = true
            }
            
            // Team avatar with death aura
            teamAvatar
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(deathPulse ? 1.0 : 0.3), lineWidth: 3)
                        .shadow(color: .red, radius: deathPulse ? 8 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
                )
            
            // Team info with critical warnings
            VStack(alignment: .leading, spacing: 6) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 4) {
                    Text("💀")
                        .scaleEffect(heartbeat ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ELIMI")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                            .tracking(1)
                            .fixedSize()
                        
                        Text("NATION")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                            .tracking(1)
                            .fixedSize()
                        
                        Text("IMMIN")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                            .tracking(1)
                            .fixedSize()
                        
                        Text("ENT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.red)
                            .tracking(1)
                            .fixedSize()
                    }
                }
                
                // 🎯 ULTRA-DRAMATIC SAFE % DISPLAY FOR DEATH ROW - FIXED NO WRAP
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text("SAFE")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.red)
                                .fixedSize()
                            
                            Text(ranking.survivalPercentage)
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.red)
                                .fixedSize()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                        )
                        .scaleEffect(heartbeat ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                        
                        Text("💔")
                            .scaleEffect(heartbeat ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: heartbeat)
                    }
                    
                    Text("From Elimination: \(ranking.safetyMarginDisplay)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
//            Spacer()
            
            // Critical points display
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.red)
                    .scaleEffect(heartbeat ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                
                // Dramatic scoring status
                dramaticScoringStatus
                
                // 🔥 NEW: Tap indicator
                Text("👆 TAP FOR ROSTER")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.red.opacity(0.7))
                    .tracking(1)
            }
        }
        .padding(.vertical, 16)
		.padding(.horizontal, 18)
		.background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(deathPulse ? 1.0 : 0.5), lineWidth: 3)
                        .shadow(color: .red.opacity(0.5), radius: deathPulse ? 10 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
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
    private var dramaticScoringStatus: some View {
        if let current = ranking.team.currentScore, current > 0 {
            Text("FINAL SCORE")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.red)
                .tracking(1)
        } else if let projected = ranking.team.projectedScore, projected > 0 {
            Text("PROJECTED")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.red)
                .tracking(1)
        } else {
            Text("CRITICAL")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.red)
                .tracking(1)
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
        .grayscale(0.3) // Slightly faded for impending doom
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor.opacity(0.7),
                        ranking.team.espnTeamColor.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
}
