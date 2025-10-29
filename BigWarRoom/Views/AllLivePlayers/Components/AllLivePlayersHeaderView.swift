//
//  AllLivePlayersHeaderView.swift
//  BigWarRoom
//
//  Header view with manager info, filters, and stats for All Live Players
//

import SwiftUI

/// Complete header section with manager info, controls, and stats
struct AllLivePlayersHeaderView: View {
    @Bindable var allLivePlayersViewModel: AllLivePlayersViewModel
    @Binding var sortHighToLow: Bool
    @Binding var showingWeekPicker: Bool
    let onAnimationReset: () -> Void
    
    // New bindings for filters and watched players
    @Binding var showingFilters: Bool
    @Binding var showingWatchedPlayers: Bool
    
    // 🔥 PHASE 2.5: Accept dependencies instead of using .shared
    private let watchService: PlayerWatchService
    private let weekManager: WeekSelectionManager
    
    // 🔥 NEW: Focus state for search TextField
    @FocusState private var isSearchFocused: Bool
    
    // Timer states for actual refresh cycle - using @State to prevent full view redraws
    @State private var refreshCountdown: Double = Double(AppConstants.MatchupRefresh)
    @State private var countdownTimer: Timer?
    @State private var refreshTimer: Timer?
    
    // 🔥 FIX: Maintain stable manager info during refreshes
    @State private var stableManager: ManagerInfo?
    
    // 🔥 PHASE 2.5: Dependency injection initializer
    init(
        allLivePlayersViewModel: AllLivePlayersViewModel,
        sortHighToLow: Binding<Bool>,
        showingWeekPicker: Binding<Bool>,
        onAnimationReset: @escaping () -> Void,
        showingFilters: Binding<Bool>,
        showingWatchedPlayers: Binding<Bool>,
        watchService: PlayerWatchService,
        weekManager: WeekSelectionManager
    ) {
        self.allLivePlayersViewModel = allLivePlayersViewModel
        self._sortHighToLow = sortHighToLow
        self._showingWeekPicker = showingWeekPicker
        self.onAnimationReset = onAnimationReset
        self._showingFilters = showingFilters
        self._showingWatchedPlayers = showingWatchedPlayers
        self.watchService = watchService
        self.weekManager = weekManager
    }

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
            
            // 🔥 FIX: Set initial stable manager when view appears
            if let newManager = allLivePlayersViewModel.firstAvailableManager {
                stableManager = newManager
            }
        }
        .onDisappear {
            stopGlobalRefreshCycle()
        }
        .onChange(of: allLivePlayersViewModel.sortHighToLow) { _, newValue in
            // 🔥 FIX: Keep View state in sync when ViewModel changes
            sortHighToLow = newValue
        }
        .onChange(of: allLivePlayersViewModel.firstAvailableManager) { _, newManager in
            // 🔥 FIX: Update stable manager when new data is available using @Observable onChange
            if let newManager = newManager {
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
            
            // 🔥 NEW: Total points display 
            Text("Total: \(totalPointsFormatted)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.gpGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gpGreen.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                        )
                )
                .animation(.easeInOut(duration: 0.3), value: totalPoints)
            
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
                
                // Timer dial with sweep animation, number swipe, and external glow
                ZStack {
                    // 🔥 External glow layers (multiple for depth)
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(timerColor.opacity(0.15 - Double(index) * 0.05))
                            .frame(width: 45 + CGFloat(index * 8), height: 45 + CGFloat(index * 8))
                            .blur(radius: CGFloat(4 + index * 3))
                            .animation(.easeInOut(duration: 0.8), value: timerColor)
                            .scaleEffect(refreshCountdown < 3 ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: refreshCountdown < 3)
                    }
                    
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
                            .frame(width: 32, height: 32)
                        
                        // 🔥 Circular sweep progress
                        Circle()
                            .trim(from: 0, to: timerProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [timerColor, timerColor.opacity(0.6), timerColor],
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: timerProgress)
                        
                        // Center fill
                        Circle()
                            .fill(timerColor.opacity(0.15))
                            .frame(width: 27, height: 27)
                            .animation(.easeInOut(duration: 0.3), value: timerColor)
                        
                        // 🔥 Timer text with swipe animation
                        ZStack {
                            Text("\(Int(refreshCountdown))")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: timerColor.opacity(0.8), radius: 2, x: 0, y: 1)
                                .scaleEffect(refreshCountdown < 3 ? 1.1 : 1.0)
                                .id("live-timer-\(Int(refreshCountdown))") // 🔥 Unique ID for transition
                                .transition(
                                    .asymmetric(
                                        insertion: AnyTransition.move(edge: .leading)
                                            .combined(with: .scale(scale: 0.8))
                                            .combined(with: .opacity),
                                        removal: AnyTransition.move(edge: .trailing)
                                            .combined(with: .scale(scale: 1.2))
                                            .combined(with: .opacity)
                                    )
                                )
                        }
                        .frame(width: 14, height: 14) // Fixed frame to prevent layout shifts
                        .clipped()
                        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1), value: Int(refreshCountdown))
                    }
                }
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
    
    // 🔥 NEW: Total points calculation - GUARANTEED LIVE
    private var totalPoints: Double {
        // 🔥 Force recalculation on every live update by depending on lastUpdateTime
        let _ = allLivePlayersViewModel.lastUpdateTime
        
        return allLivePlayersViewModel.filteredPlayers.reduce(0) { total, player in
            total + player.currentScore
        }
    }
    
    private var totalPointsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        return formatter.string(from: NSNumber(value: totalPoints)) ?? "0.00"
    }
    
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
    
    // 🔥 NEW: Timer progress for scaling effect
    private var timerProgress: Double {
        let progress = refreshCountdown / Double(AppConstants.MatchupRefresh)
        return 0.3 + (progress * 0.7) // Scale from 30% to 100%
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
        
        // 🔥 ENABLED: Restore AllLivePlayersView auto-refresh timer to fix live updates
        // This timer was previously disabled causing the missing automatic refresh issue
        
        // Start the actual refresh timer (every 15 seconds)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(AppConstants.MatchupRefresh), repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !allLivePlayersViewModel.isLoading {
                    // Background refresh without UI disruption
                    await performBackgroundRefresh()
                }
            }
        }
        
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