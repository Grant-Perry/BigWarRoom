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
    @ObservedObject var allLivePlayersViewModel: AllLivePlayersViewModel
    @Binding var sortHighToLow: Bool
    @Binding var showingWeekPicker: Bool
    let onAnimationReset: () -> Void
    
    // New bindings for filters and watched players
    @Binding var showingFilters: Bool
    @Binding var showingWatchedPlayers: Bool
    
    // 🔥 NEW: Focus state for search TextField
    @FocusState private var isSearchFocused: Bool
    
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
            
            // Search bar (when active) - should appear RIGHT AFTER the week/icons row
            if allLivePlayersViewModel.isSearching {
                searchBarSection
            }
            
            // #GoodNav: Contextual controls row
            controlsSection
            
            // Stats Summary - REMOVED (keeping it clean)
            // statsOverviewSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 8)  // Minimal bottom padding
        .onAppear {
            // 🔥 FIX: Sync initial state between View and ViewModel
            sortHighToLow = allLivePlayersViewModel.sortHighToLow
            startGlobalRefreshCycle()
        }
        .onDisappear {
            stopGlobalRefreshCycle()
        }
        .onChange(of: allLivePlayersViewModel.sortHighToLow) { _, newValue in
            // 🔥 FIX: Keep View state in sync when ViewModel changes
            sortHighToLow = newValue
        }
        .onReceive(allLivePlayersViewModel.objectWillChange) { _ in
            // 🔥 FIX: Update stable manager when new data is available
            if let newManager = allLivePlayersViewModel.firstAvailableManager {
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
        VStack(spacing: 12) {
            // Main controls row (removed search bar from here)
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
                                    allLivePlayersViewModel.setSortingMethod(method)
                                }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(allLivePlayersViewModel.sortingMethod.displayName.uppercased())
                                    .font(.caption)  // Reduced from .subheadline to .caption
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                
                                // Show sort direction text when Score is selected, otherwise "Sort By"
                                Text(allLivePlayersViewModel.sortingMethod == .score ? (sortHighToLow ? "Highest" : "Lowest") : "Sort By")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        
                        // Sort Direction Arrow (only show for Score)
                        if allLivePlayersViewModel.sortingMethod == .score {
                            Button(action: {
                                allLivePlayersViewModel.toggleSortDirection()
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
                                allLivePlayersViewModel.setPositionFilter(position)
                            }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(allLivePlayersViewModel.selectedPosition.displayName.uppercased())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(allLivePlayersViewModel.selectedPosition == .all ? .gpBlue : .purple)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            
                            Text("Position")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                    
                    Spacer()
                    
                    // Active Only toggle (toggles between "Yes" and "No")
                    Button(action: { 
                        allLivePlayersViewModel.setShowActiveOnly(!allLivePlayersViewModel.showActiveOnly)
                    }) {
                        VStack(spacing: 2) {
                            Text(allLivePlayersViewModel.showActiveOnly ? "Yes" : "No")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(allLivePlayersViewModel.showActiveOnly ? .gpGreen : .gpRedPink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            
                            Text("Active Only")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Search toggle button
                    Button(action: {
                        if allLivePlayersViewModel.isSearching {
                            allLivePlayersViewModel.clearSearch()
                            isSearchFocused = false // Clear focus when closing search
                        } else {
                            allLivePlayersViewModel.isSearching = true
                            // 🔥 FIX: Focus the search field automatically when opening search
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        }
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: allLivePlayersViewModel.isSearching ? "xmark" : "magnifyingglass")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(allLivePlayersViewModel.isSearching ? .gpRedPink : .gpBlue)
                            
                            Text("Search")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                
                // Timer dial (existing refresh countdown)
                Circle()
                    .stroke(timerColor, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(Int(refreshCountdown))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Search Bar Section
    
    private var searchBarSection: some View {
        VStack(spacing: 8) {
            // Search input row
            HStack {
                TextField("Search players by name...", text: $allLivePlayersViewModel.searchText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    .focused($isSearchFocused) // 🔥 FIX: Connect focus state
                    .textInputAutocapitalization(.never) // 🔥 FIX: Turn off auto-capitalization
                    .autocorrectionDisabled() // 🔥 FIX: Also disable autocorrect for player names
                    .onAppear {
                        // 🔥 FIX: Auto-focus when search bar appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isSearchFocused = true
                        }
                    }
                    .onChange(of: allLivePlayersViewModel.searchText) { _, newValue in
                        allLivePlayersViewModel.setSearchText(newValue)
                    }
                
                Button("Cancel") {
                    allLivePlayersViewModel.clearSearch()
                    isSearchFocused = false // 🔥 FIX: Clear focus on cancel
                }
                .foregroundColor(.gpBlue)
            }
            
            // Search filters row
            HStack {
                // Rostered Only checkbox
                Button(action: {
                    allLivePlayersViewModel.toggleRosteredFilter()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: allLivePlayersViewModel.showRosteredOnly ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(allLivePlayersViewModel.showRosteredOnly ? .gpGreen : .secondary)
                        
                        Text("Rostered Only")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Results count
                Text("\(allLivePlayersViewModel.filteredPlayers.count) results")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)  // Increased top padding
        .safeAreaInset(edge: .top, spacing: 0) {
            // Invisible spacer to maintain safe area positioning
            Rectangle()
                .fill(Color.clear)
                .frame(height: 0)
        }
        .animation(.easeInOut(duration: 0.3), value: allLivePlayersViewModel.isSearching)
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
                value: String(format: "%.1f", allLivePlayersViewModel.topScore),
                label: "TOP SCORE",
                color: .gpGreen
            )
            
            StatCardView(
                value: allLivePlayersViewModel.selectedPosition.displayName.uppercased(),
                label: "POSITION",
                color: .purple
            )
            
            StatCardView(
                value: allLivePlayersViewModel.showActiveOnly ? "YES" : "NO",
                label: "ACTIVE ONLY",
                color: allLivePlayersViewModel.showActiveOnly ? .gpGreen : .gpRedPink
            )
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper Methods
    
    private var timerColor: Color {
        let progress = refreshCountdown / Double(AppConstants.MatchupRefresh)
        
        if progress > 0.66 {
            return .gpGreen
        } else if progress > 0.33 {
            return .orange
        } else {
            return .gpRedPink
        }
    }
    
    private func getOverallPerformanceEmoji() -> String {
        let totalPlayers = allLivePlayersViewModel.filteredPlayers.count
        let highPerformers = allLivePlayersViewModel.filteredPlayers.filter { $0.currentScore > 15.0 }.count
        let lowPerformers = allLivePlayersViewModel.filteredPlayers.filter { $0.currentScore < 5.0 }.count
        
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
        return allLivePlayersViewModel.firstAvailableManager ?? stableManager
    }
    
    // MARK: - Background Refresh (No UI Resets)
    private func performBackgroundRefresh() async {
        // 🔥 FIXED: Use silent live update instead of full refresh to prevent spinning orbs
        await allLivePlayersViewModel.performLiveUpdate()
        resetCountdown()
        // DO NOT call onAnimationReset() here - that causes the jarring refresh
    }
    
    // 🔥 NEW: Refresh with UI reset - for manual refresh button
    private func performRefreshWithReset() async {
        // 🔥 NUCLEAR OPTION: Complete state reset to fix filtering bugs
        await allLivePlayersViewModel.hardResetFilteringState()
        onAnimationReset() // Reset animations and UI state
        resetCountdown()
    }
    
    // MARK: - Global Refresh Cycle Management
    private func startGlobalRefreshCycle() {
        stopGlobalRefreshCycle()
        
        // Initialize stable manager on first load
        if let manager = allLivePlayersViewModel.firstAvailableManager {
            stableManager = manager
        }
        
        // 🔥 DISABLED: Removed competing timer - MatchupsHubViewModel handles all auto-refresh
        // Individual views should not create their own refresh timers to prevent conflicts
        // Only MatchupsHubViewModel.shared should control the global refresh cycle
        
        // Start the actual refresh timer (every 15 seconds)
        // refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
        //     Task { @MainActor in
        //         if UIApplication.shared.applicationState == .active && !allLivePlayersViewModel.isLoading {
        //             // Background refresh without UI disruption
        //             await performBackgroundRefresh()
        //         }
        //     }
        // }
        
        // Keep the visual countdown timer only (every 1 second)
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