//
//  FantasyMatchupListViewModel.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI
import Foundation
import Combine

/// Coordinator ViewModel for FantasyMatchupListView
/// Handles smart mode detection, draft position management, and league setup
@MainActor
final class FantasyMatchupListViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var matchupsHubViewModel: MatchupsHubViewModel
    private let weekManager: WeekSelectionManager
    private let fantasyViewModel: FantasyViewModel
    private var draftRoomViewModel: DraftRoomViewModel?
    
    // MARK: - Published States
    @Published var showLeaguePicker = false
    @Published var availableLeagues: [UnifiedMatchup] = []
    @Published var showDraftPositionPicker = false
    @Published var selectedLeagueForPosition: UnifiedLeagueManager.LeagueWrapper?
    @Published var selectedDraftPosition = 1
    @Published var forceChoppedMode = false // DEBUG: Force chopped mode
    
    // MARK: - Race Condition Prevention
    @Published var isDetectingSmartMode = false
    @Published var isSettingUpLeague = false
    @Published var hasInitializedSmartMode = false
    
    init(
        weekManager: WeekSelectionManager = WeekSelectionManager.shared,
        fantasyViewModel: FantasyViewModel = FantasyViewModel.shared
    ) {
        self.weekManager = weekManager
        self.fantasyViewModel = fantasyViewModel
        self.matchupsHubViewModel = MatchupsHubViewModel()
    }
    
    // MARK: - Setup
    @MainActor
    func setSharedDraftRoomViewModel(_ draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
        fantasyViewModel.setSharedDraftRoomViewModel(draftRoomViewModel)
        
        // Ensure matchupsHubViewModel is initialized
        if matchupsHubViewModel == nil {
            matchupsHubViewModel = MatchupsHubViewModel()
        }
    }
    
    // MARK: - Smart Mode Detection
    /// Determines whether to show league picker, draft position picker, or single league view
    var shouldShowLeaguePicker: Bool {
        return showLeaguePicker && !availableLeagues.isEmpty && !isSettingUpLeague
    }
    
    /// Determines whether to show draft position picker
    var shouldShowDraftPositionPicker: Bool {
        return showDraftPositionPicker && selectedLeagueForPosition != nil
    }
    
    /// Smart detection of current context and mode (Race Condition Safe)
    @MainActor
    func smartModeDetection() async {
        // Prevent concurrent executions
        guard !isDetectingSmartMode else {
            print("🧠 SMART MODE: Already detecting, skipping...")
            return
        }
        
        isDetectingSmartMode = true
        defer { isDetectingSmartMode = false }
        
        print("🧠 SMART MODE: Detecting current context...")
        
        // Ensure matchupsHubViewModel is initialized
        if matchupsHubViewModel == nil {
            matchupsHubViewModel = MatchupsHubViewModel()
        }
        
        // Load all available matchups first
        await matchupsHubViewModel.loadAllMatchups()
        availableLeagues = matchupsHubViewModel.myMatchups
        
        print("🧠 SMART MODE: Found \(availableLeagues.count) available leagues")
        
        // Check if we have a specific league selected from War Room
        if let connectedLeague = draftRoomViewModel?.selectedLeagueWrapper {
            print("🧠 SMART MODE: War Room has selected league: \(connectedLeague.league.name)")
            print("🧠 SMART MODE: → SINGLE LEAGUE MODE")
            
            // Single League Mode - setup that specific league
            showLeaguePicker = false
            showDraftPositionPicker = false
            await setupSingleLeague(connectedLeague)
            
        } else if fantasyViewModel.selectedLeague == nil && availableLeagues.count > 1 {
            print("🧠 SMART MODE: No specific league selected, multiple leagues available")
            print("🧠 SMART MODE: → ALL LEAGUES MODE (Show Picker)")
            
            // All Leagues Mode - show picker
            showLeaguePicker = true
            showDraftPositionPicker = false
            
        } else if availableLeagues.count == 1 {
            print("🧠 SMART MODE: Only one league available, checking draft position...")
            
            let league = availableLeagues[0].league
            
            // Check if we need draft position for this league
            if needsDraftPosition(for: league) {
                print("🧠 SMART MODE: → DRAFT POSITION SELECTION NEEDED")
                showLeaguePicker = false
                selectedLeagueForPosition = league
                showDraftPositionPicker = true
            } else {
                print("🧠 SMART MODE: → AUTO SINGLE LEAGUE MODE")
                // Auto-select the only available league
                showLeaguePicker = false
                showDraftPositionPicker = false
                await setupSingleLeague(league)
            }
            
        } else {
            print("🧠 SMART MODE: No leagues available or already selected")
            print("🧠 SMART MODE: → MAINTAIN CURRENT STATE")
            
            // Maintain current state
            showLeaguePicker = false
            showDraftPositionPicker = false
        }
    }
    
    // MARK: - Draft Position Management
    
    /// Check if a league needs draft position selection
    func needsDraftPosition(for league: UnifiedLeagueManager.LeagueWrapper) -> Bool {
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
    func getSavedDraftPosition(for league: UnifiedLeagueManager.LeagueWrapper) -> Int? {
        @AppStorage("draftPosition") var storedDraftPositions: String = "{}"
        
        guard let data = storedDraftPositions.data(using: .utf8),
              let positions = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            return nil
        }
        
        return positions[league.league.name]
    }
    
    /// Handle draft position confirmation
    @MainActor
    func confirmDraftPosition(_ league: UnifiedLeagueManager.LeagueWrapper, position: Int) {
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
    @MainActor
    func cancelDraftPositionSelection() {
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
    
    /// Handle league selection from gorgeous picker
    @MainActor
    func selectLeagueFromPicker(_ selectedLeague: UnifiedLeagueManager.LeagueWrapper) {
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
    
    /// Setup Fantasy for a specific league (Race Condition Safe)
    @MainActor
    func setupSingleLeague(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper, draftPosition: Int? = nil) async {
        // Prevent concurrent executions
        guard !isSettingUpLeague else {
            print("🏈 Fantasy: Already setting up league, skipping...")
            return
        }
        
        isSettingUpLeague = true
        defer { isSettingUpLeague = false }
        
        print("🏈 Fantasy: Setting up single league: \(leagueWrapper.league.name)")
        if let position = draftPosition {
            print("🏈 Fantasy: With draft position: \(position)")
        }
        
        // Ensure we're on the main actor for UI updates
        fantasyViewModel.isLoading = true
        fantasyViewModel.errorMessage = nil
        
        // Load all available leagues if not already loaded
        await fantasyViewModel.loadLeagues()
        
        // Find matching league in Fantasy's available leagues
        if let matchingLeague = fantasyViewModel.availableLeagues.first(where: { 
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
            if let teamID = myTeamID {
                fantasyViewModel.selectLeague(matchingLeague, myTeamID: teamID)
            } else {
                fantasyViewModel.selectLeague(matchingLeague)
            }
            
            // Wait for data loading to complete with timeout
            var attempts = 0
            let maxAttempts = 20 // 2 seconds max
            
            while fantasyViewModel.matchups.isEmpty && !fantasyViewModel.detectedAsChoppedLeague && !fantasyViewModel.hasActiveRosters && attempts < maxAttempts {
                try? await Task.sleep(for: .milliseconds(100))
                attempts += 1
            }
            
            // Ensure loading state is cleared
            fantasyViewModel.isLoading = false
            
            // Force UI refresh
            if !fantasyViewModel.matchups.isEmpty || fantasyViewModel.detectedAsChoppedLeague || fantasyViewModel.hasActiveRosters {
                print("🏈 Fantasy: League setup complete with data")
            } else {
                print("⚠️ Fantasy: League setup complete but no data found")
            }
        } else {
            print("❌ Fantasy: League not found in available leagues")
            fantasyViewModel.isLoading = false
            fantasyViewModel.errorMessage = "League not found in available leagues"
        }
    }
    
    // MARK: - Loading State Detection
    /// Determines when to show loading spinner instead of empty state
    func shouldShowLoadingState() -> Bool {
        // Always show loading if no connected league yet
        guard let connectedLeague = draftRoomViewModel?.selectedLeagueWrapper else {
            return true
        }
        
        // Show loading if we have a connected league but no selected league in viewModel yet
        if fantasyViewModel.selectedLeague == nil {
            return true
        }
        
        // Show loading if league IDs don't match (still switching leagues)
        if fantasyViewModel.selectedLeague?.league.leagueID != connectedLeague.league.leagueID {
            return true
        }
        
        // Show loading if we have no matchups AND no rosters AND not detected as chopped yet
        if fantasyViewModel.matchups.isEmpty && !fantasyViewModel.hasActiveRosters && !fantasyViewModel.detectedAsChoppedLeague {
            return true
        }
        
        return false
    }
    
    // MARK: - Chopped League Detection
    func isChoppedLeague() -> Bool {
        // NEW: Use FantasyViewModel's data-based detection
        if fantasyViewModel.detectedAsChoppedLeague {
            return true
        }
        
        // FALLBACK: Check connected league settings (only for Sleeper)
        if let leagueWrapper = draftRoomViewModel?.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper,
           let sleeperLeague = leagueWrapper.league as? SleeperLeague {
            return sleeperLeague.settings?.isChoppedLeague ?? false
        }
        
        return false
    }
    
    /// Should hide the navigation title (only for Chopped leagues)
    func shouldHideTitle() -> Bool {
        // Only hide title for confirmed Chopped leagues (avoid flickering)
        guard let league = fantasyViewModel.selectedLeague else { return false }
        
        // ESPN leagues should ALWAYS show title
        if league.source == .espn { return false }
        
        // Only hide for definitively detected Chopped leagues
        return fantasyViewModel.detectedAsChoppedLeague || forceChoppedMode
    }
    
    // MARK: - Mock Data Creation
    func createChoppedSummaryFromMatchups() -> ChoppedWeekSummary {
        // If this is a real Chopped league, fetch real data
        if let leagueWrapper = draftRoomViewModel?.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper {
            
            // Try to get real Chopped data from FantasyViewModel
            let task = Task {
                return await fantasyViewModel.createRealChoppedSummary(
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
        for matchup in fantasyViewModel.matchups {
            allTeams.append(matchup.homeTeam)
            allTeams.append(matchup.awayTeam)
        }
        
        // Add bye week teams
        allTeams.append(contentsOf: fantasyViewModel.byeWeekTeams)
        
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
    
    /// Create Mock Chopped Teams for Demo
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
}