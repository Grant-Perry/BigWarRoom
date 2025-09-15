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
        applyPositionFilter() // Re-apply filter with current sort settings
    }
    
    // 🔥 NEW: Debounced week change subscription
    private func subscribeToWeekChanges() {
        weekSubscription = WeekSelectionManager.shared.$selectedWeek
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // Add 500ms debounce
            .sink { [weak self] newWeek in
                print("📊 AllLivePlayersViewModel: Week changed to \(newWeek), invalidating stats (debounced)")
                
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
            print("📊 Stats already loaded, skipping...")
            return 
        }
        
        print("📊 Starting synchronous stats load...")
        
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
            }
            
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // 🔥 IMPROVED: Add method to force refresh stats
    func forceLoadStats() async {
        print("📊 Force loading stats...")
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
        
        print("📊 AllLivePlayersViewModel: Loading stats for Week \(selectedWeek) (async)")
        
        guard let url = URL(string: urlString) else { 
            print("❌ AllLivePlayersViewModel: Invalid URL: \(urlString)")
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
                print("✅ AllLivePlayersViewModel: Stats loaded for Week \(selectedWeek). Player count: \(statsData.keys.count)")
                
                // Only update UI if we're not cancelled
                self.objectWillChange.send()
            }
            
        } catch {
            print("❌ AllLivePlayersViewModel: Stats loading failed for Week \(selectedWeek): \(error)")
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
        
        print("🔍 EXTRACTING PLAYERS from matchup: \(matchup.league.league.name)")
        
        // For regular matchups, extract ONLY from MY team
        if let fantasyMatchup = matchup.fantasyMatchup {
            print("   - Regular matchup detected")
            print("   - Home team: \(fantasyMatchup.homeTeam.ownerName) (ID: \(fantasyMatchup.homeTeam.id))")
            print("   - Away team: \(fantasyMatchup.awayTeam.ownerName) (ID: \(fantasyMatchup.awayTeam.id))")
            
            // 🔥 CRITICAL FIX: Only extract from MY team, not both teams!
            if let myTeam = matchup.myTeam {
                print("   - My team identified: \(myTeam.ownerName) (ID: \(myTeam.id))")
                
                let myStarters = myTeam.roster.filter { $0.isStarter }
                print("   - My starters count: \(myStarters.count)")
                
                for player in myStarters {
                    print("     - Adding MY player: \(player.fullName) (\(player.currentPoints ?? 0.0) pts)")
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
                print("   ❌ ERROR: Could not identify my team in this matchup!")
            }
        }
        
        // For Chopped leagues, extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            print("   - Chopped league detected")
            print("   - My team: \(myTeamRanking.team.ownerName) (ID: \(myTeamRanking.team.id))")
            
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }
            print("   - My chopped starters count: \(myTeamStarters.count)")
            
            for player in myTeamStarters {
                print("     - Adding MY chopped player: \(player.fullName) (\(player.currentPoints ?? 0.0) pts)")
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
        
        print("   - Total players extracted: \(players.count)")
        return players
    }
    
    // MARK: - Filtering and Sorting
    
    func setPositionFilter(_ position: PlayerPosition) {
        selectedPosition = position
        applyPositionFilter()
    }
    
    func setSortDirection(highToLow: Bool) {
        sortHighToLow = highToLow
        applyPositionFilter() // Re-apply filter with new sort direction
    }
    
    func setSortingMethod(_ method: SortingMethod) {
        sortingMethod = method
        applyPositionFilter() // Re-apply filter with new sorting method
    }
    
    func setShowActiveOnly(_ showActive: Bool) {
        showActiveOnly = showActive
        applyPositionFilter() // Re-apply filter with new active-only setting
    }

    /// Check if a player is from a completed game (FINAL status)
    private func isPlayerFromCompletedGame(_ player: FantasyPlayer) -> Bool {
        guard let team = player.team else { 
            print("🔍 FILTER DEBUG: Player \(player.fullName) has no team - treating as ACTIVE")
            return false 
        }
        
        // 🔥 FIX: Try multiple sources with fallback logic and debug logging
        var isCompleted = false
        var detectionMethod = "none"
        
        // Primary source: NFLGameDataService
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
            let statusLower = gameInfo.gameStatus.lowercased()
            isCompleted = statusLower.contains("final") || statusLower.contains("post")
            detectionMethod = "NFLGameDataService(\(gameInfo.gameStatus))"
            
            // 🔥 SAFETY: Only consider truly final games with actual scores
            if isCompleted && gameInfo.homeScore == 0 && gameInfo.awayScore == 0 {
                print("🔍 FILTER DEBUG: Game marked as \(gameInfo.gameStatus) but no scores yet - treating as ACTIVE")
                isCompleted = false
                detectionMethod += "[no-scores-override]"
            }
        } else {
            // Fallback: Player's game status
            if let playerGameStatus = player.gameStatus?.status {
                let statusLower = playerGameStatus.lowercased()
                isCompleted = statusLower.contains("final") || statusLower.contains("post")
                detectionMethod = "PlayerGameStatus(\(playerGameStatus))"
            }
        }
        
        print("🔍 FILTER DEBUG: \(player.fullName) (\(team)) - \(isCompleted ? "COMPLETED" : "ACTIVE") via \(detectionMethod)")
        return isCompleted
    }
    
    // 🔥 IMPROVED: Enhanced filtering with safety checks and recovery
    private func applyPositionFilter() {
        print("🔍 FILTER DEBUG: Starting filter - Position: \(selectedPosition.rawValue), Show Active Only: \(showActiveOnly)")
        
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
        
        // Apply active-only filter with safety checks
        var players = positionFiltered
        if showActiveOnly {
            let activePlayers = positionFiltered.filter { !isPlayerFromCompletedGame($0.player) }
            print("🔍 FILTER DEBUG: After active-only filter: \(activePlayers.count) active players out of \(positionFiltered.count)")
            
            // 🔥 SAFETY CHECK: If filtering results in empty list, fall back to showing all
            if activePlayers.isEmpty && !positionFiltered.isEmpty {
                print("⚠️ FILTER SAFETY: All players filtered out! Falling back to showing all games to prevent empty state")
                players = positionFiltered
                
                // 🔥 RECOVERY: Reset the filter to prevent getting stuck
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.showActiveOnly = false
                    print("🔧 FILTER RECOVERY: Auto-disabled 'Active Only' to prevent empty state")
                }
            } else {
                players = activePlayers
            }
        }
        
        // Early return if no players after filtering
        guard !players.isEmpty else {
            print("🔍 FILTER DEBUG: No players after all filters - this should not happen due to safety checks")
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
        
        // Apply sorting based on method and direction (optimized)
        filteredPlayers = sortPlayers(updatedPlayers)
        
        print("🔍 FILTER DEBUG: Final result: \(filteredPlayers.count) players displayed")
    }
    
    // 🔥 NEW: Separated sorting logic for better performance
    private func sortPlayers(_ players: [LivePlayerEntry]) -> [LivePlayerEntry] {
        switch sortingMethod {
        case .score:
            return sortHighToLow ? 
                players.sorted { $0.currentScore > $1.currentScore } :
                players.sorted { $0.currentScore < $1.currentScore }
            
        case .name:
            // 🔥 FIX: Sort by last name instead of full name
            return sortHighToLow ? 
                players.sorted { extractLastName($0.playerName) < extractLastName($1.playerName) } :
                players.sorted { extractLastName($0.playerName) > extractLastName($1.playerName) }
            
        case .team:
            return sortHighToLow ? 
                players.sorted { player1, player2 in
                    if player1.teamName != player2.teamName {
                        return player1.teamName < player2.teamName
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                } :
                players.sorted { player1, player2 in
                    if player1.teamName != player2.teamName {
                        return player1.teamName > player2.teamName
                    }
                    return positionPriority(player1.position) < positionPriority(player2.position)
                }
        }
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
        print("🔄 Refreshing all player data...")
        
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
    
    // 🔥 NEW: Manual recovery method for stuck filter states
    func recoverFromStuckState() {
        print("🔧 RECOVERY: Attempting to recover from stuck filter state...")
        
        // Reset all filters to safe defaults
        showActiveOnly = false
        selectedPosition = .all
        
        // Force re-apply filtering
        applyPositionFilter()
        
        // Trigger UI update
        objectWillChange.send()
        
        print("🔧 RECOVERY: State reset complete - \(filteredPlayers.count) players now visible")
    }
    
    /// Enhanced computed property with recovery logic
    var hasNoPlayersWithRecovery: Bool {
        let hasNoPlayers = filteredPlayers.isEmpty && !allPlayers.isEmpty && !isLoading
        
        if hasNoPlayers {
            print("⚠️ WARNING: No filtered players detected - this might be a stuck state")
        }
        
        return hasNoPlayers
    }
}