//
//  RosterTeamRostersSection.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Team rosters section showing all teams
struct RosterTeamRostersSection: View {
    let rosterViewModel: RosterViewModel
    let draftRoomViewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Team Rosters")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(rosterViewModel.expandedTeam != nil ? "1 team expanded" : "All teams collapsed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 16) {
                ForEach(rosterViewModel.sortedTeamSlots, id: \.self) { teamSlot in
                    let teamPicks = rosterViewModel.picksByTeam[teamSlot] ?? []
                    RosterCollapsibleTeamCard(
                        teamSlot: teamSlot,
                        picks: teamPicks,
                        rosterViewModel: rosterViewModel,
                        draftRoomViewModel: draftRoomViewModel
                    )
                }
            }
        }
    }
}