//
//  PlayerCardBackgroundView.swift
//  BigWarRoom
//
//  Background component for PlayerCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerCardBackgroundView: View {
    let team: NFLTeam?
    
    var body: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 12)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
    }
}