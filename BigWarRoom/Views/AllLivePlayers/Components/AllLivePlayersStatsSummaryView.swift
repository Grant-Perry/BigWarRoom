//
//  AllLivePlayersStatsSummaryView.swift
//  BigWarRoom
//
//  Stats summary bar for All Live Players
//

import SwiftUI

/// Stats summary display with player count, top score, and position filter
struct AllLivePlayersStatsSummaryView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    let onPositionChange: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            StatBlock(
                title: "Players",
                value: "\(viewModel.filteredPlayers.count)",
                color: .gpGreen
            )
            
            StatBlock(
                title: "Top Score",
                value: String(format: "%.1f", viewModel.positionTopScore > 0 ? viewModel.positionTopScore : viewModel.topScore),
                color: .blue
            )
            
            Menu {
                ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.setPositionFilter(position)
                            onPositionChange()
                        }
                    }) {
                        HStack {
                            Text(position.displayName)
                            if viewModel.selectedPosition == position {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                StatBlock(
                    title: "Position",
                    value: viewModel.selectedPosition.displayName,
                    color: .orange
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Completed games filter styled as stat blocks
            CompletedGamesFilterView(
                viewModel: viewModel,
                onFilterChange: onPositionChange
            )
            
            Spacer()
        }
    }
}

#Preview {
    AllLivePlayersStatsSummaryView(
        viewModel: AllLivePlayersViewModel.shared,
        onPositionChange: {}
    )
}