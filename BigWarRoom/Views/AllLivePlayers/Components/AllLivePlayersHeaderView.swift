//
//  AllLivePlayersHeaderView.swift
//  BigWarRoom
//
//  Header view with manager info, filters, and stats for All Live Players
//

import SwiftUI
import Combine

/// Complete header section with manager info, controls, and stats
struct AllLivePlayersHeaderView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    @Binding var sortHighToLow: Bool
    @Binding var showingWeekPicker: Bool
    let onAnimationReset: () -> Void
    
    // Timer states for actual refresh cycle - using @State to prevent full view redraws
    @State private var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State private var countdownTimer: Timer?
    @State private var refreshTimer: Timer?
    
    // 🔥 FIX: Maintain stable manager info during refreshes
    @State private var stableManager: ManagerInfo?
    
    // 🔥 NEW: Week picker state - now passed as binding
    @StateObject private var weekManager = WeekSelectionManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Manager info as full width header with countdown timer - always show if we have one
            if let manager = currentManager {
                ManagerInfoCardView(
                    manager: manager, 
                    style: .fullWidth,
                    countdown: refreshCountdown,
                    onRefresh: {
                        Task {
                            await performRefreshWithReset()
                        }
                    }
                )
            }
            
            // Controls row with position filter, sort controls, and week picker
            HStack(spacing: 6) {
                PlayerPositionFilterView(
                    viewModel: viewModel,
                    onPositionChange: onAnimationReset
                )
                
                PlayerSortControlsView(
                    viewModel: viewModel,
                    sortHighToLow: $sortHighToLow,
                    onSortChange: onAnimationReset
                )
                
                Spacer()
                
                // 🔥 NEW: Week picker button (same style as Mission Control)
                Button(action: {
                    showingWeekPicker = true
                }) {
                    HStack(spacing: 4) {
                        Text("Week")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("\(weekManager.selectedWeek)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gpGreen.opacity(0.1))
                    .foregroundColor(.gpGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            
            // Stats Summary
            if !viewModel.filteredPlayers.isEmpty {
                AllLivePlayersStatsSummaryView(
                    viewModel: viewModel,
                    onPositionChange: onAnimationReset
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGray6).opacity(0.3))
        .onAppear {
            // 🔥 FIX: Sync initial state between View and ViewModel
            sortHighToLow = viewModel.sortHighToLow
            startGlobalRefreshCycle()
        }
        .onDisappear {
            stopGlobalRefreshCycle()
        }
        .onChange(of: viewModel.sortHighToLow) { _, newValue in
            // 🔥 FIX: Keep View state in sync when ViewModel changes
            sortHighToLow = newValue
        }
        .onReceive(viewModel.objectWillChange) { _ in
            // 🔥 FIX: Update stable manager when new data is available
            if let newManager = viewModel.firstAvailableManager {
                stableManager = newManager
            }
        }
        .onChange(of: weekManager.selectedWeek) { _, _ in
            // 🔥 NEW: Refresh data when week changes
            Task {
                await performRefreshWithReset()
            }
        }
    }
    
    // 🔥 NEW: Computed property that provides stable manager info
    private var currentManager: ManagerInfo? {
        // Prefer fresh data, fallback to stable version during refresh
        return viewModel.firstAvailableManager ?? stableManager
    }
    
    // MARK: - Background Refresh (No UI Resets)
    private func performBackgroundRefresh() async {
        // Perform data refresh without triggering UI animations reset
        await viewModel.refresh()
        resetCountdown()
        // DO NOT call onAnimationReset() here - that causes the jarring refresh
    }
    
    // 🔥 NEW: Refresh with UI reset - for manual refresh button
    private func performRefreshWithReset() async {
        // 🔥 NUCLEAR OPTION: Complete state reset to fix filtering bugs
        await viewModel.hardResetFilteringState()
        onAnimationReset() // Reset animations and UI state
        resetCountdown()
    }
    
    // MARK: - Global Refresh Cycle Management
    private func startGlobalRefreshCycle() {
        stopGlobalRefreshCycle()
        
        // Initialize stable manager on first load
        if let manager = viewModel.firstAvailableManager {
            stableManager = manager
        }
        
        // Start the actual refresh timer (every 15 seconds)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !viewModel.isLoading {
                    // Background refresh without UI disruption
                    await performBackgroundRefresh()
                }
            }
        }
        
        // Start the visual countdown timer (every 1 second)
        startCountdownTimer()
    }
    
    private func stopGlobalRefreshCycle() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        stopCountdownTimer()
    }
    
    private func startCountdownTimer() {
        resetCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if refreshCountdown > 0 {
                refreshCountdown -= 1
            } else {
                resetCountdown()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func resetCountdown() {
        refreshCountdown = Double(AppConstants.MatchupRefresh)
    }
}