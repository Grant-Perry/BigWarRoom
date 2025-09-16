//
//  RosterCollapsibleTeamCard.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Collapsible team roster card
struct RosterCollapsibleTeamCard: View {
    let teamSlot: Int
    let picks: [EnhancedPick]
    let rosterViewModel: RosterViewModel
    let draftRoomViewModel: DraftRoomViewModel
    
    private var isExpanded: Bool {
        rosterViewModel.expandedTeam == teamSlot
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible Team Header
            Button {
                rosterViewModel.toggleTeamExpansion(teamSlot: teamSlot)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rosterViewModel.teamDisplayName(for: teamSlot, from: picks))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(rosterViewModel.boxForeColor)
                        
                        Text("Draft Slot \(teamSlot)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(picks.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text("picks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(rosterViewModel.boxGradient)
            }
            
            // Collapsible Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Team roster organized by position
                    let rosterByPosition = rosterViewModel.organizeRosterByPosition(picks)
                    
                    if !picks.isEmpty {
                        VStack(spacing: 20) {
                            ForEach(rosterViewModel.rosterPositionOrder, id: \.self) { position in
                                if let playersAtPosition = rosterByPosition[position], !playersAtPosition.isEmpty {
                                    RosterPositionGroupCard(
                                        position: position,
                                        players: playersAtPosition,
                                        rosterViewModel: rosterViewModel,
                                        draftRoomViewModel: draftRoomViewModel
                                    )
                                }
                            }
                        }
                    } else {
                        Text("No picks yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .background(Color(.systemGray6).opacity(0.05))
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}