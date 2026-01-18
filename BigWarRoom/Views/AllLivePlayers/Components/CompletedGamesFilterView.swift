//
//  CompletedGamesFilterView.swift
//  BigWarRoom
//
//  Filter toggle for showing only active players vs all players
//

import SwiftUI

/// Toggle filter for showing active players only or all players including those from completed games
struct CompletedGamesFilterView: View {
    @Bindable var allLivePlayersViewModel: AllLivePlayersViewModel
    let onFilterChange: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Text(allLivePlayersViewModel.showActiveOnly ? "Yes" : "No")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(filterColor)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // 🔥 IMPROVED: Add haptic feedback for better user experience
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        allLivePlayersViewModel.setShowActiveOnly(!allLivePlayersViewModel.showActiveOnly)
                        onFilterChange()
                    }
                }
            
            Text("Active Only")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        // 🔥 NEW: Visual indicator when filter might be causing issues
        .overlay(alignment: .topTrailing) {
            if allLivePlayersViewModel.showActiveOnly && allLivePlayersViewModel.filteredPlayers.isEmpty && !allLivePlayersViewModel.allPlayers.isEmpty {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .background(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 14, height: 14)
                    )
                    .offset(x: 8, y: -8)
            }
        }
    }
    
    // 🔥 NEW: Dynamic color based on filter state and potential issues
    private var filterColor: Color {
        if allLivePlayersViewModel.showActiveOnly && allLivePlayersViewModel.filteredPlayers.isEmpty && !allLivePlayersViewModel.allPlayers.isEmpty {
            // Orange warning when filter might be causing empty state
            return .orange
        } else {
            return allLivePlayersViewModel.showActiveOnly ? .gpGreen : .gpRedPink
        }
    }
}
