//
//  BettingOddsExtractor.swift
//  BigWarRoom
//
//  Extracts and transforms betting odds data from The Odds API responses
//

import Foundation

@MainActor
final class BettingOddsExtractor {
    
    // MARK: - Game Odds Extraction
    
    /// Extract game odds for a schedule game from API response
    func extractGameOdds(
        for scheduleGame: ScheduleGame,
        from games: [TheOddsGame],
        preferredSportsbook: Sportsbook
    ) -> GameBettingOdds? {
        
        DebugPrint(mode: .bettingOdds, "🔎 [MATCH] Looking for: home='\(scheduleGame.homeTeam)' away='\(scheduleGame.awayTeam)'")
        
        guard let oddsGame = games.first(where: { game in
            let homeMatch = teamsMatch(scheduleGame.homeTeam, game.homeTeam)
            let awayMatch = teamsMatch(scheduleGame.awayTeam, game.awayTeam)
            
            if homeMatch && awayMatch {
                DebugPrint(mode: .bettingOdds, "✅ [MATCH] Found match: '\(game.awayTeam)' @ '\(game.homeTeam)'")
            }
            
            return homeMatch && awayMatch
        }) else {
            DebugPrint(mode: .bettingOdds, "❌ [MATCH] No match found in API results")
            return nil
        }
        
        DebugPrint(mode: .bettingOdds, "📊 [EXTRACT] Game has \(oddsGame.bookmakers.count) bookmakers")
        
        // Extract odds from ALL available books
        var allBookOdds: [BookOdds] = []
        
        for bookmaker in oddsGame.bookmakers {
            DebugPrint(mode: .bettingOdds, "📚 [BOOK] Processing bookmaker: \(bookmaker.title)")
            
            guard let book = Sportsbook.from(apiKey: bookmaker.key) else {
                DebugPrint(mode: .bettingOdds, "⚠️ [BOOK] Unknown bookmaker key: \(bookmaker.key)")
                continue
            }
            
            let h2hMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "h2h" })
            let totalsMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "totals" })
            let spreadsMarket = bookmaker.markets.first(where: { $0.key.lowercased() == "spreads" })
            
            DebugPrint(mode: .bettingOdds, "📊 [BOOK] Markets - h2h: \(h2hMarket != nil), totals: \(totalsMarket != nil), spreads: \(spreadsMarket != nil)")
            
            // Extract moneylines
            let bothML = extractBothMoneylines(
                homeCode: scheduleGame.homeTeam,
                awayCode: scheduleGame.awayTeam,
                homeName: oddsGame.homeTeam,
                awayName: oddsGame.awayTeam,
                market: h2hMarket
            )
            
            if let ml = bothML {
                DebugPrint(mode: .bettingOdds, "📊 [BOOK] Favorite ML: \(ml.favorite.teamCode) \(ml.favorite.display), Underdog ML: \(ml.underdog.teamCode) \(ml.underdog.display)")
            }
            
            // Extract total
            let total = totalsMarket?.outcomes.first?.point
            if let t = total {
                DebugPrint(mode: .bettingOdds, "📊 [BOOK] Total: \(t)")
            }
            
            // Extract spread
            let spreadInfo = extractSpreadInfo(
                homeCode: scheduleGame.homeTeam,
                awayCode: scheduleGame.awayTeam,
                homeName: oddsGame.homeTeam,
                awayName: oddsGame.awayTeam,
                market: spreadsMarket
            )
            
            if let spread = spreadInfo {
                DebugPrint(mode: .bettingOdds, "📊 [BOOK] Spread: \(spread.teamCode) \(spread.points)")
            }
            
            let bookOdds = BookOdds(
                book: book,
                favoriteTeamCode: bothML?.favorite.teamCode,
                favoriteMoneylineOdds: bothML?.favorite.odds,
                favoriteMoneylineDisplay: bothML?.favorite.display,
                underdogTeamCode: bothML?.underdog.teamCode,
                underdogMoneylineOdds: bothML?.underdog.odds,
                underdogMoneylineDisplay: bothML?.underdog.display,
                totalPoints: total,
                spreadPoints: spreadInfo?.points,
                spreadTeamCode: spreadInfo?.teamCode
            )
            
            allBookOdds.append(bookOdds)
        }
        
        DebugPrint(mode: .bettingOdds, "📚 [BOOKS] Collected odds from \(allBookOdds.count) bookmakers")
        
        // Determine which book to display
        let displayBook: BookOdds?
        let selectedSportsbook: Sportsbook?
        
        if preferredSportsbook == .bestLine {
            DebugPrint(mode: .bettingOdds, "🎯 [SELECTION] Using best line logic")
            displayBook = allBookOdds
                .filter { $0.favoriteMoneylineOdds != nil }
                .max { ($0.favoriteMoneylineOdds ?? -9999) < ($1.favoriteMoneylineOdds ?? -9999) }
            selectedSportsbook = displayBook?.book
            
            if let selected = selectedSportsbook {
                DebugPrint(mode: .bettingOdds, "✅ [SELECTION] Best line from: \(selected.displayName)")
            }
        } else {
            DebugPrint(mode: .bettingOdds, "🎯 [SELECTION] Using preferred book: \(preferredSportsbook.displayName)")
            displayBook = allBookOdds.first { $0.book == preferredSportsbook }
            selectedSportsbook = preferredSportsbook
            
            if displayBook == nil {
                DebugPrint(mode: .bettingOdds, "⚠️ [SELECTION] Preferred book not found, will use fallback")
            }
        }
        
        // Fallback to any available book
        let finalBook = displayBook ?? allBookOdds.first
        let finalSportsbook = selectedSportsbook ?? finalBook?.book
        
        if let book = finalSportsbook {
            DebugPrint(mode: .bettingOdds, "✅ [FINAL] Using sportsbook: \(book.displayName)")
        }
        
        // Format display values
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
            DebugPrint(mode: .bettingOdds, "❌ [FINAL] No usable odds data found")
            return nil
        }
        
        DebugPrint(mode: .bettingOdds, "✅ [FINAL] Returning odds: spread=\(spreadDisplay ?? "N/A"), total=\(totalDisplay ?? "N/A"), ML=\(finalBook?.favoriteMoneylineDisplay ?? "N/A")")
        
        return GameBettingOdds(
            gameID: scheduleGame.id,
            homeTeamCode: scheduleGame.homeTeam,
            awayTeamCode: scheduleGame.awayTeam,
            spreadDisplay: spreadDisplay,
            totalDisplay: totalDisplay,
            favoriteMoneylineTeamCode: finalBook?.favoriteTeamCode,
            favoriteMoneylineOdds: finalBook?.favoriteMoneylineDisplay,
            underdogMoneylineTeamCode: finalBook?.underdogTeamCode,
            underdogMoneylineOdds: finalBook?.underdogMoneylineDisplay,
            totalPoints: totalPoints,
            moneylineDisplay: nil,
            sportsbook: finalSportsbook?.displayName,
            sportsbookEnum: finalSportsbook,
            lastUpdated: Date(),
            allBookOdds: allBookOdds
        )
    }
    
    // MARK: - Player Odds Extraction
    
    /// Extract player-specific odds from a game
    func extractPlayerOdds(
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
        
        var foundMarkets = Set<String>()
        
        for bookmaker in game.bookmakers {
            for market in bookmaker.markets {
                for outcome in market.outcomes {
                    let outcomeName = outcome.name.lowercased()
                    let playerFullNameLower = playerName.lowercased()
                    let playerFirstLower = (player.firstName ?? "").lowercased()
                    let playerLastLower = (player.lastName ?? "").lowercased()
                    
                    let matchesPlayer = outcomeName.contains(playerFullNameLower) ||
                                       (!playerFirstLower.isEmpty && !playerLastLower.isEmpty &&
                                        outcomeName.contains(playerFirstLower) && outcomeName.contains(playerLastLower)) ||
                                       (!playerLastLower.isEmpty && outcomeName.contains(playerLastLower))
                    
                    if matchesPlayer {
                        foundMarkets.insert(market.key)
                        
                        switch market.key.lowercased() {
                        case let key where key.contains("touchdown") || key.contains("td"):
                            if anytimeTD == nil {
                                anytimeTD = PropOdds(
                                    id: "\(player.playerID)_anytime_td",
                                    marketType: .anytimeTD,
                                    playerName: playerName,
                                    overUnder: nil,
                                    yesOdds: outcome.price > 0 ? Int(outcome.price) : nil,
                                    noOdds: nil,
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
                                    underOdds: nil,
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
    
    // MARK: - Private Extraction Helpers
    
    private func extractBothMoneylines(
        homeCode: String,
        awayCode: String,
        homeName: String,
        awayName: String,
        market: TheOddsMarket?
    ) -> (favorite: (teamCode: String, odds: Int, display: String), underdog: (teamCode: String, odds: Int, display: String))? {
        guard let market = market else {
            DebugPrint(mode: .bettingOdds, "⚠️ [ML EXTRACT] No h2h market provided")
            return nil
        }
        
        func outcome(forTeamName name: String) -> TheOddsOutcome? {
            return market.outcomes.first(where: { teamsMatch($0.name, name) })
        }
        
        guard let homeOutcome = outcome(forTeamName: homeName),
              let awayOutcome = outcome(forTeamName: awayName) else {
            DebugPrint(mode: .bettingOdds, "⚠️ [ML EXTRACT] Could not find both team outcomes")
            return nil
        }
        
        let homePrice = Int(homeOutcome.price)
        let awayPrice = Int(awayOutcome.price)
        
        DebugPrint(mode: .bettingOdds, "🎲 [ML EXTRACT] RAW PRICES - Home(\(homeCode)): \(homePrice), Away(\(awayCode)): \(awayPrice)")
        
        let homeIsFav = (homePrice < 0 && awayPrice >= 0) || (homePrice < awayPrice)
        
        let favTeamCode = homeIsFav ? homeCode : awayCode
        let favPrice = homeIsFav ? homePrice : awayPrice
        let favDisplay = favPrice > 0 ? "+\(favPrice)" : "\(favPrice)"
        
        let dogTeamCode = homeIsFav ? awayCode : homeCode
        let dogPrice = homeIsFav ? awayPrice : homePrice
        let dogDisplay = dogPrice > 0 ? "+\(dogPrice)" : "\(dogPrice)"
        
        DebugPrint(mode: .bettingOdds, "🎲 [ML EXTRACT] DETERMINED - Fav: \(favTeamCode) \(favPrice), Dog: \(dogTeamCode) \(dogPrice)")
        
        return (
            favorite: (favTeamCode, favPrice, favDisplay),
            underdog: (dogTeamCode, dogPrice, dogDisplay)
        )
    }
    
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
        
        if homePoint < awayPoint {
            return (homeCode, homePoint)
        } else {
            return (awayCode, awayPoint)
        }
    }
    
    // MARK: - Team Matching
    
    /// Check if two team names match (handles various formats)
    func teamsMatch(_ team1: String, _ team2: String) -> Bool {
        let t1 = team1.lowercased().trimmingCharacters(in: .whitespaces)
        let t2 = team2.lowercased().trimmingCharacters(in: .whitespaces)
        
        DebugPrint(mode: .bettingOdds, limit: 20, "🔤 [MATCH] Comparing: '\(t1)' vs '\(t2)'")
        
        if t1 == t2 {
            DebugPrint(mode: .bettingOdds, limit: 20, "✅ [MATCH] Direct match")
            return true
        }
        
        if t1.contains(t2) || t2.contains(t1) {
            DebugPrint(mode: .bettingOdds, limit: 20, "✅ [MATCH] Contains match")
            return true
        }
        
        let abbr1 = normalizeTeamName(team1)
        let abbr2 = normalizeTeamName(team2)
        
        DebugPrint(mode: .bettingOdds, limit: 20, "🔤 [MATCH] Normalized: '\(abbr1)' vs '\(abbr2)'")
        
        if abbr1.contains(abbr2) || abbr2.contains(abbr1) {
            DebugPrint(mode: .bettingOdds, limit: 20, "✅ [MATCH] Normalized match")
            return true
        }
        
        if (t1.contains("kansas") && t2.contains("chiefs")) ||
           (t2.contains("kansas") && t1.contains("chiefs")) {
            DebugPrint(mode: .bettingOdds, limit: 20, "✅ [MATCH] Special case: Chiefs")
            return true
        }
        
        if (t1.contains("buffalo") && t2.contains("bills")) ||
           (t2.contains("buffalo") && t1.contains("bills")) {
            DebugPrint(mode: .bettingOdds, limit: 20, "✅ [MATCH] Special case: Bills")
            return true
        }
        
        DebugPrint(mode: .bettingOdds, limit: 20, "❌ [MATCH] No match found")
        return false
    }
    
    /// Normalize team name for matching
    private func normalizeTeamName(_ teamName: String) -> String {
        let upperTeam = teamName.uppercased()
        let lowerTeam = teamName.lowercased()
        
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
        
        if let variants = fullTeamNames[upperTeam] {
            return variants.first ?? lowerTeam
        }
        
        return lowerTeam
    }
    
    /// Find game for a specific team
    func findGame(for team: String, in games: [TheOddsGame]) -> TheOddsGame? {
        return games.first { game in
            teamsMatch(team, game.homeTeam) || teamsMatch(team, game.awayTeam)
        }
    }
    
    // MARK: - Formatting Helpers
    
    private func formatPoint(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}