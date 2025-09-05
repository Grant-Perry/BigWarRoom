//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
// MARK: -> Fantasy Matchup List View

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel  // Accept the shared view model
    @StateObject private var viewModel = FantasyViewModel()
    @State private var forceChoppedMode = false // DEBUG: Force chopped mode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Connection status header (always show)
                    connectionStatusHeader
                    
                    // Matchups content
                    if viewModel.isLoading || shouldShowLoadingState {
                        let _ = print("⏳ UI CONDITION: Loading state - showing spinning football")
                        loadingView
                    } else if viewModel.detectedAsChoppedLeague || isChoppedLeague || forceChoppedMode {
                        // CHOPPED LEAGUE: Detected via empty matchups + rosters OR settings
                        let _ = print("🔥 UI CONDITION: Showing Chopped leaderboard!")
                        let _ = print("   - viewModel.detectedAsChoppedLeague: \(viewModel.detectedAsChoppedLeague)")
                        let _ = print("   - isChoppedLeague (computed): \(isChoppedLeague)")
                        let _ = print("   - forceChoppedMode: \(forceChoppedMode)")
                        let _ = print("   - viewModel.matchups.count: \(viewModel.matchups.count)")
                        let _ = print("   - viewModel.hasActiveRosters: \(viewModel.hasActiveRosters)")
                        choppedLeaderboardView
                    } else if viewModel.matchups.isEmpty && viewModel.hasActiveRosters {
                        // CHOPPED LEAGUE: No matchups but has rosters (safety net)
                        let _ = print("🔥 UI CONDITION: Showing Chopped leaderboard (safety net)!")
                        let _ = print("   - matchups.isEmpty: \(viewModel.matchups.isEmpty)")
                        let _ = print("   - hasActiveRosters: \(viewModel.hasActiveRosters)")
                        choppedLeaderboardView
                    } else if viewModel.matchups.isEmpty && !viewModel.hasActiveRosters {
                        // TRUE EMPTY STATE: Only after we've confirmed data loading is complete
                        let _ = print("❌ UI CONDITION: Confirmed empty state (not loading)")
                        let _ = print("   - shouldShowLoadingState: \(shouldShowLoadingState)")
                        let _ = print("   - matchups.isEmpty: \(viewModel.matchups.isEmpty)")
                        let _ = print("   - hasActiveRosters: \(viewModel.hasActiveRosters)")
                        let _ = print("   - detectedAsChoppedLeague: \(viewModel.detectedAsChoppedLeague)")
                        emptyStateView
                    } else {
                        // NORMAL LEAGUE: Has matchups
                        let _ = print("✅ UI CONDITION: Showing normal matchups")
                        let _ = print("   - matchups.count: \(viewModel.matchups.count)")
                        matchupsList
                    }
                }
            }
            .navigationTitle(shouldHideTitle ? "" : (viewModel.selectedLeague?.league.name ?? "Fantasy"))
            .navigationBarTitleDisplayMode(shouldHideTitle ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Week \(viewModel.selectedWeek)") {
                        viewModel.presentWeekSelector()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showWeekSelector) {
                ESPNDraftPickSelectionSheet.forFantasy(
                    leagueName: viewModel.selectedLeague?.league.name ?? "Fantasy League",
                    currentWeek: viewModel.currentNFLWeek,
                    selectedWeek: $viewModel.selectedWeek,
                    onConfirm: { week in
                        viewModel.selectWeek(week)
                        viewModel.dismissWeekSelector()
                    },
                    onCancel: {
                        viewModel.dismissWeekSelector()
                    }
                )
            }
            .task {
                await setupConnectedLeague()
            }
            .onReceive(draftRoomViewModel.$selectedLeagueWrapper) { newLeague in
                // Detect when league changes from War Room and refresh immediately
                Task {
                    print("🔄 LEAGUE CHANGE DETECTED: \(newLeague?.league.name ?? "nil")")
                    await setupConnectedLeague()
                }
            }
            .onAppear {
                // Pass the shared DraftRoomViewModel to FantasyViewModel
                viewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
                
                // Also check for league changes on appear (in case we missed the publisher)
                Task {
                    await setupConnectedLeague()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack navigation style
    }
    
    // MARK: -> Loading State Detection
    /// Determines when to show loading spinner instead of empty state
    private var shouldShowLoadingState: Bool {
        // Always show loading if no connected league yet
        guard let connectedLeague = draftRoomViewModel.selectedLeagueWrapper else {
            return true
        }
        
        // Show loading if we have a connected league but no selected league in viewModel yet
        if viewModel.selectedLeague == nil {
            return true
        }
        
        // Show loading if league IDs don't match (still switching leagues)
        if viewModel.selectedLeague?.league.leagueID != connectedLeague.league.leagueID {
            return true
        }
        
        // Show loading if we have no matchups AND no rosters AND not detected as chopped yet
        if viewModel.matchups.isEmpty && !viewModel.hasActiveRosters && !viewModel.detectedAsChoppedLeague {
            return true
        }
        
        return false
    }
    
    // MARK: -> Chopped League Detection
    private var isChoppedLeague: Bool {
        // NEW: Use FantasyViewModel's data-based detection
        if viewModel.detectedAsChoppedLeague {
            return true
        }
        
        // FALLBACK: Check connected league settings (only for Sleeper)
        if let leagueWrapper = draftRoomViewModel.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper,
           let sleeperLeague = leagueWrapper.league as? SleeperLeague {
            return sleeperLeague.settings?.isChoppedLeague ?? false
        }
        
        return false
    }
    
    /// Should hide the navigation title (only for Chopped leagues)
    private var shouldHideTitle: Bool {
        // Only hide title for confirmed Chopped leagues (avoid flickering)
        guard let league = viewModel.selectedLeague else { return false }
        
        // ESPN leagues should ALWAYS show title
        if league.source == .espn { return false }
        
        // Only hide for definitively detected Chopped leagues
        return viewModel.detectedAsChoppedLeague || forceChoppedMode
    }
    
    // MARK: -> Chopped Leaderboard View
    private var choppedLeaderboardView: some View {
        // Use async loading for real Chopped data
        if let leagueWrapper = draftRoomViewModel.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper {
            return AnyView(
                AsyncChoppedLeaderboardView(
                    leagueWrapper: leagueWrapper,
                    week: viewModel.selectedWeek,
                    fantasyViewModel: viewModel
                )
            )
        } else {
            // Fallback to mock data for non-Sleeper leagues
            let choppedSummary = createChoppedSummaryFromMatchups()
            return AnyView(
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: viewModel.selectedLeague?.league.name ?? "Chopped League"
                )
            )
        }
    }
    
    // MARK: -> Create Chopped Summary from Matchups
    private func createChoppedSummaryFromMatchups() -> ChoppedWeekSummary {
        // If this is a real Chopped league, fetch real data
        if let leagueWrapper = draftRoomViewModel.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper {
            
            // Try to get real Chopped data from FantasyViewModel
            let task = Task {
                return await viewModel.createRealChoppedSummary(
                    leagueID: leagueWrapper.league.leagueID,
                    week: viewModel.selectedWeek
                )
            }
            
            // For now, we'll use the existing logic but this will be improved
            // In the next iteration, we'll make this async properly
        }
        
        // Collect all teams from matchups and bye weeks (EXISTING LOGIC)
        var allTeams: [FantasyTeam] = []
        
        // Add teams from matchups
        for matchup in viewModel.matchups {
            allTeams.append(matchup.homeTeam)
            allTeams.append(matchup.awayTeam)
        }
        
        // Add bye week teams
        allTeams.append(contentsOf: viewModel.byeWeekTeams)
        
        // If no teams found, create MOCK CHOPPED LEAGUE data for demo
        if allTeams.isEmpty {
            allTeams = createMockChoppedTeams()
        }
        
        // Sort by current score (highest to lowest)
        let sortedTeams = allTeams.sorted { team1, team2 in
            let score1 = team1.currentScore ?? 0.0
            let score2 = team2.currentScore ?? 0.0
            return score1 > score2
        }
        
        // Create team rankings with survival data
        let teamRankingList = sortedTeams.enumerated().map { (index, team) -> FantasyTeamRanking in
            let rank = index + 1
            let isLastPlace = (rank == sortedTeams.count)
            let isDangerZone = rank > (sortedTeams.count * 3 / 4) // Bottom 25%
            
            let status: EliminationStatus
            if rank == 1 {
                status = .champion
            } else if isLastPlace {
                status = .critical
            } else if isDangerZone {
                status = .danger
            } else if rank > (sortedTeams.count / 2) {
                status = .warning
            } else {
                status = .safe
            }
            
            let teamScore = team.currentScore ?? 0.0
            let averageScore = sortedTeams.compactMap { $0.currentScore }.reduce(0, +) / Double(sortedTeams.count)
            let survivalProb = min(1.0, max(0.0, (teamScore / averageScore) * 0.7)) // Simple survival calculation
            
            return FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: teamScore,
                rank: rank,
                eliminationStatus: status,
                isEliminated: false, // No one eliminated yet in this mock
                survivalProbability: survivalProb,
                pointsFromSafety: 0.0, // Will calculate below
                weeksAlive: viewModel.selectedWeek
            )
        }
        
        // Calculate cutoff and update safety margins
        let cutoffScore = teamRankingList.last?.weeklyPoints ?? 0.0
        let finalTeamRankings = teamRankingList.map { ranking in
            return FantasyTeamRanking(
                id: ranking.id,
                team: ranking.team,
                weeklyPoints: ranking.weeklyPoints,
                rank: ranking.rank,
                eliminationStatus: ranking.eliminationStatus,
                isEliminated: ranking.isEliminated,
                survivalProbability: ranking.survivalProbability,
                pointsFromSafety: ranking.weeklyPoints - cutoffScore,
                weeksAlive: ranking.weeksAlive
            )
        }
        
        // Summary statistics
        let eliminatedTeam = finalTeamRankings.last
        let allScores = finalTeamRankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        return ChoppedWeekSummary(
            id: "week_\(viewModel.selectedWeek)",
            week: viewModel.selectedWeek,
            rankings: finalTeamRankings,
            eliminatedTeam: eliminatedTeam,
            cutoffScore: cutoffScore,
            isComplete: true,
            totalSurvivors: finalTeamRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: [] // No historical data for mock/fallback
        )
    }
    
    // MARK: -> Create Mock Chopped Teams for Demo
    private func createMockChoppedTeams() -> [FantasyTeam] {
        let mockTeams = [
            ("The Chopped Champions", "Gp", 142.8),
            ("Survival Squad", "Mike", 138.2),
            ("Last Stand United", "Sarah", 135.6),
            ("Death Dodgers", "Chris", 131.4),
            ("Battle Royale Bros", "Alex", 128.9),
            ("Elimination Elites", "Jordan", 125.3),
            ("Final Four", "Taylor", 122.7),
            ("Danger Zone Dawgs", "Casey", 118.1),
            ("Critical Condition", "Jamie", 114.5),
            ("About To Be Chopped", "Riley", 98.2)
        ]
        
        return mockTeams.enumerated().map { index, teamData in
            FantasyTeam(
                id: "mock_team_\(index)",
                name: teamData.0,
                ownerName: teamData.1,
                record: TeamRecord(wins: Int.random(in: 5...12), losses: Int.random(in: 1...8), ties: 0),
                avatar: nil,
                currentScore: teamData.2,
                projectedScore: teamData.2 + Double.random(in: -10...10),
                roster: [],
                rosterID: index + 1
            )
        }
    }
    
    // MARK: -> Connected League Setup
    /// Setup Fantasy to show only the connected league from War Room
    private func setupConnectedLeague() async {
        print("🔄 SETUP: Checking for connected league changes...")
        
        await viewModel.loadLeagues()
        
        // FIXED: Only use connected league from War Room - no switching allowed
        if let connectedLeagueWrapper = draftRoomViewModel.selectedLeagueWrapper {
            print("🏈 Fantasy: Connected league: '\(connectedLeagueWrapper.league.name)' (\(connectedLeagueWrapper.league.leagueID))")
            
            // Check if this is a different league than currently selected
            let isNewLeague = viewModel.selectedLeague?.league.leagueID != connectedLeagueWrapper.league.leagueID
            
            if isNewLeague {
                print("🔄 LEAGUE SWITCH: Switching from '\(viewModel.selectedLeague?.league.name ?? "none")' to '\(connectedLeagueWrapper.league.name)'")
                
                // Find matching league in Fantasy's available leagues
                if let matchingLeague = viewModel.availableLeagues.first(where: { 
                    $0.league.leagueID == connectedLeagueWrapper.league.leagueID 
                }) {
                    print("🏈 Fantasy: Loading matchups for new league: '\(matchingLeague.league.name)'")
                    viewModel.selectLeague(matchingLeague)
                } else {
                    print("❌ Fantasy: Connected league not found in available leagues")
                }
            } else {
                print("✅ Fantasy: Same league already selected, no change needed")
            }
        } else {
            print("⚠️ Fantasy: No connected league from War Room")
        }
    }
    
    // MARK: -> Connection Status Header
    private var connectionStatusHeader: some View {
        VStack(spacing: 12) {
            // Only show connection status in debug mode
            if AppConstants.debug {
                if let connectedLeague = draftRoomViewModel.selectedLeagueWrapper {
                    // Connected league info with auto-refresh toggle
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            // Source logo
                            Group {
                                if connectedLeague.source == .sleeper {
                                    AppConstants.sleeperLogo
                                        .frame(width: 20, height: 20)
                                } else {
                                    AppConstants.espnLogo
                                        .frame(width: 20, height: 20)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Image(systemName: "link")
                                        .foregroundColor(.green)
                                        .font(.system(size: 12))
                                    
                                    Text("Connected to '\(connectedLeague.league.name)'")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                
                                Text("From War Room • \(connectedLeague.source.displayName)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Auto-refresh toggle
                            Button(action: {
                                viewModel.toggleAutoRefresh()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(viewModel.autoRefresh ? .green : .secondary)
                                        .font(.system(size: 12))
                                    
                                    Text(viewModel.autoRefresh ? "ON" : "OFF")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(viewModel.autoRefresh ? .green : .secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                } else {
                    // No connection - prompt user (only in debug)
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            
                            Text("No League Connected")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        
                        Text("Go to War Room to connect to a league first")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                }
            }
            
            // DEBUG: ESPN Test Button (only in debug mode)
            if AppConstants.debug {
                NavigationLink(destination: ESPNFantasyTestView()) {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.red)
                        
                        Text("🔥 ESPN Fantasy Test (SleepThis Integration)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                
                // FORCE CHOPPED MODE BUTTON
                Button(action: {
                    forceChoppedMode.toggle()
                }) {
                    HStack {
                        Text("💀")
                        Text(forceChoppedMode ? "DISABLE CHOPPED MODE" : "🔥 FORCE CHOPPED BATTLE ROYALE 🔥")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.red)
                        Text("💀")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(forceChoppedMode ? 0.2 : 0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: -> Content Views (unchanged)
    private var loadingView: some View {
        FantasyLoadingIndicator()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No matchups available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("This week may not have started yet or league data is unavailable")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var matchupsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Regular matchups
                ForEach(viewModel.matchups) { matchup in
                    NavigationLink(destination: FantasyMatchupDetailView(
                        matchup: matchup,
                        fantasyViewModel: viewModel,
                        leagueName: viewModel.selectedLeague?.league.name ?? "League"
                    )) {
                        FantasyMatchupCard(matchup: matchup)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Bye week teams section
                if !viewModel.byeWeekTeams.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header
                        HStack {
                            Image(systemName: "bed.double")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            
                            Text("Bye Week")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.orange)
                            
                            Spacer()
                            
                            Text("\(viewModel.byeWeekTeams.count) team\(viewModel.byeWeekTeams.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Bye week teams
                        ForEach(viewModel.byeWeekTeams, id: \.id) { team in
                            ByeWeekCard(team: team, week: viewModel.selectedWeek)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: -> Fantasy Matchup Card
struct FantasyMatchupCard: View {
    let matchup: FantasyMatchup
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with week info
            HStack {
                Text("Week \(matchup.week)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(matchup.winProbabilityString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main matchup content
            HStack(spacing: 0) {
                // Away team (left side)
                teamSection(
                    team: matchup.awayTeam,
                    score: matchup.awayTeam.currentScoreString,
                    isHome: false
                )
                
                // VS divider  
                VStack {
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Week \(matchup.week)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(matchup.winProbabilityString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
                .frame(width: 60)
                
                // Home team (right side)
                teamSection(
                    team: matchup.homeTeam,
                    score: matchup.homeTeam.currentScoreString,
                    isHome: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func teamSection(team: FantasyTeam, score: String, isHome: Bool) -> some View {
        VStack(spacing: 8) {
            // Team avatar - Enhanced for ESPN teams
            Group {
                if let avatarURL = team.avatarURL {
                    // Sleeper leagues with real avatars
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            espnTeamAvatar(team: team)
                        case .empty:
                            espnTeamAvatar(team: team)
                        @unknown default:
                            espnTeamAvatar(team: team)
                        }
                    }
                } else {
                    // ESPN leagues with custom team avatars
                    espnTeamAvatar(team: team)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            // Team info
            VStack(spacing: 2) {
                Text(team.ownerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Text("PF: \(team.record?.wins ?? 0)nd • PA: \(team.record?.losses ?? 0)nd")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // Score
            Text(score)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isHome ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Custom ESPN team avatar with unique colors and better styling
    private func espnTeamAvatar(team: FantasyTeam) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        team.espnTeamColor,
                        team.espnTeamColor.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(team.espnTeamColor.opacity(0.3), lineWidth: 2)
            )
            .overlay(
                Text(team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
    }
}

// MARK: -> Bye Week Card
struct ByeWeekCard: View {
    let team: FantasyTeam
    let week: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Team avatar
            Group {
                if let avatarURL = team.avatarURL {
                    // Sleeper leagues with real avatars
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            espnTeamAvatar(team: team)
                        case .empty:
                            espnTeamAvatar(team: team)
                        @unknown default:
                            espnTeamAvatar(team: team)
                        }
                    }
                } else {
                    // ESPN leagues with custom team avatars
                    espnTeamAvatar(team: team)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .grayscale(0.5) // Make bye week avatars slightly faded
            
            // Team info
            VStack(alignment: .leading, spacing: 4) {
                Text(team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if let record = team.record {
                    Text(record.displayString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("No opponent this week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Bye week indicator
            VStack(spacing: 4) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                Text("BYE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("Week \(week)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            )
    }
    
    /// Custom ESPN team avatar (same as matchup card)
    private func espnTeamAvatar(team: FantasyTeam) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        team.espnTeamColor.opacity(0.6), // More faded for bye weeks
                        team.espnTeamColor.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(team.espnTeamColor.opacity(0.2), lineWidth: 2)
            )
            .overlay(
                Text(team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            )
    }
}