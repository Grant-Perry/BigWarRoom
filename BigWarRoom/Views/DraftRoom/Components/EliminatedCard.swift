//
//  EliminatedCard.swift
//  BigWarRoom
//
//  🪦 ELIMINATED CARD COMPONENT 🪦
//  Hall of the Dead - In Memory of the Fallen
//

import SwiftUI

/// **EliminatedCard**
/// 
/// Memorial display for eliminated teams with:
/// - Grayscale avatar treatment for the deceased
/// - Week elimination marker
/// - Strikethrough team names
/// - Memorial styling and opacity effects
struct EliminatedCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Death marker
            VStack {
                Text("🪦")
                    .font(.system(size: 20))
                
                Text("WEEK \(ranking.weeksAlive)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(width: 50)
            
            // Faded team avatar
            teamAvatar
            
            // Memorial info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .strikethrough()
                
                Text("💀 ELIMINATED - WEEK \(ranking.weeksAlive)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("\"Fought valiantly but couldn't survive\"")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .italic()
            }
            
            Spacer()
            
            // Final score
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("FINAL")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
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
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .grayscale(1.0) // Completely grayscale for the dead
        .opacity(0.6)
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.4),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.gray.opacity(0.6))
            )
    }
}