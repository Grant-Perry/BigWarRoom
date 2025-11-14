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
    let onPlayerTap: (UnifiedMatchup) -> Void // 🔥 DEPRECATED: Will be removed
    
    // 🔥 PHASE 3 DI: Add watchService parameter
    let watchService: PlayerWatchService
    
    var body: some View {
        ScrollView {
            // 🔥 FIXED: Use stable ID and reset animations when sort changes
            LazyVStack(spacing: 8) { // Reduced from 12 to 8 for tighter spacing
                ForEach(allLLivePlayersViewModel.filteredPlayers, id: \.id) { playerEntry in
                    // 🔥 SIMPLE: No NavigationLink wrapper - all navigation handled by buttons within the card
                    PlayerScoreBarCardView(
                        playerEntry: playerEntry,
                        animateIn: shouldAnimatePlayer(playerEntry.id),
                        onTap: nil, // No card-level tap - use individual buttons instead
                        viewModel: allLLivePlayersViewModel,
                        watchService: watchService // 🔥 PHASE 3 DI: Pass watchService
                    )
                    .onAppear {
                        handlePlayerAppearance(playerEntry)
                    }
                }
            }
            .id(allLLivePlayersViewModel.sortChangeID) // 🔥 FIXED: Force LazyVStack to rebuild when sort changes
            .padding(.horizontal, 20) // 🔥 FIXED: Increased horizontal padding from default to 20 to prevent edge clipping
            .padding(.top, 4) // 🔥 REDUCED: From 12 to 4 for tighter spacing
            .padding(.bottom, 12) // Keep bottom padding for safe area
        }
        .clipped() // Prevent scroll view overflow during fast scrolling
        .onChange(of: allLLivePlayersViewModel.shouldResetAnimations) { _, shouldReset in
            if shouldReset {
                // 🔥 FIXED: Clear animation state when sorting changes
                animatedPlayers.removeAll()
            }
        }
    }
    
    // 🔥 FIX: Build destination to use same loading flow as Mission Control
    @ViewBuilder
    private func buildDestinationView(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIX: Use MatchupDetailSheetsView for consistent loading experience
        MatchupDetailSheetsView(matchup: matchup)
    }
    
    // 🔥 NEW: Determine if player should animate in
    private func shouldAnimatePlayer(_ playerID: String) -> Bool {
        return !animatedPlayers.contains(playerID)
    }
    
    // 🔥 NEW: Handle player card appearance with improved logic
    private func handlePlayerAppearance(_ playerEntry: AllLivePlayersViewModel.LivePlayerEntry) {
        guard shouldAnimatePlayer(playerEntry.id) else { return }
        
        // Get the index for staggered animation
        let index = allLLivePlayersViewModel.filteredPlayers.firstIndex(where: { $0.id == playerEntry.id }) ?? 0
        
        // Optimized staggered animation with shorter delays
        let delay = min(Double(index) * 0.03, 0.8) // Reduced delay and cap
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Check if view is still alive and player still exists
            guard !Task.isCancelled,
                  allLLivePlayersViewModel.filteredPlayers.contains(where: { $0.id == playerEntry.id }),
                  shouldAnimatePlayer(playerEntry.id) else { return }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedPlayers.append(playerEntry.id)
            }
        }
    }
}

// 🔥 PHASE 3 DI: Preview temporarily disabled - requires full dependency tree
// TODO: Create preview mock instances or use PreviewContainer pattern