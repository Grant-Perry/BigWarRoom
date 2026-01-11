//
//  BettingOddsService.swift
//  BigWarRoom
//
//  Orchestrates betting odds fetching, caching, and extraction
//

import Foundation
import Observation
import SwiftUI

// MARK: - User Preference Key
extension UserDefaults {
    static let preferredSportsbookKey = "PreferredSportsbook"
}

@Observable
@MainActor
final class BettingOddsService {
    
    // MARK: - Dependencies
    
    private let bettingOddsAPIClient = BettingOddsAPIClient()
    private let bettingOddsExtractor = BettingOddsExtractor()
    private let bettingOddsCacheManager = BettingOddsCacheManager()
    
    // MARK: - User Preferences
    
    var preferredSportsbook: Sportsbook {
        get {
            if let raw = UserDefaults.standard.string(forKey: UserDefaults.preferredSportsbookKey),
               let book = Sportsbook(rawValue: raw) {
                return book
            }
            return .bestLine
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaults.preferredSportsbookKey)
        }
    }
    
    // MARK: - Loading State
    
    var isLoading = false
    var errorMessage: String?
    
    init() {}
    
    // MARK: - Public API
    
    /// Force refresh game odds cache
    func refreshGameOddsCache() {
        bettingOddsCacheManager.clearGameOddsCache()
    }
    
    /// Fetch betting odds for a player
    func fetchPlayerOdds(
        for player: SleeperPlayer,
        week: Int,
        year: Int? = nil
    ) async -> PlayerBettingOdds? {
        
        guard !bettingOddsAPIClient.apiKey.isEmpty else {
            errorMessage = "API key not configured"
            return nil
        }
        
        let cacheKey = "\(player.playerID)_\(week)_\(year ?? AppConstants.currentSeasonYearInt)"
        
        // Check cache
        if let cached = bettingOddsCacheManager.getCachedPlayerOdds(cacheKey: cacheKey) {
            return cached
        }
        
        guard let team = player.team else {
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let games = try await bettingOddsAPIClient.fetchAllNFLGames()
            
            guard let game = bettingOddsExtractor.findGame(for: team, in: games) else {
                errorMessage = "No game found for \(team). Games may not be posted yet or team name mismatch."
                return nil
            }
            
            let playerOdds = bettingOddsExtractor.extractPlayerOdds(
                for: player,
                team: team,
                from: game,
                week: week
            )
            
            bettingOddsCacheManager.cachePlayerOdds(playerOdds, cacheKey: cacheKey)
            
            if playerOdds == nil {
                errorMessage = "Player props not available. The Odds API free tier only includes game moneylines (h2h). Player props require a paid plan ($99+/month)."
            }
            
            return playerOdds
            
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Fetch game odds for schedule games
    func fetchGameOdds(
        for scheduleGames: [ScheduleGame],
        week: Int,
        year: Int? = nil
    ) async -> [String: GameBettingOdds] {
        
        guard !bettingOddsAPIClient.apiKey.isEmpty else {
            DebugPrint(mode: .bettingOdds, "❌ [ODDS] API key is empty - cannot fetch odds")
            return [:]
        }
        
        let actualYear = year ?? AppConstants.currentSeasonYearInt
        let cacheKey = "schedule_games_\(week)_\(actualYear)"
        
        DebugPrint(mode: .bettingOdds, "🎰 [ODDS] Fetching game odds for \(scheduleGames.count) games, week \(week), year \(actualYear)")
        
        // Check persistent cache
        let intervalMinutes = UserDefaults.standard.double(forKey: "OddsRefreshInterval")
        let finalIntervalMinutes = intervalMinutes > 0 ? intervalMinutes : 15.0
        let expirationInterval = finalIntervalMinutes * 60.0
        
        DebugPrint(mode: .bracketTimer, "⏱️ [ODDS CACHE CHECK] User interval: \(Int(finalIntervalMinutes)) minutes (\(Int(expirationInterval))s)")
        
        let cacheStatus = bettingOddsCacheManager.isGameOddsCacheValid()
        
        if cacheStatus.isValid {
            if let timeSince = cacheStatus.timeSinceLastFetch,
               let lastFetch = cacheStatus.lastFetchDate {
                DebugPrint(mode: .bracketTimer, "📊 [ODDS CACHE CHECK] Last fetch: \(Int(timeSince))s ago (at \(Self.formatDate(lastFetch)))")
                DebugPrint(mode: .bracketTimer, "📊 [ODDS CACHE CHECK] Expires in: \(Int(expirationInterval - timeSince))s")
                
                // Try in-memory cache first
                if let cached = bettingOddsCacheManager.getCachedGameOdds(cacheKey: cacheKey) {
                    let minutesAgo = Int(timeSince / 60)
                    DebugPrint(mode: .bracketTimer, "✅ [ODDS CACHE HIT - MEMORY] Using in-memory cached odds - \(cached.count) games, \(minutesAgo) min old, \(Int(finalIntervalMinutes - Double(minutesAgo))) min until refresh")
                    return cached
                }
                
                // Try persistent file cache
                if let persisted = bettingOddsCacheManager.loadPersistedGameOdds(cacheKey: cacheKey) {
                    let minutesAgo = Int(timeSince / 60)
                    DebugPrint(mode: .bracketTimer, "✅ [ODDS CACHE HIT - DISK] Using persisted odds from file - \(persisted.count) games, \(minutesAgo) min old, \(Int(finalIntervalMinutes - Double(minutesAgo))) min until refresh")
                    
                    // Populate in-memory cache
                    if let lastFetch = cacheStatus.lastFetchDate {
                        bettingOddsCacheManager.cacheGameOdds(persisted, cacheKey: cacheKey, timestamp: lastFetch)
                    }
                    
                    return persisted
                } else {
                    DebugPrint(mode: .bracketTimer, "⚠️ [ODDS CACHE PARTIAL] Timestamp valid but no persisted data - will fetch fresh")
                }
            }
        } else {
            if let timeSince = cacheStatus.timeSinceLastFetch {
                let minutesOverdue = Int((timeSince - expirationInterval) / 60)
                DebugPrint(mode: .bracketTimer, "⏰ [ODDS CACHE EXPIRED] Cache is \(minutesOverdue) min overdue - fetching fresh odds")
            } else {
                DebugPrint(mode: .bracketTimer, "🆕 [ODDS CACHE MISS] No previous fetch found - fetching fresh odds")
            }
        }
        
        // Fetch fresh data
        DebugPrint(mode: .bracketTimer, "🌐 [ODDS API CALL] Fetching fresh odds from The Odds API...")
        
        do {
            let games = try await bettingOddsAPIClient.fetchNFLGamesWithMarkets(["h2h", "spreads", "totals"])
            
            DebugPrint(mode: .bettingOdds, "📥 [ODDS] The Odds API returned \(games.count) total games")
            
            var mapped: [String: GameBettingOdds] = [:]
            
            for scheduleGame in scheduleGames {
                DebugPrint(mode: .bettingOdds, "🔍 [ODDS] Searching for odds: \(scheduleGame.awayTeam) @ \(scheduleGame.homeTeam)")
                
                if let odds = bettingOddsExtractor.extractGameOdds(
                    for: scheduleGame,
                    from: games,
                    preferredSportsbook: preferredSportsbook
                ) {
                    mapped[scheduleGame.id] = odds
                    DebugPrint(mode: .bettingOdds, "✅ [ODDS] Found odds for \(scheduleGame.id): spread=\(odds.spreadDisplay ?? "N/A"), total=\(odds.totalDisplay ?? "N/A"), ML=\(odds.favoriteMoneylineOdds ?? "N/A")")
                } else {
                    DebugPrint(mode: .bettingOdds, "❌ [ODDS] No odds found for \(scheduleGame.id)")
                }
            }
            
            DebugPrint(mode: .bettingOdds, "✅ [ODDS] Mapped \(mapped.count) out of \(scheduleGames.count) games with odds")
            
            // Update caches
            let now = Date()
            bettingOddsCacheManager.updateGameOddsFetchTimestamp()
            bettingOddsCacheManager.persistGameOdds(mapped, cacheKey: cacheKey)
            bettingOddsCacheManager.cacheGameOdds(mapped, cacheKey: cacheKey, timestamp: now)
            
            let nextRefreshTime = now.addingTimeInterval(expirationInterval)
            DebugPrint(mode: .bracketTimer, "💾 [ODDS CACHE UPDATED] Saved timestamp + file: \(Self.formatDate(now))")
            DebugPrint(mode: .bracketTimer, "⏰ [ODDS CACHE UPDATED] Next refresh at: \(Self.formatDate(nextRefreshTime)) (\(Int(finalIntervalMinutes)) min from now)")
            
            return mapped
        } catch {
            DebugPrint(mode: .bettingOdds, "❌ [ODDS] Error fetching odds: \(error)")
            DebugPrint(mode: .bracketTimer, "❌ [ODDS API ERROR] Failed to fetch fresh odds: \(error.localizedDescription)")
            return [:]
        }
    }
    
    // MARK: - Helpers
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}