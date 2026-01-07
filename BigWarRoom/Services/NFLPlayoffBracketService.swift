//
//  NFLPlayoffBracketService.swift
//  BigWarRoom
//
//  Service to fetch and manage NFL Playoff Bracket data from ESPN Standings API
//

import Foundation
import Observation
import Combine

@Observable
@MainActor
final class NFLPlayoffBracketService {
    
    // MARK: - Published State
    
    var currentBracket: PlayoffBracket?
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Private Properties
    
    @ObservationIgnored private var cache: [Int: PlayoffBracket] = [:]
    @ObservationIgnored private var cacheTimestamps: [Int: Date] = [:]
    @ObservationIgnored private let cacheExpiration: TimeInterval = 300  // 5 minutes
    
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var refreshTimer: Timer?
    
    // Dependencies
    private let weekSelectionManager: WeekSelectionManager
    private let appLifecycleManager: AppLifecycleManager
    
    // MARK: - Initialization
    
    init(
        weekSelectionManager: WeekSelectionManager,
        appLifecycleManager: AppLifecycleManager
    ) {
        self.weekSelectionManager = weekSelectionManager
        self.appLifecycleManager = appLifecycleManager
    }
    
    // MARK: - Public Methods
    
    /// Fetch playoff bracket for a given season using ESPN Standings API
    func fetchPlayoffBracket(for season: Int, forceRefresh: Bool = false) {
        DebugPrint(mode: .nflData, "🏈 Fetching playoff bracket for season \(season)")
        
        // Check cache first
        if !forceRefresh,
           let cached = cache[season],
           let timestamp = cacheTimestamps[season],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            DebugPrint(mode: .nflData, "✅ Using cached bracket for \(season)")
            currentBracket = cached
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Fetch both standings (for seeds) and scoreboard (for actual games)
        Task {
            await fetchBracketData(for: season)
        }
    }
    
