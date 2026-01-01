//
//  GameStatusService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized game status checking logic
//  Eliminates 60+ duplicate status checks across the codebase
//
//  Service for providing real NFL game status data and centralized status checks

import Foundation
import SwiftUI
import Observation

/// Centralized service for all game status checking logic
/// 
/// **Consolidates:**
/// - `isLive` checks scattered across 20+ files
/// - `isComplete` checks duplicated everywhere
/// - Game status string comparisons ("in", "post", "pre")
/// - Player "yet to play" logic
/// - Matchup status determination
@Observable
@MainActor
final class GameStatusService {
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: GameStatusService?
    
    static var shared: GameStatusService {
        if let existing = _shared {
            return existing
        }
        fatalError("GameStatusService.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: GameStatusService) {
        _shared = instance
    }
    
    // Dependencies - inject instead of using singletons
    private let nflGameDataService: NFLGameDataService
    
    init(nflGameDataService: NFLGameDataService) {
        self.nflGameDataService = nflGameDataService
    }
    
    // MARK: - Legacy Methods (Keep for backward compatibility)
    
    /// Get real game status for a player based on their NFL team
    /// This replaces all the createMockGameStatus() bullshit with actual data
    func getGameStatus(for playerTeam: String?) -> GameStatus? {
        guard let team = playerTeam, !team.isEmpty else {
            return nil
        }
        
        // Use NFLGameDataService to get real game info
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return nil
        }
        
        // Convert NFLGameInfo to GameStatus
        let gameStatus = GameStatus(from: gameInfo)
        return gameStatus
    }
    
    /// Get game status with fallback for cases where team is unknown
    /// This should RARELY be used - ideally we always have player teams
    func getGameStatusWithFallback(for playerTeam: String?) -> GameStatus {
        if let gameStatus = getGameStatus(for: playerTeam) {
            return gameStatus
        }
        
        // Fallback: Default to pregame status instead of random mock data
        return GameStatus(
            status: "pregame",
            startTime: nil,
            timeRemaining: nil,
            quarter: nil,
            homeScore: nil,
            awayScore: nil
        )
    }
    
    /// Determine if a player is "yet to play" based on real game status
    /// This is the authoritative method for "yet to play" calculation
    /// 🔥 FIXED: Now properly excludes BYE players
    func isPlayerYetToPlay(
        playerTeam: String?,
        currentPoints: Double?,
        gameDate: Date? = nil
    ) -> Bool {
        // 🔥 BYE CHECK: If player team has no game, they're NOT "yet to play"
        guard let team = playerTeam, !team.isEmpty else {
            return false
        }
        
        // Check if team is on BYE (no game data available)
        if nflGameDataService.getGameInfo(for: team) == nil {
            // No game = BYE week, not "yet to play"
            return false
        }
        
        // First check: If we have a game date and it's in the past, no one is "yet to play"
        if let gameDate = gameDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let gameDayStart = calendar.startOfDay(for: gameDate)
            
            // If game date is before today, all games are finished
            if gameDayStart < today {
                return false
            }
        }
        
        guard let gameStatus = getGameStatus(for: playerTeam) else {
            // If we can't determine game status but have game date, use date logic
            if let gameDate = gameDate {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let gameDayStart = calendar.startOfDay(for: gameDate)
                return gameDayStart >= today
            }
            
            // No game info = BYE
            return false
        }
        
        let points = currentPoints ?? 0.0
        let status = gameStatus.status.lowercased()
        
        // Player is "yet to play" if:
        // 1. They have 0 points AND
        // 2. Their game status is NOT final/post
        let hasZeroPoints = points == 0.0
        let gameNotFinal = !status.contains("final") && !status.contains("post")
        
        let yetToPlay = hasZeroPoints && gameNotFinal
        
