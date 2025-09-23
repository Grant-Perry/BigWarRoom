//
//  NFLTeamRosterViewModel.swift
//  BigWarRoom
//
//  🏈 NFL TEAM ROSTER VIEW MODEL 🏈
//  Handles all business logic for NFL team roster display with smart filtering
//

import Foundation
import SwiftUI
import Combine

/// **NFLTeamRosterViewModel**
/// 
/// MVVM ViewModel for NFL team roster display with intelligent player filtering:
/// - Loads full NFL team rosters using NFLTeamRosterService
/// - SMART FILTERING: Hides 0.0 point players in completed games
/// - Position sorting: QB, RB, WR, TE, K, DST
/// - Reuses existing stats and game status infrastructure
@MainActor
class NFLTeamRosterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var teamInfo: NFLTeamInfo?
    @Published var filteredPlayers: [SleeperPlayer] = []
    
    // MARK: - Private Properties
    private let teamCode: String
    private let nflRosterService = NFLTeamRosterService.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    private let livePlayersViewModel = AllLivePlayersViewModel.shared
    private let gameStatusService = GameStatusService.shared
    
    // MARK: - Initialization
    init(teamCode: String) {
        self.teamCode = teamCode
        self.teamInfo = NFLTeamInfo(
            teamCode: teamCode,
            teamName: getTeamName(for: teamCode),
            primaryColor: getTeamColor(for: teamCode)
        )
    }
    
    // MARK: - Public Interface
    
    /// Load the NFL team roster with smart filtering
    func loadTeamRoster() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Ensure player directory is loaded
            if nflRosterService.needsRefresh {
                await nflRosterService.refreshPlayerDirectory()
            }
            
            // Load live player stats if needed
            if !livePlayersViewModel.statsLoaded {
                await livePlayersViewModel.loadAllPlayers()
            }
            
            // Get the NFL team roster
            let nflRoster = nflRosterService.getTeamRoster(for: teamCode)
            
            // Apply smart filtering and sorting
            let smartFilteredPlayers = applySmartFiltering(nflRoster.allPlayers)
            
            self.filteredPlayers = smartFilteredPlayers
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to load \(teamCode) roster: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    /// Get actual player points for current week
    func getPlayerPoints(for player: SleeperPlayer) -> Double? {
        if let stats = livePlayersViewModel.playerStats[player.playerID] {
            return stats["pts_ppr"] ?? stats["pts_half_ppr"] ?? stats["pts_std"]
        }
        return nil
    }
    
    /// Format player stat breakdown based on position
    func formatPlayerStatBreakdown(_ player: SleeperPlayer) -> String? {
        guard let stats = livePlayersViewModel.playerStats[player.playerID] else { return nil }
        return formatStatsForPosition(stats: stats, position: player.position ?? "")
    }
    
    // MARK: - Smart Filtering Logic
    
    /// Apply intelligent filtering: hide 0.0 point players in completed games
    private func applySmartFiltering(_ players: [SleeperPlayer]) -> [SleeperPlayer] {
        return players.filter { player in
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
    }
    
    /// Determine if a player should be shown in the roster
    /// 🔥 SMART FILTERING: Filters out 0.0 point players in completed games
    private func shouldShowPlayer(_ player: SleeperPlayer) -> Bool {
        let points = getPlayerPoints(for: player) ?? 0.0
        
        // Always show players with points > 0
        if points > 0.0 {
            return true
        }
        
        // For 0.0 point players, check if their game is completed
        guard let gameStatus = gameStatusService.getGameStatus(for: player.team) else {
            // If we can't determine game status, show the player (safer default)
            return true
        }
        
        let status = gameStatus.status.lowercased()
        let isGameCompleted = status.contains("final") || status.contains("post")
        
        // Hide 0.0 point players if their game is completed (they didn't contribute)
        // Show 0.0 point players if their game is still in progress or hasn't started
        let shouldShow = !isGameCompleted
        
        if !shouldShow {
            print("🚫 FILTERED OUT: \(player.firstName ?? "") \(player.lastName ?? "") (\(player.position ?? "")) - 0.0 pts in completed game (\(status))")
        }
        
        return shouldShow
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