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
    @StateObject internal var matchupsHubViewModel = MatchupsHubViewModel()
    
    // MARK: - Week Selection (SSOT)
    @StateObject internal var weekManager = WeekSelectionManager.shared
    
    // MARK: - Navigation State
    @State internal var showingMatchupDetail: UnifiedMatchup?
    @State internal var showingSettings = false
    @State internal var showingWeekPicker = false
    
    // MARK: - UI State
    @State internal var refreshing = false
    @State internal var cardAnimationStagger: Double = 0
    
    // MARK: - Micro Mode States
    @State internal var microMode = false
    @State internal var expandedCardId: String? = nil
    
    // MARK: - Battles Section State
    @State internal var battlesMinimized = false
    @State internal var poweredByExpanded = true
    
    // MARK: - Sorting States
    @State internal var sortByWinning = true
    
    // MARK: - View Mode State
    @State internal var dualViewMode = true
    
    // MARK: - Timer States (Following standard app pattern)
    @State internal var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State internal var countdownTimer: Timer?
    @State internal var refreshTimer: Timer?
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                buildBackgroundView()
                
                // Show the black loading screen with league loading indicators
                if matchupsHubViewModel.isLoading && matchupsHubViewModel.myMatchups.isEmpty {
                    buildLoadingStateView()
                } else if matchupsHubViewModel.myMatchups.isEmpty && !matchupsHubViewModel.isLoading {
                    buildEmptyStateView()
                } else {
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
            }
            .refreshable {
                await handlePullToRefresh()
            }
        }
        .sheet(item: $showingMatchupDetail) { matchup in
            buildMatchupDetailSheet(for: matchup)
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $showingWeekPicker) {
            buildWeekPickerSheet()
        }
        .onChange(of: weekManager.selectedWeek) { oldValue, newValue in
            if oldValue != newValue {
                onWeekSelected(newValue)
            }
        }
    }
}