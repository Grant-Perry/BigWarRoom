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
        HStack(spacing: 12) {
            // Rank badge with elimination status color
            VStack(spacing: 2) {
                Text(ranking.rankDisplay)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(ranking.eliminationStatus.color)
                
                Text("RANK")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
            }
            .frame(width: 45)
            
            // Team avatar
            teamAvatar
            
            // Team info - COMPLETELY HORIZONTAL LAYOUT
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(ranking.team.ownerName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // Status + Safe % + Proj - ALL HORIZONTAL
                HStack(spacing: 8) {
                    // Status emoji + text
                    HStack(spacing: 3) {
                        Text(ranking.eliminationStatus.emoji)
                            .font(.system(size: 12))
                        
                        Text(ranking.eliminationStatus.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ranking.eliminationStatus.color)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Safe percentage - SINGLE LINE
                    Text("SAFE \(ranking.survivalPercentage)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(survivalColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(survivalColor.opacity(0.2))
                        )
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    
                    // Projected score if available
                    if let projectedScore = ranking.team.projectedScore {
                        Text("PROJ: \(String(format: "%.1f", projectedScore))")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Weekly points - Right aligned
            VStack(alignment: .trailing, spacing: 2) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("PTS")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackgroundColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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
        .frame(width: 42, height: 42)
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