//
//  ChoppedDangerZoneSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Danger zone section with pulsing effects
struct ChoppedDangerZoneSection: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let dangerPulse: Bool
    let leagueID: String
    let week: Int
    let zoneOpacity: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Danger header with pulsing effect
            HStack {
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: dangerPulse)
                
                Text("DANGER ZONE")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.orange)
                    .tracking(2)
                
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(0.5), value: dangerPulse)
                
                Spacer()
                
                Text("\(choppedLeaderboardViewModel.dangerZoneCount) IN DANGER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            Text("🚨 ONE STEP AWAY FROM THE CHOPPING BLOCK 🚨")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Death zone teams with tap functionality
            ForEach(choppedLeaderboardViewModel.choppedSummary.dangerZoneTeams) { ranking in
                DangerZoneCard(
                    ranking: ranking,
                    leagueID: leagueID,
                    week: week
                )
            }
        }
        .padding(.horizontal, 16) // FIXED: Normal padding like other sections
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(zoneOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(dangerPulse ? 0.6 : 0.3), lineWidth: 2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: dangerPulse)
                )
        )
    }
}