//
//  RosterPositionGroupCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Position group card showing players at a specific position
struct RosterPositionGroupCard: View {
    let position: String
    let players: [EnhancedPick]
    let rosterViewModel: RosterViewModel
    let draftRoomViewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Position header
            HStack {
                Text(position)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(rosterViewModel.positionColor(position))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Spacer()
                
                Text("\(players.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Players at this position (vertical list for better spacing)
            VStack(spacing: 12) {
                ForEach(players.sorted { $0.pickNumber < $1.pickNumber }) { player in
                    CompactTeamRosterPlayerCard(
                        pick: player,
                        onPlayerTap: { sleeperPlayer in
                            rosterViewModel.showPlayerStats(for: sleeperPlayer)
                        },
                        viewModel: draftRoomViewModel
                    )
                }
            }
        }
        .padding(16)
        .background(
            // Add the gpBlue to clear gradient background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.gpBlue.opacity(0.2), location: 0.0),
                    .init(color: Color.clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}