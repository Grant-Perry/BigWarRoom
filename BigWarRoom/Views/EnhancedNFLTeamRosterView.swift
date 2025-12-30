//
//  EnhancedNFLTeamRosterView.swift
//  BigWarRoom
//
//  🔥🏈 ENHANCED NFL TEAM ROSTER VIEW 🏈🔥
//  NFL team rosters with ChoppedRosterPlayerCard styling - GORGEOUS!
//

import SwiftUI

/// **EnhancedNFLTeamRosterView**
/// 
/// Shows NFL team rosters using the beautiful ChoppedRosterPlayerCard styling:
/// - Rich player photos with team logo backgrounds
/// - Live game scores and matchup info
/// - Score bars based on fantasy points
/// - Detailed stat breakdowns
/// - Position badges and live indicators
struct EnhancedNFLTeamRosterView: View {
    let teamCode: String
    let rootDismiss: (() -> Void)? // 🔥 NEW: Optional root dismiss action
    
    @Environment(\.dismiss) private var dismiss
    // 🔥 PURE DI: Inject from environment
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    @State private var viewModel: NFLTeamRosterViewModel?
    @State private var nflGameService = NFLGameDataService.shared
    
    // UI State
    @State private var sortingMethod: MatchupSortingMethod = .position
    @State private var sortHighToLow = false
    @State private var showContributingPlayers = true
    // 🔥 FIX: Add navigation state for opponent team
    @State private var navigateToTeam: String?
    
    init(teamCode: String, rootDismiss: (() -> Void)? = nil) {
        self.teamCode = teamCode
        self.rootDismiss = rootDismiss
    }
    
