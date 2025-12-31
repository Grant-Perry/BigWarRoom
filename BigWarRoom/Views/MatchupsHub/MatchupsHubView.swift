//
//  MatchupsHubView.swift
//  BigWarRoom
//
//  The ultimate fantasy football command center - your personal war room
//

import SwiftUI

/// Main matchups hub view - focuses on core structure and state management
struct MatchupsHubView: View {
    // 🔥 PHASE 4: Use @Environment to get injected instance (internal for extensions)
    @Environment(MatchupsHubViewModel.self) internal var matchupsHubViewModel
    @Environment(NFLWeekService.self) private var nflWeekService
    
    // Dependencies injected via initializer (proper @Observable pattern)
    let weekManager: WeekSelectionManager
    let espnCredentials: ESPNCredentialsManager
    let sleeperCredentials: SleeperCredentialsManager
    
    // MARK: - Navigation State
    @State internal var showingSettings = false
    @State internal var showingWeekPicker = false
    @State internal var showingWatchedPlayers = false
    
    // MARK: - UI State
    @State internal var refreshing = false
    @State internal var cardAnimationStagger: Double = 0
    
    // MARK: - Battles Section State
    @State internal var battlesMinimized = false
    @State internal var poweredByExpanded = false
    
    // MARK: - Sorting States
    @AppStorage("MatchupsHub_SortByWinning") internal var sortByWinning = false
    
    // MARK: - View Mode State
    @AppStorage("MatchupsHub_DualViewMode") internal var dualViewMode = true
    
    // MARK: - Timer States (Following standard app pattern)
    @State internal var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State internal var countdownTimer: Timer?
    @State internal var refreshTimer: Timer?
    @State internal var justMeModeTimer: Timer?
    
    // MARK: - Initializers
    
    // MARK: - Dependency injection initializer (PREFERRED)
    init(weekManager: WeekSelectionManager, 
         espnCredentials: ESPNCredentialsManager,
         sleeperCredentials: SleeperCredentialsManager) {
        self.weekManager = weekManager
        self.espnCredentials = espnCredentials
        self.sleeperCredentials = sleeperCredentials
    }
    
    // MARK: - Default initializer (uses .shared for backward compatibility)
    init() {
        self.weekManager = WeekSelectionManager.shared
        self.espnCredentials = ESPNCredentialsManager.shared
        self.sleeperCredentials = SleeperCredentialsManager.shared
    }
    
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
            // 🔥 NAVIGATION FIX: Only load if we don't have data - prevents loading screen on navigation return
            loadInitialData() // This function now checks if data exists before loading
            startPeriodicRefresh()
        }
        .onDisappear {
            stopPeriodicRefresh()
            stopJustMeModeTimer()
        }
        .refreshable {
            await handlePullToRefresh()
        }
        // 🔥 FIX: Handle LineupRX navigation at this level (outside lazy containers)
        .navigationDestination(for: UnifiedMatchup.self) { matchup in
            LineupRXView(matchup: matchup)
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView(nflWeekService: nflWeekService)
        }
        .sheet(isPresented: $showingWeekPicker) {
            buildWeekPickerSheet()
        }
        .sheet(isPresented: $showingWatchedPlayers) {
            // 🔥 TODO: Convert PlayerWatchService to @Observable and inject
            WatchedPlayersSheet(watchService: PlayerWatchService.shared)
        }
        .onChange(of: weekManager.selectedWeek) { oldValue, newValue in
            if oldValue != newValue {
                onWeekSelected(newValue)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .missionControlFiltersChanged)) { _ in
            Task { @MainActor in
                await matchupsHubViewModel.manualRefresh()
            }
        }
//        .siriAnimate(
//            isActive: matchupsHubViewModel.isUpdating, // 🔥 Only active during 15-second updates  
//            intensity: 0.4,
//            speed: 0.8,
//            baseColors: [.gpBlue, .gpGreen, .purple]
//        )
    }
}