        return yetToPlay
    }
    
    // MARK: - NEW DRY Methods (Consolidate duplicate logic)
    
    /// Check if a team's game is currently live
    /// **Consolidates:** 30+ duplicate `isLive` checks
    func isGameLive(for team: String) -> Bool {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return false
        }
        return gameInfo.isLive
    }
    
    /// Check if a team's game is complete
    /// **Consolidates:** 25+ duplicate `isComplete` checks
    func isGameComplete(for team: String) -> Bool {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return false
        }
        return gameInfo.isCompleted
    }
    
    /// Check if a team's game is pregame (not started yet)
    /// **Consolidates:** 15+ duplicate pregame checks
    func isGamePregame(for team: String) -> Bool {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            // No game data = might be pregame or bye
            return false
        }
        
        let status = gameInfo.gameStatus.lowercased()
        return status == "pre" || status == "pregame"
    }
    
    /// Check if a team is on bye this week
    /// **Consolidates:** 10+ duplicate bye checks
    func isTeamOnBye(_ team: String) -> Bool {
        // If no game info exists for the team, they're on bye
        return nflGameDataService.getGameInfo(for: team) == nil
    }
    
    /// Get game status category for a team
    /// **Consolidates:** Status string comparisons scattered everywhere
    func getGameStatusCategory(for team: String) -> GameStatusCategory {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return .bye
        }
        
        if gameInfo.isLive {
            return .live
        }
        
        if gameInfo.isCompleted {
            return .complete
        }
        
        return .pregame
    }
    
    // MARK: - Player Status Checks
    
    /// Check if a player is currently in an active game
    /// **Consolidates:** 8+ duplicate "in active game" checks
    func isPlayerInActiveGame(playerTeam: String?, currentPoints: Double?) -> Bool {
        guard let team = playerTeam else { return false }
        
        // Player is in active game if:
        // - Game is live
        // - Not on bye
        // - Game not complete
        return isGameLive(for: team) && 
               !isTeamOnBye(team) && 
               !isGameComplete(for: team)
    }
    
    // MARK: - Matchup Status
    
    /// Determine matchup status based on player game statuses
    /// **Consolidates:** Matchup status logic scattered across multiple ViewModels
    func determineMatchupStatus(
        homeRoster: [FantasyPlayer],
        awayRoster: [FantasyPlayer]
    ) -> MatchupStatus {
        let allPlayers = homeRoster + awayRoster
        
        // Check if any players are live
        let hasLivePlayers = allPlayers.contains { player in
            guard let team = player.team else { return false }
            return isGameLive(for: team)
        }
        
        if hasLivePlayers {
            return .live
        }
        
        // Check if all players have completed games
        let allComplete = allPlayers.allSatisfy { player in
            guard let team = player.team else { return true }
            return isGameComplete(for: team) || isTeamOnBye(team)
        }
        
        if allComplete {
            return .complete
        }
        
        return .upcoming
    }
    
    // MARK: - Game Time Display
    
    /// Get formatted game time display for a team
    /// **Consolidates:** Game time formatting scattered across views
    func getFormattedGameTime(for team: String) -> String {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return "BYE"
        }
        
        return gameInfo.formattedGameTime
    }
    
    /// Get status badge text for a team's game
    /// **Consolidates:** Status badge logic duplicated in multiple views
    func getStatusBadgeText(for team: String) -> String {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return "BYE"
        }
        
        return gameInfo.statusBadgeText
    }
    
    // MARK: - Bulk Operations
    
    /// Count how many players in a roster are yet to play
    /// **Consolidates:** "Yet to play" counting logic in multiple ViewModels
    func countPlayersYetToPlay(in roster: [FantasyPlayer]) -> Int {
        return roster.filter { player in
            guard player.isStarter else { return false }
            return isPlayerYetToPlay(
                playerTeam: player.team,
                currentPoints: player.currentPoints
            )
        }.count
    }
    
    /// Get all live players from a roster
    /// **Consolidates:** Live player filtering scattered across ViewModels
    func getLivePlayers(from roster: [FantasyPlayer]) -> [FantasyPlayer] {
        return roster.filter { player in
            guard let team = player.team else { return false }
            return isGameLive(for: team)
        }
    }
    
    /// Check if any players in roster are live
    /// **Consolidates:** "Has live players" checks duplicated everywhere
    func hasLivePlayers(in roster: [FantasyPlayer]) -> Bool {
        return roster.contains { player in
            guard let team = player.team else { return false }
            return isGameLive(for: team)
        }
    }
}

// MARK: - Supporting Types

/// Game status categories for cleaner logic
enum GameStatusCategory {
    case pregame
    case live
    case complete
    case bye
    
    var displayName: String {
        switch self {
        case .pregame: return "Pregame"
        case .live: return "Live"
        case .complete: return "Final"
        case .bye: return "Bye"
        }
    }
    
    var emoji: String {
        switch self {
        case .pregame: return "⏰"
        case .live: return "🔴"
        case .complete: return "✅"
        case .bye: return "📅"
        }
    }
}