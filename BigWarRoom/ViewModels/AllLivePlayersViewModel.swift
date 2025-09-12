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
    
    // 🔥 NEW: Private init for singleton
    private init() {
        // Subscribe to week changes to invalidate stats with debouncing
        subscribeToWeekChanges()
    }
    
    // 🔥 IMPROVED: Debounced week change subscription
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
            
            // Update all players with proper percentages and tiers
            allPlayers = allPlayerEntries.map { entry in
                let percentage = calculateScaledPercentage(score: entry.currentScore, topScore: topScore)
                let tier = determinePerformanceTier(score: entry.currentScore, quartiles: quartiles)
                
                return LivePlayerEntry(
                    id: entry.id,
                    player: entry.player,
                    leagueName: entry.leagueName,
                    leagueSource: entry.leagueName,
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

    private func extractPlayersFromMatchup(_ matchup: UnifiedMatchup) -> [LivePlayerEntry] {
        var players: [LivePlayerEntry] = []
        
        // For regular matchups, extract from both teams
        if let fantasyMatchup = matchup.fantasyMatchup {
            // Extract starters from home team
            let homeStarters = fantasyMatchup.homeTeam.roster.filter { $0.isStarter }
            for player in homeStarters {
                players.append(LivePlayerEntry(
                    id: "\(matchup.id)_home_\(player.id)",
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
            
            // Extract starters from away team
            let awayStarters = fantasyMatchup.awayTeam.roster.filter { $0.isStarter }
            for player in awayStarters {
                players.append(LivePlayerEntry(
                    id: "\(matchup.id)_away_\(player.id)",
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
        
        // For Chopped leagues, extract from my team ranking
        if let myTeamRanking = matchup.myTeamRanking {
            let myTeamStarters = myTeamRanking.team.roster.filter { $0.isStarter }
            for player in myTeamStarters {
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
    
    // 🔥 IMPROVED: Optimized filtering with early returns
    private func applyPositionFilter() {
        // Early return if no players
        guard !allPlayers.isEmpty else { 
            filteredPlayers = []
            return 
        }
        
        let players = selectedPosition == .all ? 
            allPlayers : 
            allPlayers.filter { $0.position.uppercased() == selectedPosition.rawValue }
        
        // Early return if no players after filtering
        guard !players.isEmpty else {
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
    }
    
    // 🔥 NEW: Separated sorting logic for better performance
    private func sortPlayers(_ players: [LivePlayerEntry]) -> [LivePlayerEntry] {
        switch sortingMethod {
        case .score:
            return sortHighToLow ? 
                players.sorted { $0.currentScore > $1.currentScore } :
                players.sorted { $0.currentScore < $1.currentScore }
            
        case .name:
            return sortHighToLow ? 
                players.sorted { $0.playerName < $1.playerName } :
                players.sorted { $0.playerName > $1.playerName }
            
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
    
    // 🔥 IMPROVED: Enhanced refresh with task cancellation
    func refresh() async {
        print("🔄 Refreshing all player data...")
        
        // Cancel any existing tasks
        debounceTask?.cancel()
        
        statsLoaded = false  // Reset stats loaded state
        await loadAllPlayers()
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
}