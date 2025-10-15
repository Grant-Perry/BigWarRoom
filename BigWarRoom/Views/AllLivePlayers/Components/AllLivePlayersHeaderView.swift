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
            // #GoodNav: Header with WEEK + icons (like Mission Control/Intelligence)
            weekPickerWithIconsRow
            
            // #GoodNav: Contextual controls row
            controlsSection
            
            // Stats Summary - REMOVED (keeping it clean)
            // statsOverviewSection
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
            // 🔥 FIXED: Use gentle refresh instead of hard reset to preserve user settings
            Task {
                await performBackgroundRefresh()
            }
        }
    }
    
    // #GoodNav: Week picker with icons (matching template)
    private var weekPickerWithIconsRow: some View {
        HStack {
            // WEEK picker (left side) 
            Button(action: { showingWeekPicker = true }) {
                HStack(spacing: 6) {
                    Text("WEEK \(weekManager.selectedWeek)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Icons (right side)
            HStack(spacing: 12) {
                // Filters button
                Button(action: { showingFilters = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Watched players button
                Button(action: { showingWatchedPlayers = true }) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                        .notificationBadge(count: watchService.watchCount)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh button
                Button(action: { 
                    Task { await performManualRefresh() }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // #GoodNav: Controls section with CONTEXTUAL All Rostered Players filters
    private var controlsSection: some View {
        HStack {
            // #GoodNav: CONTEXTUAL All Rostered Players controls
            HStack {
                Spacer()
                
                // Position/Sort Method with conditional arrow (replacing Top Score)
                HStack(spacing: 8) {
                    // Sort Method Menu
                    Menu {
                        ForEach(AllLivePlayersViewModel.SortingMethod.allCases) { method in
                            Button(method.displayName) {
                                viewModel.setSortingMethod(method)
                            }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(viewModel.sortingMethod.displayName.uppercased())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                            
                            // Show sort direction text when Score is selected, otherwise "Sort By"
                            Text(viewModel.sortingMethod == .score ? (sortHighToLow ? "Highest" : "Lowest") : "Sort By")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    // Sort Direction Arrow (only show for Score)
                    if viewModel.sortingMethod == .score {
                        Button(action: {
                            viewModel.toggleSortDirection()
                        }) {
                            // Up arrow for Highest (sortHighToLow = true), Down arrow for Lowest
                            Image(systemName: sortHighToLow ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gpGreen)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                // Position filter with picker
                Menu {
                    ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                        Button(position.displayName) {
                            viewModel.setPositionFilter(position)
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(viewModel.selectedPosition.displayName.uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.selectedPosition == .all ? .gpBlue : .purple)
                        
                        Text("Position")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                // Active Only toggle (toggles between "Yes" and "No")
                Button(action: { 
                    viewModel.setShowActiveOnly(!viewModel.showActiveOnly)
                }) {
                    VStack(spacing: 2) {
                        Text(viewModel.showActiveOnly ? "Yes" : "No")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.showActiveOnly ? .gpGreen : .gpRedPink)
                        
                        Text("Active Only")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            
            // Timer dial (existing refresh countdown)
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 30, height: 30)
                .overlay(
                    Text("\(Int(refreshCountdown))")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8) // 🔥 REDUCED: From 24 to 8 for tighter spacing
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
                color: viewModel.showActiveOnly ? .gpGreen : .gpRedPink
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
        // 🔥 FIXED: Manual refresh should do EXACTLY the same as the automatic 15-second timer
        // This ensures consistency between manual and automatic refreshes
        print("🔄 Manual refresh: Using same logic as 15-second timer")
        await performBackgroundRefresh()
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
        // 🔥 FIXED: Use silent live update instead of full refresh to prevent spinning orbs
        await viewModel.performLiveUpdate()
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