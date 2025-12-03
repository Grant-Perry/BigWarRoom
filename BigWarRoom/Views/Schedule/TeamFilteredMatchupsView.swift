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
    @State private var viewModel: TeamFilteredMatchupsViewModel
    @State private var standingsService = NFLStandingsService.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UI State (reusing Mission Control patterns)
    @State private var refreshing = false
    @State private var sortByWinning = false
    @State private var microMode = false
    @State private var expandedCardId: String? = nil
    // 🔥 NUCLEAR: Add navigation trigger state
    @State private var navigateToTeam: String?
    
    // 🔥 FIXED: Team roster navigation state - USE NAVIGATIONLINKS INSTEAD OF SHEETS
    // @State private var showingTeamRoster: String?
    
    // MARK: - Initialization
    init(awayTeam: String, homeTeam: String, matchupsHubViewModel: MatchupsHubViewModel, gameData: ScheduleGame? = nil, rootDismiss: (() -> Void)? = nil) {
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.gameData = gameData // 🔥 NEW: Store actual game data
        self.rootDismiss = rootDismiss // 🔥 NEW: Store root dismiss closure
        self._viewModel = State(wrappedValue: TeamFilteredMatchupsViewModel(matchupsHubViewModel: matchupsHubViewModel))
    }
    
    // MARK: - Body
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove NavigationView - parent NavigationStack handles it
        // BEFORE: NavigationView { ... }
        // AFTER: Direct content - NavigationStack provided by parent tab
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
        // 🔥 NUCLEAR FIX: Remove onAppear/onDisappear to prevent navigation conflicts
        // These async operations might be causing immediate navigation resets
        // .onAppear { ... }
        // .onDisappear { ... }
        .onAppear {
            DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Appeared")
            DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Away team: \(awayTeam), Home team: \(homeTeam)")
            DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Passed game data: \(gameData?.scoreDisplay ?? "nil")")
            DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: shouldShowLoadingState: \(viewModel.shouldShowLoadingState)")
            
            // Use the game object if available, otherwise create a temporary one
            if let gameData = gameData {
                DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Using passed game data for filtering")
                viewModel.filterMatchups(for: gameData)
            } else {
                DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Creating temporary game object for filtering")
                // Create a minimal ScheduleGame object for backward compatibility
                let tempGame = ScheduleGame(
                    id: "\(awayTeam)@\(homeTeam)",
                    awayTeam: awayTeam,
                    homeTeam: homeTeam,
                    awayScore: 0,
                    homeScore: 0,
                    gameStatus: "scheduled",
                    gameTime: "",
                    startDate: Date(),
                    isLive: false
                )
                viewModel.filterMatchups(for: tempGame)
            }
            
            DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: After filterMatchups call - shouldShowLoadingState: \(viewModel.shouldShowLoadingState)")
        }
        .refreshable {
            await handlePullToRefresh()
        }
        .navigationDestination(item: $navigateToTeam) { teamCode in
            EnhancedNFLTeamRosterView(teamCode: teamCode)
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
            
            VStack(spacing: 32) {
                // Header with team logos (even during loading)
                buildFilteredHeader()
                
                Spacer()
                
                // 🔥 SICK LOADING ANIMATION SECTION
                VStack(spacing: 28) {
                    // Epic animated team logos battle
                    ZStack {
                        // Background glow effects
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        getTeamColor(for: awayTeam).opacity(0.4),
                                        getTeamColor(for: awayTeam).opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .leading,
                                    startRadius: 10,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        getTeamColor(for: homeTeam).opacity(0.4),
                                        getTeamColor(for: homeTeam).opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .trailing,
                                    startRadius: 10,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0), value: UUID())
                        
                        // Main logos with sick animations
                        HStack(spacing: 40) {
                            // Away team logo with multiple animation layers
                            ZStack {
                                // Pulsing ring effect
                                Circle()
                                    .stroke(getTeamColor(for: awayTeam), lineWidth: 3)
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(1.2)
                                    .opacity(0.6)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: UUID())
                                
                                // Inner glow ring with rotation
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                getTeamColor(for: awayTeam).opacity(0.8),
                                                getTeamColor(for: awayTeam).opacity(0.3),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 95, height: 95)
                                    .rotationEffect(.degrees(0))
                                    .animation(.linear(duration: 3.0).repeatForever(), value: UUID())
                                
                                // Team logo with bounce and glow
                                TeamLogoView(teamCode: awayTeam, size: 85)
                                    .frame(width: 85, height: 85)
                                    .scaleEffect(1.1)
                                    .shadow(color: getTeamColor(for: awayTeam).opacity(0.8), radius: 15, x: 0, y: 0)
                                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: UUID())
                            }
                            
                            // Epic VS with electricity effect
                            ZStack {
                                // Lightning background
                                Text("VS")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .gpBlue.opacity(0.8), radius: 20, x: 0, y: 0)
                                    .shadow(color: .gpGreen.opacity(0.6), radius: 10, x: 0, y: 0)
                                    .scaleEffect(1.1)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: UUID())
                                
                                // Sparkling particles effect
                                ForEach(0..<6, id: \.self) { index in
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .frame(width: 3, height: 3)
                                        .offset(
                                            x: cos(Double(index) * .pi / 3) * 25,
                                            y: sin(Double(index) * .pi / 3) * 25
                                        )
                                        .scaleEffect(1.5)
                                        .opacity(0.8)
                                        .animation(
                                            .easeInOut(duration: 1.0)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.2),
                                            value: UUID()
                                        )
                                }
                            }
                            
                            // Home team logo with multiple animation layers
                            ZStack {
                                // Pulsing ring effect
                                Circle()
                                    .stroke(getTeamColor(for: homeTeam), lineWidth: 3)
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(1.2)
                                    .opacity(0.6)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.7), value: UUID())
                                
                                // Inner glow ring with rotation
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                getTeamColor(for: homeTeam).opacity(0.8),
                                                getTeamColor(for: homeTeam).opacity(0.3),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 95, height: 95)
                                    .rotationEffect(.degrees(180))
                                    .animation(.linear(duration: 3.0).repeatForever().delay(1.5), value: UUID())
                                
                                // Team logo with bounce and glow
                                TeamLogoView(teamCode: homeTeam, size: 85)
                                    .frame(width: 85, height: 85)
                                    .scaleEffect(1.1)
                                    .shadow(color: getTeamColor(for: homeTeam).opacity(0.8), radius: 15, x: 0, y: 0)
                                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.6), value: UUID())
                            }
                        }
                    }
                    
                    // Epic progress section with multiple indicators
                    VStack(spacing: 16) {
                        // Main progress indicator with glow
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .stroke(Color.gpBlue.opacity(0.3), lineWidth: 8)
                                .frame(width: 60, height: 60)
                                .blur(radius: 4)
                            
                            // Animated progress ring
                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(
                                    AngularGradient(
                                        colors: [.gpBlue, .gpGreen, .gpBlue],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1.5).repeatForever(), value: UUID())
                            
                            // Center dot with pulse
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.5)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: UUID())
                        }
                        
                        // Dynamic loading text with typewriter effect
                        VStack(spacing: 8) {
                            Text("Loading your \(awayTeam) vs \(homeTeam) matchups...")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                            
                            // Animated status messages
                            VStack(spacing: 4) {
                                Text("🔍 Scanning fantasy rosters...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gpBlue.opacity(0.9))
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                                
                                Text("⚡ Processing league data...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gpGreen.opacity(0.9))
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0), value: UUID())
                                
                                Text("🏆 Building matchup analysis...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gpYellow.opacity(0.9))
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(2.0), value: UUID())
                            }
                        }
                        
                        // Epic loading dots with wave animation
                        HStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { index in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.gpBlue, .gpGreen],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(1.5)
                                    .shadow(color: .gpBlue.opacity(0.6), radius: 8, x: 0, y: 0)
                                    .animation(
                                        .easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.15),
                                        value: UUID()
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // Bottom info with subtle glow
                VStack(spacing: 10) {
                    Text("⏱️ First load takes a moment...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .gpBlue.opacity(0.3), radius: 4)
                    
                    Text("Subsequent loads will be instant")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)
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
                    Button(action: {
                        DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Button tapped for \(awayTeam)")
                        navigateToTeam = awayTeam
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                TeamLogoView(teamCode: awayTeam, size: 140)
                                    .scaleEffect(0.75)
                                    .clipped()
                            }
                            .frame(width: 90, height: 60)
                            .clipShape(Rectangle())
                            .offset(x: -10, y: -8)
                            
                            Text(getTeamName(for: awayTeam))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.center)
                                .frame(width: 90)
                            
                            Text(getTeamRecord(for: awayTeam))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Game info section (VS + score/status) - MOVED SCORES HERE
                    VStack(spacing: 6) {
                        Text("vs")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Game score and status - REPOSITIONED AND ENHANCED
                        buildGameInfo()
                    }
                    
                    // Home team section
                    Button(action: {
                        DebugPrint(mode: .navigation, "🎯 TEAM FILTER VIEW: Button tapped for \(homeTeam)")
                        navigateToTeam = homeTeam
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                TeamLogoView(teamCode: homeTeam, size: 140)
                                    .scaleEffect(0.75)
                                    .clipped()
                            }
                            .frame(width: 90, height: 60)
                            .clipShape(Rectangle())
                            .offset(x: 10, y: -8)
                            
                            Text(getTeamName(for: homeTeam))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.center)
                                .frame(width: 90)
                            
                            Text(getTeamRecord(for: homeTeam))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
                    // 🔥 FIX: Use NavigationLink approach - no callback needed
                    onMicroCardTap: { cardId in
                        expandedCardId = (expandedCardId == cardId) ? nil : cardId
                    },
                    dualViewMode: true, // Use dual view mode for 2-column layout
                    isLineupOptimized: false // 💊 RX: Always false for filtered views (not supported)
                )
            }
        }
        .padding(.horizontal, 32) // Increased from 20 to 32 to prevent card clipping
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: microMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedCardId)
    }
    
    // MARK: - Pull to Refresh
    private func handlePullToRefresh() async {
        refreshing = true
        await viewModel.refresh()
        refreshing = false
    }
    
    // MARK: - Team Roster Navigation - REMOVE SHEET-BASED APPROACH
    // Navigation now handled by NavigationLinks and parent navigationDestination
    
    // MARK: - Matchup Detail Sheet (commented out - using NavigationLinks instead)
    /*
    private func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIX: Use same loading flow as Mission Control
        MatchupDetailSheetsView(matchup: matchup)
    }
    */
}


#Preview("Team Filtered Matchups - With Data") {
    TeamFilteredMatchupsView(
        awayTeam: "WSH", 
        homeTeam: "GB",
        // 🔥 FIXED: Use shared MatchupsHubViewModel to ensure data consistency
        matchupsHubViewModel: MatchupsHubViewModel.shared,
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
        // 🔥 FIXED: Use shared MatchupsHubViewModel to ensure data consistency
        matchupsHubViewModel: MatchupsHubViewModel.shared,
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