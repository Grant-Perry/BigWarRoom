//
//  ChoppedTeamHeaderCard.swift
//  BigWarRoom
//
//  🏈 CHOPPED TEAM HEADER CARD 🏈
//  Team information header display
//

import SwiftUI

/// **ChoppedTeamHeaderCard**
/// 
/// Displays team header with avatar, info, score, and roster stats
struct ChoppedTeamHeaderCard: View {
    let teamRanking: FantasyTeamRanking
    let week: Int
    let roster: ChoppedTeamRoster
    
    var body: some View {
        VStack(spacing: 16) {
            // Team avatar and info
            HStack(spacing: 16) {
                // Team avatar
                Group {
                    if let avatarURL = teamRanking.team.avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Circle()
                                    .fill(teamRanking.team.espnTeamColor)
                                    .overlay(
                                        Text(teamRanking.team.teamInitials)
                                            .font(.system(size: 32, weight: .black))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    } else {
                        Circle()
                            .fill(teamRanking.team.espnTeamColor)
                            .overlay(
                                Text(teamRanking.team.teamInitials)
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(teamRanking.team.ownerName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Week \(week) Roster")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text(teamRanking.rankDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(teamRanking.eliminationStatus.color)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(teamRanking.eliminationStatus.displayName)
                            .font(.subheadline)
                            .foregroundColor(teamRanking.eliminationStatus.color)
                    }
                }
                
                Spacer()
                
                // Score display
                VStack(alignment: .trailing, spacing: 4) {
                    Text(teamRanking.weeklyPointsString)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("POINTS")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            }
            
            // Roster stats
            HStack(spacing: 20) {
                ChoppedRosterStatCard(
                    title: "STARTERS",
                    value: "\(roster.starters.count)",
                    color: .green
                )
                
                ChoppedRosterStatCard(
                    title: "BENCH", 
                    value: "\(roster.bench.count)",
                    color: .blue
                )
                
                ChoppedRosterStatCard(
                    title: "TOTAL",
                    value: "\(roster.starters.count + roster.bench.count)",
                    color: .white
                )
            }
        }
        .padding(.horizontal, 20) // 🔥 IMPROVED: Better horizontal padding
        .padding(.vertical, 16)   // 🔥 IMPROVED: Better vertical padding
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(teamRanking.eliminationStatus.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

#Preview {
    // Cannot preview without proper models setup
    Text("ChoppedTeamHeaderCard Preview")
        .foregroundColor(.white)
        .background(Color.black)
}