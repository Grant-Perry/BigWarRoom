//
//  NFLTeamRosterViewModel.swift
//  BigWarRoom
//
//  🏈 NFL TEAM ROSTER VIEW MODEL 🏈
//  Handles all business logic for NFL team roster display with smart filtering
//  🔥 PHASE 3 DI: Converted to use dependency injection
//

import Foundation
import SwiftUI
import Observation

/// **NFLTeamRosterViewModel**
/// 
/// MVVM ViewModel for NFL team roster display with intelligent player filtering:
/// - Uses TeamRosterCoordinator to eliminate race conditions
/// - SMART FILTERING: Hides 0.0 point players in completed games ONLY
/// - Position sorting: QB, RB, WR, TE, K, DST
/// - Reuses existing stats and game status infrastructure
@Observable
@MainActor
final class NFLTeamRosterViewModel {
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var isLoading = true
    var errorMessage: String?
    var teamInfo: NFLTeamInfo?
    var filteredPlayers: [SleeperPlayer] = []
    var loadingState: String = "Initializing..."
    
    // MARK: - Private Properties
    private let teamCode: String
    private let coordinator: TeamRosterCoordinator // 🔥 PHASE 3: Now injected
    private let nflGameService: NFLGameDataService
    
    // 🔥 PHASE 3 DI: Dependency injection initializer
    init(teamCode: String, coordinator: TeamRosterCoordinator, nflGameService: NFLGameDataService) {
        self.teamCode = teamCode
        self.coordinator = coordinator
        self.nflGameService = nflGameService
        self.teamInfo = NFLTeamInfo(
            teamCode: teamCode,
            teamName: getTeamName(for: teamCode),
            primaryColor: getTeamColor(for: teamCode)
        )
    }
    
    // MARK: - Public Interface
    
