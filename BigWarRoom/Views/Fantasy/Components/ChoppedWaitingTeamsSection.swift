//
//  ChoppedWaitingTeamsSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// All teams waiting section (pre-game)
struct ChoppedWaitingTeamsSection: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let leagueID: String
    let week: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("⏰ ALL MANAGERS")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                Spacer()
                
                Text("\(choppedLeaderboardViewModel.choppedSummary.rankings.count) TEAMS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            Text("Waiting for games to begin...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show all teams without rankings - just in neutral waiting state
            ForEach(choppedLeaderboardViewModel.choppedSummary.rankings.sorted(by: { $0.team.ownerName < $1.team.ownerName })) { ranking in
                WaitingTeamCard(
                    ranking: ranking,
                    leagueID: leagueID,
                    week: week
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}