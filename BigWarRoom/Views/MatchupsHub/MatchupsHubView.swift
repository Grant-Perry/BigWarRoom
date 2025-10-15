//
//  MatchupsHubView.swift
//  BigWarRoom
//
//  The ultimate fantasy football command center - your personal war room
//

import SwiftUI

/// Main matchups hub view - focuses on core structure and state management
struct MatchupsHubView: View {
    // MARK: - ViewModels
    // 🔥 FIXED: Use shared MatchupsHubViewModel to ensure data consistency across all views
    @StateObject internal var matchupsHubViewModel = MatchupsHubViewModel.shared
    
    // MARK: - Week Selection (SSOT)
    @StateObject internal var weekManager = WeekSelectionManager.shared
    
    // 🔥 NEW: Service Credential Managers for Connection Status
    @StateObject private var espnCredentials = ESPNCredentialsManager.shared
    @StateObject private var sleeperCredentials = SleeperCredentialsManager.shared
    
    // MARK: - Navigation State
    // 🏈 NAVIGATION FREEDOM: Remove showingMatchupDetail - using NavigationLinks instead
    // @State internal var showingMatchupDetail: UnifiedMatchup?
    @State internal var showingSettings = false
    @State internal var showingWeekPicker = false
    @State internal var showingWatchedPlayers = false // NEW: Add watched players sheet state
    
    // MARK: - UI State
    @State internal var refreshing = false
    @State internal var cardAnimationStagger: Double = 0
    
    // MARK: - Battles Section State
    @State internal var battlesMinimized = false
    @State internal var poweredByExpanded = false // Changed from true to false - hide the branding banner
    
    // MARK: - Sorting States
    @State internal var sortByWinning = false
    
    // MARK: - View Mode State
    @State internal var dualViewMode = true
    
    // MARK: - Timer States (Following standard app pattern)
    @State internal var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State internal var countdownTimer: Timer?
    @State internal var refreshTimer: Timer?
    @State internal var justMeModeTimer: Timer?
    
    // MARK: - Computed Properties for State Access
    private var microMode: Bool {
        get { matchupsHubViewModel.microModeEnabled }
        set { matchupsHubViewModel.microModeEnabled = newValue }
    }

    private var expandedCardId: String? {
        get { matchupsHubViewModel.expandedCardId }
        set { matchupsHubViewModel.expandedCardId = newValue }
    }

    // MARK: - Body
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove NavigationView - parent TabView provides it
        // BEFORE: NavigationView { ... }
        // AFTER: Direct content - NavigationView provided by parent TabView
        ZStack {
            buildBackgroundView()

            // 🔥 FIXED: Only show empty state if user has NO service connections
            let hasAnyService = espnCredentials.hasValidCredentials || sleeperCredentials.hasValidCredentials

            // Show league loading and hero/minibar progress IMMEDIATELY
            if matchupsHubViewModel.isLoading && matchupsHubViewModel.myMatchups.isEmpty {
                buildLoadingStateView()
            } else if !hasAnyService && !matchupsHubViewModel.isLoading {
                // Only show empty state if user has NO services connected
                buildEmptyStateView()
            } else {
                // Show content even if no matchups but user has services connected
                buildContentView()
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            loadInitialData()
            startPeriodicRefresh()
        }
        .onDisappear {
            stopPeriodicRefresh()
            stopJustMeModeTimer()
        }
        .refreshable {
            await handlePullToRefresh()
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $showingWeekPicker) {
            buildWeekPickerSheet()
        }
        .sheet(isPresented: $showingWatchedPlayers) {
            WatchedPlayersSheet(watchService: PlayerWatchService.shared)
        }
        .onChange(of: weekManager.selectedWeek) { oldValue, newValue in
            if oldValue != newValue {
                onWeekSelected(newValue)
            }
        }
    }
}