    var body: some View {
        // 🔥 REMOVE: NavigationStack - This view is presented via NavigationLink from parent NavigationStack
        // Nested NavigationStack breaks navigationDestination matching
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let vm = viewModel {
                if vm.isLoading {
                    enhancedLoadingView
                } else if !vm.filteredPlayers.isEmpty {
                    enhancedRosterContentView
                } else {
                    enhancedErrorView
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    print("🏈 ROSTER DEBUG: Toolbar Done button tapped - using dismiss()")
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 🔥 PURE DI: Create viewModel with injected instance
            if viewModel == nil {
                viewModel = NFLTeamRosterViewModel(
                    teamCode: teamCode,
                    coordinator: TeamRosterCoordinator(livePlayersViewModel: allLivePlayersViewModel),
                    nflGameService: nflGameService
                )
            }
            
            // 🔥 FIX: Use onAppear instead of .task to prevent navigation conflicts
            print("🏈 ROSTER DEBUG: EnhancedNFLTeamRosterView appeared for team \(teamCode)")
            Task {
                await viewModel?.loadTeamRoster()
            }
        }
        .onDisappear {
            print("🏈 ROSTER DEBUG: EnhancedNFLTeamRosterView disappeared for team \(teamCode)")
        }
        // 🔥 FIX: Add navigationDestination for opponent team navigation
        .navigationDestination(item: $navigateToTeam) { teamCode in
            EnhancedNFLTeamRosterView(teamCode: teamCode, rootDismiss: rootDismiss)
        }
    }
    
    // MARK: - Enhanced Loading View
    
    private var enhancedLoadingView: some View {
        VStack(spacing: 25) {
            // Team logo with glow effect
            ZStack {
                Circle()
                    .fill(getTeamColor().opacity(0.3))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                TeamLogoView(teamCode: teamCode, size: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(getTeamColor(), lineWidth: 3)
                    )
            }
            
            VStack(spacing: 12) {
                Text("Loading \(getTeamName()) Roster...")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Fetching live player data and stats")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(getTeamColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("BG5")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.3)
        )
    }
    
    // MARK: - Enhanced Roster Content View
    
    private var enhancedRosterContentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 🔥 FIXED: Add close button at the top of content
                HStack {
                    Spacer()
                    
                    Button(action: { 
                        print("🏈 ROSTER DEBUG: Close button tapped - using dismiss()")
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Enhanced team header
                if let vm = viewModel {
                    enhancedTeamHeaderCard(vm: vm)
                        .padding(.horizontal, 16)
                    
                    // FIXED: Tighter spacing - combine sort controls and players into one section
                    VStack(spacing: 8) { // Reduced spacing between controls and players
                        // Sorting controls
                        PlayerSortingControlsView(
                            sortingMethod: $sortingMethod, 
                            sortHighToLow: $sortHighToLow
                        )
                        
                        // Players section (no extra padding)
                        enhancedPlayersSection(vm: vm)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(
            Image("BG3")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .opacity(0.4)
        )
    }
    
    // MARK: - Enhanced Team Header Card
    
    private func enhancedTeamHeaderCard(vm: NFLTeamRosterViewModel) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // Team logo with enhanced styling
                ZStack {
                    Circle()
                        .fill(getTeamColor().opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    TeamLogoView(teamCode: teamCode, size: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(getTeamColor(), lineWidth: 3)
                        )
                        .shadow(color: getTeamColor().opacity(0.5), radius: 10)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.teamInfo?.teamName ?? getTeamName())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Active Roster")
                        .font(.title3)
                        .foregroundColor(getTeamColor())
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vm.filteredPlayers.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("CONTRIBUTING")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Game status bar (if available) - ENHANCED WITH MOVED FINAL/SCORE
            if let gameInfo = getGameInfo() {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week 3 • FINAL") // Static for now
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // FIXED: vs section with opponent logo only
                        HStack(spacing: 12) {
                            Text("vs")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            // 🔥 FIXED: Use Button + state instead of NavigationLink
                            Button(action: {
                                print("🏈 OPPONENT TEAM: Button tapped for \(gameInfo.opponent)")
                                navigateToTeam = gameInfo.opponent
                            }) {
                                TeamLogoView(teamCode: gameInfo.opponent, size: 40)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer()
                    
                    // 🔥 MOVED: Game score and status to trailing side
                    VStack(alignment: .trailing, spacing: 4) {
                        // Score display with larger font and win/lose colors
                        HStack(spacing: 6) {
                            Text("\(gameInfo.actualAwayScore)")
                                .font(.system(size: 24, weight: .bold)) // Larger font
                                .foregroundColor(gameInfo.actualAwayScore > gameInfo.actualHomeScore ? .gpGreen : .gpRedPink)
                            
                            Text("-")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(gameInfo.actualHomeScore)")
                                .font(.system(size: 24, weight: .bold)) // Larger font
                                .foregroundColor(gameInfo.actualHomeScore > gameInfo.actualAwayScore ? .gpGreen : .gpRedPink)
                        }
                        
                        // FINAL/LIVE status
                        Text(gameInfo.isLive ? "LIVE" : "FINAL")
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(getTeamColor().opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            getTeamColor().opacity(0.15),
                            Color.black.opacity(0.9),
                            getTeamColor().opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(getTeamColor().opacity(0.4), lineWidth: 2)
                )
        )
        .shadow(color: getTeamColor().opacity(0.3), radius: 15)
    }
    
    // MARK: - Enhanced Players Section
    
    private func enhancedPlayersSection(vm: NFLTeamRosterViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with dynamic team name
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showContributingPlayers.toggle()
                }
            } label: {
                HStack {
                    // FIXED: Dynamic team-based title
                    Text("🔥 \(getTeamName()) Live Roster")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(getSortedPlayers(vm: vm).count) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showContributingPlayers ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Players list with enhanced cards
            if showContributingPlayers {
                VStack(spacing: 12) {
                    ForEach(getSortedPlayers(vm: vm), id: \.playerID) { player in
                        EnhancedNFLPlayerCard(
                            player: player,
                            teamCode: teamCode,
                            viewModel: vm
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(getTeamColor().opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(getTeamColor().opacity(0.25), lineWidth: 1.5)
                )
        )
    }
    
    // MARK: - Enhanced Error View
    
    private var enhancedErrorView: some View {
        VStack(spacing: 25) {
            // 🔥 FIXED: Add close button at the top
            HStack {
                Spacer()
                
                Button(action: { 
                    print("🏈 ROSTER DEBUG: Error view close button tapped - using dismiss()")
                    dismiss() 
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                TeamLogoView(teamCode: teamCode, size: 80)
                    .clipShape(Circle())
                    .opacity(0.6)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Contributing Players")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if let error = viewModel?.errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else {
                    // 🔥 FIXED: More accurate message that doesn't assume game is completed
                    Text("All contributing players are currently filtered out. This could be due to incomplete data or the game hasn't started yet.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Buttons row
            HStack(spacing: 16) {
                // Close button
                Button("Close") {
                    print("🏈 ROSTER DEBUG: Error view Close button tapped - using dismiss()")
                    dismiss()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
                .fontWeight(.semibold)
                
                // Try Again button  
                Button("Try Again") {
                    Task {
                        await viewModel?.loadTeamRoster()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(getTeamColor())
                .foregroundColor(.white)
                .cornerRadius(12)
                .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func getSortedPlayers(vm: NFLTeamRosterViewModel) -> [SleeperPlayer] {
        let players = vm.filteredPlayers
        
        switch sortingMethod {
        case .position:
            return players.sorted { lhs, rhs in
                let lhsOrder = getPositionOrder(lhs.position ?? "")
                let rhsOrder = getPositionOrder(rhs.position ?? "")
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                // Secondary sort by points
                let lhsPoints = vm.getPlayerPoints(for: lhs) ?? 0.0
                let rhsPoints = vm.getPlayerPoints(for: rhs) ?? 0.0
                return lhsPoints > rhsPoints
            }
        case .score:
            return players.sorted { lhs, rhs in
                let lhsPoints = vm.getPlayerPoints(for: lhs) ?? 0.0
                let rhsPoints = vm.getPlayerPoints(for: rhs) ?? 0.0
                return sortHighToLow ? lhsPoints > rhsPoints : lhsPoints < rhsPoints
            }
        case .name:
            return players.sorted { lhs, rhs in
                let lhsName = "\(lhs.firstName ?? "") \(lhs.lastName ?? "")"
                let rhsName = "\(rhs.firstName ?? "") \(rhs.lastName ?? "")"
                return sortHighToLow ? lhsName > rhsName : lhsName < rhsName
            }
        case .team:
            return players.sorted { lhs, rhs in
                let lhsTeam = lhs.team ?? ""
                let rhsTeam = rhs.team ?? ""
                return sortHighToLow ? lhsTeam > rhsTeam : lhsTeam < rhsTeam
            }
        case .recentActivity:
            // Sort by live teams first, then by score
            let liveTeams = Set(NFLGameDataService.shared.gameData.values
                .filter { $0.isLive }
                .flatMap { [$0.homeTeam, $0.awayTeam] })
            
            return players.sorted { lhs, rhs in
                let lhsLive = liveTeams.contains(lhs.team ?? "")
                let rhsLive = liveTeams.contains(rhs.team ?? "")
                
                if lhsLive != rhsLive {
                    return lhsLive
                }
                let lhsPoints = vm.getPlayerPoints(for: lhs) ?? 0.0
                let rhsPoints = vm.getPlayerPoints(for: rhs) ?? 0.0
                return lhsPoints > rhsPoints
            }
        }
    }
    
    private func getPositionOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 0
        case "RB": return 1
        case "WR": return 2
        case "TE": return 3
        case "K": return 4
        case "DST", "DEF": return 5
        default: return 6
        }
    }
    
    private func getTeamName() -> String {
        return NFLTeam.team(for: teamCode)?.city ?? teamCode
    }
    
    private func getTeamColor() -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    private func getGameInfo() -> GameDisplayInfo? {
        if let gameInfo = nflGameService.getGameInfo(for: teamCode) {
            let opponent = teamCode == gameInfo.awayTeam ? gameInfo.homeTeam : gameInfo.awayTeam
            
            return GameDisplayInfo(
                opponent: opponent,
                scoreDisplay: "\(gameInfo.awayScore) - \(gameInfo.homeScore)",
                teamScore: teamCode == gameInfo.awayTeam ? "\(gameInfo.awayScore)" : "\(gameInfo.homeScore)",
                opponentScore: teamCode == gameInfo.awayTeam ? "\(gameInfo.homeScore)" : "\(gameInfo.awayScore)",
                gameTime: gameInfo.displayTime,
                isLive: gameInfo.isLive,
                hasStarted: gameInfo.awayScore > 0 || gameInfo.homeScore > 0,
                isWinning: teamCode == gameInfo.awayTeam ? gameInfo.awayScore > gameInfo.homeScore : gameInfo.homeScore > gameInfo.awayScore,
                isLosing: teamCode == gameInfo.awayTeam ? gameInfo.awayScore < gameInfo.homeScore : gameInfo.homeScore < gameInfo.awayScore,
                isByeWeek: false,
                isHome: teamCode == gameInfo.homeTeam,
                actualAwayTeam: gameInfo.awayTeam,
                actualHomeTeam: gameInfo.homeTeam,
                actualAwayScore: gameInfo.awayScore,
                actualHomeScore: gameInfo.homeScore
            )
        }
        return nil
    }
    
    private func getOpponentName(_ gameInfo: GameDisplayInfo) -> String {
        let opponentCode = gameInfo.opponent
        return NFLTeam.team(for: opponentCode)?.city ?? opponentCode
    }
}

// MARK: - Enhanced NFL Player Card (Adapted from ChoppedRosterPlayerCard)

struct EnhancedNFLPlayerCard: View {
    let player: SleeperPlayer
    let teamCode: String
    let viewModel: NFLTeamRosterViewModel
    
    @State private var showingScoreBreakdown = false
    
    // FIXED: Increase card height to fit all content properly
    private var cardHeight: CGFloat { 110 } // Increased from 100 to 110
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Card content layout (adapted from ChoppedRosterPlayerCard)
            HStack(spacing: 0) {
                // Empty space for player image overlay
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 75)
                
                // Player info section - REBALANCED
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Spacer()
                        
                        // Player name
                        Text("\(player.firstName ?? "") \(player.lastName ?? "")")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    // FIXED: Position and Points on same line
                    HStack(spacing: 12) {
                        Spacer()
                        
                        // Position badge
                        Text(player.position ?? "?")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(getPositionColor().opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        
                        // FIXED: Points moved to same line and made larger
                        HStack(spacing: 4) {
                            if let points = viewModel.getPlayerPoints(for: player), points > 0 {
                                Button(action: { showingScoreBreakdown = true }) {
                                    Text(String(format: "%.1f", points))
                                        .font(.system(size: 16, weight: .bold)) // Increased from 14 to 16
                                        .foregroundColor(getScoreColor(points))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.15))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(getScoreColor(points).opacity(0.5), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Text("0.0")
                                    .font(.system(size: 16, weight: .bold)) // Increased from 14 to 16
                                    .foregroundColor(.gray)
                            }
                            
                            Text("pts")
                                .font(.system(size: 11, weight: .medium)) // Increased from 10 to 11
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(playerCardBackground)
            
            // FIXED: Better positioned stats to avoid clipping
            if let points = viewModel.getPlayerPoints(for: player), points > 0,
               let statLine = viewModel.formatPlayerStatBreakdown(player) {
                VStack {
                    Spacer()
                    HStack {
                        Text(statLine)
                            .font(.system(size: 9, weight: .bold)) // Reduced back to 9
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6) // Reduced from 0.7 to 0.6 for better fitting
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 8) // Reduced from 12 to 8
                            .padding(.vertical, 4) // Reduced from 6 to 4
                    }
                    .padding(.bottom, 6) // Reduced from 12 to 6 to fit better
                }
            }
            
            // Player image overlay - same position
            HStack {
                ZStack {
                    // Team logo background
                    TeamAssetManager.shared.logoOrFallback(for: teamCode)
                        .frame(width: 120, height: 120)
                        .opacity(0.3)
                        .offset(x: 15, y: -5)
                        .zIndex(0)
                    
                    // Player image
                    playerImageView
                        .scaleEffect(0.95)
                        .zIndex(1)
                        .offset(x: -15)
                }
                .frame(height: 90) // Increased from 80 to 90 to match taller card
                .frame(maxWidth: 140)
                .offset(x: -5)
                
                Spacer()
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [getTeamColor(), getTeamColor().opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
                .opacity(0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $showingScoreBreakdown) {
            if let breakdown = createScoreBreakdown() {
                ScoreBreakdownView(breakdown: breakdown)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
            }
        }
    }
    
    // MARK: - Player Image View
    
    private var playerImageView: some View {
        Group {
            if let imageURL = player.headshotURL {
                // 🔥 ADD: NavigationLink for player image to navigate to player stats
                NavigationLink(value: player) {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 85, height: 85)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } placeholder: {
                        playerImageFallback
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 🔥 ADD: NavigationLink for fallback image to navigate to player stats
                NavigationLink(value: player) {
                    playerImageFallback
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var playerImageFallback: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(getTeamColor().opacity(0.6))
            .frame(width: 85, height: 85)
            .overlay(
                Text(player.position ?? "?")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - Background and Colors
    
    private var playerCardBackground: some View {
        ZStack {
            // Base gradient
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.95),
                            getTeamColor().opacity(0.15),
                            Color.black.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Score bar
            HStack {
                Rectangle()
                    .fill(getScoreBarGradient())
                    .frame(width: getScoreBarWidth())
                    .opacity(0.6)
                
                Spacer()
            }
            
            // Team accent
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            getTeamColor().opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    private func getTeamColor() -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    private func getPositionColor() -> Color {
        switch player.position?.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DST", "DEF": return .red
        default: return .gray
        }
    }
    
    private func getScoreColor(_ points: Double) -> Color {
        if points >= 20 { return .gpGreen }
        else if points >= 12 { return .blue }
        else if points >= 8 { return .orange }
        else { return .gpRedPink }
    }
    
    private func getScoreBarWidth() -> CGFloat {
        guard let points = viewModel.getPlayerPoints(for: player) else { return 8 }
        let maxPoints: Double = 40.0
        let percentage = min(points / maxPoints, 1.0)
        let minWidth: CGFloat = 8
        let maxWidth: CGFloat = 100
        return minWidth + (CGFloat(percentage) * (maxWidth - minWidth))
    }
    
    private func getScoreBarGradient() -> LinearGradient {
        guard let points = viewModel.getPlayerPoints(for: player) else {
            return LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
        
        if points >= 20 {
            return LinearGradient(colors: [.gpGreen.opacity(0.8), .gpGreen.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else if points >= 12 {
            return LinearGradient(colors: [.blue.opacity(0.8), .blue.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else if points >= 8 {
            return LinearGradient(colors: [.orange.opacity(0.8), .orange.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private func getNFLGameInfo() -> GameDisplayInfo? {
        let nflService = NFLGameDataService.shared
        if let gameInfo = nflService.getGameInfo(for: teamCode) {
            return GameDisplayInfo(
                opponent: teamCode == gameInfo.awayTeam ? gameInfo.homeTeam : gameInfo.awayTeam,
                scoreDisplay: "\(gameInfo.awayScore) - \(gameInfo.homeScore)",
                teamScore: teamCode == gameInfo.awayTeam ? "\(gameInfo.awayScore)" : "\(gameInfo.homeScore)",
                opponentScore: teamCode == gameInfo.awayTeam ? "\(gameInfo.homeScore)" : "\(gameInfo.awayScore)",
                gameTime: gameInfo.displayTime,
                isLive: gameInfo.isLive,
                hasStarted: gameInfo.awayScore > 0 || gameInfo.homeScore > 0,
                isWinning: teamCode == gameInfo.awayTeam ? gameInfo.awayScore > gameInfo.homeScore : gameInfo.homeScore > gameInfo.awayScore,
                isLosing: teamCode == gameInfo.awayTeam ? gameInfo.awayScore < gameInfo.homeScore : gameInfo.homeScore < gameInfo.awayScore,
                isByeWeek: false,
                isHome: teamCode == gameInfo.homeTeam,
                actualAwayTeam: gameInfo.awayTeam,
                actualHomeTeam: gameInfo.homeTeam,
                actualAwayScore: gameInfo.awayScore,
                actualHomeScore: gameInfo.homeScore
            )
        }
        return nil
    }
    
    // FIXED: Get REAL stat breakdown using ScoreBreakdownFactory
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        guard let actualPoints = viewModel.getPlayerPoints(for: player), actualPoints > 0 else { 
            return nil 
        }
        
        // Create proper FantasyPlayer with correct data
        let fantasyPlayer = FantasyPlayer(
            id: player.playerID ?? UUID().uuidString,
            sleeperID: player.playerID,
            espnID: nil,
            firstName: player.firstName,
            lastName: player.lastName,
            position: player.position ?? "",
            team: player.team ?? teamCode,
            jerseyNumber: nil,
            currentPoints: actualPoints,
            projectedPoints: 0.0,
            gameStatus: GameStatus(status: "final"),
            isStarter: true,
            lineupSlot: nil
        )
        
        // FIXED: Use ScoreBreakdownFactory to get REAL stats breakdown
        // This will fetch actual rushing yards, receiving yards, TDs, etc.
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: fantasyPlayer,
            week: 3,
            localStatsProvider: nil, // Let it use default stats provider
            leagueContext: LeagueContext(
                leagueID: "nfl-roster",
                source: .sleeper,
                isChopped: false,
                customScoringSettings: nil
            )
        )
        
        // Create a corrected breakdown with the authoritative total
        // but keeping all the real stat breakdown items
        let correctedBreakdown = PlayerScoreBreakdown(
            player: breakdown.player,
            week: breakdown.week,
            items: breakdown.items, // Keep the real stat items (rush_yd, rec_yd, etc.)
            totalScore: actualPoints, // Use the authoritative total from the card
            isChoppedLeague: false,
            hasRealScoringData: true,
            leagueContext: breakdown.leagueContext,
            leagueName: "NFL Team Roster"
        )
        
        return correctedBreakdown
    }
}