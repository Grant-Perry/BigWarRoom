//
//  GameStatusService.swift
//  BigWarRoom
//
//  Service for providing real NFL game status data instead of mock bullshit
//

import Foundation
import Observation

/// Service to provide real NFL game status data for fantasy players
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
}
