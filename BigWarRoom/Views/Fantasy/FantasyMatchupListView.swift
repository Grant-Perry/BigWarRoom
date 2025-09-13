//
//  FantasyMatchupListView.swift  
//  BigWarRoom
//
// MARK: -> Fantasy Matchup List View

import SwiftUI

struct FantasyMatchupListView: View {
    let draftRoomViewModel: DraftRoomViewModel  // Accept the shared view model
    @StateObject private var viewModel = FantasyViewModel.shared
    @StateObject private var weekManager = WeekSelectionManager.shared
    @StateObject private var matchupsHubViewModel = MatchupsHubViewModel()
    @State private var forceChoppedMode = false // DEBUG: Force chopped mode
    @State private var showLeaguePicker = false
    @State private var availableLeagues: [UnifiedMatchup] = []
    
    // MARK: - Race Condition Prevention
    @State private var isDetectingSmartMode = false
    @State private var isSettingUpLeague = false
    @State private var hasInitializedSmartMode = false
    
    // MARK: - Draft Position Selection
    @State private var showDraftPositionPicker = false
    @State private var selectedLeagueForPosition: UnifiedLeagueManager.LeagueWrapper?
    @State private var selectedDraftPosition = 1
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                // Smart Mode Detection
                if shouldShowLeaguePicker {
                    // ALL LEAGUES MODE: Show gorgeous picker overlay
                    Color.clear // Transparent background for overlay
                } else if shouldShowDraftPositionPicker {
                    // DRAFT POSITION MODE: Show position picker
                    Color.clear // Transparent background for sheet
                } else {
                    // SINGLE LEAGUE MODE: Normal Fantasy view
                    singleLeagueContent
                }
            }
            .navigationTitle(shouldHideTitle ? "" : (viewModel.selectedLeague?.league.name ?? "Fantasy"))
            .navigationBarTitleDisplayMode(shouldHideTitle ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Week \(weekManager.selectedWeek)") {
                        viewModel.presentWeekSelector()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showWeekSelector) {
                WeekPickerView(
                    isPresented: $viewModel.showWeekSelector
                )
            }
            .sheet(isPresented: $showDraftPositionPicker) {
                if let league = selectedLeagueForPosition {
                    ESPNDraftPickSelectionSheet.forDraft(
                        leagueName: league.league.name,
                        maxTeams: league.league.totalRosters,
                        selectedPosition: $selectedDraftPosition,
                        onConfirm: { position in
                            confirmDraftPosition(league, position: position)
                        },
                        onCancel: {
                            cancelDraftPositionSelection()
                        }
                    )
                }
            }
            .task {
                // Only run once on initial load
                if !hasInitializedSmartMode {
                    await smartModeDetection()
                    hasInitializedSmartMode = true
                }
            }
            .onReceive(draftRoomViewModel.$selectedLeagueWrapper) { newLeague in
                // Only react to actual changes, not repeat values
                guard !isSettingUpLeague else {
                    print("🔄 LEAGUE CHANGE: Ignoring during setup")
                    return
                }
                
                print("🔄 LEAGUE CHANGE DETECTED: \(newLeague?.league.name ?? "nil")")
                
                // Debounce this call to prevent rapid fire
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    if !isDetectingSmartMode && !isSettingUpLeague {
                        await smartModeDetection()
                    }
                }
            }
            .onAppear {
                // Pass the shared DraftRoomViewModel to FantasyViewModel
                viewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay {
            // League Picker Overlay
            if showLeaguePicker {
                LeaguePickerOverlay(
                    leagues: availableLeagues,
                    onLeagueSelected: { selectedLeague in
                        selectLeagueFromPicker(selectedLeague)
                    },
                    onDismiss: {
                        showLeaguePicker = false
                    }
                )
                .zIndex(1000) // Ensure it's on top
            }
        }
    }
    
    // MARK: - Smart Mode Detection (Updated for Draft Position)
    /// Determines whether to show league picker, draft position picker, or single league view
    private var shouldShowLeaguePicker: Bool {
        return showLeaguePicker && !availableLeagues.isEmpty && !isSettingUpLeague
    }
    
    /// Determines whether to show draft position picker
    private var shouldShowDraftPositionPicker: Bool {
        return showDraftPositionPicker && selectedLeagueForPosition != nil
    }
    
    /// Smart detection of current context and mode (Race Condition Safe)
    private func smartModeDetection() async {
        // Prevent concurrent executions
        guard !isDetectingSmartMode else {
            print("🧠 SMART MODE: Already detecting, skipping...")
            return
        }
        
        isDetectingSmartMode = true
        defer { isDetectingSmartMode = false }
        
        print("🧠 SMART MODE: Detecting current context...")
        
        // Load all available matchups first
        await matchupsHubViewModel.loadAllMatchups()
        await MainActor.run {
            availableLeagues = matchupsHubViewModel.myMatchups
        }
        
        print("🧠 SMART MODE: Found \(availableLeagues.count) available leagues")
        
        // Check if we have a specific league selected from War Room
        if let connectedLeague = draftRoomViewModel.selectedLeagueWrapper {
            print("🧠 SMART MODE: War Room has selected league: \(connectedLeague.league.name)")
            print("🧠 SMART MODE: → SINGLE LEAGUE MODE")
            
            // Single League Mode - setup that specific league
            await MainActor.run {
                showLeaguePicker = false
                showDraftPositionPicker = false
            }
            await setupSingleLeague(connectedLeague)
            
        } else if viewModel.selectedLeague == nil && availableLeagues.count > 1 {
            print("🧠 SMART MODE: No specific league selected, multiple leagues available")
            print("🧠 SMART MODE: → ALL LEAGUES MODE (Show Picker)")
            
            // All Leagues Mode - show picker
            await MainActor.run {
                showLeaguePicker = true
                showDraftPositionPicker = false
            }
            
        } else if availableLeagues.count == 1 {
            print("🧠 SMART MODE: Only one league available, checking draft position...")
            
            let league = availableLeagues[0].league
            
            // Check if we need draft position for this league
            if needsDraftPosition(for: league) {
                print("🧠 SMART MODE: → DRAFT POSITION SELECTION NEEDED")
                await MainActor.run {
                    showLeaguePicker = false
                    selectedLeagueForPosition = league
                    showDraftPositionPicker = true
                }
            } else {
                print("🧠 SMART MODE: → AUTO SINGLE LEAGUE MODE")
                // Auto-select the only available league
                await MainActor.run {
                    showLeaguePicker = false
                    showDraftPositionPicker = false
                }
                await setupSingleLeague(league)
            }
            
        } else {
            print("🧠 SMART MODE: No leagues available or already selected")
            print("🧠 SMART MODE: → MAINTAIN CURRENT STATE")
            
            // Maintain current state
            await MainActor.run {
                showLeaguePicker = false
                showDraftPositionPicker = false
            }
        }
    }
    
    // MARK: - Draft Position Management
    
    /// Check if a league needs draft position selection
    private func needsDraftPosition(for league: UnifiedLeagueManager.LeagueWrapper) -> Bool {
        // Always need position if coming from Fantasy directly (not War Room)
        // War Room handles position selection, so if we're here without War Room connection, we need it
        
        // Check if we have a saved position for this league
        @AppStorage("draftPosition") var storedDraftPositions: String = "{}"
        
        if let data = storedDraftPositions.data(using: .utf8),
           let positions = try? JSONSerialization.jsonObject(with: data) as? [String: Int],
           let _ = positions[league.league.name] {
            // We have a saved position for this league
            return false
        }
        
        // No saved position and not coming from War Room = need position
        return true
    }
    
    /// Get saved draft position for a league
    private func getSavedDraftPosition(for league: UnifiedLeagueManager.LeagueWrapper) -> Int? {
        @AppStorage("draftPosition") var storedDraftPositions: String = "{}"
        
        guard let data = storedDraftPositions.data(using: .utf8),
              let positions = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            return nil
        }
        
        return positions[league.league.name]
    }
    
    /// Handle draft position confirmation
    private func confirmDraftPosition(_ league: UnifiedLeagueManager.LeagueWrapper, position: Int) {
        print("🎯 DRAFT POSITION: User selected position \(position) for league: \(league.league.name)")
        
        // Dismiss the position picker
        showDraftPositionPicker = false
        selectedLeagueForPosition = nil
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Setup the league with the confirmed position
        Task {
            // Store the position for future use (handled by the sheet)
            await setupSingleLeague(league, draftPosition: position)
        }
    }
    
    /// Handle draft position selection cancellation
    private func cancelDraftPositionSelection() {
        print("🎯 DRAFT POSITION: User cancelled position selection")
        
        // Go back to league picker if we had multiple leagues, or show empty state
        if availableLeagues.count > 1 {
            showDraftPositionPicker = false
            selectedLeagueForPosition = nil
            showLeaguePicker = true
        } else {
            // Single league but user cancelled - show empty state or prompt
            showDraftPositionPicker = false
            selectedLeagueForPosition = nil
        }
    }
    
    /// Setup Fantasy for a specific league (Race Condition Safe) - Updated with optional position
    private func setupSingleLeague(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper, draftPosition: Int? = nil) async {
        // Prevent concurrent executions
        guard !isSettingUpLeague else {
            print("🏈 Fantasy: Already setting up league, skipping...")
            return
        }
        
        isSettingUpLeague = true
        defer { isSettingUpLeague = false }
        
        print("🏈 Fantasy: Setting up single league: \(leagueWrapper.league.name)")
        if let position = draftPosition {
            print("🏈 Fantasy:With draft position: \(position)")
        }
        
        // Ensure we're on the main actor for UI updates
        await MainActor.run {
            viewModel.isLoading = true
            viewModel.errorMessage = nil
        }
        
        // Load all available leagues if not already loaded
        await viewModel.loadLeagues()
        
        // Find matching league in Fantasy's available leagues
        if let matchingLeague = viewModel.availableLeagues.first(where: { 
            $0.league.leagueID == leagueWrapper.league.leagueID 
        }) {
            print("🏈 Fantasy: Loading matchups for league: \(matchingLeague.league.name)")
            
            // Determine team ID based on draft position or saved position
            var myTeamID: String?
            
            if let position = draftPosition {
                // Use the confirmed position to find team ID
                myTeamID = "\(position)" // Simplified - you might need more complex logic
            } else if let savedPosition = getSavedDraftPosition(for: leagueWrapper) {
                // Use saved position
                myTeamID = "\(savedPosition)"
            }
            
            // Select the league with team ID for proper identification
            await MainActor.run {
                if let teamID = myTeamID {
                    viewModel.selectLeague(matchingLeague, myTeamID: teamID)
                } else {
                    viewModel.selectLeague(matchingLeague)
                }
            }
            
            // Wait for data loading to complete with timeout
            var attempts = 0
            let maxAttempts = 20 // 2 seconds max
            
            while viewModel.matchups.isEmpty && !viewModel.detectedAsChoppedLeague && !viewModel.hasActiveRosters && attempts < maxAttempts {
                try? await Task.sleep(for: .milliseconds(100))
                attempts += 1
            }
            
            // Ensure loading state is cleared
            await MainActor.run {
                viewModel.isLoading = false
                
                // Force UI refresh
                if !viewModel.matchups.isEmpty || viewModel.detectedAsChoppedLeague || viewModel.hasActiveRosters {
                    print("🏈 Fantasy: League setup complete with data")
                } else {
                    print("⚠️ Fantasy: League setup complete but no data found")
                }
            }
        } else {
            print("❌ Fantasy: League not found in available leagues")
            await MainActor.run {
                viewModel.isLoading = false
                viewModel.errorMessage = "League not found in available leagues"
            }
        }
    }
    
    /// Handle league selection from gorgeous picker (Updated for Draft Position)
    private func selectLeagueFromPicker(_ selectedLeague: UnifiedLeagueManager.LeagueWrapper) {
        guard !isSettingUpLeague else {
            print("🎯 PICKER: Selection ignored - already setting up league")
            return
        }
        
        print("🎯 PICKER: User selected league: \(selectedLeague.league.name)")
        
        // Immediate UI feedback - dismiss picker first
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showLeaguePicker = false
        }
        
        // Haptic feedback for selection
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Check if we need draft position for this league
        if needsDraftPosition(for: selectedLeague) {
            print("🎯 PICKER: Draft position needed for league: \(selectedLeague.league.name)")
            
            // Show draft position picker
            selectedLeagueForPosition = selectedLeague
            showDraftPositionPicker = true
        } else {
            print("🎯 PICKER: Using saved position or War Room position")
            
            // Setup the selected league directly
            Task {
                await setupSingleLeague(selectedLeague)
            }
        }
    }
    
    // MARK: - Single League Content (Existing Content)
    private var singleLeagueContent: some View {
        VStack(spacing: 0) {
            // Connection status header (always show)
            connectionStatusHeader
            
            // Matchups content
            if viewModel.isLoading || shouldShowLoadingState {
                loadingView
            } else if viewModel.detectedAsChoppedLeague || isChoppedLeague || forceChoppedMode {
                choppedLeaderboardView
            } else if viewModel.matchups.isEmpty && viewModel.hasActiveRosters {
                choppedLeaderboardView
            } else if viewModel.matchups.isEmpty && !viewModel.hasActiveRosters {
                emptyStateView
            } else {
                matchupsList
            }
        }
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
                    week: weekManager.selectedWeek,
                    fantasyViewModel: viewModel
                )
            )
        } else {
            // Fallback to mock data for non-Sleeper leagues
            let choppedSummary = createChoppedSummaryFromMatchups()
            return AnyView(
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: viewModel.selectedLeague?.league.name ?? "Chopped League",
                    leagueID: viewModel.selectedLeague?.league.leagueID ?? "" // 🔥 NEW: Pass league ID
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
                    week: weekManager.selectedWeek
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
                weeksAlive: weekManager.selectedWeek
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
            id: "week_\(weekManager.selectedWeek)",
            week: weekManager.selectedWeek,
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