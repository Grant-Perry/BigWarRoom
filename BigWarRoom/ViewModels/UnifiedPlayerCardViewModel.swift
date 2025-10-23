//
//  UnifiedPlayerCardViewModel.swift
//  BigWarRoom
//
//  🔥 PHASE 2 CONSOLIDATION: Unified Player Card Business Logic
//  Centralizes all player card business logic that was duplicated across
//  FantasyPlayerViewModel, ChoppedPlayerCardViewModel, and 10+ others
//

import SwiftUI
import Foundation

/// **Unified Player Card View Model**
/// 
/// **Centralizes all player card business logic:**
/// - Player data resolution and formatting
/// - Score calculation and display logic
/// - Team color and styling logic
/// - Watch service integration
/// - Live status detection
/// - Score breakdown creation
///
/// **Replaces:** FantasyPlayerViewModel, ChoppedPlayerCardViewModel, 
/// and business logic scattered across 15+ card components
@MainActor
final class UnifiedPlayerCardViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    private let watchService = PlayerWatchService.shared
    private let allLivePlayersViewModel = AllLivePlayersViewModel.shared
    
    // MARK: - Player Configuration
    
    /// Configure the view model for a specific player
    func configurePlayer(_ player: FantasyPlayer) {
        // Any setup logic needed for the player
        // This is where we could cache expensive lookups
    }
    
    // MARK: - Player Data Resolution
    
    /// Get SleeperPlayer data for enhanced information
    func getSleeperPlayerData(for player: FantasyPlayer) -> SleeperPlayer? {
        return playerDirectoryStore.player(for: player.id)
    }
    
    /// Get enhanced team information
    func getTeamInfo(for player: FantasyPlayer) -> NFLTeam? {
        return NFLTeam.team(for: player.team ?? "")
    }
    
    // MARK: - Display Logic
    
    /// Get position-based color for badges and accents
    func positionColor(for position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
    
    /// Get score-based color for point displays
    func scoreColor(for points: Double) -> Color {
        if points >= 20 { return .gpGreen }
        else if points >= 12 { return .blue }
        else if points >= 8 { return .orange }
        else if points > 0 { return .gpRedPink }
        else { return .gray }
    }
    
    /// Get team color with fallbacks
    func teamColor(for player: FantasyPlayer) -> Color {
        if let team = player.team {
            return NFLTeamColors.color(for: team)
        }
        return NFLTeamColors.fallbackColor(for: player.position)
    }
    
    /// Get border color based on player status and style
    func borderColor(for player: FantasyPlayer, style: UnifiedPlayerCardBuilder.CardStyle) -> Color {
        switch style {
        case .fantasy, .enhanced:
            if player.isLive {
                return .blue
            } else {
                return teamColor(for: player)
            }
            
        case .chopped:
            if player.isLive {
                return .gpGreen
            } else {
                return .gpYellow
            }
            
        case .opponent:
            if isWatching(player.id) {
                return .gpOrange
            } else {
                return .gray
            }
            
        case .scoreBar, .teamRoster:
            return teamColor(for: player)
        }
    }
    
    /// Get border width based on player status and style
    func borderWidth(for player: FantasyPlayer, style: UnifiedPlayerCardBuilder.CardStyle) -> CGFloat {
        switch style {
        case .fantasy, .enhanced:
            return player.isLive ? 2.0 : 1.5
            
        case .chopped:
            return player.isLive ? 3.0 : 2.0
            
        case .opponent:
            return isWatching(player.id) ? 2.0 : 1.0
            
        case .scoreBar, .teamRoster:
            return 1.0
        }
    }
    
    // MARK: - Watch Service Integration
    
    /// Check if player is being watched
    func isWatching(_ playerID: String) -> Bool {
        return watchService.isWatching(playerID)
    }
    
    /// Toggle watch status for player
    func toggleWatch(for player: FantasyPlayer) {
        if isWatching(player.id) {
            watchService.unwatchPlayer(player.id)
        } else {
            // Create OpponentPlayer for watch service
            if let opponentPlayer = createOpponentPlayer(from: player) {
                let opponentRefs = [OpponentReference(
                    id: "temp_opponent",
                    opponentName: "Opponent",
                    leagueName: "League",
                    leagueSource: "sleeper"
                )]
                
                let _ = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentRefs)
            }
        }
    }
    
    /// Convert FantasyPlayer to OpponentPlayer for watch service
    private func createOpponentPlayer(from player: FantasyPlayer) -> OpponentPlayer? {
        return OpponentPlayer(
            id: UUID().uuidString,
            player: player,
            isStarter: player.isStarter,
            currentScore: player.currentPoints ?? 0.0,
            projectedScore: player.projectedPoints ?? 0.0,
            threatLevel: .moderate,
            matchupAdvantage: .neutral,
            percentageOfOpponentTotal: 0.0
        )
    }
    
    // MARK: - Score Breakdown Creation
    
    /// Create score breakdown for player
    func createScoreBreakdown(for player: FantasyPlayer) -> PlayerScoreBreakdown? {
        guard let sleeperPlayer = getSleeperPlayerData(for: player) else {
            return nil
        }
        
        // Get stats from AllLivePlayersViewModel
        guard let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID],
              !stats.isEmpty else {
            return nil
        }
        
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        // Create basic league context (can be enhanced with actual league data)
        let leagueContext = LeagueContext(leagueID: "unified", source: .sleeper)
        
        // Use ScoreBreakdownFactory
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: player,
            week: selectedWeek,
            localStatsProvider: nil,
            leagueContext: leagueContext
        )
        
        return breakdown
    }
    
    /// Create empty breakdown for players with no stats
    func createEmptyBreakdown(for player: FantasyPlayer) -> PlayerScoreBreakdown {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        return PlayerScoreBreakdown(
            player: player,
            week: selectedWeek,
            items: [],
            totalScore: player.currentPoints ?? 0.0,
            isChoppedLeague: false
        )
    }
    
    // MARK: - Utility Methods
    
    /// Format player stat breakdown for display
    func formatPlayerStatBreakdown(for player: FantasyPlayer) -> String? {
        guard let points = player.currentPoints, points > 0 else {
            return nil
        }
        
        // Get basic stats from the player's position
        switch player.position.uppercased() {
        case "QB":
            return formatQuarterbackStats(for: player)
        case "RB":
            return formatRunningBackStats(for: player)
        case "WR", "TE":
            return formatReceiverStats(for: player)
        case "K":
            return formatKickerStats(for: player)
        case "DEF", "DST":
            return formatDefenseStats(for: player)
        default:
            return "\(String(format: "%.1f", points)) pts"
        }
    }
    
    // MARK: - Position-Specific Stat Formatting
    
    private func formatQuarterbackStats(for player: FantasyPlayer) -> String? {
        // Try to get detailed stats from AllLivePlayersViewModel
        if let sleeperPlayer = getSleeperPlayerData(for: player),
           let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID] {
            
            let passYds = Int(stats["pass_yd"] ?? 0)
            let passTds = Int(stats["pass_td"] ?? 0)
            let ints = Int(stats["pass_int"] ?? 0)
            
            if passYds > 0 || passTds > 0 {
                return "\(passYds) YDS, \(passTds) TD, \(ints) INT"
            }
        }
        
        return nil
    }
    
    private func formatRunningBackStats(for player: FantasyPlayer) -> String? {
        if let sleeperPlayer = getSleeperPlayerData(for: player),
           let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID] {
            
            let rushYds = Int(stats["rush_yd"] ?? 0)
            let rushTds = Int(stats["rush_td"] ?? 0)
            let rec = Int(stats["rec"] ?? 0)
            
            if rushYds > 0 || rushTds > 0 || rec > 0 {
                return "\(rushYds) RUSH, \(rec) REC, \(rushTds) TD"
            }
        }
        
        return nil
    }
    
    private func formatReceiverStats(for player: FantasyPlayer) -> String? {
        if let sleeperPlayer = getSleeperPlayerData(for: player),
           let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID] {
            
            let rec = Int(stats["rec"] ?? 0)
            let recYds = Int(stats["rec_yd"] ?? 0)
            let recTds = Int(stats["rec_td"] ?? 0)
            
            if rec > 0 || recYds > 0 || recTds > 0 {
                return "\(rec) REC, \(recYds) YDS, \(recTds) TD"
            }
        }
        
        return nil
    }
    
    private func formatKickerStats(for player: FantasyPlayer) -> String? {
        if let sleeperPlayer = getSleeperPlayerData(for: player),
           let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID] {
            
            let fgm = Int(stats["fgm"] ?? 0)
            let xpm = Int(stats["xpm"] ?? 0)
            
            if fgm > 0 || xpm > 0 {
                return "\(fgm) FG, \(xpm) XP"
            }
        }
        
        return nil
    }
    
    private func formatDefenseStats(for player: FantasyPlayer) -> String? {
        if let sleeperPlayer = getSleeperPlayerData(for: player),
           let stats = allLivePlayersViewModel.playerStats[sleeperPlayer.playerID] {
            
            let sacks = Int(stats["def_sack"] ?? 0)
            let ints = Int(stats["def_int"] ?? 0)
            let fumbRec = Int(stats["def_fum_rec"] ?? 0)
            
            if sacks > 0 || ints > 0 || fumbRec > 0 {
                return "\(sacks) SACKS, \(ints) INT, \(fumbRec) FR"
            }
        }
        
        return nil
    }
}