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
    let gameData: ScheduleGame? // 🔥 NEW: Pass actual game data to avoid NFLGameDataService lookup
    let rootDismiss: (() -> Void)? // 🔥 NEW: Optional closure to dismiss entire sheet stack
    
    // MARK: - ViewModels
    @StateObject private var viewModel: TeamFilteredMatchupsViewModel
    @StateObject private var standingsService = NFLStandingsService.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UI State (reusing Mission Control patterns)
    @State private var showingMatchupDetail: UnifiedMatchup?
    @State private var refreshing = false
    @State private var sortByWinning = true
    @State private var microMode = false
    @State private var expandedCardId: String? = nil
    
    // 🔥 FIXED: Team roster navigation state - SIMPLIFIED TO PREVENT LOOPS
    @State private var showingTeamRoster: String?
    
    // MARK: - Initialization
    init(awayTeam: String, homeTeam: String, matchupsHubViewModel: MatchupsHubViewModel, gameData: ScheduleGame? = nil, rootDismiss: (() -> Void)? = nil) {
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.gameData = gameData // 🔥 NEW: Store actual game data
        self.rootDismiss = rootDismiss // 🔥 NEW: Store root dismiss closure
        self._viewModel = StateObject(wrappedValue: TeamFilteredMatchupsViewModel(matchupsHubViewModel: matchupsHubViewModel))
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Background changes based on loading state
                buildBackgroundView()
                
                if viewModel.shouldShowLoadingState {
                    buildLoadingView()
                } else if !viewModel.hasMatchups {
                    buildEmptyStateView()
                } else {
                    buildContentView()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onAppear {
                print("🔍 SHEET DEBUG: TeamFilteredMatchupsView appeared")
                print("🔍 SHEET DEBUG: Away team: \(awayTeam), Home team: \(homeTeam)")
                print("🔍 SHEET DEBUG: Passed game data: \(gameData?.scoreDisplay ?? "nil")")
                print("🔍 SHEET DEBUG: shouldShowLoadingState: \(viewModel.shouldShowLoadingState)")
                
                // Use the game object if available, otherwise fall back to team strings
                if let gameData = gameData {
                    print("🔍 SHEET DEBUG: Using passed game data for filtering")
                    viewModel.filterMatchups(for: gameData)
                } else {
                    print("🔍 SHEET DEBUG: Falling back to team strings for filtering")
                    viewModel.filterMatchups(awayTeam: awayTeam, homeTeam: homeTeam)
                }
                
                print("🔍 SHEET DEBUG: After filterMatchups call - shouldShowLoadingState: \(viewModel.shouldShowLoadingState)")
            }
            .onDisappear {
                print("🔍 SHEET DEBUG: TeamFilteredMatchupsView disappeared - clearing filter state")
                viewModel.clearFilterState()
            }
            .refreshable {
                await handlePullToRefresh()
            }
        }
        .sheet(item: $showingMatchupDetail) { matchup in
            buildMatchupDetailSheet(for: matchup)
        }
        .sheet(item: Binding<TeamRosterSheetInfo?>(
            get: { showingTeamRoster.map { TeamRosterSheetInfo(teamCode: $0) } },
            set: { showingTeamRoster = $0?.teamCode }
        )) { teamInfo in
            buildTeamRosterSheet(for: teamInfo.teamCode)
        }
    }
    
    // MARK: - Background (reuse Mission Control)
    private func buildBackgroundView() -> some View {
        // Use BG3 asset with reduced opacity for loading states, BG5 for content
        Image(viewModel.shouldShowLoadingState ? "BG3" : "BG5")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(viewModel.shouldShowLoadingState ? 0.25 : 0.35)
            .ignoresSafeArea(.all)
    }
    
    // MARK: - Loading View
    private func buildLoadingView() -> some View {
        ZStack {
            // BG3 background is handled by buildBackgroundView()
            
            VStack(spacing: 24) {
                // Header with team logos (even during loading)
                buildFilteredHeader()
                
                Spacer()
                
                // Main loading section
                VStack(spacing: 20) {
                    // Animated team logos during loading
                    HStack(spacing: 32) {
                        // Away team logo with pulse animation
                        TeamLogoView(teamCode: awayTeam, size: 80)
                            .frame(width: 80, height: 80)
                            .scaleEffect(1.1)
                            .opacity(0.9)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
                        
                        // VS text with glow
                        Text("vs")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.3), radius: 8)
                        
                        // Home team logo with pulse animation (offset timing)
                        TeamLogoView(teamCode: homeTeam, size: 80)
                            .frame(width: 80, height: 80)
                            .scaleEffect(1.1)
                            .opacity(0.9)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5), value: true)
                    }
                    
                    // Glowing progress indicator
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .shadow(color: .white.opacity(0.3), radius: 8)
                        
                        Text("Loading your \(awayTeam) vs \(homeTeam) matchups...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        
                        // Subtle loading dots animation
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.2)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                        value: true
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Loading tips/info
                VStack(spacing: 8) {
                    Text("🔍 Analyzing fantasy rosters...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("This might take a moment if you have many leagues")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
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
            // Close button - X dismisses current sheet only
            HStack {
                // 🔥 NEW: DONE button to collapse entire sheet stack
                if let rootDismiss = rootDismiss {
                    Button(action: { rootDismiss() }) {
                        Text("DONE")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                } else {
                    // Spacer when no DONE button
                    Color.clear.frame(width: 60, height: 32)
                }
                
                Spacer()
                
                // X button - dismisses current sheet only
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
            
            // Team section with gradient background and prominent border
            VStack(spacing: 8) {
                // Large team logos (styled like Schedule cards)
                HStack(spacing: 24) {
                    // Away team section
                    VStack(spacing: 4) { // Reduced spacing from 6 to 4
                        Button(action: {
                            print("🏈 SCHEDULE: Tapped away team logo for \(awayTeam)")
                            showTeamRoster(for: awayTeam)
                        }) {
                            ZStack {
                                TeamLogoView(teamCode: awayTeam, size: 140)
                                    .scaleEffect(0.75)
                                    .clipped()
                            }
                            .frame(width: 90, height: 60) // Increased width from 80 to 90
                            .clipShape(Rectangle())
                            .offset(x: -10, y: -8) // Bleed off leading and top edges
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Away team name - centered and smaller font
                        Text(getTeamName(for: awayTeam))
                            .font(.system(size: 14, weight: .bold)) // Reduced from 16 to 14
                            .foregroundColor(.white)
                            .lineLimit(2) // Allow 2 lines for city + team name
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center) // Center the text
                            .frame(width: 90) // Match logo width for centering
                        
                        // Away team record - reduced spacing
                        Text(getTeamRecord(for: awayTeam))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Game info section (VS + score/status) - MOVED SCORES HERE
                    VStack(spacing: 6) {
                        Text("vs")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Game score and status - REPOSITIONED AND ENHANCED
                        buildGameInfo()
                    }
                    
                    // Home team section
                    VStack(spacing: 4) { // Reduced spacing from 6 to 4
                        Button(action: {
                            print("🏈 SCHEDULE: Tapped home team logo for \(homeTeam)")
                            showTeamRoster(for: homeTeam)
                        }) {
                            ZStack {
                                TeamLogoView(teamCode: homeTeam, size: 140)
                                    .scaleEffect(0.75)
                                    .clipped()
                            }
                            .frame(width: 90, height: 60) // Increased width from 80 to 90
                            .clipShape(Rectangle())
                            .offset(x: 10, y: -8) // Bleed off trailing and top edges
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Home team name - centered and smaller font
                        Text(getTeamName(for: homeTeam))
                            .font(.system(size: 14, weight: .bold)) // Reduced from 16 to 14
                            .foregroundColor(.white)
                            .lineLimit(2) // Allow 2 lines for city + team name
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center) // Center the text
                            .frame(width: 90) // Match logo width for centering
                        
                        // Home team record - reduced spacing
                        Text(getTeamRecord(for: homeTeam))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Matchup count - changed to "Players in X matchups"
                Text("Players in \(viewModel.filteredMatchups.count) matchup\(viewModel.filteredMatchups.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                // .nyyPrimary gradient background with opacity 0.75
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
                    .opacity(0.75) // Added .opacity(0.75) to the background
            )
            .overlay(
                // More prominent border
                RoundedRectangle(cornerRadius: 16)
                    .stroke((isGameLive ? Color.gpGreen : Color.white), lineWidth: 3) // Increased from 2 to 3 and removed opacity for more prominence
            )
        }
    }
    
    // MARK: - Helper to check if game is live
    private var isGameLive: Bool {
        // 🔥 FIXED: Use passed gameData first, then fallback to service lookup
        if let gameData = gameData {
            return gameData.isLive
        }
        
        // Fallback to service lookup (original behavior)
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: awayTeam) {
            return gameInfo.isLive
        }
        return false
    }
    
    // MARK: - Game Info Display - REVERTED TO ORIGINAL
    private func buildGameInfo() -> some View {
        Group {
            // 🔥 FIXED: Use passed gameData first, then fallback to service lookup
            if let gameData = gameData {
                VStack(spacing: 2) {
                    // Score display (if game has started)
                    if gameData.awayScore > 0 || gameData.homeScore > 0 {
                        HStack(spacing: 6) {
                            // Away team score
                            Text("\(gameData.awayScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(gameData.awayScore > gameData.homeScore ? .gpGreen : .white)
                            
                            Text("-")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Home team score  
                            Text("\(gameData.homeScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(gameData.homeScore > gameData.awayScore ? .gpGreen : .white)
                        }
                    }
                    
                    // Game status/time
                    Text(gameData.displayTime)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(gameData.isLive ? .red : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            gameData.isLive ? 
                            AnyView(Capsule().fill(Color.red.opacity(0.2))) :
                            AnyView(Color.clear)
                        )
                }
            } else if let gameInfo = NFLGameDataService.shared.getGameInfo(for: awayTeam) {
                // Fallback to service lookup (original behavior)
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
    
    // MARK: - Helper function to get team name
    private func getTeamName(for teamCode: String) -> String {
        // Return full city + team name like "Miami Dolphins" instead of just "Dolphins"
        return NFLTeam.team(for: teamCode)?.fullName ?? teamCode
    }
    
    // MARK: - Helper function to get team record (REAL DATA - NO MORE MOCK BULLSHIT)
    private func getTeamRecord(for teamCode: String) -> String {
        return standingsService.getTeamRecord(for: teamCode)
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
        .padding(.horizontal, 32) // Increased from 20 to 32 to prevent card clipping
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
    }
    
    // MARK: - Matchup Detail Sheet (reuse Mission Control)
    private func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIXED: Wrap in NavigationView for proper layout, title, and dismiss controls.
        // This provides the correct full-width context for the content view.
        NavigationView {
            Group {
                if matchup.isChoppedLeague {
                    ChoppedLeaderboardView(
                        choppedSummary: matchup.choppedSummary!,
                        leagueName: matchup.league.league.name,
                        leagueID: matchup.league.league.id
                    )
                } else {
                    let configuredViewModel = matchup.createConfiguredFantasyViewModel()
                    FantasyMatchupDetailView(
                        matchup: matchup.fantasyMatchup!,
                        fantasyViewModel: configuredViewModel,
                        leagueName: matchup.league.league.name
                    )
                }
            }
            .navigationTitle(matchup.league.league.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        showingMatchupDetail = nil // Dismisses the sheet
                    }
                }
            }
        }
    }
    
    // MARK: - Pull to Refresh
    private func handlePullToRefresh() async {
        refreshing = true
        await viewModel.refresh()
        refreshing = false
    }
    
    // MARK: - Team Roster Navigation - REVERTED TO WORKING APPROACH
    private func showTeamRoster(for teamCode: String) {
        print("🏈 FILTERED MATCHUPS: Opening team roster for \(teamCode)")
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        showingTeamRoster = teamCode
    }
    
    private func buildTeamRosterSheet(for teamCode: String) -> some View {
        // 🔥 FIXED: Pass the rootDismiss to team roster so DONE button works from there too
        EnhancedNFLTeamRosterView(teamCode: teamCode, rootDismiss: rootDismiss ?? { dismiss() })
    }
}


#Preview("Team Filtered Matchups - With Data") {
    TeamFilteredMatchupsView(
        awayTeam: "WSH", 
        homeTeam: "GB",
        matchupsHubViewModel: MatchupsHubViewModel(),
        gameData: ScheduleGame(
            id: "WSH@GB",
            awayTeam: "WSH",
            homeTeam: "GB",
            awayScore: 24,
            homeScore: 31,
            gameStatus: "final",
            gameTime: "",
            startDate: Date(),
            isLive: false
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Team Filtered Matchups - Empty") {
    TeamFilteredMatchupsView(
        awayTeam: "JAX",
        homeTeam: "TEN", 
        matchupsHubViewModel: MatchupsHubViewModel(),
        gameData: ScheduleGame(
            id: "JAX@TEN",
            awayTeam: "JAX",
            homeTeam: "TEN",
            awayScore: 10,
            homeScore: 17,
            gameStatus: "final",
            gameTime: "",
            startDate: Date(),
            isLive: false
        )
    )
    .preferredColorScheme(.dark)
}