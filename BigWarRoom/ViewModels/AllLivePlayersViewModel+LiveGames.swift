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
    
    // 🔥 DEPRECATED: This function is no longer needed - use player.isInActiveGame instead
    // Keeping for backward compatibility during migration
    internal func isPlayerInLiveGame(_ player: FantasyPlayer) -> Bool {
        // 🔥 PHASE 4 DI: Use method with injected service
        return player.isInActiveGame(gameDataService: nflGameDataService)
    }
    
    // MARK: - Cache Management
    
    internal func clearLiveGameCache() {
        liveGameCache = [:]
        liveGameCacheTimestamp = nil
    }
    
    func refreshLiveGameData() {
        clearLiveGameCache()
        
        // Trigger background load of fresh game data
        Task { @MainActor in
            // 🔥 CRITICAL FIX: Use WeekSelectionManager.selectedWeek (user's chosen week) instead of getCurrentWeek
            let selectedWeek = weekSelectionManager.selectedWeek
            
            DebugPrint(mode: .weekCheck, "📅 AllLivePlayers.refreshLiveGameData: Using user-selected week \(selectedWeek)")
            
            nflGameDataService.fetchGameData(forWeek: selectedWeek, forceRefresh: true)
        }
    }
    
    // MARK: - Live Game Status Helpers
    
    var activeLiveGamesCount: Int {
        return nflGameDataService.gameData.values.filter { gameInfo in
            gameInfo.gameStatus.lowercased() == "in" && gameInfo.isLive
        }.count / 2 // Divide by 2 since each game has 2 teams
    }
    
    var hasAnyLiveGames: Bool {
        activeLiveGamesCount > 0
    }
    
    func getLiveGameStatus(for team: String) -> String? {
        guard let gameInfo = nflGameDataService.getGameInfo(for: team) else {
            return nil
        }
        
        if gameInfo.isLive {
            return "LIVE: \(gameInfo.homeScore) - \(gameInfo.awayScore)"
        } else {
            return gameInfo.gameStatus.uppercased()
        }
    }
}