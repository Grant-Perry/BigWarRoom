//
//  NonMicroTeamInitials.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Team initials circle for non-micro cards
struct NonMicroTeamInitials: View {
    let team: FantasyTeam
    let isWinning: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isWinning ? [.gpGreen.opacity(0.8), .gpGreen] : [team.espnTeamColor.opacity(0.8), team.espnTeamColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(team.teamInitials)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white)
        }
    }
}