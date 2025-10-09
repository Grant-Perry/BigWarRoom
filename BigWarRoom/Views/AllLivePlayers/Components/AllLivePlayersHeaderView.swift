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
    
    // New bindings for filters and watched players
    @Binding var showingFilters: Bool
    @Binding var showingWatchedPlayers: Bool
    
    // Timer states for actual refresh cycle - using @State to prevent full view redraws
    @State private var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State private var countdownTimer: Timer?
    @State private var refreshTimer: Timer?
    
    // 🔥 FIX: Maintain stable manager info during refreshes
    @State private var stableManager: ManagerInfo?
    
    // 🔥 NEW: Week picker state - now passed as binding
    @StateObject private var weekManager = WeekSelectionManager.shared
    @StateObject private var watchService = PlayerWatchService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Controls section (simplified - removed Week picker)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Player Analysis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Updated: \(Int(refreshCountdown))s ago")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Filters button
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    // Watched players button with count badge
                    Button(action: { showingWatchedPlayers = true }) {
                        ZStack {
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                            
                            // Badge showing watch count
                            if watchService.watchCount > 0 {
                                Text("\(watchService.watchCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(.red))
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // Refresh button
                    Button(action: { 
                        Task { await performManualRefresh() }
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Stats Summary with Week picker in first position
            statsOverviewSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
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
    
    // MARK: - Stats Overview Section (Intelligence style)
    
    private var statsOverviewSection: some View {
        HStack(spacing: 0) {
            // Week picker replaces the PLAYERS stat
            Button(action: { showingWeekPicker = true }) {
                VStack(spacing: 6) {
                    Text("\(weekManager.selectedWeek)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.gpGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("WEEK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gpGreen.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gpGreen.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            StatCardView(
                value: String(format: "%.1f", viewModel.topScore),
                label: "TOP SCORE",
                color: .gpGreen
            )
            
            StatCardView(
                value: viewModel.selectedPosition.displayName.uppercased(),
                label: "POSITION",
                color: .purple
            )
            
            StatCardView(
                value: viewModel.showActiveOnly ? "YES" : "NO",
                label: "ACTIVE ONLY",
                color: viewModel.showActiveOnly ? .orange : .gray
            )
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Methods
    
    private func getOverallPerformanceEmoji() -> String {
        let totalPlayers = viewModel.filteredPlayers.count
        let highPerformers = viewModel.filteredPlayers.filter { $0.currentScore > 15.0 }.count
        let lowPerformers = viewModel.filteredPlayers.filter { $0.currentScore < 5.0 }.count
        
        if totalPlayers == 0 { return "📊" }
        
        let highPercentage = Double(highPerformers) / Double(totalPlayers)
        let lowPercentage = Double(lowPerformers) / Double(totalPlayers)
        
        if highPercentage > 0.3 { return "🔥" }  // 30% high performers
        else if lowPercentage > 0.5 { return "❄️" }  // 50% low performers
        else { return "📊" }  // Average performance
    }
    
    private func getLastUpdateText() -> String {
        return "Updated \(Int(refreshCountdown))s ago"
    }
    
    private func performManualRefresh() async {
        // Manual refresh with full reset
        await viewModel.hardResetFilteringState()
        onAnimationReset()
        resetCountdown()
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

// MARK: - Supporting Components

/// Individual stat card for header overview (same as Intelligence)
private struct StatCardView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}