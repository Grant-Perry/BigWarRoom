//
//  GameStatusService.swift
//  BigWarRoom
//
//  Service for providing real NFL game status data instead of mock bullshit
//

import Foundation

/// Service to provide real NFL game status data for fantasy players
final class GameStatusService {
    static let shared = GameStatusService()
    
    private init() {}
    
    /// Get real game status for a player based on their NFL team
    /// This replaces all the createMockGameStatus() bullshit with actual data
    func getGameStatus(for playerTeam: String?) -> GameStatus? {
        guard let team = playerTeam, !team.isEmpty else {
//            print("⚠️ GAME STATUS: No team provided - cannot determine game status")
            return nil
        }
        
        // Use NFLGameDataService to get real game info
        guard let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) else {
//            print("⚠️ GAME STATUS: No game info found for team \(team)")
            return nil
        }
        
        // Convert NFLGameInfo to GameStatus
        let gameStatus = GameStatus(from: gameInfo)
        
//        print("✅ GAME STATUS: Team \(team) -> Status: \(gameStatus.status), Time: \(gameStatus.timeString)")
        
        return gameStatus
    }
    
    /// Get game status with fallback for cases where team is unknown
    /// This should RARELY be used - ideally we always have player teams
    func getGameStatusWithFallback(for playerTeam: String?) -> GameStatus {
        if let gameStatus = getGameStatus(for: playerTeam) {
            return gameStatus
        }
        
        // Fallback: Default to pregame status instead of random mock data
//        print("🔥 GAME STATUS FALLBACK: Using pregame status for unknown team '\(playerTeam ?? "nil")'")
        
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
    func isPlayerYetToPlay(
        playerTeam: String?,
        currentPoints: Double?
    ) -> Bool {
        guard let gameStatus = getGameStatus(for: playerTeam) else {
            // If we can't determine game status, assume they haven't played
            // This should be rare with proper data
//            print("⚠️ YET TO PLAY: Cannot determine game status for team '\(playerTeam ?? "nil")' - assuming yet to play")
            return true
        }
        
        let points = currentPoints ?? 0.0
        let status = gameStatus.status.lowercased()
        
        // Player is "yet to play" if:
        // 1. They have 0 points AND
        // 2. Their game status is NOT final/post
        let hasZeroPoints = points == 0.0
        let gameNotFinal = !status.contains("final") && !status.contains("post")
        
        let yetToPlay = hasZeroPoints && gameNotFinal
        
//        print("🎯 YET TO PLAY: Team \(playerTeam ?? "nil"), Points: \(points), Status: \(status) -> Yet to play: \(yetToPlay)")
        
        return yetToPlay
    }
}
