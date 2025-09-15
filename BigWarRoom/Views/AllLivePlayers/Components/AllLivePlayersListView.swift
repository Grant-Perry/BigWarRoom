//
//  AllLivePlayersListView.swift
//  BigWarRoom
//
//  Scrollable list view for All Live Players with animations
//

import SwiftUI

/// Scrollable list of players with staggered animations and tap handling
struct AllLivePlayersListView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    @Binding var animatedPlayers: [String]
    let onPlayerTap: (UnifiedMatchup) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) { // Reduced from 12 to 8 for tighter spacing
                ForEach(Array(viewModel.filteredPlayers.enumerated()), id: \.element.id) { index, playerEntry in
                    PlayerScoreBarCardView(
                        playerEntry: playerEntry,
                        animateIn: !animatedPlayers.contains(playerEntry.id),
                        onTap: {
                            onPlayerTap(playerEntry.matchup)
                        },
                        viewModel: viewModel
                    )
                    .onAppear {
                        // Optimized staggered animation with shorter delays
                        if !animatedPlayers.contains(playerEntry.id) {
                            let delay = min(Double(index) * 0.05, 1.0) // Cap max delay at 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                // Check if view is still alive before animating
                                guard !Task.isCancelled else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    animatedPlayers.append(playerEntry.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .clipped() // Prevent scroll view overflow during fast scrolling
    }
}

#Preview {
    AllLivePlayersListView(
        viewModel: AllLivePlayersViewModel.shared,
        animatedPlayers: .constant([]),
        onPlayerTap: { _ in }
    )
}