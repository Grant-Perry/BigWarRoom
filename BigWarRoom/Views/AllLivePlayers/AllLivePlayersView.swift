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
    @StateObject private var watchService = PlayerWatchService.shared
    
    // 🔥 UI STATE ONLY - No business logic
    @State private var animatedPlayers: [String] = []
    @State private var sortHighToLow = true
    @State private var showingWeekPicker = false
    @State private var showingFilters = false
    @State private var showingWatchedPlayers = false
    
    // 🔥 PERFORMANCE: Task management for better lifecycle control
    @State private var loadTask: Task<Void, Never>?
    
    // 🔥 FIXED: Track if initial load has been done to prevent reloading on navigation return
    @State private var hasInitiallyLoaded = false
    
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove NavigationView - parent TabView provides it
        // BEFORE: NavigationView { ... }
        // AFTER: Direct content - NavigationView provided by parent TabView
        ZStack {
            // BG7 background
            Image("BG7")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.35)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // 🔥 CLEAN: Extracted header component
                AllLivePlayersHeaderView(
                    viewModel: allLivePlayersViewModel,
                    sortHighToLow: $sortHighToLow,
                    showingWeekPicker: $showingWeekPicker,
                    onAnimationReset: resetAnimations,
                    showingFilters: $showingFilters,
                    showingWatchedPlayers: $showingWatchedPlayers
                )
                
                // 🔥 CLEAN: Content based on state - no business logic here
                buildContentView()
            }
        }
        .navigationTitle("All Rostered Players")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("All Rostered Players")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .notificationBadge(count: allLivePlayersViewModel.filteredPlayers.count, xOffset: 28, yOffset: -8)
            }
        }
        .refreshable {
            await performRefresh()
        }
        .onAppear {
            // 🔥 FIXED: Only load if we haven't loaded before
            if !hasInitiallyLoaded {
                Task {
                    await loadInitialData()
                    hasInitiallyLoaded = true
                }
            }
        }
        .onDisappear {
            cancelTasks()
        }
        // 🔥 DEATH TO SHEETS: Remove sheet for matchup detail - using NavigationLink instead
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerView(isPresented: $showingWeekPicker)
        }
        .sheet(isPresented: $showingFilters) {
            AllLivePlayersFiltersSheet(viewModel: allLivePlayersViewModel)
        }
        .sheet(isPresented: $showingWatchedPlayers) {
            WatchedPlayersSheet(watchService: watchService)
        }
        // 🔥 FIXED: Listen for sort changes and reset animations
        .onChange(of: allLivePlayersViewModel.sortChangeID) { _, _ in
            resetAnimations()
        }
        .onChange(of: allLivePlayersViewModel.lastUpdateTime) { _ in
            // Update watched player scores when live players update
            let allOpponentPlayers = allLivePlayersViewModel.allPlayers.compactMap { playerEntry in
                OpponentPlayer(
                    id: UUID().uuidString,
                    player: playerEntry.player,
                    isStarter: playerEntry.isStarter,
                    currentScore: playerEntry.currentScore,
                    projectedScore: playerEntry.projectedScore,
                    threatLevel: .moderate,
                    matchupAdvantage: .neutral,
                    percentageOfOpponentTotal: 0.0
                )
            }
            watchService.updateWatchedPlayerScores(allOpponentPlayers)
        }
    }
    
    // MARK: - Content View Selection (No Business Logic)
    
    func buildContentView() -> some View {
        if allLivePlayersViewModel.isLoading {
            return AnyView(AllLivePlayersLoadingView())
        } else if allLivePlayersViewModel.filteredPlayers.isEmpty {
            return AnyView(
                AllLivePlayersEmptyStateView(
                    viewModel: allLivePlayersViewModel,
                    onAnimationReset: resetAnimations
                )
                // 🔥 NEW: Automatic recovery for potentially stuck states
                .onAppear {
                    // Only trigger auto-recovery if we have players, not loading, AND it's not due to legitimate filtering
                    if !allLivePlayersViewModel.allPlayers.isEmpty && !allLivePlayersViewModel.isLoading {
                        // Delay to allow normal filtering to complete first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Only recover if filtered list is empty AND it's not due to user choosing Active Only filter
                            let isEmptyDueToActiveFilter = allLivePlayersViewModel.showActiveOnly && allLivePlayersViewModel.filteredPlayers.isEmpty
                            
                            if allLivePlayersViewModel.filteredPlayers.isEmpty && 
                               !allLivePlayersViewModel.allPlayers.isEmpty && 
                               !isEmptyDueToActiveFilter {
                                print("🔧 AUTO-RECOVERY: Detected potentially stuck state after 2 seconds (not due to Active Only filter)")
                                allLivePlayersViewModel.recoverFromStuckState()
                            }
                        }
                    }
                }
            )
        } else {
            return AnyView(
                AllLivePlayersListView(
                    viewModel: allLivePlayersViewModel,
                    animatedPlayers: $animatedPlayers,
                    onPlayerTap: handlePlayerTap // 🔥 Keep this for now - will change to NavigationLink in list view
                )
            )
        }
    }
    
    // MARK: - Event Handlers (UI Coordination Only)
    
    /// Reset animation state for smooth transitions
    private func resetAnimations() {
        // 🔥 IMPROVED: Clear animations immediately and smoothly
        withAnimation(.easeOut(duration: 0.1)) {
            animatedPlayers.removeAll()
        }
    }
    
    /// Handle player tap - DEPRECATED: Will be replaced with NavigationLink
    private func handlePlayerTap(_ matchup: UnifiedMatchup) {
        // 🔥 DEATH TO SHEETS: This will be replaced with NavigationLink in the list view
        print("🔥 DEBUG: Player tap - should use NavigationLink instead of sheet")
    }
    
    /// Refresh data with task management
    private func refreshData() {
        loadTask?.cancel()
        loadTask = Task {
            await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
            await allLivePlayersViewModel.loadAllPlayers()
        }
    }
    
    /// Perform pull-to-refresh - always allow manual refresh
    private func performRefresh() async {
        await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
        await allLivePlayersViewModel.refresh()
    }
    
    /// Load initial data with proper task management - ONLY run once
    private func loadInitialData() async {
        print("🔥 DEBUG: Loading initial data for All Live Players")
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