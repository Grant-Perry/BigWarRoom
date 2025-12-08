//
//  AllLivePlayersListView.swift
//  BigWarRoom
//
//  Scrollable list view for All Live Players with animations
//

import SwiftUI

/// Scrollable list of players with staggered animations and NavigationLink (NO MORE SHEETS!)
struct AllLivePlayersListView: View {
    @Bindable var allLLivePlayersViewModel: AllLivePlayersViewModel
    @Binding var animatedPlayers: [String]
    let onPlayerTap: (UnifiedMatchup) -> Void
    
    let watchService: PlayerWatchService
    
    @State private var animatedPlayerSet: Set<String> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(allLLivePlayersViewModel.filteredPlayers, id: \.id) { playerEntry in
                    // 🔥 SIMPLE: No NavigationLink wrapper - all navigation handled by buttons within the card
                    PlayerScoreBarCardView(
                        playerEntry: playerEntry,
                        animateIn: shouldAnimatePlayer(playerEntry.id),
                        onTap: nil,
                        viewModel: allLLivePlayersViewModel,
                        watchService: watchService
                    )
                    .onAppear {
                        handlePlayerAppearance(playerEntry)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .clipped()
        .onChange(of: allLLivePlayersViewModel.shouldResetAnimations) { _, shouldReset in
            if shouldReset {
                animatedPlayerSet.removeAll()
                animatedPlayers.removeAll()
                allLLivePlayersViewModel.shouldResetAnimations = false
            }
        }
    }
    
    // 🔥 FIX: Build destination to use same loading flow as Mission Control
    @ViewBuilder
    private func buildDestinationView(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIX: Use MatchupDetailSheetsView for consistent loading experience
        MatchupDetailSheetsView(matchup: matchup)
    }
    
    private func shouldAnimatePlayer(_ playerID: String) -> Bool {
        return !animatedPlayerSet.contains(playerID)
    }
    
    private func handlePlayerAppearance(_ playerEntry: AllLivePlayersViewModel.LivePlayerEntry) {
        guard shouldAnimatePlayer(playerEntry.id) else { return }
        
        // Get the index for staggered animation
        let index = allLLivePlayersViewModel.filteredPlayers.firstIndex(where: { $0.id == playerEntry.id }) ?? 0
        
        // Optimized staggered animation with shorter delays
        let delay = min(Double(index) * 0.03, 0.8)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !Task.isCancelled,
                  allLLivePlayersViewModel.filteredPlayers.contains(where: { $0.id == playerEntry.id }),
                  shouldAnimatePlayer(playerEntry.id) else { return }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedPlayerSet.insert(playerEntry.id)
                animatedPlayers.append(playerEntry.id)
            }
        }
    }
}

// 🔥 PHASE 3 DI: Preview temporarily disabled - requires full dependency tree
// TODO: Create preview mock instances or use PreviewContainer pattern