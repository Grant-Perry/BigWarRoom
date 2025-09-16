//
//  ChoppedChampionSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Champion section with crown and leader display
struct ChoppedChampionSection: View {
    let champion: FantasyTeamRanking
    let weekDisplay: String
    let leagueID: String
    let week: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Crown header with dynamic week
            HStack {
                Text("👑")
                    .font(.system(size: 24))
                
                Text("\(weekDisplay) LEADER")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(2)
                
                Text("👑")
                    .font(.system(size: 24))
            }
            
            // Champion card with tap functionality
            ChampionCard(
                ranking: champion,
                leagueID: leagueID,
                week: week
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4) // Reduced top padding to tighten gap
        .padding(.bottom, 20)
    }
}