//
//  AllLivePlayersViewModel.swift
//  BigWarRoom
//
//  ViewModel for aggregating all active players across all leagues
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AllLivePlayersViewModel: ObservableObject {
    // 🔥 NEW: Shared singleton instance
    static let shared = AllLivePlayersViewModel()
    
    @Published var allPlayers: [LivePlayerEntry] = []
    @Published var filteredPlayers: [LivePlayerEntry] = []
    @Published var selectedPosition: PlayerPosition = .all
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var topScore: Double = 0.0
    @Published var sortHighToLow = true
    @Published var sortingMethod: SortingMethod = .score
    @Published var showActiveOnly: Bool = false // Changed from includeCompletedGames
    
    // 🔥 NEW: Animation state management
    @Published var shouldResetAnimations = false
    @Published var sortChangeID = UUID()
    
    @Published var medianScore: Double = 0.0
    @Published var scoreRange: Double = 0.0
    @Published var useAdaptiveScaling: Bool = false
    
    @Published var positionTopScore: Double = 0.0
    
    // 🔥 NEW: Centralized player stats
    @Published var playerStats: [String: [String: Double]] = [:]
    @Published var statsLoaded: Bool = false
    
    let matchupsHubViewModel = MatchupsHubViewModel()
    
    // 🔥 NEW: Week selection subscription with debouncing
    private var weekSubscription: AnyCancellable?
    private var debounceTask: Task<Void, Never>?
    
    // 🔥 PERFORMANCE: Batch update control
    private var isBatchingUpdates = false
    
    // 🔥 NEW: Private init for singleton
    private init() {
        // Subscribe to week changes to invalidate stats with debouncing
        subscribeToWeekChanges()
        
        // Scoring settings are now extracted from existing API calls automatically
        // No separate initialization needed
    }
    
    // MARK: - Business Logic (Moved from View)
    
    /// Get the first available manager from loaded matchups
    var firstAvailableManager: ManagerInfo? {
        for matchup in matchupsHubViewModel.myMatchups {
            if let myTeam = matchup.myTeam {
                let isWinning = determineIfWinning(matchup: matchup, team: myTeam)
                return ManagerInfo(
                    name: myTeam.ownerName,
                    score: myTeam.currentScore ?? 0.0,
                    avatarURL: myTeam.avatarURL,
                    scoreColor: isWinning ? .green : .red
                )
            }
        }
        return nil
    }
    
    /// Determine if a team is currently winning their matchup
    private func determineIfWinning(matchup: UnifiedMatchup, team: FantasyTeam) -> Bool {
        // For chopped leagues, use ranking logic
        if matchup.isChoppedLeague {
            return true // Default to green for chopped leagues since there's no direct opponent
        }
        
        // For regular matchups, compare against opponent
        guard let opponent = matchup.opponentTeam else { return true }
        return (team.currentScore ?? 0.0) > (opponent.currentScore ?? 0.0)
    }
    
    /// Get dynamic sort direction text based on current sorting method
    var sortDirectionText: String {
        switch sortingMethod {
        case .score:
            return sortHighToLow ? "Highest" : "Lowest"
        case .name:
            return sortHighToLow ? "A to Z" : "Z to A"
        case .team:
            return sortHighToLow ? "A to Z" : "Z to A"
        }
    }
    
    /// Check if we have leagues connected but no players for current position
    var hasLeaguesButNoPlayers: Bool {
        return !matchupsHubViewModel.myMatchups.isEmpty && filteredPlayers.isEmpty && !isLoading
    }
    
    /// Check if we have no leagues connected
    var hasNoLeagues: Bool {
        return matchupsHubViewModel.myMatchups.isEmpty
    }
    
    /// Get count of connected leagues for display
    var connectedLeaguesCount: Int {
        return matchupsHubViewModel.myMatchups.count
    }
    
    /// Apply current sorting direction to filtered players
    func applySorting() {
        // 🔥 FIXED: Clear animation state when sorting changes
        triggerAnimationReset()
        applyPositionFilter() // Re-apply filter with current sort settings
    }
    
    // 🔥 NEW: Debounced week change subscription
    private func subscribeToWeekChanges() {
        weekSubscription = WeekSelectionManager.shared.$selectedWeek
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // Add 500ms debounce
            .sink { [weak self] newWeek in
                // print("📊 AllLivePlayersViewModel: Week changed to \(newWeek), invalidating stats (debounced)")
                
                // Cancel any existing debounce task
                self?.debounceTask?.cancel()
                
                // Create new debounced task
                self?.debounceTask = Task { @MainActor in
                    // When week changes, invalidate stats to force reload
                    self?.statsLoaded = false
                    self?.playerStats = [:]
                    
                    // Only reload if we have existing players (avoid unnecessary loads)
                    if !(self?.allPlayers.isEmpty ?? true) {
                        await self?.loadPlayerStats()
                    }
                }
            }
    }
    
    // 🔥 NEW: Cleanup method
    deinit {
        debounceTask?.cancel()
        weekSubscription?.cancel()
    }

    // 🔥 NEW: Synchronous stats loading method for immediate access
    func loadStatsIfNeeded() {
        guard !statsLoaded else { 
            // print("📊 Stats already loaded, skipping...")
            return 
        }
        
        // print("📊 Starting synchronous stats load...")
        
        Task {
            await loadPlayerStats()
        }
    }
    
    // MARK: - Player Position Filter
    enum PlayerPosition: String, CaseIterable, Identifiable {
        case all = "All"
        case qb = "QB"
        case rb = "RB"
        case wr = "WR"
        case te = "TE"
        case k = "K"
        case def = "DEF"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
    
    // MARK: - Live Player Entry
    struct LivePlayerEntry: Identifiable {
        let id: String
        let player: FantasyPlayer
        let leagueName: String
        let leagueSource: String
        let currentScore: Double
        let projectedScore: Double
        let isStarter: Bool
        let percentageOfTop: Double
        let matchup: UnifiedMatchup
        let performanceTier: PerformanceTier
        
        var scoreBarWidth: Double {
            // Reduce minimum to 8%, increase scalable to 92% for steeper decline
            let minBarWidth: Double = 0.08
            let scalableWidth: Double = 0.92
            
            return minBarWidth + (percentageOfTop * scalableWidth)
        }
        
        var position: String {
            return player.position
        }
        
        var teamName: String {
            return player.team ?? ""
        }
        
        var playerName: String {
            return player.fullName
        }
        
        var currentScoreString: String {
            return String(format: "%.2f", currentScore)
        }
    }
    
    enum PerformanceTier: String, CaseIterable {
        case elite = "Elite"
        case good = "Good"
        case average = "Average"
        case struggling = "Struggling"
        
        var color: Color {
            switch self {
            case .elite: return .gpGreen
            case .good: return .blue
            case .average: return .orange
            case .struggling: return .red
            }
        }
    }
    
    // MARK: - Sorting Method
    enum SortingMethod: String, CaseIterable, Identifiable {
        case score = "Score"
        case name = "Name"
        case team = "Team"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
    
    // MARK: - Data Loading
    
    // 🔥 CLEANED UP: Ensure stats are loaded in loadAllPlayers
    func loadAllPlayers() async {
        isLoading = true
        errorMessage = nil
        
        // Load stats first if not already loaded
        if !statsLoaded {
            await loadPlayerStats()
        }
        
        do {
            // Use MatchupsHubViewModel to get current matchups
            await matchupsHubViewModel.loadAllMatchups()
            
            var allPlayerEntries: [LivePlayerEntry] = []
            
            // Extract players from each matchup (with temporary values)
            for matchup in matchupsHubViewModel.myMatchups {
                let playersFromMatchup = extractPlayersFromMatchup(matchup)
                allPlayerEntries.append(contentsOf: playersFromMatchup)
            }
            
            // Calculate overall statistics
            let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
            topScore = scores.first ?? 1.0
            let bottomScore = scores.last ?? 0.0
            scoreRange = topScore - bottomScore
            
            // Calculate median
            if !scores.isEmpty {
                let mid = scores.count / 2
                medianScore = scores.count % 2 == 0 ? 
                    (scores[mid - 1] + scores[mid]) / 2 : 
                    scores[mid]
            }
            
            // Use adaptive scaling if there's a huge gap (top score is 3x+ median)
            useAdaptiveScaling = topScore > (medianScore * 3)
            
            // Calculate quartiles for tier determination
            let quartiles = calculateQuartiles(from: scores)
            
            // 🔥 PERFORMANCE: Batch updates to prevent UI churn
            await performBatchUpdate {
                // Update all players with proper percentages and tiers
                allPlayers = allPlayerEntries.map { entry in
                    let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: topScore)
                    let tier = determinePerformanceTier(score: entry.currentScore, quartiles: quartiles)
                    
                    return LivePlayerEntry(
                        id: entry.id,
                        player: entry.player,
                        leagueName: entry.leagueName,
                        leagueSource: entry.leagueSource,  // 🔥 FIXED: Use actual leagueSource, not leagueName!
                        currentScore: entry.currentScore,
                        projectedScore: entry.projectedScore,
                        isStarter: entry.isStarter,
                        percentageOfTop: percentage,
                        matchup: entry.matchup,
                        performanceTier: tier
                    )
                }
                
                // Apply initial filter
                applyPositionFilter()
                
                // 🔥 NEW: Debug Josh Allen after loading
                debugJoshAllenScoreDifferences()
            }
            
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // 🔥 IMPROVED: Add method to force refresh stats
    func forceLoadStats() async {
        // print("📊 Force loading stats...")
        statsLoaded = false
        await loadPlayerStats()
    }
    
    // 🔥 IMPROVED: Non-blocking stats loading with better error handling
    private func loadPlayerStats() async {
        // Prevent multiple concurrent loads
        guard !Task.isCancelled else { return }
        
        let currentYear = AppConstants.currentSeasonYear
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let urlString = "https://api.sleeper.app/v1/stats/nfl/regular/\(currentYear)/\(selectedWeek)"
        
        // print("📊 AllLivePlayersViewModel: Loading stats for Week \(selectedWeek) (async)")
        
        guard let url = URL(string: urlString) else { 
            // print("❌ AllLivePlayersViewModel: Invalid URL: \(urlString)")
            await MainActor.run {
                self.statsLoaded = true
            }
            return 
        }
        
        do {
            // Use async URLSession with timeout to prevent hanging
            let request = URLRequest(url: url, timeoutInterval: 10.0)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Check if task was cancelled before processing
            guard !Task.isCancelled else { return }
            
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            await MainActor.run {
                // Final check before updating UI
                guard !Task.isCancelled else { return }
                
                self.playerStats = statsData
                self.statsLoaded = true
                // print("✅ AllLivePlayersViewModel: Stats loaded for Week \(selectedWeek). Player count: \(statsData.keys.count)")
                
                // Only update UI if we're not cancelled
                self.objectWillChange.send()
            }
            
        } catch {
            // print("❌ AllLivePlayersViewModel: Stats loading failed for Week \(selectedWeek): \(error)")
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.statsLoaded = true // Mark as loaded even on error to prevent infinite loading
                self.objectWillChange.send()
            }
        }
    }

    // 🔥 CRITICAL BUG FIX: Only extract players from MY teams, not opponent teams!
    private func extractPlayersFromMatchup(_ matchup: UnifiedMatchup) -> [LivePlayerEntry] {
        var players: [LivePlayerEntry] = []
        
        // print("🔍 EXTRACTING PLAYERS from matchup: \(matchup.league.league.name)")
        
        // For regular matchups, extract ONLY from MY team
        if let fantasyMatchup = matchup.fantasyMatchup {
            // print("   - Regular matchup detected")
            // print("   - Home team: \(fantasyMatchup.homeTeam.ownerName) (ID: \(fantasyMatchup.homeTeam.id))")
            // print("   - Away team: \(fantasyMatchup.awayTeam.ownerName) (ID: \(fantasyMatchup.awayTeam.id))")
            
            // 🔥 CRITICAL FIX: Only extract from MY team, not both teams!
            if let myTeam = matchup.myTeam {
                // print("   - My team identified: \(myTeam.ownerName) (ID: \(myTeam.id))")
                
                let myStarters = myTeam.roster.filter { $0.isStarter }
                // print("   - My starters count: \(myStarters.count)")
                
                for player in myStarters {
                    // 🔥 NEW: Debug Josh Allen specifically
                    if player.fullName.contains("Josh Allen") {
                        print("🎯 JOSH ALLEN DEBUG:")
                        print("   League: \(matchup.league.league.name) (ID: \(matchup.league.league.id))")
                        print("   Source: \(matchup.league.source)")
                        print("   Player ID: \(player.id)")
                        print("   ESPN ID: \(player.espnID ?? "none")")
                        print("   Sleeper ID: \(player.sleeperID ?? "none")")
                        print("   Current Points: \(player.currentPoints ?? 0.0)")
                        print("   Projected Points: \(player.projectedPoints ?? 0.0)")
                        print("   Position: \(player.position)")
                        print("   Team: \(player.team ?? "none")")
                    }
                    
                    players.append(LivePlayerEntry(
                        id: "\(matchup.id)_my_\(player.id)",
                        player: player,
                        leagueName: matchup.league.league.name,
                        leagueSource: matchup.league.source.rawValue,
                        currentScore: player.currentPoints ?? 0.0,
                        projectedScore: player.projectedPoints ?? 0.0,
                        isStarter: player.isStarter,
                        percentageOfTop: 0.0, // Will be calculated later
                        matchup: matchup,
                        performanceTier: .average // Temporary, will be calculated later
                    ))
                }
            } else {
                // print("   ❌ ERROR: Could not identify my team in this matchup!")
            }
        }
        
        // For Chopped leagues, extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            // print("   - Chopped league detected")
            // print("   - My team: \(myTeamRanking.team.ownerName) (ID: \(myTeamRanking.team.id))")
            
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }
            // print("   - My chopped starters count: \(myTeamStarters.count)")
            
            for player in myTeamStarters {
                // 🔥 NEW: Debug Josh Allen specifically
                if player.fullName.contains("Josh Allen") {
                    print("🎯 JOSH ALLEN CHOPPED DEBUG:")
                    print("   League: \(matchup.league.league.name) (ID: \(matchup.league.league.id))")
                    print("   Source: \(matchup.league.source)")
                    print("   Player ID: \(player.id)")
                    print("   ESPN ID: \(player.espnID ?? "none")")
                    print("   Sleeper ID: \(player.sleeperID ?? "none")")
                    print("   Current Points: \(player.currentPoints ?? 0.0)")
                    print("   Projected Points: \(player.projectedPoints ?? 0.0)")
                    print("   Position: \(player.position)")
                    print("   Team: \(player.team ?? "none")")
                }
                
                players.append(LivePlayerEntry(
                    id: "\(matchup.id)_chopped_\(player.id)",
                    player: player,
                    leagueName: matchup.league.league.name,
                    leagueSource: matchup.league.source.rawValue,
                    currentScore: player.currentPoints ?? 0.0,
                    projectedScore: player.projectedPoints ?? 0.0,
                    isStarter: player.isStarter,
                    percentageOfTop: 0.0, // Will be calculated later
                    matchup: matchup,
                    performanceTier: .average // Temporary, will be calculated later
                ))
            }
        }
        
//        // print("   - Total players extracted: \(players.count)")
        return players
    }
    
    // MARK: - Filtering and Sorting
    
    func setPositionFilter(_ position: PlayerPosition) {
        selectedPosition = position
        // 🔥 FIXED: Clear animations when filter changes
        triggerAnimationReset()
        applyPositionFilter()
    }
    
    func setSortDirection(highToLow: Bool) {
        sortHighToLow = highToLow
        // 🔥 FIXED: Clear animations when sort direction changes
        triggerAnimationReset()
        applyPositionFilter() // Re-apply filter with new sort direction
    }
    
    func setSortingMethod(_ method: SortingMethod) {
        sortingMethod = method
        // 🔥 FIXED: Clear animations when sorting method changes
        triggerAnimationReset()
        applyPositionFilter() // Re-apply filter with new sorting method
    }
    
    func setShowActiveOnly(_ showActive: Bool) {
        showActiveOnly = showActive
        // 🔥 FIXED: Clear animations when active filter changes
        triggerAnimationReset()
        applyPositionFilter() // Re-apply filter with new active-only setting
    }

    /// Check if a player is currently in a LIVE game (not completed, not scheduled - LIVE only)
    private func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        guard let team = player.team else { 
//            // print("🔍 LIVE FILTER DEBUG: Player \(player.fullName) has no team - NOT LIVE")
            return false 
        }
        
        // 🔥 FIX: Check if game is actually LIVE right now
        var isLive = false
        var detectionMethod = "none"
        
        // Primary source: NFLGameDataService
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
            // Only consider live if status is "in" AND it's marked as live
            isLive = gameInfo.gameStatus.lowercased() == "in" && gameInfo.isLive
            detectionMethod = "NFLGameDataService(\(gameInfo.gameStatus), isLive: \(gameInfo.isLive))"
            
            // 🔥 ADDITIONAL SAFETY: Ensure scores are actually updating (not stuck at 0-0)
            if isLive && gameInfo.homeScore == 0 && gameInfo.awayScore == 0 {
                // Still allow it - game could be 0-0 but actively playing
//                // print("🔍 LIVE FILTER DEBUG: Game is LIVE but scores are 0-0 - allowing it")
            }
        } else {
            // Fallback: Player's game status
            if let playerGameStatus = player.gameStatus?.status {
                isLive = playerGameStatus.lowercased() == "in"
                detectionMethod = "PlayerGameStatus(\(playerGameStatus))"
            }
        }
        
