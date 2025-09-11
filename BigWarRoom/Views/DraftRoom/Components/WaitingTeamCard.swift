//
//  WaitingTeamCard.swift
//  BigWarRoom
//
//  Team card for pre-game state - shows manager without rankings
//

import SwiftUI

struct WaitingTeamCard: View {
    let ranking: FantasyTeamRanking
    let leagueID: String
    let week: Int
    
    @State private var showingRoster = false
    
    var body: some View {
        Button(action: {
            showingRoster = true
        }) {
            HStack(spacing: 16) {
                // Manager avatar
                Group {
                    if let avatarURL = ranking.team.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            managerInitials
                        }
                    } else {
                        managerInitials
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )
                
                // Manager info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ranking.team.ownerName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(ranking.team.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text("⏰")
                            .font(.system(size: 12))
                        
                        Text("Waiting for games")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Score placeholder
                VStack(spacing: 2) {
                    Text("--")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.gray)
                    
                    Text("PTS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                
                // Tap indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingRoster) {
            ChoppedTeamRosterView(
                teamRanking: ranking,
                leagueID: leagueID,
                week: week
            )
        }
    }
    
    private var managerInitials: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text(String(ranking.team.ownerName.prefix(2)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}