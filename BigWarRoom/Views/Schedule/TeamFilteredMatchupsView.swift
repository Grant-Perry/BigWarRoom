//
//  TeamFilteredMatchupsView.swift
//  BigWarRoom
//
//  Sheet view showing fantasy matchups filtered by selected NFL teams
//

import SwiftUI

/// Sheet view for team-filtered matchups (DRY - reuses Mission Control components)
struct TeamFilteredMatchupsView: View {
    
    // MARK: - Properties
    let awayTeam: String
    let homeTeam: String
    
    // MARK: - ViewModels
    @StateObject private var viewModel: TeamFilteredMatchupsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UI State (reusing Mission Control patterns)
    @State private var showingMatchupDetail: UnifiedMatchup?
    @State private var refreshing = false
    @State private var sortByWinning = true
    @State private var microMode = false
    @State private var expandedCardId: String? = nil
    
    // MARK: - Initialization
    init(awayTeam: String, homeTeam: String, matchupsHubViewModel: MatchupsHubViewModel) {
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self._viewModel = StateObject(wrappedValue: TeamFilteredMatchupsViewModel(matchupsHubViewModel: matchupsHubViewModel))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Same background as Mission Control
                buildBackgroundView()
                
                if viewModel.isLoading && viewModel.filteredMatchups.isEmpty {
                    buildLoadingView()
                } else if !viewModel.hasMatchups && !viewModel.isLoading {
                    buildEmptyStateView()
                } else {
                    buildContentView()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                viewModel.filterMatchups(awayTeam: awayTeam, homeTeam: homeTeam)
            }
            .refreshable {
                await handlePullToRefresh()
            }
        }
        .sheet(item: $showingMatchupDetail) { matchup in
            buildMatchupDetailSheet(for: matchup)
        }
    }
    
    // MARK: - Background (reuse Mission Control)
    private func buildBackgroundView() -> some View {
        // Use BG5 asset with reduced opacity
        Image("BG5")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.35)
            .ignoresSafeArea(.all)
    }
    
    // MARK: - Loading View
    private func buildLoadingView() -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Loading matchups...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Empty State View
    private func buildEmptyStateView() -> some View {
        VStack(spacing: 20) {
            // Header with team logos
            buildFilteredHeader()
            
            Spacer()
            
            // Empty state content
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Away team logo
                    TeamLogoView(teamCode: awayTeam, size: 60)
                        .frame(width: 60, height: 60)
                    
                    Text("NO MATCHUPS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Home team logo  
                    TeamLogoView(teamCode: homeTeam, size: 60)
                        .frame(width: 60, height: 60)
                }
                
                Text("You don't have any players from \(awayTeam) or \(homeTeam)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Close button
            Button("Close") {
                dismiss()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium))
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Content View (reuse Mission Control components)
    private func buildContentView() -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 24) { // Increased spacing from 16 to 24
                // Filtered header
                buildFilteredHeader()
                
                // Stats overview (reuse Mission Control component)
                buildStatsOverview()
                    .padding(.bottom, 8) // Add extra bottom padding to stats
                
                // Matchup cards (reuse Mission Control grid)
                buildMatchupCards()
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Filtered Header
    private func buildFilteredHeader() -> some View {
        VStack(spacing: 16) {
            // Close button
            HStack {
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
            
            // "MATCHUPS FOR" centered header
            Text("MATCHUPS FOR")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Team section with gradient background and border (back to original width)
            VStack(spacing: 8) {
                // Large team logos (styled like Schedule cards)
                HStack(spacing: 24) {
                    // Away team logo - bleeding off edges
                    ZStack {
                        TeamLogoView(teamCode: awayTeam, size: 140)
                            .scaleEffect(1.1)
                            .clipped()
                    }
                    .frame(width: 80, height: 60)
                    .clipShape(Rectangle())
                    .offset(x: -10, y: -8) // Bleed off leading and top edges
                    
                    // Game info section (VS + score/status)
                    VStack(spacing: 4) {
                        Text("vs")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Game score and status
                        buildGameInfo()
                    }
                    
                    // Home team logo - bleeding off edges
                    ZStack {
                        TeamLogoView(teamCode: homeTeam, size: 140)
                            .scaleEffect(1.1)
                            .clipped()
                    }
                    .frame(width: 80, height: 60)
                    .clipShape(Rectangle())
                    .offset(x: 10, y: -8) // Bleed off trailing and top edges
                }
                
                // Matchup count
                Text("\(viewModel.filteredMatchups.count) matchup\(viewModel.filteredMatchups.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                // .nyyPrimary gradient background with opacity
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.nyyPrimary.opacity(0.4),
                                Color.nyyPrimary.opacity(0.2),
                                Color.nyyPrimary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                // Conditional border with reduced opacity
                RoundedRectangle(cornerRadius: 16)
                    .stroke((isGameLive ? Color.gpGreen : Color.white).opacity(0.3), lineWidth: 2)
            )
            .clipped() // Clip the entire container to hide overflowing logos
        }
    }
    
    // MARK: - Helper to check if game is live
    private var isGameLive: Bool {
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: awayTeam) {
            return gameInfo.isLive
        }
        return false
    }
    
    // MARK: - Game Info Display
    private func buildGameInfo() -> some View {
        Group {
            if let gameInfo = NFLGameDataService.shared.getGameInfo(for: awayTeam) {
                VStack(spacing: 2) {
                    // Score display (if game has started)
                    if gameInfo.awayScore > 0 || gameInfo.homeScore > 0 {
                        HStack(spacing: 6) {
                            // Away team score
                            Text("\(gameInfo.awayScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(gameInfo.awayScore > gameInfo.homeScore ? .gpGreen : .white)
                            
                            Text("-")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Home team score  
                            Text("\(gameInfo.homeScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(gameInfo.homeScore > gameInfo.awayScore ? .gpGreen : .white)
                        }
                    }
                    
                    // Game status/time
                    Text(gameInfo.displayTime)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(gameInfo.isLive ? .red : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            gameInfo.isLive ? 
                            AnyView(Capsule().fill(Color.red.opacity(0.2))) :
                            AnyView(Color.clear)
                        )
                }
            }
        }
    }
    
    // MARK: - Helper function to get team color
    private func getTeamColor(for teamCode: String) -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    // MARK: - Stats Overview (reuse Mission Control)
    private func buildStatsOverview() -> some View {
        let sortedMatchups = viewModel.sortedMatchups(sortByWinning: sortByWinning)
        
        return HStack(spacing: 40) { // Reduced spacing to bring them closer together
            // Live matchups
            StatBlock(
                title: "LIVE",
                value: "\(viewModel.liveMatchupsCount())",
                color: .red
            )
            
            // Winning matchups
            StatBlock(
                title: "WINNING",
                value: "\(viewModel.winningMatchupsCount())",
                color: .gpGreen
            )
            
            // Total matchups
            StatBlock(
                title: "TOTAL",
                value: "\(sortedMatchups.count)",
                color: .white
            )
        }
        .frame(maxWidth: 280) // Constrain the width to bring them together
        .frame(maxWidth: .infinity) // But center the constrained group
    }
    
    // MARK: - Matchup Cards (reuse Mission Control grid)
    private func buildMatchupCards() -> some View {
        let sortedMatchups = viewModel.sortedMatchups(sortByWinning: sortByWinning)
        
        // Copy Mission Control's exact grid layout
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), // 2 columns like Mission Control
            spacing: 16 // Same spacing as Mission Control
        ) {
            ForEach(sortedMatchups) { matchup in
                MatchupCardViewBuilder(
                    matchup: matchup,
                    microMode: microMode,
                    expandedCardId: expandedCardId,
                    isWinning: viewModel.getWinningStatusForMatchup(matchup),
                    onShowDetail: {
                        showingMatchupDetail = matchup
                    },
                    onMicroCardTap: { cardId in
                        expandedCardId = (expandedCardId == cardId) ? nil : cardId
                    },
                    dualViewMode: true // Use dual view mode for 2-column layout
                )
            }
        }
        .padding(.horizontal, 20) // Add proper edge padding to prevent clipping - same as Mission Control
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
    }
    
    // MARK: - Matchup Detail Sheet (reuse Mission Control)
    private func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        let configuredViewModel = matchup.createConfiguredFantasyViewModel()
        
        if matchup.isChoppedLeague {
            return AnyView(
                ChoppedLeaderboardView(
                    choppedSummary: matchup.choppedSummary!,
                    leagueName: matchup.league.league.name,
                    leagueID: matchup.league.league.id
                )
            )
        } else {
            return AnyView(
                FantasyMatchupDetailView(
                    matchup: matchup.fantasyMatchup!,
                    fantasyViewModel: configuredViewModel,
                    leagueName: matchup.league.league.name
                )
            )
        }
    }
    
    // MARK: - Pull to Refresh
    private func handlePullToRefresh() async {
        refreshing = true
        await viewModel.refresh()
        refreshing = false
    }
}

#Preview("Team Filtered Matchups - With Data") {
    TeamFilteredMatchupsView(
        awayTeam: "WSH", 
        homeTeam: "GB",
        matchupsHubViewModel: MatchupsHubViewModel()
    )
    .preferredColorScheme(.dark)
}

#Preview("Team Filtered Matchups - Empty") {
    TeamFilteredMatchupsView(
        awayTeam: "JAX",
        homeTeam: "TEN", 
        matchupsHubViewModel: MatchupsHubViewModel()
    )
    .preferredColorScheme(.dark)
}