//
//  AllLivePlayersStatsSummaryView.swift
//  BigWarRoom
//
//  Stats summary bar for All Live Players
//

import SwiftUI

/// Stats summary display with player count, top score, and position filter
struct AllLivePlayersStatsSummaryView: View {
    @Bindable var allLivePlayersViewModel: AllLivePlayersViewModel
    let onPositionChange: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            StatBlock(
                title: "Players",
                value: "\(allLivePlayersViewModel.filteredPlayers.count)",
                color: .gpGreen
            )
            
            StatBlock(
                title: "Top Score",
                value: String(format: "%.1f", allLivePlayersViewModel.positionTopScore > 0 ? allLivePlayersViewModel.positionTopScore : allLivePlayersViewModel.topScore),
                color: .blue
            )
            
            Menu {
                ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            allLivePlayersViewModel.setPositionFilter(position)
                            onPositionChange()
                        }
                    }) {
                        HStack {
                            Text(position.displayName)
                            if allLivePlayersViewModel.selectedPosition == position {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                StatBlock(
                    title: "Position",
                    value: allLivePlayersViewModel.selectedPosition.displayName,
                    color: .orange
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Completed games filter styled as stat blocks
            CompletedGamesFilterView(
                allLivePlayersViewModel: allLivePlayersViewModel,
                onFilterChange: onPositionChange
            )
            
            Spacer()
        }
    }
}

#Preview {
    AllLivePlayersStatsSummaryView(
        	  allLivePlayersViewModel: AllLivePlayersViewModel.shared,
        onPositionChange: {}
    )
}