//
//  ChoppedPlayerCard.swift
//  BigWarRoom
//
//  Player card for Chopped leagues in MatchupsHub - matches ChoppedLeaderboardView design
//

import SwiftUI

/// ChoppedPlayerCard for MatchupsHub
/// Uses the same design as SurvivalCard/DangerZoneCard/CriticalCard from ChoppedLeaderboardView
struct ChoppedPlayerCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge with elimination status color
            VStack(spacing: 4) {
                Text(ranking.rankDisplay)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(ranking.eliminationStatus.color)
                
                Text("RANK")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
            }
            .frame(width: 50)
            
            // Team avatar
            teamAvatar
            
            // Team info with elimination status
            VStack(alignment: .leading, spacing: 6) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // Elimination status with emoji and dramatic message
                HStack(spacing: 6) {
                    Text(ranking.eliminationStatus.emoji)
                        .font(.system(size: 14))
                    
                    Text(ranking.eliminationStatus.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ranking.eliminationStatus.color)
                }
                
                // Survival percentage (Sleeper-style)
                HStack(spacing: 12) {
                    Text("SAFE \(ranking.survivalPercentage)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(survivalColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(survivalColor.opacity(0.2))
                        )
                    
                    // Safety margin
                    Text(ranking.pointsFromSafety >= 0 ? "+\(String(format: "%.1f", ranking.pointsFromSafety))" : String(format: "%.1f", ranking.pointsFromSafety))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ranking.pointsFromSafety >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            // Weekly points
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("PTS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ranking.eliminationStatus.color.opacity(strokeIntensity), lineWidth: strokeWidth)
                )
        )
    }
    
    // MARK: - Computed Properties
    
    private var survivalColor: Color {
        if ranking.survivalProbability > 0.6 {
            return .green
        } else if ranking.survivalProbability > 0.3 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var cardBackgroundColor: Color {
        switch ranking.eliminationStatus {
        case .champion: return .yellow
        case .safe: return .green
        case .warning: return .blue
        case .danger: return .orange
        case .critical: return .red
        case .eliminated: return .gray
        }
    }
    
    private var strokeWidth: CGFloat {
        switch ranking.eliminationStatus {
        case .critical, .eliminated: return 3
        case .danger: return 2
        default: return 1
        }
    }
    
    private var strokeIntensity: Double {
        switch ranking.eliminationStatus {
        case .critical: return 0.8
        case .danger: return 0.6
        case .champion: return 0.7
        default: return 0.3
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
                        teamInitialsAvatar
                    @unknown default:
                        teamInitialsAvatar
                    }
                }
            } else {
                teamInitialsAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(ranking.eliminationStatus.color, lineWidth: 2)
        )
    }
    
    private var teamInitialsAvatar: some View {
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