//        // print("🔍 LIVE FILTER DEBUG: \(player.fullName) (\(team)) - \(isLive ? "LIVE NOW" : "NOT LIVE") via \(detectionMethod)")
        return isLive
    }
    
    // 🔥 IMPROVED: Enhanced filtering with true live-only logic
    private func applyPositionFilter() {
        print("🔍 FILTER DEBUG: Starting filter - Position: \(selectedPosition.rawValue), Show Active Only: \(showActiveOnly)")
        print("🔍 FILTER DEBUG: All players count: \(allPlayers.count)")
        
        // Early return if no players
        guard !allPlayers.isEmpty else { 
            print("🔍 FILTER DEBUG: No players to filter")
            filteredPlayers = []
            return 
        }
        
        // Apply position filter
        let positionFiltered = selectedPosition == .all ? 
            allPlayers : 
            allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }
        
        print("🔍 FILTER DEBUG: After position filter: \(positionFiltered.count) players")
        
        // Apply active-only filter with LIVE-ONLY logic
        var players = positionFiltered
        if showActiveOnly {
            let livePlayers = positionFiltered.filter { isPlayerInLiveGame($0.player) }
            print("🔍 FILTER DEBUG: After LIVE-ONLY filter: \(livePlayers.count) live players out of \(positionFiltered.count)")
            
            players = livePlayers
            
            // If no live players, that's legitimate - games may not be in progress
            if livePlayers.isEmpty {
                print("ℹ️ FILTER INFO: No players in LIVE games right now - this is expected when no games are actively being played")
            }
        }
        
        // Early return if no players after filtering
        guard !players.isEmpty else {
            print("🔍 FILTER DEBUG: No players after filtering - setting empty array")
            filteredPlayers = []
            positionTopScore = 0.0
            return
        }
        
        let positionScores = players.map { $0.currentScore }.sorted(by: >)
        positionTopScore = positionScores.first ?? 1.0
        
        // Calculate position-specific quartiles for tier determination
        let positionQuartiles = calculateQuartiles(from: positionScores)
        
        // Update players with position-relative percentages and tiers
        let updatedPlayers = players.map { entry in
            let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: positionTopScore)
            let tier = determinePerformanceTier(score: entry.currentScore, quartiles: positionQuartiles)
            
            // 🔥 REMOVED PROBLEMATIC STABLE ID: Back to original IDs
            return LivePlayerEntry(
                id: entry.id,
                player: entry.player,
                leagueName: entry.leagueName,
                leagueSource: entry.leagueSource,
                currentScore: entry.currentScore,
                projectedScore: entry.projectedScore,
                isStarter: entry.isStarter,
                percentageOfTop: percentage,
                matchup: entry.matchup,
                performanceTier: tier
            )
        }
        
        print("🔍 FILTER DEBUG: Before sorting: \(updatedPlayers.count) players")
        
        // Apply sorting based on method and direction (optimized)
        filteredPlayers = sortPlayers(updatedPlayers)
        
        print("🔍 FILTER DEBUG: Final result: \(filteredPlayers.count) players displayed")
    }
    
    // 🔥 NEW: Separated sorting logic for better performance
    private func sortPlayers(_ players: [LivePlayerEntry]) -> [LivePlayerEntry] {
        print("🔍 SORT DEBUG: Sorting \(players.count) players by \(sortingMethod.rawValue), direction: \(sortHighToLow ? "high to low" : "low to high")")
        
        let sortedPlayers: [LivePlayerEntry]
        
        switch sortingMethod {
        case .score:
            sortedPlayers = sortHighToLow ? 
                players.sorted { $0.currentScore > $1.currentScore } :
                players.sorted { $0.currentScore < $1.currentScore }
            
        case .name:
            // 🔥 FIX: Sort by last name instead of full name
            sortedPlayers = sortHighToLow ? 
                players.sorted { extractLastName($0.playerName) < extractLastName($1.playerName) } :
                players.sorted { extractLastName($0.playerName) > extractLastName($1.playerName) }
            
        case .team:
            // 🔥 FIXED: Don't filter out players - handle empty team names in sorting instead
            sortedPlayers = sortHighToLow ? 
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()
                    
                    if team1 != team2 {
                        return team1 < team2
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                } :
                players.sorted { player1, player2 in
                    let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                    let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()
                    
                    if team1 != team2 {
                        return team1 > team2
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                }
        }
        
        print("🔍 SORT DEBUG: After sorting, returning \(sortedPlayers.count) players")
        
        // 🔥 DEBUG: Print first few players to see what we're returning
        for (index, player) in sortedPlayers.prefix(5).enumerated() {
            print("  \(index + 1). \(player.playerName) (\(player.teamName.isEmpty ? "NO TEAM" : player.teamName)) - \(player.currentScore) pts")
        }
        
        return sortedPlayers
    }
    
    /// Extract last name from full name for proper sorting
    private func extractLastName(_ fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }
    
    /// Returns priority order for positions: QB=1, RB=2, WR=3, TE=4, FLEX=5, DEF=6, K=7
    private func positionPriority(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "RB": return 2
        case "WR": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "DEF", "DST": return 6
        case "K": return 7
        default: return 8 // For any unknown positions
        }
    }

    // MARK: - Refresh
    
    // 🔥 IMPROVED: Enhanced refresh with task cancellation and batch updates
    func refresh() async {
//        // print("🔄 Refreshing all player data...")
        
        // Cancel any existing tasks
        debounceTask?.cancel()
        
        // Don't reset stats or loading state for background refresh
        // statsLoaded = false  // Keep this commented - we want surgical updates only
        
        // Refresh matchups data first
        await matchupsHubViewModel.loadAllMatchups()
        
        // Then update player data surgically
        await updatePlayerDataSurgically()
    }
    
    // 🔥 NEW: Surgical data update that doesn't trigger full UI refresh
    private func updatePlayerDataSurgically() async {
        var allPlayerEntries: [LivePlayerEntry] = []
        
        // Extract players from each matchup (with temporary values)
        for matchup in matchupsHubViewModel.myMatchups {
            let playersFromMatchup = extractPlayersFromMatchup(matchup)
            allPlayerEntries.append(contentsOf: playersFromMatchup)
        }
        
        // Only update if data actually changed
        guard !allPlayerEntries.isEmpty else { return }
        
        // Calculate overall statistics
        let scores = allPlayerEntries.map { $0.currentScore }.sorted(by: >)
        let newTopScore = scores.first ?? 1.0
        let bottomScore = scores.last ?? 0.0
        let newScoreRange = newTopScore - bottomScore
        
        // Calculate median
        var newMedianScore: Double = 0.0
        if !scores.isEmpty {
            let mid = scores.count / 2
            newMedianScore = scores.count % 2 == 0 ? 
                (scores[mid - 1] + scores[mid]) / 2 : 
                scores[mid]
        }
        
        // Use adaptive scaling if there's a huge gap (top score is 3x+ median)
        let newUseAdaptiveScaling = newTopScore > (newMedianScore * 3)
        
        // Calculate quartiles for tier determination
        let quartiles = calculateQuartiles(from: scores)
        
        // 🔥 PERFORMANCE: Only update if values actually changed
        await performBatchUpdate {
            topScore = newTopScore
            scoreRange = newScoreRange
            medianScore = newMedianScore
            useAdaptiveScaling = newUseAdaptiveScaling
            
            // Update all players with proper percentages and tiers
            allPlayers = allPlayerEntries.map { entry in
                let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: newTopScore)
                let tier = determinePerformanceTier(score: entry.currentScore, quartiles: quartiles)
                
                return LivePlayerEntry(
                    id: entry.id,
                    player: entry.player,
                    leagueName: entry.leagueName,
                    leagueSource: entry.leagueSource,  // 🔥 FIXED: Use actual leagueSource, not leagueName!
                    currentScore: entry.currentScore,
                    projectedScore: entry.projectedScore,
                    isStarter: entry.isStarter,
                    percentageOfTop: percentage,
                    matchup: entry.matchup,
                    performanceTier: tier
                )
            }
            
            // Re-apply current filter
            applyPositionFilter()
        }
    }
    
    // 🔥 NEW: Batch update mechanism to reduce UI churn
    private func performBatchUpdate(_ updates: () -> Void) async {
        guard !isBatchingUpdates else { return }
        
        isBatchingUpdates = true
        
        // Perform all updates in one batch
        updates()
        
        // Single UI update notification
        objectWillChange.send()
        
        isBatchingUpdates = false
    }

    private func calculateScaledPercentage(score: Double, topScore: Double) -> Double {
        guard topScore > 0 else { return 0.0 }
        
        if useAdaptiveScaling {
            // Logarithmic scaling for extreme distributions
            let logTop = log(max(topScore, 1.0))
            let logScore = log(max(score, 1.0))
            return logScore / logTop
        } else {
            // Standard linear scaling
            return score / topScore
        }
    }

    private func calculateQuartiles(from sortedScores: [Double]) -> (q1: Double, q2: Double, q3: Double) {
        guard !sortedScores.isEmpty else { return (0, 0, 0) }
        
        let count = sortedScores.count
        let q1Index = count / 4
        let q2Index = count / 2
        let q3Index = (3 * count) / 4
        
        let q1 = q1Index < count ? sortedScores[q1Index] : sortedScores.last!
        let q2 = q2Index < count ? sortedScores[q2Index] : sortedScores.last!
        let q3 = q3Index < count ? sortedScores[q3Index] : sortedScores.last!
        
        return (q1, q2, q3)
    }
    
    private func determinePerformanceTier(score: Double, quartiles: (q1: Double, q2: Double, q3: Double)) -> PerformanceTier {
        if score >= quartiles.q3 {
            return .elite
        } else if score >= quartiles.q2 {
            return .good
        } else if score >= quartiles.q1 {
            return .average
        } else {
            return .struggling
        }
    }
    
    // 🔥 NEW: Nuclear option - complete state reset to fix filtering bugs
    func hardResetFilteringState() async {
//        // // print("💥 NUCLEAR RESET: Completely resetting all filtering state...")
        
        // Step 1: Reset all filtering state to defaults
        showActiveOnly = false
        selectedPosition = .all
        sortHighToLow = true
        sortingMethod = .score
        
        // Step 2: Clear all player data
        allPlayers = []
        filteredPlayers = []
        
        // Step 3: Force reload from scratch
        await matchupsHubViewModel.loadAllMatchups()
        await loadAllPlayers()
        
        // print("💥 NUCLEAR RESET: Complete - \(filteredPlayers.count) players now visible")
    }
    
    // 🔥 NEW: Manual recovery method for stuck filter states
    func recoverFromStuckState() {
        // print("🔧 RECOVERY: Attempting to recover from stuck filter state...")
        
        // Reset all filters to safe defaults
        showActiveOnly = false
        selectedPosition = .all
        
        // Force re-apply filtering
        applyPositionFilter()
        
        // Trigger UI update
        objectWillChange.send()
        
        // print("🔧 RECOVERY: State reset complete - \(filteredPlayers.count) players now visible")
    }
    
    /// Enhanced computed property with recovery logic
    var hasNoPlayersWithRecovery: Bool {
        let hasNoPlayers = filteredPlayers.isEmpty && !allPlayers.isEmpty && !isLoading
        
        if hasNoPlayers {
            // print("⚠️ WARNING: No filtered players detected - this might be a stuck state")
        }
        
        return hasNoPlayers
    }
    
    // 🔥 REMOVED: Separate scoring settings initialization since we now piggyback on existing API calls
    // Scoring settings are automatically extracted when leagues are fetched via registerESPNScoringSettings()
    
    // 🔥 NEW: Validate player points against calculated points using unified manager
    func validatePlayerPoints(player: FantasyPlayer, leagueID: String, source: LeagueSource) -> PointsValidationResult? {
        guard let playerStats = playerStats[player.id] else { return nil }
        
        return ScoringSettingsManager.shared.validatePlayerPoints(
            player: player,
            stats: playerStats,
            leagueID: leagueID,
            source: source
        )
    }
    
    /// Get validation results for all players with scoring discrepancies
    func getAllValidationResults() -> [PointsValidationResult] {
        var results: [PointsValidationResult] = []
        
        for entry in allPlayers {
            let leagueID = String(entry.matchup.league.league.id)
            let source: LeagueSource = entry.leagueSource == "ESPN" ? .espn : .sleeper
            
            if let validation = validatePlayerPoints(player: entry.player, leagueID: leagueID, source: source) {
                results.append(validation)
            }
        }
        
        return results.filter { $0.hasDiscrepancy }
    }
    
    /// 🔥 NEW: Debug method to print all scoring bases
    func debugPrintScoringBases() {
        ScoringSettingsManager.shared.printAllScoringBases()
    }
    
    /// 🔥 NEW: Call this after loading matchups to see scoring basis for each league
    func debugScoringAfterLoad() async {
        // Load all matchups first (this will register scoring settings automatically)
        await matchupsHubViewModel.loadAllMatchups()
        
        // Then print the scoring bases to see what we got
        print("🎯 SCORING DEBUG: After loading matchups, here are the scoring bases:")
        debugPrintScoringBases()
    }

    /// 🔥 NEW: Debug method to analyze Josh Allen score differences
    func debugJoshAllenScoreDifferences() {
        print("🎯 JOSH ALLEN SCORE ANALYSIS:")
        print("===============================")
        
        let joshAllenEntries = allPlayers.filter { $0.player.fullName.contains("Josh Allen") }
        
        if joshAllenEntries.isEmpty {
            print("❌ No Josh Allen entries found")
            return
        }
        
        print("Found \(joshAllenEntries.count) Josh Allen entries:")
        
        for (index, entry) in joshAllenEntries.enumerated() {
            print("\n\(index + 1). League: \(entry.leagueName)")
            print("   Source: \(entry.leagueSource)")
            print("   Score: \(entry.currentScore)")
            print("   Player ID: \(entry.player.id)")
            print("   ESPN ID: \(entry.player.espnID ?? "none")")
            print("   Sleeper ID: \(entry.player.sleeperID ?? "none")")
            
            // Try to get Sleeper stats
            if let sleeperPlayer = PlayerMatchService.shared.matchPlayer(
                fullName: entry.player.fullName,
                shortName: entry.player.shortName,
                team: entry.player.team,
                position: entry.player.position
            ) {
                print("   Matched Sleeper ID: \(sleeperPlayer.playerID)")
                
                if let stats = playerStats[sleeperPlayer.playerID] {
                    print("   Stats available: YES (\(stats.count) categories)")
                    
                    // Show key stats
                    let keyStats = ["pass_yd", "pass_td", "pass_int", "rush_yd", "rush_td", "pts_ppr", "pts_std", "pts_half_ppr"]
                    for statKey in keyStats {
                        if let value = stats[statKey], value > 0 {
                            print("     \(statKey): \(value)")
                        }
                    }
                } else {
                    print("   Stats available: NO")
                }
            } else {
                print("   Sleeper matching: FAILED")
            }
        }
        
        // Analyze score differences
        let uniqueScores = Set(joshAllenEntries.map { $0.currentScore })
        print("\n🔍 SCORE ANALYSIS:")
        print("Unique scores: \(uniqueScores.sorted(by: >))")
        
        if uniqueScores.count > 1 {
            print("⚠️ INCONSISTENT SCORES DETECTED!")
            
            // Group by score
            let scoreGroups = Dictionary(grouping: joshAllenEntries) { $0.currentScore }
            
            for (score, entries) in scoreGroups.sorted(by: { $0.key > $1.key }) {
                print("\nScore \(score):")
                for entry in entries {
                    print("  - \(entry.leagueName) (\(entry.leagueSource))")
                }
            }
        } else {
            print("✅ All Josh Allen scores are consistent")
        }
    }

    // 🔥 NEW: Method to trigger animation reset
    private func triggerAnimationReset() {
        shouldResetAnimations = true
        sortChangeID = UUID()
        
        // Reset the flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldResetAnimations = false
        }
    }
}