//
//  ByeWeekCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Bye Week Card component
struct ByeWeekCard: View {
    let team: FantasyTeam
    let week: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Team avatar (grayed out for bye weeks)
            TeamAvatarView(
                team: team, 
                size: CGSize(width: 50, height: 50),
                isGrayedOut: true
            )
            
            // Team info
            VStack(alignment: .leading, spacing: 4) {
                Text(team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("No opponent this week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Bye week indicator
            VStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("BYE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Week \(week)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}