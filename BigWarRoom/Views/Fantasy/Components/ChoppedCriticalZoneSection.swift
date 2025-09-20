//
//  ChoppedCriticalZoneSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Critical zone (death row) section
struct ChoppedCriticalZoneSection: View {
    let choppedLeaderboardViewModel: ChoppedLeaderboardViewModel
    let pulseAnimation: Bool
    let leagueID: String
    let week: Int
    let zoneOpacity: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Critical header - MOST DRAMATIC
            HStack {
                Text("💀")
                    .font(.system(size: 24))
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                
                VStack {
                    Text("DEATH ROW")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.red)
                        .tracking(3)
                    
                    Text("ELIMINATION IMMINENT")
                        .font(.system(size: 10, weight: .bold))
						
                        .foregroundColor(.gray)
                        .tracking(2)
                }
                
                Text("☠️")
                    .font(.system(size: 24))
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.3), value: pulseAnimation)
            }
            
            // Critical teams with tap functionality
            ForEach(choppedLeaderboardViewModel.choppedSummary.criticalTeams) { ranking in
                CriticalCard(
                    ranking: ranking,
                    leagueID: leagueID,
                    week: week
                )
            }
			.padding(.horizontal, 18)

            // Elimination ceremony button
            if choppedLeaderboardViewModel.shouldShowEliminationCeremonyButton {
                Button(action: {
                    choppedLeaderboardViewModel.showEliminationCeremonyModal()
                }) {
                    HStack {
                        Text("🎬")
                        Text("WATCH ELIMINATION CEREMONY")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(1)
                        Text("🎬")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.5), radius: 10)
                    )
                }
            }
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(zoneOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .black, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                )
        )
    }
}