    /// Start live updates for active playoff games
    func startLiveUpdates(for season: Int) {
        stopLiveUpdates()
        
        let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard await self.appLifecycleManager.isActive else { return }
                
                DebugPrint(mode: .nflData, "🔄 Auto-refreshing playoff bracket")
                self.fetchPlayoffBracket(for: season, forceRefresh: true)
            }
        }
    }
    
    /// Stop live updates
    func stopLiveUpdates() {
        DebugPrint(mode: .nflData, "🛑 Stopping playoff bracket live updates")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellable?.cancel()
        cancellable = nil
    }
    
    /// Check if we're currently in playoff weeks
    func isPlayoffWeek(_ week: Int) -> Bool {
        return week >= 19 && week <= 22
    }
    
    /// Get all available historical seasons (2010-present)
    func getAvailableSeasons() -> [Int] {
        let currentYear = AppConstants.currentSeasonYearInt
        return Array(2010...currentYear).reversed()
    }
    
    // MARK: - Private Methods
    
    /// Fetch bracket data from both standings and scoreboard APIs
    private func fetchBracketData(for season: Int) async {
        // First, fetch standings to get seeds
        guard let standingsURL = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/standings?season=\(season)") else {
            errorMessage = "Failed to build standings API URL"
            isLoading = false
            return
        }
        
        do {
            // Fetch standings
            let (standingsData, _) = try await URLSession.shared.data(from: standingsURL)
            let standingsResponse = try JSONDecoder().decode(ESPNStandingsV2Response.self, from: standingsData)
            
            // Extract seeds
            let (afcSeeds, nfcSeeds) = extractSeeds(from: standingsResponse)
            
            // Prefer per-week postseason fetch (weeks 1..4). If empty, fall back to date range.
            let playoffYear = season + 1
            let weeklyEvents = try await fetchWeeklyPlayoffEvents(for: playoffYear)
            
            if !weeklyEvents.isEmpty {
                DebugPrint(mode: .nflData, "📅 Using weekly postseason fetch (weeks 1–4) – events: \(weeklyEvents.count)")
                let merged = ESPNScoreboardResponse(events: weeklyEvents)
                await buildBracketFromGames(merged, afcSeeds: afcSeeds, nfcSeeds: nfcSeeds, season: season)
                return
            }
            
            // Fallback to date-range scoreboard (defensive)
            guard let scoreboardURL = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates=\(playoffYear)0101-\(playoffYear)0228&seasontype=3") else {
                await buildBracketFromSeeds(afcSeeds: afcSeeds, nfcSeeds: nfcSeeds, season: season)
                return
            }
            
            let (scoreboardData, _) = try await URLSession.shared.data(from: scoreboardURL)
            let scoreboardResponse = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: scoreboardData)
            
            // Build bracket from actual games
            await buildBracketFromGames(scoreboardResponse, afcSeeds: afcSeeds, nfcSeeds: nfcSeeds, season: season)
            
        } catch {
            DebugPrint(mode: .nflData, "❌ Failed to fetch bracket data: \(error)")
            errorMessage = "Failed to load playoff data: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Extract seeds from standings data
    private func extractSeeds(from response: ESPNStandingsV2Response) -> (afc: [Int: PlayoffTeam], nfc: [Int: PlayoffTeam]) {
        var afcSeeds: [Int: PlayoffTeam] = [:]
        var nfcSeeds: [Int: PlayoffTeam] = [:]
        
        let children = response.children ?? []
        for child in children {
            let entries = child.standings?.entries ?? []
            for entry in entries {
                let teamAbbrRaw = entry.team.abbreviation.uppercased()
                
                guard let seedValue = entry.stats?.first(where: { ($0.name ?? $0.type) == "playoffSeed" })?.value else {
                    continue
                }
                
                let seed = Int(seedValue)
                guard seed >= 1 && seed <= 7 else {
                    continue
                }
                
                // 🔥 Normalize team code before lookup
                let teamAbbr = normalizeTeamCode(teamAbbrRaw)
                
                // 🔥 DEBUG: Log Washington specifically
                if teamAbbrRaw.contains("WAS") || teamAbbrRaw.contains("WSH") {
                    DebugPrint(mode: .nflData, "🔍 Found Washington in standings: '\(teamAbbrRaw)' → normalized to '\(teamAbbr)' with seed \(seed)")
                }
                
                guard let nflTeam = NFLTeam.team(for: teamAbbr) else {
                    DebugPrint(mode: .nflData, "⚠️ Could not find NFLTeam for '\(teamAbbr)' (original: '\(teamAbbrRaw)')")
                    continue
                }
                
                let team = PlayoffTeam(
                    abbreviation: teamAbbr,
                    name: nflTeam.fullName,
                    seed: seed,
                    score: nil,
                    logoURL: nil
                )
                
                if nflTeam.conference == .afc {
                    afcSeeds[seed] = team
                } else {
                    nfcSeeds[seed] = team
                }
            }
        }
        
        DebugPrint(mode: .nflData, "🏈 Extracted seeds from standings - NFC seed 6: \(nfcSeeds[6]?.abbreviation ?? "MISSING")")
        
        return (afcSeeds, nfcSeeds)
    }
    
    /// Build bracket from actual playoff games
    private func buildBracketFromGames(
        _ scoreboardResponse: ESPNScoreboardResponse,
        afcSeeds: [Int: PlayoffTeam],
        nfcSeeds: [Int: PlayoffTeam],
        season: Int
    ) async {
        var afcGames: [PlayoffGame] = []
        var nfcGames: [PlayoffGame] = []
        var superBowl: PlayoffGame?
        
        for event in scoreboardResponse.events ?? [] {
            guard let competition = event.competitions?.first else { continue }
            
            // Extract teams
            guard competition.competitors?.count == 2 else { continue }
            let competitors = competition.competitors!
            
            let homeComp = competitors.first { $0.homeAway == "home" }
            let awayComp = competitors.first { $0.homeAway == "away" }
            
            guard let homeTeamRaw = homeComp?.team.abbreviation.uppercased(),
                  let awayTeamRaw = awayComp?.team.abbreviation.uppercased() else { continue }
            
            // 🔥 Normalize team codes (handle Washington WASH/WSH)
            let homeTeam = normalizeTeamCode(homeTeamRaw)
            let awayTeam = normalizeTeamCode(awayTeamRaw)
            
            // Get scores
            let homeScore = Int(homeComp?.score ?? "0")
            let awayScore = Int(awayComp?.score ?? "0")
            
            // Determine round from week/date
            guard let round = determinePlayoffRound(from: event, season: season) else {
                DebugPrint(mode: .nflData, "⏭️ Skipping non-postseason event id:\(event.id ?? "?") name:'\(event.name ?? "")' week:\(event.week?.number ?? -1)")
                continue
            }
            DebugPrint(mode: .nflData, "🧭 Round mapping -> id:\(event.id ?? "?"), name:'\(event.name ?? "")', week:\(event.week?.number ?? -1) => \(round)")
            
            // Get seeds - use normalized team codes
            let homeNFLTeam = NFLTeam.team(for: homeTeam)
            let awayNFLTeam = NFLTeam.team(for: awayTeam)
            
            let homeSeed = (homeNFLTeam?.conference == .afc ? afcSeeds : nfcSeeds).first(where: { $0.value.abbreviation == homeTeam })?.key
            let awaySeed = (awayNFLTeam?.conference == .afc ? afcSeeds : nfcSeeds).first(where: { $0.value.abbreviation == awayTeam })?.key
            
            // 🔥 DEBUG: Log seed assignment
            if homeSeed == nil || awaySeed == nil {
                DebugPrint(mode: .nflData, "⚠️ Missing seed for game: \(awayTeam) (seed \(awaySeed ?? -1)) @ \(homeTeam) (seed \(homeSeed ?? -1))")
            }
            
            // Create playoff teams with scores
            let homePlayoffTeam = PlayoffTeam(
                abbreviation: homeTeam,
                name: homeNFLTeam?.fullName ?? homeTeam,
                seed: homeSeed,
                score: homeScore,
                logoURL: nil
            )
            
            let awayPlayoffTeam = PlayoffTeam(
                abbreviation: awayTeam,
                name: awayNFLTeam?.fullName ?? awayTeam,
                seed: awaySeed,
                score: awayScore,
                logoURL: nil
            )
            
            // Parse game date
            let gameDate = ISO8601DateFormatter().date(from: event.date ?? "") ?? Date()
            
            // Determine game status
            let status: PlayoffGame.GameStatus
            if competition.status?.type?.completed == true {
                status = .final
            } else if competition.status?.type?.state == "in" {
                let quarter = "Q\(competition.status?.period ?? 1)"
                let time = competition.status?.displayClock ?? ""
                status = .inProgress(quarter: quarter, timeRemaining: time)
            } else {
                status = .scheduled
            }
            
            // Determine conference
            let conference: PlayoffGame.Conference
            if round == .superBowl {
                conference = .none
            } else if homeNFLTeam?.conference == .afc && awayNFLTeam?.conference == .afc {
                conference = .afc
            } else {
                conference = .nfc
            }
            
            let game = PlayoffGame(
                id: event.id ?? UUID().uuidString,
                round: round,
                conference: conference,
                homeTeam: homePlayoffTeam,
                awayTeam: awayPlayoffTeam,
                gameDate: gameDate,
                status: status
            )
            
            // Sort into proper arrays
            if round == .superBowl {
                superBowl = game
            } else if conference == .afc {
                afcGames.append(game)
            } else {
                nfcGames.append(game)
            }
        }
        
        // Sort games by date
        afcGames.sort { $0.gameDate < $1.gameDate }
        nfcGames.sort { $0.gameDate < $1.gameDate }
        
        // Historical fallback for Super Bowl if ESPN provided a generic or missing SB
        if superBowl == nil || isGenericSuperBowl(superBowl!) {
            if let fb = fallbackSuperBowl(for: season) {
                DebugPrint(mode: .nflData, "🏆 Using historical Super Bowl fallback for season \(season)")
                superBowl = fb
            } else {
                DebugPrint(mode: .nflData, "⚠️ No Super Bowl data (and no fallback) for season \(season)")
            }
        }
        
        let bracket = PlayoffBracket(
            season: season,
            afcGames: afcGames,
            nfcGames: nfcGames,
            superBowl: superBowl,
            afcSeed1: afcSeeds[1],
            nfcSeed1: nfcSeeds[1]
        )
        
        // Update cache
        cache[season] = bracket
        cacheTimestamps[season] = Date()
        currentBracket = bracket
        isLoading = false
        
        DebugPrint(mode: .nflData, """
        ✅ Built playoff bracket from games:
           - Season: \(season)
           - AFC Games: \(afcGames.count)
           - NFC Games: \(nfcGames.count)
           - Super Bowl: \(superBowl != nil ? "✓" : "✗")
        """)
        if superBowl == nil {
            DebugPrint(mode: .nflData, "⚠️ Super Bowl event not found after parsing. Check round mapping & ESPN payload.")
        }
    }
    
    /// Fallback: Build bracket from seeds only (prediction mode)
    private func buildBracketFromSeeds(afcSeeds: [Int: PlayoffTeam], nfcSeeds: [Int: PlayoffTeam], season: Int) async {
        let afcGames = buildWildCardGames(seeds: afcSeeds, conference: .afc, season: season)
        let nfcGames = buildWildCardGames(seeds: nfcSeeds, conference: .nfc, season: season)
        
        let bracket = PlayoffBracket(
            season: season,
            afcGames: afcGames,
            nfcGames: nfcGames,
            superBowl: nil,
            afcSeed1: afcSeeds[1],
            nfcSeed1: nfcSeeds[1]
        )
        
        cache[season] = bracket
        cacheTimestamps[season] = Date()
        currentBracket = bracket
        isLoading = false
    }
    
    /// Determine playoff round from ESPN event data
    private func determinePlayoffRound(from event: ESPNScoreboardResponse.Event, season: Int) -> PlayoffRound? {
        if let week = event.week?.number {
            switch week {
            case 1: return .wildCard
            case 2: return .divisional
            case 3: return .conference
            case 4: return .superBowl
            default: break
            }
            switch week {
            case 19: return .wildCard
            case 20: return .divisional
            case 21: return .conference
            case 22: return .superBowl
            default: break
            }
            switch week {
            case 20: return .wildCard
            case 21: return .divisional
            case 22: return .conference
            case 23: return .superBowl
            default: break
            }
            switch week {
            case 21: return .wildCard
            case 22: return .divisional
            case 23: return .conference
            case 24: return .superBowl
            default: break
            }
        }
        
        // Fallback to name parsing – if we can’t confidently tag it, return nil.
        let name = (event.name ?? "").lowercased()
        if name.contains("super bowl")       { return .superBowl }
        if name.contains("championship")     { return .conference }
        if name.contains("divisional")       { return .divisional }
        if name.contains("wild card") || name.contains("wild-card") { return .wildCard }
        
        // Unknown/non-postseason event
        return nil
    }
    
    /// Build Wild Card games from seeds
    private func buildWildCardGames(seeds: [Int: PlayoffTeam], conference: PlayoffGame.Conference, season: Int) -> [PlayoffGame] {
        var games: [PlayoffGame] = []
        
        // Wild Card matchups: #2 vs #7, #3 vs #6, #4 vs #5
        let matchups: [(home: Int, away: Int)] = [(2, 7), (3, 6), (4, 5)]
        
        for (index, matchup) in matchups.enumerated() {
            guard let homeTeam = seeds[matchup.home],
                  let awayTeam = seeds[matchup.away] else {
                continue
            }
            
            // Calculate Wild Card weekend dates (2nd weekend of January)
            let playoffYear = season + 1  // Playoffs are in January of following year
            let gameDate = calculateWildCardDate(for: playoffYear, gameIndex: index)
            
            let game = PlayoffGame(
                id: "\(season)_\(conference.rawValue)_WC_\(matchup.home)v\(matchup.away)",
                round: .wildCard,
                conference: conference,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                gameDate: gameDate,
                status: .scheduled
            )
            
            games.append(game)
        }
        
        return games.sorted { $0.gameDate < $1.gameDate }
    }
    
    /// Calculate Wild Card game date
    private func calculateWildCardDate(for year: Int, gameIndex: Int) -> Date {
        let calendar = Calendar.current
        
        // Find first Saturday of January
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return Date()
        }
        
        var date = jan1
        while calendar.component(.weekday, from: date) != 7 {  // Saturday = 7
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // Wild Card is 2nd Saturday
        let wildCardSaturday = calendar.date(byAdding: .day, value: 7, to: date)!
        
        // Spread games across Sat/Sun/Mon
        let daysToAdd = gameIndex < 2 ? 0 : (gameIndex < 4 ? 1 : 2)
        return calendar.date(byAdding: .day, value: daysToAdd, to: wildCardSaturday)!
    }
    
    /// Normalize team codes (handle Washington WASH/WSH inconsistency)
    private func normalizeTeamCode(_ code: String) -> String {
        // Handle all Washington variations - convert to WAS (our internal code)
        if code == "WASH" || code == "WSH" {
            return "WAS"
        }
        return code
    }
    
    deinit {
        DebugPrint(mode: .nflData, "♻️ NFLPlayoffBracketService deinit - cleaning up")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - ESPN Standings V2 Response Model

private struct ESPNStandingsV2Response: Decodable {
    let children: [Child]?
    
    struct Child: Decodable {
        let standings: Standings?
    }
    
    struct Standings: Decodable {
        let entries: [Entry]?
    }
    
    struct Entry: Decodable {
        let team: Team
        let stats: [Stat]?
    }
    
    struct Team: Decodable {
        let abbreviation: String
    }
    
    struct Stat: Decodable {
        let name: String?
        let type: String?
        let value: Double?
        let displayValue: String?
    }
}

// MARK: - ESPN Scoreboard Response Model

private struct ESPNScoreboardResponse: Decodable {
    let events: [Event]?
    
    struct Event: Decodable {
        let id: String?
        let name: String?
        let date: String?
        let week: Week?
        let competitions: [Competition]?
    }
    
    struct Week: Decodable {
        let number: Int?
    }
    
    struct Competition: Decodable {
        let competitors: [Competitor]?
        let status: Status?
    }
    
    struct Competitor: Decodable {
        let homeAway: String?
        let team: Team
        let score: String?
    }
    
    struct Team: Decodable {
        let abbreviation: String
    }
    
    struct Status: Decodable {
        let type: StatusType?
        let period: Int?
        let displayClock: String?
    }
    
    struct StatusType: Decodable {
        let state: String?
        let completed: Bool?
    }
}

// MARK: - Weekly postseason fetch (weeks 1..4)
    private func fetchWeeklyPlayoffEvents(for playoffYear: Int) async throws -> [ESPNScoreboardResponse.Event] {
        var all: [ESPNScoreboardResponse.Event] = []
        for wk in 1...4 {
            guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/scoreboard?year=\(playoffYear)&seasontype=3&week=\(wk)") else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let resp = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: data)
                let events = resp.events ?? []
                DebugPrint(mode: .nflData, "📥 Week \(wk) postseason events fetched: \(events.count)")
                all.append(contentsOf: events)
            } catch {
                DebugPrint(mode: .nflData, "⚠️ Failed weekly fetch for week \(wk), year \(playoffYear): \(error)")
            }
        }
        return all
    }

// MARK: - Detect whether SB event is generic/missing scores
    private func isGenericSuperBowl(_ game: PlayoffGame) -> Bool {
        let home = game.homeTeam.abbreviation.uppercased()
        let away = game.awayTeam.abbreviation.uppercased()
        let isGenericHome = (home == "AFC" || home == "NFC" || home == "TBD" || home.isEmpty)
        let isGenericAway = (away == "AFC" || away == "NFC" || away == "TBD" || away.isEmpty)
        let missingScores = (game.homeTeam.score == nil && game.awayTeam.score == nil)
        return isGenericHome || isGenericAway || missingScores
    }

// MARK: - Historical SB fallback 2012–2024 (season year)
    private func fallbackSuperBowl(for season: Int) -> PlayoffGame? {
        let results: [Int: (winner: String, loser: String, wScore: Int, lScore: Int)] = [
            2012: ("BAL","SF",34,31),
            2013: ("SEA","DEN",43,8),
            2014: ("NE","SEA",28,24),
            2015: ("DEN","CAR",24,10),
            2016: ("NE","ATL",34,28),
            2017: ("PHI","NE",41,33),
            2018: ("NE","LAR",13,3),
            2019: ("KC","SF",31,20),
            2020: ("TB","KC",31,9),
            2021: ("LAR","CIN",23,20),
            2022: ("KC","PHI",38,35),
            2023: ("KC","SF",25,22),
            2024: ("PHI","KC",40,22)
        ]
        guard let r = results[season] else { return nil }
        
        // Identify conferences to place NFC as home
        let wTeam = NFLTeam.team(for: r.winner)
        let lTeam = NFLTeam.team(for: r.loser)
        guard let wConf = wTeam?.conference, let lConf = lTeam?.conference else { return nil }
        
        let nfcWinner = (wConf == .nfc)
        let nfcAbbr = nfcWinner ? r.winner : r.loser
        let afcAbbr = nfcWinner ? r.loser  : r.winner
        let nfcScore = nfcWinner ? r.wScore : r.lScore
        let afcScore = nfcWinner ? r.lScore : r.wScore
        
        let nfcName = NFLTeam.team(for: nfcAbbr)?.fullName ?? nfcAbbr
        let afcName = NFLTeam.team(for: afcAbbr)?.fullName ?? afcAbbr
        
        let playoffYear = season + 1
        let date = computeSuperBowlDate(for: playoffYear)
        
        let home = PlayoffTeam(abbreviation: nfcAbbr, name: nfcName, seed: nil, score: nfcScore, logoURL: nil)
        let away = PlayoffTeam(abbreviation: afcAbbr, name: afcName, seed: nil, score: afcScore, logoURL: nil)
        
        return PlayoffGame(
            id: "SB_\(season)",
            round: .superBowl,
            conference: .none,
            homeTeam: home,
            awayTeam: away,
            gameDate: date,
            status: .final
        )
    }

// MARK: - Compute SB date (2nd Sunday of February)
    private func computeSuperBowlDate(for playoffYear: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(abbreviation: "UTC") ?? .current
        let feb1 = cal.date(from: DateComponents(year: playoffYear, month: 2, day: 1)) ?? Date()
        // find first Sunday in Feb
        var d = feb1
        while cal.component(.weekday, from: d) != 1 { // Sunday = 1
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        // 2nd Sunday
        return cal.date(byAdding: .day, value: 7, to: d) ?? d
    }