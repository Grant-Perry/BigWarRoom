//
//  MatchupsHubView+UI.swift
//  BigWarRoom
//
//  UI components and layouts for MatchupsHubView
//

import SwiftUI

// MARK: - UI Components
extension MatchupsHubView {
    
    // MARK: - Background & Layout
    var backgroundGradient: some View {
        ZStack {
            // Original background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.9),
                    Color.gpGreen.opacity(0.1),
                    Color.black.opacity(0.9),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // NEW: Overall nyyDark gradient overlay
            LinearGradient(
                colors: [Color.nyyDark.opacity(0.6), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Loading State
    var loadingState: some View {
        VStack {
            Spacer()
            
            MatchupsHubLoadingIndicator(
                currentLeague: viewModel.currentLoadingLeague,
                progress: viewModel.loadingProgress,
                loadingStates: viewModel.loadingStates
            )
            
            Spacer()
        }
    }
    
    // MARK: - Matchups Content
    var matchupsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroHeader
                matchupsSection // Remove spacing between heroHeader and matchupsSection
                Color.clear.frame(height: 100) // Bottom padding for tab bar
            }
        }
        .onAppear {
            // Start 5-second timer to auto-collapse "Powered By" section
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    poweredByExpanded = false
                }
            }
        }
    }
    
    // MARK: - Hero Header
    var heroHeader: some View {
        VStack(spacing: 16) {
            // Mission Control title
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gpGreen)
                    
                    Text("MISSION CONTROL")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .gpGreen.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Image(systemName: "rocket")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.gpGreen)
                }
                
                Text("Fantasy Football Command Center")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            statsOverview
            lastUpdateInfo
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8) // Reduced from 24 to 8 to tighten gap
    }
    
    // MARK: - Stats Overview
    var statsOverview: some View {
        HStack(spacing: 0) {
            statCard(
                value: "\(viewModel.myMatchups.count)",
                label: "MATCHUPS",
                color: .gpGreen
            )
            
            Button(action: { showWeekPicker() }) {
                statCard(
                    value: "WEEK \(weekManager.selectedWeek)",
                    label: "ACTIVE",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            statCard(
                value: "\(connectedLeaguesCount)",
                label: "LEAGUES",
                color: .purple
            )
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Stat Card Helper
    func statCard(value: String, label: String, color: Color) -> some View {
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
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Last Update Info
    var lastUpdateInfo: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(.gpGreen)
            
            if let lastUpdate = viewModel.lastUpdateTime {
                Text("Last Update: \(timeAgo(lastUpdate))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("Ready to load your battles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 🔥 NEW: Auto-refresh toggle - same style as other toggles
            VStack(spacing: 2) {
                Text(viewModel.autoRefreshEnabled ? "On" : "Off")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(viewModel.autoRefreshEnabled ? .gpGreen : .gpRedPink)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleAutoRefresh()
                            
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                
                Text("Auto-refresh")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Matchups Section
    var matchupsSection: some View {
        VStack(spacing: 20) {
            matchupsSectionHeader
            
            // Always show the powered by section (controlled by poweredByExpanded)
            if poweredByExpanded {
                poweredByBranding
            }
            
            // Just Me Mode Banner (when microMode is enabled)
            if microMode {
                justMeModeBanner
            }
            
            // 🔥 NEW: Extra spacing before cards when powered by section is collapsed
            if !poweredByExpanded {
                Color.clear.frame(height: 4) // 🔥 CHANGED: Reduced to 8pt spacing when collapsed
            }
            
            // Always show the sort toggle and matchup cards (not controlled by battlesMinimized anymore)
            sortByToggle
            matchupCardsGrid
        }
    }

    // MARK: - Just Me Mode Banner
    private var justMeModeBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("🙍")
                    .font(.system(size: 16))
                
                Text("JUST ME MODE")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("💎")
                    .font(.system(size: 16))
            }
            
            Text("Focus view - your performance only")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    // 🔥 NEW: Same gradient background as overall theme using nyyDark
                    LinearGradient(
                        colors: [
                            Color.nyyDark.opacity(0.8),
                            Color.nyyDark.opacity(0.6), 
                            Color.black.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.gpGreen.opacity(0.4), .blue.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Section Header
    private var matchupsSectionHeader: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    poweredByExpanded.toggle() // Control only the "Powered By" section
                }
            }) {
                Image(systemName: poweredByExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Even spacing across the row
            HStack {
                Spacer()
                
                // 1. Winning/Losing toggle
                VStack(spacing: 2) {
                    Text(sortByWinning ? "Winning" : "Losing")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(sortByWinning ? .gpGreen : .gpRedPink)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                sortByWinning.toggle()
                                
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                    
                    Text("Sort")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 2. Dual/Single view toggle
                VStack(spacing: 2) {
                    Text(dualViewMode ? "Dual" : "Single")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(dualViewMode ? .blue : .orange)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dualViewMode.toggle()
                                expandedCardId = nil
                                
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                    
                    Text("View")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 3. Just me mode toggle
                VStack(spacing: 2) {
                    Text(microMode ? "On" : "Off")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(microMode ? .gpGreen : .gpRedPink) // 🔥 CHANGED: Off is now .gpRedPink instead of .gray
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                microMode.toggle()
                                expandedCardId = nil
                                
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                    
                    Text("Just me")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 🔥 NEW: Timer dial moved to trailing edge of same row
            PollingCountdownDial(
                countdown: refreshCountdown,
                maxInterval: Double(AppConstants.MatchupRefresh),
                isPolling: viewModel.autoRefreshEnabled,
                onRefresh: {
                    Task {
                        await handlePullToRefresh()
                    }
                }
            )
            .scaleEffect(0.8)
            .onAppear {
                startCountdownTimer()
            }
            .onDisappear {
                stopCountdownTimer()
            }
        }
        .padding(.horizontal, 20)
    }

    // 🔥 REMOVED: Old sortByToggle since timer is now in header
    var sortByToggle: some View {
        // Empty view since timer moved to header
        EmptyView()
    }

    // MARK: - Minimized Summary
    var minimizedBattlesSummary: some View {
        HStack {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    summaryStatItem("\(viewModel.myMatchups.count)", "Battles", .gpGreen)
                    summaryStatItem("\(liveMatchupsCount)", "Live", .blue)
                    
                    let winningCount = sortedMatchups.filter { getWinningStatusForMatchup($0) }.count
                    summaryStatItem("\(winningCount)", "Winning", .gpGreen)
                }
            }
            
            Spacer()
            
            Text("Tap to expand")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                battlesMinimized = false
            }
        }
    }
    
    // MARK: - Summary Stat Item Helper
    private func summaryStatItem(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Powered By Branding
    var poweredByBranding: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("POWERED BY BIG WARROOM")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
            }
            
            Text("The ultimate fantasy football command center")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.gpGreen.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Matchup Cards Grid
    @ViewBuilder
    var matchupCardsGrid: some View {
        LazyVGrid(
            columns: microMode ? 
            [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ] :
            // 🔥 NEW: Dynamic columns based on dualViewMode toggle
            dualViewMode ?
            [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ] :
            [
                GridItem(.flexible(), spacing: 0) // Single column for horizontal view
            ],
            spacing: microMode ? 8 : (dualViewMode ? 16 : 12)
        ) {
            ForEach(sortedMatchups, id: \.id) { matchup in
                MatchupCardViewBuilder(
                    matchup: matchup,
                    microMode: microMode,
                    expandedCardId: expandedCardId,
                    isWinning: getWinningStatusForMatchup(matchup),
                    onShowDetail: {
                        showingMatchupDetail = matchup
                    },
                    onMicroCardTap: { cardId in
                        handleMicroCardTap(cardId)
                    },
                    dualViewMode: dualViewMode // 🔥 NEW: Pass dualViewMode parameter (moved to end)
                )
            }
        }
        .padding(.horizontal, 20)
        // FIXED: Much faster animations - no more 1.0 second delays!
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: sortByWinning)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dualViewMode) // 🔥 NEW: Animation for view mode changes
        .overlay(
            expandedCardOverlay
        )
    }
    
    // MARK: - Expanded Card Overlay
    @ViewBuilder
    private var expandedCardOverlay: some View {
        if let expandedId = expandedCardId,
           let expandedMatchup = sortedMatchups.first(where: { $0.id == expandedId }) {
            
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        expandedCardId = nil
                    }
                }
            
            NonMicroCardView(
                matchup: expandedMatchup,
                isWinning: getWinningStatusForMatchup(expandedMatchup)
            ) {
                showingMatchupDetail = expandedMatchup
            }
            .frame(width: UIScreen.main.bounds.width * 0.6, height: 205)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen, .blue, .gpGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
            .zIndex(1000)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    expandedCardId = nil
                }
            }
        }
    }
    
    // MARK: - Sheet Views
    @ViewBuilder
    func matchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        if matchup.isChoppedLeague {
            if let choppedSummary = matchup.choppedSummary {
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: matchup.league.league.name,
                    leagueID: matchup.league.league.leagueID
                )
            }
        } else if let fantasyMatchup = matchup.fantasyMatchup {
            let configuredViewModel = matchup.createConfiguredFantasyViewModel()
            FantasyMatchupDetailView(
                matchup: fantasyMatchup,
                fantasyViewModel: configuredViewModel,
                leagueName: matchup.league.league.name
            )
        }
    }

    var weekPickerSheet: some View {
        WeekPickerView(
            isPresented: $showingWeekPicker
        )
    }
}