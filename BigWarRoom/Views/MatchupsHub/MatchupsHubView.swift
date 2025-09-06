//
//  MatchupsHubView.swift
//  BigWarRoom
//
//  The ultimate fantasy football command center - your personal war room
//

import SwiftUI

struct MatchupsHubView: View {
    @StateObject private var viewModel = MatchupsHubViewModel()
    @State private var showingMatchupDetail: UnifiedMatchup?
    @State private var refreshing = false
    @State private var cardAnimationStagger: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                backgroundGradient
                
                if viewModel.isLoading && viewModel.myMatchups.isEmpty {
                    // Initial loading state
                    loadingState
                } else if viewModel.myMatchups.isEmpty && !viewModel.isLoading {
                    // Empty state
                    emptyState
                } else {
                    // Matchups content
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
            if matchup.isChoppedLeague {
                // Show chopped league detail view
                if let choppedSummary = matchup.choppedSummary {
                    ChoppedLeaderboardView(
                        choppedSummary: choppedSummary,
                        leagueName: matchup.league.league.name
                    )
                }
            } else if let fantasyMatchup = matchup.fantasyMatchup {
                // Show regular matchup detail view
                let configuredViewModel = matchup.createConfiguredFantasyViewModel()
                FantasyMatchupDetailView(
                    matchup: fantasyMatchup,
                    fantasyViewModel: configuredViewModel,
                    leagueName: matchup.league.league.name
                )
            }
        }
    }
    
    // MARK: -> Background
    
    private var backgroundGradient: some View {
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
        .ignoresSafeArea()
    }
    
    // MARK: -> Loading State
    
    private var loadingState: some View {
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
    
    // MARK: -> Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated empty illustration
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.gpGreen.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "football")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.gpGreen)
                }
                
                VStack(spacing: 8) {
                    Text("No Active Matchups")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Connect your fantasy leagues to see your battles here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            // Setup button
            Button(action: {
                // TODO: Navigate to settings/setup
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("Connect Leagues")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: -> Matchups Content
    
    private var matchupsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Hero header
                heroHeader
                
                // Matchups section
                matchupsSection
                
                // Bottom padding for tab bar
                Color.clear.frame(height: 100)
            }
        }
    }
    
    private var heroHeader: some View {
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
            
            // Stats overview
            statsOverview
            
            // Last update info
            lastUpdateInfo
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    private var statsOverview: some View {
        HStack(spacing: 0) {
            statCard(
                value: "\(viewModel.myMatchups.count)",
                label: "MATCHUPS",
                color: .gpGreen
            )
            
            statCard(
                value: "WEEK \(currentNFLWeek)",
                label: "ACTIVE",
                color: .blue
            )
            
            statCard(
                value: "\(connectedLeaguesCount)",
                label: "LEAGUES",
                color: .purple
            )
        }
        .padding(.horizontal, 8)
    }
    
    private func statCard(value: String, label: String, color: Color) -> some View {
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
    
    private var lastUpdateInfo: some View {
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
            
            // Auto refresh indicator
            if viewModel.autoRefreshEnabled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                    
                    Text("Auto-refresh ON")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var matchupsSection: some View {
        VStack(spacing: 20) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sword.crossed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("ALL YOUR BATTLES")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("TOTAL: \(viewModel.myMatchups.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            
            // Powered by branding
            poweredByBranding
            
            // Matchup cards in 2-column grid - MASSIVE ROW SPACING 🔥
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(Array(viewModel.myMatchups.enumerated()), id: \.element.id) { index, matchup in
                    MatchupCardView(matchup: matchup) {
                        showingMatchupDetail = matchup
                    }
                    .padding(.bottom, 44) // INCREASED from 33 to 48 for even more massive row separation - space between rows
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        )
                    )
                    .onAppear {
                        // Staggered animation for cards
                        if cardAnimationStagger < Double(index) * 0.05 {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(index) * 0.05)) {
                                cardAnimationStagger = Double(index) * 0.05
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var poweredByBranding: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gpGreen)
                
                Text("POWERED BY BIG WAR ROOM")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
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
    
    // MARK: -> Computed Properties
    
    private var liveMatchupsCount: Int {
        viewModel.myMatchups.filter { $0.fantasyMatchup?.status == .live }.count
    }
    
    private var currentNFLWeek: Int {
        return NFLWeekService.shared.currentWeek
    }
    
    private var connectedLeaguesCount: Int {
        Set(viewModel.myMatchups.map { $0.league.id }).count
    }
    
    // MARK: -> Actions
    
    private func loadInitialData() {
        Task {
            await viewModel.loadAllMatchups()
        }
    }
    
    private func handlePullToRefresh() async {
        refreshing = true
        await viewModel.manualRefresh()
        refreshing = false
        
        // Force UI update after refresh
        await MainActor.run {
            // This will trigger view refresh
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: -> Auto-refresh timer for Mission Control
    @State private var refreshTimer: Timer?
    
    private func startPeriodicRefresh() {
        // Stop any existing timer first
        stopPeriodicRefresh()
        
        // Start new timer - refresh every 30 seconds when view is active
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active && !viewModel.isLoading {
                    print("🔄 AUTO-REFRESH: Refreshing Mission Control data...")
                    await viewModel.manualRefresh()
                }
            }
        }
        
        print("🚀 TIMER: Started Mission Control auto-refresh (30s intervals)")
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("🛑 TIMER: Stopped Mission Control auto-refresh")
    }
}

// MARK: -> Preview
#Preview {
    MatchupsHubView()
        .preferredColorScheme(.dark)
}
