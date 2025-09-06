//
//  ChampionCard.swift
//  BigWarRoom
//
//  👑 CHAMPION CARD COMPONENT 👑
//  The golden throne for the reigning champion
//

import SwiftUI

/// **ChampionCard**
/// 
/// Displays the current week champion with royal treatment including:
/// - Golden crown styling and animations
/// - Team avatar with golden glow effect
/// - Survival stats and points display
/// - Gradient backgrounds and borders
struct ChampionCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        VStack(spacing: 12) {
            // Team name spanning full width at top
            HStack {
                Text("👑")
                    .font(.system(size: 20))
                
                Text(ranking.team.ownerName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Spacer()
                
                Text("👑")
                    .font(.system(size: 20))
            }
            
            // Main content row with smaller avatar and score
            HStack(spacing: 16) {
                // Crown rank
                VStack {
                    Text("1ST")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.yellow)
                        .tracking(1)
                }
                .frame(width: 40)
                
                // Smaller team avatar with golden glow
                teamAvatar
                    .overlay(
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .shadow(color: .yellow.opacity(0.6), radius: 6)
                    )
                
                // Team status info - FIXED NO WRAP
                VStack(alignment: .leading, spacing: 4) {
                    Text("REIGNING SUPREME")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(1)
                        .fixedSize()
                    
                    HStack(spacing: 4) {
                        Text("Survival: \(ranking.survivalPercentage)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.green)
                            .fixedSize()
                        
                        Text("•")
                            .foregroundColor(.gray)
                            .fixedSize()
                        
                        Text("Weeks: \(ranking.weeksAlive)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                            .fixedSize()
                    }
                }
                
                Spacer()
                
                // Points with royal treatment - prevent wrapping
                VStack(spacing: 2) {
                    Text(ranking.weeklyPointsString)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("POINTS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
                .frame(minWidth: 60)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.1),
                            Color.orange.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
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
        .frame(width: 44, height: 44)
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