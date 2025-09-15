//
//  AllLivePlayersView.swift
//  BigWarRoom
//
//  Clean coordinator view for displaying all active players across all leagues
//  Following proper MVVM architecture with separated concerns
//

import SwiftUI

/// **CLEAN MVVM COORDINATOR VIEW**
/// 
/// This view now only handles:
/// - UI coordination and navigation
/// - State management for animations and sheets
/// - Task lifecycle management
/// 
/// All business logic has been moved to AllLivePlayersViewModel
/// All UI components have been extracted to separate, reusable view files
struct AllLivePlayersView: View {
    // 🔥 FIXED: Use shared instance instead of creating new one
    @ObservedObject private var allLivePlayersViewModel = AllLivePlayersViewModel.shared
    
    // 🔥 UI STATE ONLY - No business logic
    @State private var animatedPlayers: [String] = []
    @State private var selectedMatchup: UnifiedMatchup?
    @State private var showingMatchupDetail = false
    @State private var sortHighToLow = true
    
    // 🔥 PERFORMANCE: Task management for better lifecycle control
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 🔥 CLEAN: Extracted header component
                AllLivePlayersHeaderView(
                    viewModel: allLivePlayersViewModel,
                    sortHighToLow: $sortHighToLow,
                    onAnimationReset: resetAnimations
                )
                
                // 🔥 CLEAN: Content based on state - no business logic here
                contentView
            }
            .navigationTitle("All Live Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allLivePlayersViewModel.hasNoLeagues && !allLivePlayersViewModel.isLoading {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Refresh") {
                            refreshData()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .refreshable {
                await performRefresh()
            }
        }
        .task {
            await loadInitialData()
        }
        .onDisappear {
            cancelTasks()
        }
        .sheet(isPresented: $showingMatchupDetail) {
            if let matchup = selectedMatchup {
                MatchupDetailSheet(matchup: matchup)
            }
        }
    }
    
    // MARK: - Content View Selection (No Business Logic)
    
    @ViewBuilder
    private var contentView: some View {
        if allLivePlayersViewModel.isLoading {
            AllLivePlayersLoadingView()
        } else if allLivePlayersViewModel.filteredPlayers.isEmpty {
            AllLivePlayersEmptyStateView(
                viewModel: allLivePlayersViewModel,
                onAnimationReset: resetAnimations
            )
            // 🔥 NEW: Automatic recovery for potentially stuck states
            .onAppear {
                // If we have players but filtered list is empty (and we're not loading), might be stuck
                if !allLivePlayersViewModel.allPlayers.isEmpty && !allLivePlayersViewModel.isLoading {
                    // Delay to allow normal filtering to complete first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if allLivePlayersViewModel.filteredPlayers.isEmpty && !allLivePlayersViewModel.allPlayers.isEmpty {
                            print("🔧 AUTO-RECOVERY: Detected potentially stuck state after 2 seconds")
                            allLivePlayersViewModel.recoverFromStuckState()
                        }
                    }
                }
            }
        } else {
            AllLivePlayersListView(
                viewModel: allLivePlayersViewModel,
                animatedPlayers: $animatedPlayers,
                onPlayerTap: handlePlayerTap
            )
        }
    }
    
    // MARK: - Event Handlers (UI Coordination Only)
    
    /// Reset animation state for smooth transitions
    private func resetAnimations() {
        animatedPlayers.removeAll()
    }
    
    /// Handle player tap - open matchup detail
    private func handlePlayerTap(_ matchup: UnifiedMatchup) {
        selectedMatchup = matchup
        showingMatchupDetail = true
    }
    
    /// Refresh data with task management
    private func refreshData() {
        loadTask?.cancel()
        loadTask = Task {
            await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
            await allLivePlayersViewModel.loadAllPlayers()
        }
    }
    
    /// Perform pull-to-refresh
    private func performRefresh() async {
        await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
        await allLivePlayersViewModel.refresh()
    }
    
    /// Load initial data with proper task management
    private func loadInitialData() async {
        // Cancel any existing task before starting new one
        loadTask?.cancel()
        loadTask = Task {
            // Ensure leagues are loaded first
            await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
            
            // Then load players
            await allLivePlayersViewModel.loadAllPlayers()
        }
    }
    
    /// Cancel background tasks when view disappears
    private func cancelTasks() {
        loadTask?.cancel()
    }
}