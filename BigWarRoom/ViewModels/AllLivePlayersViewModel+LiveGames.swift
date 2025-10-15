//
//  AllLivePlayersViewModel+LiveGames.swift
//  BigWarRoom
//
//  🔥 FOCUSED: Live game detection and caching logic
//

import Foundation

extension AllLivePlayersViewModel {
    // MARK: - Live Game Cache Constants
    private var liveGameCacheExpiration: TimeInterval { 30.0 } // 30 second cache
    
    // MARK: - Live Game Cache Storage
    private var liveGameCache: [String: Bool] {
        get { 
            UserDefaults.standard.object(forKey: "AllLivePlayers_LiveGameCache") as? [String: Bool] ?? [:]
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: "AllLivePlayers_LiveGameCache")
        }
    }
    
    private var liveGameCacheTimestamp: Date? {
        get { 
            UserDefaults.standard.object(forKey: "AllLivePlayers_LiveGameCacheTimestamp") as? Date
        }
        set { 
            if let date = newValue {
                UserDefaults.standard.set(date, forKey: "AllLivePlayers_LiveGameCacheTimestamp")
            } else {
                UserDefaults.standard.removeObject(forKey: "AllLivePlayers_LiveGameCacheTimestamp")
            }
        }
    }
    
    // MARK: - Live Game Detection
    
    internal func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        guard let team = player.team else {
            print("🔥 LIVE CHECK: No team for player \(player.fullName)")
            return false
        }
        
        let cacheKey = team.uppercased()
        
        // Check cache first to avoid repeated API calls
        if let cachedResult = liveGameCache[cacheKey],
           let cacheTime = liveGameCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < liveGameCacheExpiration {
            print("🔥 LIVE CHECK: Using cached result for \(team): \(cachedResult)")
            return cachedResult
        }

        // Determine if game is actually LIVE right now
        var isLive = false
        var detectionMethod = "none"

        // Primary source: NFLGameDataService
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
            // Only consider live if status is "in" AND it's marked as live
            isLive = gameInfo.gameStatus.lowercased() == "in" && gameInfo.isLive
            detectionMethod = "NFLGameDataService(\(gameInfo.gameStatus), isLive: \(gameInfo.isLive))"

            // Additional safety: Ensure scores are actually updating (not stuck at 0-0)
            if isLive && gameInfo.homeScore == 0 && gameInfo.awayScore == 0 {
                // Still allow it - game could be 0-0 but actively playing
            }
            print("🔥 LIVE CHECK: \(team) -> \(isLive) via \(detectionMethod)")
        } else {
            // Fallback: Player's game status with better logging
            if let playerGameStatus = player.gameStatus?.status {
                isLive = playerGameStatus.lowercased() == "in"
                detectionMethod = "PlayerGameStatus(\(playerGameStatus))"
                print("🔥 LIVE CHECK: \(team) -> \(isLive) via \(detectionMethod) (fallback)")
            } else {
                print("🔥 LIVE CHECK: \(team) -> false (no game data available)")
            }
        }
        
        // Cache the result to prevent repeated lookups
        var cache = liveGameCache
        cache[cacheKey] = isLive
        liveGameCache = cache
        liveGameCacheTimestamp = Date()

        return isLive
    }
    
    // MARK: - Cache Management
    
    internal func clearLiveGameCache() {
        print("🔄 LIVE CACHE: Clearing live game cache")
        liveGameCache = [:]
        liveGameCacheTimestamp = nil
    }
    
    func refreshLiveGameData() {
        clearLiveGameCache()
        
        // Trigger background load of fresh game data
        Task { @MainActor in
            let currentWeek = NFLWeekCalculator.getCurrentWeek()
            NFLGameDataService.shared.fetchGameData(forWeek: currentWeek, forceRefresh: true)
        }
    }
    
    // MARK: - Live Game Status Helpers
    
    var activeLiveGamesCount: Int {
        let currentTime = Date()
        return NFLGameDataService.shared.gameData.values.filter { gameInfo in
            gameInfo.gameStatus.lowercased() == "in" && gameInfo.isLive
        }.count / 2 // Divide by 2 since each game has 2 teams
    }
    
    var hasAnyLiveGames: Bool {
        activeLiveGamesCount > 0
    }
    
    func getLiveGameStatus(for team: String) -> String? {
        guard let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) else {
            return nil
        }
        
        if gameInfo.isLive {
            return "LIVE: \(gameInfo.homeScore) - \(gameInfo.awayScore)"
        } else {
            return gameInfo.gameStatus.uppercased()
        }
    }
}