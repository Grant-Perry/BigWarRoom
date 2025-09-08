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
    @StateObject internal var viewModel = MatchupsHubViewModel()
    
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
    @State internal var poweredByExpanded = true // NEW: Control "Powered By" section separately
    
    // MARK: - Sorting States
    @State internal var sortByWinning = true // true = Win (highest scores first), false = Lose (lowest scores first)
    
    // MARK: - Timer States
    @State internal var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State internal var countdownTimer: Timer?
    @State internal var refreshTimer: Timer?
    
    // MARK: - Week Picker States
    @State internal var selectedWeek: Int = NFLWeekService.shared.currentWeek
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                // Show the black loading screen with league loading indicators
                if viewModel.isLoading && viewModel.myMatchups.isEmpty {
                    loadingState
                } else if viewModel.myMatchups.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    matchupsContent
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
            matchupDetailSheet(for: matchup)
        }
        .sheet(isPresented: $showingSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $showingWeekPicker) {
            weekPickerSheet
        }
        .onChange(of: selectedWeek) { oldValue, newValue in
            if oldValue != newValue {
                onWeekSelected(newValue)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    MatchupsHubView()
        .preferredColorScheme(.dark)
}