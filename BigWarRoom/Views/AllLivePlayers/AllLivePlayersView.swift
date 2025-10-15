//
//  AllLivePlayersView.swift
//  BigWarRoom
//
//  🔥 FIXED: Proper caching and navigation state management to prevent excessive refreshes
//

import SwiftUI

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
    
    // 🔥 FIXED: More persistent flag that survives navigation
    @AppStorage("AllLivePlayers_HasInitialLoad") private var hasGloballyLoaded = false
    @State private var hasLoadedThisSession = false
    // 🔥 PROPER: Clean state management without band-aids
    @State private var hasPerformedInitialLoad = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // BG7 background
                Image("BG7")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 🔥 FIXED: Header with NO top padding
                    AllLivePlayersHeaderView(
                        viewModel: allLivePlayersViewModel,
                        sortHighToLow: $sortHighToLow,
                        showingWeekPicker: $showingWeekPicker,
                        onAnimationReset: resetAnimations,
                        showingFilters: $showingFilters,
                        showingWatchedPlayers: $showingWatchedPlayers
                    )
                    
                    // 🔥 PROPER: Content based on clean state machine
                    buildContentView()
                }
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
        .keyboardAdaptive() // Custom modifier to handle keyboard properly
        .onAppear {
            // 🔥 REVERTED: Back to simple, working logic
            let hasData = !allLivePlayersViewModel.allPlayers.isEmpty
            
            print("🔥 LIVE PLAYERS ONAPPEAR: hasData = \(hasData)")
            
            // Simple rule: If we don't have data, load it
            if !hasData && !hasPerformedInitialLoad {
                print("🔥 LIVE PLAYERS: Starting data load")
                hasPerformedInitialLoad = true
                Task {
                    await allLivePlayersViewModel.loadAllPlayers()
                }
            } else {
                print("🔥 LIVE PLAYERS: Already have data or already loaded")
                hasPerformedInitialLoad = true
            }
        }
        .onDisappear {
            cancelTasks()
        }
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
    
    // MARK: - Content View Selection (Reverted to Working Logic)
    
    func buildContentView() -> some View {
        let dataState = allLivePlayersViewModel.dataState
        
        // If searching and no results, show search-specific empty state
        if allLivePlayersViewModel.isSearching && allLivePlayersViewModel.filteredPlayers.isEmpty {
            return AnyView(searchEmptyStateView)
        }
        
        // If we're loading OR if we have no data yet but are not in error state, show loading
        if case .loading = dataState {
            return AnyView(AllLivePlayersLoadingView())
        }
        
        if case .initial = dataState {
            return AnyView(AllLivePlayersLoadingView())
        }
        
        // Only show empty state if we've actually finished loading and confirmed no data
        switch dataState {
        case .loaded:
            if allLivePlayersViewModel.filteredPlayers.isEmpty {
                return AnyView(
                    AllLivePlayersEmptyStateView(
                        viewModel: allLivePlayersViewModel,
                        onAnimationReset: resetAnimations
                    )
                )
            } else {
                return AnyView(
                    AllLivePlayersListView(
                        viewModel: allLivePlayersViewModel,
                        animatedPlayers: $animatedPlayers,
                        onPlayerTap: handlePlayerTap
                    )
                )
            }
            
        case .empty:
            return AnyView(
                AllLivePlayersEmptyStateView(
                    viewModel: allLivePlayersViewModel,
                    onAnimationReset: resetAnimations
                )
            )
            
        case .error(let errorMessage):
            return AnyView(
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error Loading Players")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            await allLivePlayersViewModel.loadAllPlayers()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            )
            
        default:
            // Fallback to loading for any other state
            return AnyView(AllLivePlayersLoadingView())
        }
    }
    
    // MARK: - Search Empty State View
    
    private var searchEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(allLivePlayersViewModel.searchText.capitalized)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if allLivePlayersViewModel.showRosteredOnly {
                    Text("Not rostered in any of your leagues")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No players found in NFL database")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Suggestion to try removing rostered filter
            if allLivePlayersViewModel.showRosteredOnly {
                Button(action: {
                    allLivePlayersViewModel.showRosteredOnly = false
                    allLivePlayersViewModel.toggleRosteredFilter()
                }) {
                    Text("Search All NFL Players")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gpBlue)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Event Handlers (UI Coordination Only)
    
    /// Reset animation state for smooth transitions
    private func resetAnimations() {
        withAnimation(.easeOut(duration: 0.1)) {
            animatedPlayers.removeAll()
        }
    }
    
    /// Handle player tap - DEPRECATED: Will be replaced with NavigationLink
    private func handlePlayerTap(_ matchup: UnifiedMatchup) {
        print("🔥 DEBUG: Player tap - should use NavigationLink instead of sheet")
    }
    
    /// Refresh data with task management - ONLY for pull-to-refresh
    private func refreshData() {
        loadTask?.cancel()
        loadTask = Task {
            await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
            await allLivePlayersViewModel.loadAllPlayers()
        }
    }
    
    /// Perform pull-to-refresh - always allow manual refresh
    private func performRefresh() async {
        print("🔄 PULL-TO-REFRESH: User initiated manual refresh")
        await allLivePlayersViewModel.matchupsHubViewModel.loadAllMatchups()
        await allLivePlayersViewModel.refresh()
    }
    
    /// Load initial data with proper task management - ONLY run when needed
    private func loadInitialData() async {
        print("🔥 INITIAL LOAD: Loading initial data for All Live Players")
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

// MARK: - Custom Keyboard Adaptive Modifier
extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    keyboardHeight = keyboardFrame.cgRectValue.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
    }
}