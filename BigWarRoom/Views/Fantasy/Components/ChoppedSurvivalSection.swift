//
//  ChoppedSurvivalSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Generic survival section for safe/warning zones
struct ChoppedSurvivalSection: View {
    let title: String
    let subtitle: String
    let teams: [FantasyTeamRanking]
    let sectionColor: Color
    let leagueID: String
    let week: Int
    let zoneOpacity: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(sectionColor)
                    .tracking(1)
                
                Spacer()
                
                Text("\(teams.count) TEAMS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Teams with tap functionality
            ForEach(teams) { ranking in
                SurvivalCard(
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
                .fill(sectionColor.opacity(zoneOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sectionColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}