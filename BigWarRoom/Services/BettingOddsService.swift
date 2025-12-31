//
//  BettingOddsService.swift
//  BigWarRoom
//
//  Service to fetch player betting odds from The Odds API
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
    
    static let shared = BettingOddsService()
    
    // Cache to avoid excessive API calls
    private var oddsCache: [String: (PlayerBettingOdds?, Date)] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // Cache for game odds (spreads/totals)
    private var gameOddsCache: [String: ([String: GameBettingOdds], Date)] = [:]
    private let gameOddsCacheExpiration: TimeInterval = 600 // 10 minutes
    
    // 🔥 NEW: User's preferred sportsbook (defaults to best line)
    var preferredSportsbook: Sportsbook {
        get {
            if let raw = UserDefaults.standard.string(forKey: UserDefaults.preferredSportsbookKey),
               let book = Sportsbook(rawValue: raw) {
                return book
            }
            return .bestLine // Default to best available
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaults.preferredSportsbookKey)
        }
    }
    
    // API Configuration
    private var apiKey: String {
        guard let key = Secrets.theOddsAPIKey else {
            return ""
        }
        return key
    }
    
    private let baseURL = "https://api.the-odds-api.com/v4"
    private let session = URLSession.shared
    
    // Loading state
    var isLoading = false
    var errorMessage: String?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Fetch betting odds for a player for current week
    /// - Parameters:
    ///   - player: Sleeper player to get odds for
    ///   - week: NFL week number
    ///   - year: Season year (defaults to current)
    /// - Returns: Player betting odds or nil if unavailable
    func fetchPlayerOdds(
        for player: SleeperPlayer,
        week: Int,
        year: Int? = nil
    ) async -> PlayerBettingOdds? {
        
        guard !apiKey.isEmpty else {
            errorMessage = "API key not configured"
            return nil
        }
        
        let cacheKey = "\(player.playerID)_\(week)_\(year)"
        
        // Check cache first
        if let (cachedOdds, timestamp) = oddsCache[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheExpiration,
           let odds = cachedOdds {
            return odds
        }
        
        guard let team = player.team else {
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Fetch odds for all NFL games this week
            let actualYear = year ?? AppConstants.currentSeasonYearInt
            let games = try await fetchNFLGamesOdds(week: week, year: actualYear)
            
            // Find the game for this player's team
            guard let game = findGame(for: team, in: games) else {
                let errorMsg = "No game found for \(team). Games may not be posted yet (games start Nov 2-3) or team name mismatch."
                errorMessage = errorMsg
                return nil
            }
            
            // Extract player props from the game
            let playerOdds = extractPlayerOdds(
                for: player,
                team: team,
                from: game,
                week: week
            )
            
            // Cache the result (even if nil - prevents repeated API calls)
            if let odds = playerOdds {
                oddsCache[cacheKey] = (odds, Date())
            } else {
                // Cache nil result with shorter expiration to retry later
                oddsCache[cacheKey] = (nil, Date().addingTimeInterval(-300)) // Expires in 5 min for retry
            }
            
            if playerOdds == nil {
                let errorMsg = "Player props not available. The Odds API free tier only includes game moneylines (h2h). Player props require a paid plan ($99+/month)."
                errorMessage = errorMsg
            }
            
            return playerOdds
            
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Fetch game odds (spread + total) for a set of Schedule games.
    /// Returns a dictionary keyed by `ScheduleGame.id` (e.g. "BUF@NE").
    func fetchGameOdds(
        for scheduleGames: [ScheduleGame],
        week: Int,
        year: Int? = nil
    ) async -> [String: GameBettingOdds] {
        
        guard !apiKey.isEmpty else {
            return [:]
        }
        
        let actualYear = year ?? AppConstants.currentSeasonYearInt
        let cacheKey = "schedule_games_\(week)_\(actualYear)"
        
        if let (cached, timestamp) = gameOddsCache[cacheKey],
           Date().timeIntervalSince(timestamp) < gameOddsCacheExpiration {
            return cached
        }
        
        do {
            let games = try await fetchNFLGamesMarkets(markets: ["h2h", "spreads", "totals"])
            var mapped: [String: GameBettingOdds] = [:]
            
            for scheduleGame in scheduleGames {
                if let odds = extractGameOdds(for: scheduleGame, from: games) {
                    mapped[scheduleGame.id] = odds
                }
            }
            
            gameOddsCache[cacheKey] = (mapped, Date())
            return mapped
        } catch {
            return [:]
        }
    }
    
    // MARK: - Private Implementation
    
    /// Fetch all NFL games with odds for a given week
    private func fetchNFLGamesOdds(week: Int, year: Int) async throws -> [TheOddsGame] {
        
        // The Odds API v4 doesn't support "player_props" as a market filter
        // Go directly to fetching all markets - player props may not be available in free tier
        return try await fetchNFLGamesOddsFallback()
    }
    
    /// Fallback method - fetch without player_props filter
    private func fetchNFLGamesOddsFallback() async throws -> [TheOddsGame] {
        var components = URLComponents(string: "\(baseURL)/sports/americanfootball_nfl/odds")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "oddsFormat", value: "american")
            // Remove player_props - fetch all markets and filter client-side
        ]
        
        guard let url = components?.url else {
            throw BettingOddsError.invalidURL
        }
        
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw BettingOddsError.httpError(httpResponse.statusCode)
            }
        }
        
        let games = try JSONDecoder().decode([TheOddsGame].self, from: data)
        
        // Debug: Print all available market keys to understand what's available
        var allMarketKeys = Set<String>()
        var sampleOutcomes: [String] = []
        
        for game in games.prefix(3) {
            for bookmaker in game.bookmakers.prefix(2) {
                for market in bookmaker.markets {
                    allMarketKeys.insert(market.key)
                    if market.outcomes.count > 0 && sampleOutcomes.count < 10 {
                        sampleOutcomes.append("\(market.key): \(market.outcomes[0].name)")
                    }
                }
            }
        }
        
        for key in Array(allMarketKeys).sorted() {
        }
        if !sampleOutcomes.isEmpty {
            for outcome in sampleOutcomes.prefix(5) {
            }
        }
        
        // ⚠️ CRITICAL: Check if player props are available
        let hasPlayerProps = allMarketKeys.contains { key in
            key.lowercased().contains("player") ||
            key.lowercased().contains("touchdown") ||
            key.lowercased().contains("yards") ||
            key.lowercased().contains("reception")
        }
        
        if !hasPlayerProps {
        }
        
        // Return all games - we'll filter for player props when extracting for specific player
        return games
    }
    
    /// Fetch NFL games with specific markets (e.g. h2h/spreads/totals).
    private func fetchNFLGamesMarkets(markets: [String]) async throws -> [TheOddsGame] {
        var components = URLComponents(string: "\(baseURL)/sports/americanfootball_nfl/odds")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "oddsFormat", value: "american"),
            URLQueryItem(name: "markets", value: markets.joined(separator: ","))
        ]
        
        guard let url = components?.url else {
            throw BettingOddsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw BettingOddsError.httpError(httpResponse.statusCode)
            }
        }
        
        return try JSONDecoder().decode([TheOddsGame].self, from: data)
    }
    
    private func extractGameOdds(for scheduleGame: ScheduleGame, from games: [TheOddsGame]) -> GameBettingOdds? {
        // Find matching The Odds API game
        guard let oddsGame = games.first(where: { game in
            teamsMatch(scheduleGame.homeTeam, game.homeTeam) && teamsMatch(scheduleGame.awayTeam, game.awayTeam)
        }) else {
            return nil
        }
        
        // 🔥 NEW: Extract odds from ALL available books
        var allBookOdds: [BookOdds] = []
        
        for bookmaker in oddsGame.bookmakers {
            guard let book = Sportsbook.from(apiKey: bookmaker.key) else { continue }
            
            let h2hMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "h2h" })
            let totalsMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "totals" })
            let spreadsMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "spreads" })
            
            // Extract moneyline favorite
            let favoriteML = extractFavoriteMoneylineNumeric(
                homeCode: scheduleGame.homeTeam,
                awayCode: scheduleGame.awayTeam,
                homeName: oddsGame.homeTeam,
                awayName: oddsGame.awayTeam,
                market: h2hMarket
            )
            
            // Extract total
            let total = totalsMarket?.outcomes.first?.point
            
            // Extract spread
            let spreadInfo = extractSpreadInfo(
                homeCode: scheduleGame.homeTeam,
                awayCode: scheduleGame.awayTeam,
                homeName: oddsGame.homeTeam,
                awayName: oddsGame.awayTeam,
                market: spreadsMarket
            )
            
            let bookOdds = BookOdds(
                book: book,
                favoriteTeamCode: favoriteML?.teamCode,
                favoriteMoneylineOdds: favoriteML?.odds,
                favoriteMoneylineDisplay: favoriteML?.display,
                totalPoints: total,
                spreadPoints: spreadInfo?.points,
                spreadTeamCode: spreadInfo?.teamCode
            )
            
            allBookOdds.append(bookOdds)
        }
        
        // 🔥 Determine which book to display based on user preference
        let displayBook: BookOdds?
        let selectedSportsbook: Sportsbook?
        
        if preferredSportsbook == .bestLine {
            // Find the best moneyline (least negative = most favorable)
            displayBook = allBookOdds
                .filter { $0.favoriteMoneylineOdds != nil }
                .max { ($0.favoriteMoneylineOdds ?? -9999) < ($1.favoriteMoneylineOdds ?? -9999) }
            selectedSportsbook = displayBook?.book
        } else {
            // Use the user's preferred book
            displayBook = allBookOdds.first { $0.book == preferredSportsbook }
            selectedSportsbook = preferredSportsbook
        }
        
        // Fallback to any available book if preferred not found
        let finalBook = displayBook ?? allBookOdds.first
        let finalSportsbook = selectedSportsbook ?? finalBook?.book
        
        // Format display values from the selected book
        let spreadDisplay: String?
        if let spread = finalBook?.spreadPoints, let teamCode = finalBook?.spreadTeamCode {
            spreadDisplay = "\(teamCode) \(formatPoint(spread))"
        } else {
            spreadDisplay = nil
        }
        
        let totalDisplay: String?
        let totalPoints: String?
        if let total = finalBook?.totalPoints {
            totalDisplay = "O/U \(formatPoint(total))"
            totalPoints = formatPoint(total)
        } else {
            totalDisplay = nil
            totalPoints = nil
        }
        
        // Avoid returning empty objects
        if finalBook?.favoriteMoneylineDisplay == nil && spreadDisplay == nil && totalDisplay == nil {
            return nil
        }
        
        return GameBettingOdds(
            gameID: scheduleGame.id,
            homeTeamCode: scheduleGame.homeTeam,
            awayTeamCode: scheduleGame.awayTeam,
            spreadDisplay: spreadDisplay,
            totalDisplay: totalDisplay,
            favoriteMoneylineTeamCode: finalBook?.favoriteTeamCode,
            favoriteMoneylineOdds: finalBook?.favoriteMoneylineDisplay,
            totalPoints: totalPoints,
            moneylineDisplay: nil, // We don't need the full ML display anymore
            sportsbook: finalSportsbook?.displayName,
            sportsbookEnum: finalSportsbook,
            lastUpdated: Date(),
            allBookOdds: allBookOdds
        )
    }
    
    // 🔥 NEW: Extract numeric moneyline for comparison
    private func extractFavoriteMoneylineNumeric(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> (teamCode: String, odds: Int, display: String)? {
        guard let market = market else { return nil }
        
        func outcome(forTeamName name: String) -> TheOddsOutcome? {
            return market.outcomes.first(where: { teamsMatch($0.name, name) })
        }
        
        guard let homeOutcome = outcome(forTeamName: homeName),
              let awayOutcome = outcome(forTeamName: awayName) else {
            return nil
        }
        
        let homePrice = Int(homeOutcome.price)
        let awayPrice = Int(awayOutcome.price)
        
        // Favorite is the more negative price
        let homeIsFav = (homePrice < 0 && awayPrice >= 0) || (homePrice < awayPrice)
        let teamCode = homeIsFav ? homeCode : awayCode
        let price = homeIsFav ? homePrice : awayPrice
        let display = price > 0 ? "+\(price)" : "\(price)"
        
        return (teamCode, price, display)
    }
    
    // 🔥 NEW: Extract spread info (points and team)
    private func extractSpreadInfo(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> (teamCode: String, points: Double)? {
        guard let market = market else { return nil }
        
        func point(forTeamName name: String) -> Double? {
            return market.outcomes.first(where: { teamsMatch($0.name, name) })?.point
        }
        
        guard let homePoint = point(forTeamName: homeName),
              let awayPoint = point(forTeamName: awayName) else {
            return nil
        }
        
        // Favorite is the team with negative points
        if homePoint < awayPoint {
            return (homeCode, homePoint)
        } else {
            return (awayCode, awayPoint)
        }
    }
    
    private func formatSpread(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> String? {
        guard let market = market else { return nil }
        
        func point(forTeamName name: String) -> Double? {
            let outcome = market.outcomes.first(where: { o in
                teamsMatch(o.name, name)
            })
            return outcome?.point
        }
        
        guard let homePoint = point(forTeamName: homeName),
              let awayPoint = point(forTeamName: awayName) else {
            return nil
        }
        
        // Favorite is the team with negative points
        if homePoint < awayPoint {
            return "\(homeCode) \(formatPoint(homePoint))"
        } else {
            return "\(awayCode) \(formatPoint(awayPoint))"
        }
    }
    
    private func formatTotalDisplay(market: TheOddsMarket?) -> String? {
        guard let market = market else { return nil }
        // Totals outcomes are usually "Over" and "Under" with the same point
        if let point = market.outcomes.first?.point {
            return "O/U \(formatPoint(point))"
        }
        return nil
    }
    
    private func extractTotalPoints(market: TheOddsMarket?) -> String? {
        guard let market = market else { return nil }
        if let point = market.outcomes.first?.point {
            return formatPoint(point)
        }
        return nil
    }
    
    private func formatMoneyline(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> String? {
        guard let market = market else { return nil }
        
        func price(forTeamName name: String) -> String? {
            guard let outcome = market.outcomes.first(where: { teamsMatch($0.name, name) }) else { return nil }
            let price = Int(outcome.price)
            return price > 0 ? "+\(price)" : "\(price)"
        }
        
        guard let home = price(forTeamName: homeName),
              let away = price(forTeamName: awayName) else {
            return nil
        }
        
        return "ML: \(awayCode) \(away) / \(homeCode) \(home)"
    }
    
    private func extractFavoriteMoneyline(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> (teamCode: String, odds: String)? {
        guard let market = market else { return nil }
        
        func outcome(forTeamName name: String) -> TheOddsOutcome? {
            return market.outcomes.first(where: { teamsMatch($0.name, name) })
        }
        
        guard let homeOutcome = outcome(forTeamName: homeName),
              let awayOutcome = outcome(forTeamName: awayName) else {
            return nil
        }
        
        let homePrice = Int(homeOutcome.price)
        let awayPrice = Int(awayOutcome.price)
        
        // Favorite is the more negative price; if both positive, pick lower (more favored).
        let homeIsFav = (homePrice < 0 && awayPrice >= 0) || (homePrice < awayPrice)
        let teamCode = homeIsFav ? homeCode : awayCode
        let price = homeIsFav ? homePrice : awayPrice
        let oddsString = price > 0 ? "+\(price)" : "\(price)"
        
        return (teamCode, oddsString)
    }
    
    private func formatPoint(_ value: Double) -> String {
        // Drop trailing .0, keep .5, etc.
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
    
    /// Find game for a specific team
    private func findGame(for team: String, in games: [TheOddsGame]) -> TheOddsGame? {
        let normalizedTeam = normalizeTeamName(team)
        
        let foundGame = games.first { game in
            teamsMatch(team, game.homeTeam) || teamsMatch(team, game.awayTeam)
        }
        
        if let game = foundGame {
        } else {
        }
        
        return foundGame
    }
    
    /// Extract player-specific odds from a game
    private func extractPlayerOdds(
        for player: SleeperPlayer,
        team: String,
        from game: TheOddsGame,
        week: Int
    ) -> PlayerBettingOdds? {
        
        let playerName = player.fullName
        
        var anytimeTD: PropOdds?
        var rushingYards: PropOdds?
        var receivingYards: PropOdds?
        var passingYards: PropOdds?
        var passingTDs: PropOdds?
        var receptions: PropOdds?
        
        // Search through all bookmakers and markets for player-specific props
        
        var foundMarkets = Set<String>()
        
        for bookmaker in game.bookmakers {
            for market in bookmaker.markets {
                
                // Search outcomes for this player (case-insensitive)
                for outcome in market.outcomes {
                    let outcomeName = outcome.name.lowercased()
                    let playerFullNameLower = playerName.lowercased()
                    let playerFirstLower = (player.firstName ?? "").lowercased()
                    let playerLastLower = (player.lastName ?? "").lowercased()
                    
                    // Check if outcome matches player name
                    let matchesPlayer = outcomeName.contains(playerFullNameLower) ||
                                       (!playerFirstLower.isEmpty && !playerLastLower.isEmpty && 
                                        outcomeName.contains(playerFirstLower) && outcomeName.contains(playerLastLower)) ||
                                       (!playerLastLower.isEmpty && outcomeName.contains(playerLastLower))
                    
                    if matchesPlayer {
                        foundMarkets.insert(market.key)
                        
                        // Determine market type and extract odds
                        switch market.key.lowercased() {
                        case let key where key.contains("touchdown") || key.contains("td"):
                            if anytimeTD == nil {
                                anytimeTD = PropOdds(
                                    id: "\(player.playerID)_anytime_td",
                                    marketType: .anytimeTD,
                                    playerName: playerName,
                                    overUnder: nil,
                                    yesOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    noOdds: nil, // Would need opposite outcome
                                    overOdds: nil,
                                    underOdds: nil,
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        case let key where key.contains("rushing") && key.contains("yard"):
                            if rushingYards == nil {
                                rushingYards = PropOdds(
                                    id: "\(player.playerID)_rushing_yds",
                                    marketType: .rushingYards,
                                    playerName: playerName,
                                    overUnder: outcome.point.map { String($0) },
                                    yesOdds: nil,
                                    noOdds: nil,
                                    overOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    underOdds: nil, // Would need opposite outcome
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        case let key where key.contains("receiving") && key.contains("yard"):
                            if receivingYards == nil {
                                receivingYards = PropOdds(
                                    id: "\(player.playerID)_receiving_yds",
                                    marketType: .receivingYards,
                                    playerName: playerName,
                                    overUnder: outcome.point.map { String($0) },
                                    yesOdds: nil,
                                    noOdds: nil,
                                    overOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    underOdds: nil,
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        case let key where key.contains("passing") && key.contains("yard"):
                            if passingYards == nil {
                                passingYards = PropOdds(
                                    id: "\(player.playerID)_passing_yds",
                                    marketType: .passingYards,
                                    playerName: playerName,
                                    overUnder: outcome.point.map { String($0) },
                                    yesOdds: nil,
                                    noOdds: nil,
                                    overOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    underOdds: nil,
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        case let key where key.contains("passing") && (key.contains("td") || key.contains("touchdown")):
                            if passingTDs == nil {
                                passingTDs = PropOdds(
                                    id: "\(player.playerID)_passing_tds",
                                    marketType: .passingTDs,
                                    playerName: playerName,
                                    overUnder: outcome.point.map { String($0) },
                                    yesOdds: nil,
                                    noOdds: nil,
                                    overOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    underOdds: nil,
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        case let key where key.contains("reception"):
                            if receptions == nil {
                                receptions = PropOdds(
                                    id: "\(player.playerID)_receptions",
                                    marketType: .receptions,
                                    playerName: playerName,
                                    overUnder: outcome.point.map { String($0) },
                                    yesOdds: nil,
                                    noOdds: nil,
                                    overOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    underOdds: nil,
                                    sportsbook: bookmaker.title
                                )
                            }
                            
                        default:
                            break
                        }
                    }
                }
            }
        }
        
        
        // Only return if we found at least one prop
        guard anytimeTD != nil || rushingYards != nil || receivingYards != nil || 
              passingYards != nil || passingTDs != nil || receptions != nil else {
            return nil
        }
        
        return PlayerBettingOdds(
            id: "\(player.playerID)_\(week)",
            playerID: player.playerID,
            playerName: playerName,
            team: team,
            week: week,
            lastUpdated: Date(),
            anytimeTD: anytimeTD,
            rushingYards: rushingYards,
            receivingYards: receivingYards,
            passingYards: passingYards,
            passingTDs: passingTDs,
            receptions: receptions
        )
    }
    
    /// Normalize team name for matching (e.g., "KC" -> matches "Kansas City Chiefs")
    private func normalizeTeamName(_ teamName: String) -> String {
        let upperTeam = teamName.uppercased()
        let lowerTeam = teamName.lowercased()
        
        // Full team name mappings (how The Odds API formats them)
        let fullTeamNames: [String: [String]] = [
            "KC": ["kansas city", "kansas city chiefs", "chiefs"],
            "BUF": ["buffalo", "buffalo bills", "bills"],
            "MIA": ["miami", "miami dolphins", "dolphins"],
            "NE": ["new england", "new england patriots", "patriots"],
            "NYJ": ["new york jets", "jets"],
            "BAL": ["baltimore", "baltimore ravens", "ravens"],
            "CIN": ["cincinnati", "cincinnati bengals", "bengals"],
            "CLE": ["cleveland", "cleveland browns", "browns"],
            "PIT": ["pittsburgh", "pittsburgh steelers", "steelers"],
            "HOU": ["houston", "houston texans", "texans"],
            "IND": ["indianapolis", "indianapolis colts", "colts"],
            "JAX": ["jacksonville", "jacksonville jaguars", "jaguars"],
            "TEN": ["tennessee", "tennessee titans", "titans"],
            "DEN": ["denver", "denver broncos", "broncos"],
            "LV": ["las vegas", "las vegas raiders", "raiders", "oakland raiders"],
            "LAC": ["los angeles chargers", "chargers", "la chargers"],
            "DAL": ["dallas", "dallas cowboys", "cowboys"],
            "NYG": ["new york giants", "giants"],
            "PHI": ["philadelphia", "philadelphia eagles", "eagles"],
            "WSH": ["washington", "washington commanders", "commanders"],
            "CHI": ["chicago", "chicago bears", "bears"],
            "DET": ["detroit", "detroit lions", "lions"],
            "GB": ["green bay", "green bay packers", "packers"],
            "MIN": ["minnesota", "minnesota vikings", "vikings"],
            "ATL": ["atlanta", "atlanta falcons", "falcons"],
            "CAR": ["carolina", "carolina panthers", "panthers"],
            "NO": ["new orleans", "new orleans saints", "saints"],
            "TB": ["tampa bay", "tampa bay buccaneers", "buccaneers"],
            "ARI": ["arizona", "arizona cardinals", "cardinals"],
            "LAR": ["los angeles rams", "rams", "la rams"],
            "SF": ["san francisco", "san francisco 49ers", "49ers"],
            "SEA": ["seattle", "seattle seahawks", "seahawks"]
        ]
        
        // If input is an abbreviation, return search variants
        if let variants = fullTeamNames[upperTeam] {
            // Return the most likely match candidate
            return variants.first ?? lowerTeam
        }
        
        // If input is already a full name, return lowercase for matching
        return lowerTeam
    }
    
    /// Check if two team names match (handles various formats)
    private func teamsMatch(_ team1: String, _ team2: String) -> Bool {
        let t1 = team1.lowercased().trimmingCharacters(in: .whitespaces)
        let t2 = team2.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Direct match
        if t1 == t2 { return true }
        
        // One contains the other
        if t1.contains(t2) || t2.contains(t1) { return true }
        
        // Check abbreviations
        let abbr1 = normalizeTeamName(team1)
        let abbr2 = normalizeTeamName(team2)
        if abbr1.contains(abbr2) || abbr2.contains(abbr1) { return true }
        
        // Special cases
        if (t1.contains("kansas") && t2.contains("chiefs")) ||
           (t2.contains("kansas") && t1.contains("chiefs")) { return true }
        
        if (t1.contains("buffalo") && t2.contains("bills")) ||
           (t2.contains("buffalo") && t1.contains("bills")) { return true }
        
        return false
    }
    
    /// Get date range for an NFL week
    private func getWeekDateRange(week: Int, year: Int) -> (Date, Date) {
        // Simplified: NFL weeks generally start on Thursday
        // This is a rough calculation - could be improved
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = 9 // NFL season typically starts in September
        components.day = (week - 1) * 7 + 1 // Rough estimate
        
        guard let weekStart = calendar.date(from: components) else {
            // Fallback to current date range
            let now = Date()
            return (now, calendar.date(byAdding: .day, value: 7, to: now) ?? now)
        }
        
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        
        return (weekStart, weekEnd)
    }
}