    /// Load the NFL team roster using the coordinator for race condition prevention
    func loadTeamRoster() async {
        
        isLoading = true
        errorMessage = nil
        loadingState = "Preparing data..."
        
        do {
            // Use coordinator to handle all data dependencies
            loadingState = "Loading player stats and directory..."
            let nflRoster = try await coordinator.loadTeamRoster(for: teamCode)
            
            
            // 🔥 NEW: Debug the actual players being loaded
            if nflRoster.allPlayers.isEmpty {
                
                // Try loading with different team code variations
                let aliases = TeamCodeNormalizer.aliases(for: teamCode)
                for alias in aliases where alias != teamCode {
                    do {
                        let alternativeRoster = try await coordinator.loadTeamRoster(for: alias)
                        if !alternativeRoster.allPlayers.isEmpty {
                            let smartFilteredPlayers = applySmartFiltering(alternativeRoster.allPlayers)
                            await MainActor.run {
                                self.filteredPlayers = smartFilteredPlayers
                                self.isLoading = false
                                self.loadingState = "Complete"
                            }
                            return
                        }
                    } catch {
                    }
                }
            } else {
                // Log sample of players loaded
                let samplePlayers = nflRoster.allPlayers.prefix(5)
                for player in samplePlayers {
                }
            }
            
            // Apply smart filtering and sorting
            loadingState = "Filtering and sorting players..."
            let smartFilteredPlayers = applySmartFiltering(nflRoster.allPlayers)
            
            // Update UI
            await MainActor.run {
                self.filteredPlayers = smartFilteredPlayers
                self.isLoading = false
                self.loadingState = "Complete"
            }
            
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load \(teamCode) roster: \(error.localizedDescription)"
                self.isLoading = false
                self.loadingState = "Error"
            }
        }
    }
    
    /// Get actual player points for current week from AllLivePlayersViewModel
    func getPlayerPoints(for player: SleeperPlayer) -> Double? {
        // 🔥 PHASE 3: Access through coordinator's injected dependency
        if let stats = coordinator.livePlayersViewModel.playerStats[player.playerID] {
            return stats["pts_ppr"] ?? stats["pts_half_ppr"] ?? stats["pts_std"]
        }
        return nil
    }
    
    /// Format player stat breakdown based on position
    func formatPlayerStatBreakdown(_ player: SleeperPlayer) -> String? {
        guard let stats = coordinator.livePlayersViewModel.playerStats[player.playerID] else { return nil }
        return formatStatsForPosition(stats: stats, position: player.position ?? "")
    }
    
    /// Check if coordinator is ready for loading
    var coordinatorReady: Bool {
        return coordinator.isReadyForRosterLoading
    }
    
    /// Get detailed loading state for debugging
    var detailedLoadingState: String {
        if isLoading {
            return "\(loadingState) | Coordinator: \(coordinator.loadingStateDescription)"
        } else {
            return "Ready"
        }
    }
    
    /// Force refresh all data
    func forceRefresh() async {
        await coordinator.forceRefresh()
        await loadTeamRoster()
    }
    
    // MARK: - Smart Filtering Logic
    
    /// Apply intelligent filtering: hide 0.0 point players in completed games, with fallback
    private func applySmartFiltering(_ players: [SleeperPlayer]) -> [SleeperPlayer] {
        
        // Debug first few players
        let sampleSize = min(5, players.count)
        for i in 0..<sampleSize {
            let player = players[i]
        }
        
        let filtered = players.filter { player in
            shouldShowPlayer(player)
        }.sorted { player1, player2 in
            // Sort by position priority first
            let priority1 = getPositionPriority(player1.position ?? "")
            let priority2 = getPositionPriority(player2.position ?? "")
            
            if priority1 != priority2 {
                return priority1 < priority2
            }
            
            // Within same position, sort by points (highest first)
            let points1 = getPlayerPoints(for: player1) ?? 0.0
            let points2 = getPlayerPoints(for: player2) ?? 0.0
            return points1 > points2
        }
        
        // 🔥 ENHANCED FALLBACK: If filtering resulted in zero players, check if we might have a live game
        let finalResult: [SleeperPlayer]
        if filtered.isEmpty && !players.isEmpty {
            
            // Check if this team might have a live game
            let hasLiveGame = checkForPossibleLiveGame()
            
            if hasLiveGame {
                // Show ALL players if we suspect a live game
                finalResult = players.sorted { player1, player2 in
                    let priority1 = getPositionPriority(player1.position ?? "")
                    let priority2 = getPositionPriority(player2.position ?? "")
                    
                    if priority1 != priority2 {
                        return priority1 < priority2
                    }
                    
                    return (player1.fullName ?? "") < (player2.fullName ?? "")
                }
            } else {
                // Original fallback logic
                finalResult = players.sorted { player1, player2 in
                    let priority1 = getPositionPriority(player1.position ?? "")
                    let priority2 = getPositionPriority(player2.position ?? "")
                    
                    if priority1 != priority2 {
                        return priority1 < priority2
                    }
                    
                    // Within same position, sort by points (highest first), then by name
                    let points1 = getPlayerPoints(for: player1) ?? 0.0
                    let points2 = getPlayerPoints(for: player2) ?? 0.0
                    if points1 != points2 {
                        return points1 > points2
                    }
                    return (player1.fullName ?? "") < (player2.fullName ?? "")
                }.prefix(15).map { $0 } // Show top 15 players
            }
        } else {
            finalResult = filtered
        }
        
        return finalResult
    }
    
    /// Determine if a player should be shown in the roster
    /// 🔥 ULTRA CONSERVATIVE: Only filter out 0.0 point players if we're 100% sure the game is completely final
    private func shouldShowPlayer(_ player: SleeperPlayer) -> Bool {
        let points = getPlayerPoints(for: player) ?? 0.0
        
        // Always show players with points > 0
        if points > 0.0 {
            return true
        }
        
        // 🔥 ULTRA CONSERVATIVE: For 0.0 point players, be extremely permissive
        // Only hide them if we're absolutely certain the game is completely over
        
        // 🔥 FIX: Use app's standard TeamCodeNormalizer for consistency
        let playerTeam = TeamCodeNormalizer.normalize(player.team) ?? TeamCodeNormalizer.normalize(teamCode) ?? teamCode
        let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
        
        // 🔥 CRITICAL: Try BOTH the canonical team code AND all possible aliases
        let teamAliases = TeamCodeNormalizer.aliases(for: normalizedTeamCode)
        var gameInfo: NFLGameInfo? = nil
        
        // Try all possible team code variations
        for alias in teamAliases {
            if let foundGameInfo = nflGameService.getGameInfo(for: alias) {
                gameInfo = foundGameInfo
                break
            }
        }
        
        // Also try the raw team code as a fallback
        if gameInfo == nil {
            gameInfo = nflGameService.getGameInfo(for: teamCode)
            if gameInfo != nil {
            }
        }
        
        guard let gameInfo = gameInfo else {
            // If we can't determine game status, ALWAYS show the player (safest default)
            return true
        }
        
        
        // 🔥 RULE 1: If game is explicitly marked as live, show ALL players
        if gameInfo.isLive {
            return true
        }
        
        // 🔥 RULE 2: If game has ANY scores, assume it could still be active
        let gameHasScores = gameInfo.homeScore > 0 || gameInfo.awayScore > 0
        if gameHasScores {
            return true
        }
        
        // 🔥 RULE 3: If game time contains any indicators of active play, show all players
        let gameTimeIndicators = gameInfo.gameTime.lowercased()
        let activeIndicators = ["quarter", "q1", "q2", "q3", "q4", "ot", "overtime", ":", "live", "1st", "2nd", "3rd", "4th"]
        let hasActiveTimeIndicator = activeIndicators.contains { gameTimeIndicators.contains($0) }
        
        if hasActiveTimeIndicator {
            return true
        }
        
        // 🔥 RULE 4: Only hide if game status is explicitly "final" or "post" AND marked as completed AND no scores
        let gameStatus = gameInfo.gameStatus.lowercased()
        let isExplicitlyFinal = gameStatus.contains("final") || gameStatus.contains("post")
        
        if isExplicitlyFinal && gameInfo.isCompleted && !gameHasScores {
            return false
        }
        
        // 🔥 DEFAULT: If we're not 100% sure the game is over, show the player
        return true
    }
    
    /// Get position priority for sorting: QB, RB, WR, TE, K, DST
    private func getPositionPriority(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 0
        case "RB": return 1
        case "WR": return 2
        case "TE": return 3
        case "K": return 4
        case "DST", "DEF", "D/ST": return 5
        default: return 6 // Unknown positions go last
        }
    }
    
    /// Check if this team might have a live game that we should show all players for
    private func checkForPossibleLiveGame() -> Bool {
        let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
        let teamAliases = TeamCodeNormalizer.aliases(for: normalizedTeamCode)
        
        // Try to find game info using any alias
        var gameInfo: NFLGameInfo? = nil
        for alias in teamAliases {
            if let foundGameInfo = nflGameService.getGameInfo(for: alias) {
                gameInfo = foundGameInfo
                break
            }
        }
        
        // Fallback to raw team code
        if gameInfo == nil {
            gameInfo = nflGameService.getGameInfo(for: teamCode)
        }
        
        guard let gameInfo = gameInfo else {
            // No game info = can't determine, assume live for safety
            return true
        }
        
        
        // If explicitly live, definitely show all
        if gameInfo.isLive {
            return true
        }
        
        // If game has scores, likely still active
        if gameInfo.homeScore > 0 || gameInfo.awayScore > 0 {
            return true
        }
        
        // If game time suggests active play
        let gameTimeIndicators = gameInfo.gameTime.lowercased()
        let activeIndicators = ["quarter", "q1", "q2", "q3", "q4", "ot", "overtime", ":", "live", "1st", "2nd", "3rd", "4th"]
        let hasActiveTimeIndicator = activeIndicators.contains { gameTimeIndicators.contains($0) }
        
        if hasActiveTimeIndicator {
            return true
        }
        
        // If not explicitly completed, assume it could be live
        if !gameInfo.isCompleted {
            return true
        }
        
        return false // Only return false if we're very sure it's not live
    }
    
    // MARK: - Stats Formatting
    
    /// Format stats breakdown for position
    private func formatStatsForPosition(stats: [String: Double], position: String) -> String {
        var breakdown: [String] = []
        
        switch position.uppercased() {
        case "QB":
            if let attempts = stats["pass_att"], attempts > 0 {
                let completions = stats["pass_cmp"] ?? 0
                let yards = stats["pass_yd"] ?? 0
                let tds = stats["pass_td"] ?? 0
                breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
            }
            if let rushYards = stats["rush_yd"], rushYards > 0 {
                let carries = stats["rush_att"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                breakdown.append("\(Int(rushYards)) RUSH YD")
            }
            
        case "RB":
            if let carries = stats["rush_att"], carries > 0 {
                let yards = stats["rush_yd"] ?? 0
                let tds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            }
            if let receptions = stats["rec"], receptions > 0 {
                breakdown.append("\(Int(receptions)) REC")
            }
            
        case "WR", "TE":
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            }
            
        case "K":
            if let fgMade = stats["fgm"], fgMade > 0 {
                let fgAtt = stats["fga"] ?? fgMade
                breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
            }
            if let xpMade = stats["xpm"], xpMade > 0 {
                breakdown.append("\(Int(xpMade)) XP")
            }
            
        case "DST", "DEF":
            if let sacks = stats["def_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            if let ints = stats["def_int"], ints > 0 {
                breakdown.append("\(Int(ints)) INT")
            }
            
        default:
            break
        }
        
        return breakdown.isEmpty ? "" : breakdown.joined(separator: ", ")
    }
    
    // MARK: - Helper Functions
    
    /// Get team name for display
    private func getTeamName(for teamCode: String) -> String {
        return NFLTeam.team(for: teamCode)?.fullName ?? teamCode
    }
    
    /// Get team color for display
    private func getTeamColor(for teamCode: String) -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
}

/// **NFLTeamInfo**
/// 
/// Basic team information for display
struct NFLTeamInfo {
    let teamCode: String
    let teamName: String
    let primaryColor: Color
}