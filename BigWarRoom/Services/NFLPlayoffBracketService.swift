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
    var gameOdds: [String: GameBettingOdds] = [:]  // Keyed by game ID
    
    // MARK: - Private Properties
    
    @ObservationIgnored private var cache: [Int: PlayoffBracket] = [:]
    @ObservationIgnored private var cacheTimestamps: [Int: Date] = [:]
    @ObservationIgnored private let cacheExpiration: TimeInterval = 300  // 5 minutes
    
    // 🔥 NEW: Odds fetch throttling
    @ObservationIgnored private var lastOddsFetchKey: String?
    @ObservationIgnored private var lastOddsFetchAt: Date?
    @ObservationIgnored private let oddsFetchThrottleInterval: TimeInterval = 600  // 10 minutes (same as NFLScheduleViewModel)
    @ObservationIgnored private var manualRefreshObserver: NSObjectProtocol? // 🔥 NEW: Observer for manual refresh
    
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var refreshTimer: Timer?
    
    // Dependencies
    private let weekSelectionManager: WeekSelectionManager
    private let appLifecycleManager: AppLifecycleManager
    private let bettingOddsService: BettingOddsService
    
    // MARK: - Initialization
    
    init(
        weekSelectionManager: WeekSelectionManager,
        appLifecycleManager: AppLifecycleManager,
        bettingOddsService: BettingOddsService
    ) {
        self.weekSelectionManager = weekSelectionManager
        self.appLifecycleManager = appLifecycleManager
        self.bettingOddsService = bettingOddsService
        
        // 🔥 NEW: Listen for manual refresh notifications
        manualRefreshObserver = NotificationCenter.default.addObserver(
            forName: .oddsManualRefreshRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.resetOddsThrottle()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch playoff bracket for a given season using ESPN Standings API
    func fetchPlayoffBracket(for season: Int, forceRefresh: Bool = false) async {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DebugPrint(mode: .bracketTimer, "🏈 [BRACKET FETCH START] Season: \(season), Force: \(forceRefresh), Time: \(timestamp)")
        
        // 🔥 FIX: Prevent duplicate fetches
        if isLoading && !forceRefresh {
            DebugPrint(mode: .bracketTimer, "⏸️ [SKIP] Already loading bracket for season \(season)")
            return
        }
        
        // Check cache first
        if !forceRefresh,
           let cached = cache[season],
           let timestamp = cacheTimestamps[season],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            DebugPrint(mode: .bracketTimer, "✅ [CACHED] Using cached bracket for \(season)")
            currentBracket = cached
            
            // 🏈 NEW: Even with cached bracket, refresh live situations
            if cached.hasLiveGames {
                await refreshLiveSituations(for: cached)
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DebugPrint(mode: .bracketTimer, "🌐 [NETWORK] Starting network fetch for season \(season)")
        
        // 🔥 FIX: Actually await the fetch instead of wrapping in Task
        await fetchBracketData(for: season)
        
        let endTimestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DebugPrint(mode: .bracketTimer, "✅ [BRACKET FETCH COMPLETE] Season: \(season), Time: \(endTimestamp)")
        
        // 🔥 NEW: Log bracket state after fetch
        if let bracket = currentBracket {
            let liveGamesCount = bracket.hasLiveGames ? "HAS LIVE GAMES" : "NO LIVE GAMES"
            DebugPrint(mode: .bracketTimer, "📊 [BRACKET STATE] AFC: \(bracket.afcGames.count), NFC: \(bracket.nfcGames.count), SB: \(bracket.superBowl != nil), \(liveGamesCount)")
        } else {
            DebugPrint(mode: .bracketTimer, "⚠️ [BRACKET STATE] currentBracket is NIL after fetch!")
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
                await self.fetchPlayoffBracket(for: season, forceRefresh: true)  // 🔥 FIX: Add await
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
            
            // Prefer per-week postseason fetch (weeks 1..5). Pass season (not playoffYear) to the fetch function.
            let weeklyEvents = try await fetchWeeklyPlayoffEvents(for: season)
            
            if !weeklyEvents.isEmpty {
                DebugPrint(mode: .nflData, "📅 Using weekly postseason fetch (weeks 1–5) – events: \(weeklyEvents.count)")
                let merged = ESPNScoreboardResponse(events: weeklyEvents)
                await buildBracketFromGames(merged, afcSeeds: afcSeeds, nfcSeeds: nfcSeeds, season: season)
                return
            }
            
            // Fallback to date-range scoreboard (defensive)
            let playoffYear = season + 1
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
                    logoURL: nil,
                    timeoutsRemaining: nil
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
        
        // 🔥 DEBUG: Log all events ESPN returned
        DebugPrint(mode: .nflData, "🔍 ESPN returned \(scoreboardResponse.events?.count ?? 0) total events for season \(season)")
        
        for event in scoreboardResponse.events ?? [] {
            // 🔥 DEBUG: Log each event before processing
            DebugPrint(mode: .nflData, "🔍 Processing event: id=\(event.id ?? "?"), name='\(event.name ?? "")', week=\(event.week?.number ?? -1)")
            
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
            
            // 🏈 NEW: Get timeouts remaining
            let homeTimeouts = homeComp?.timeouts
            let awayTimeouts = awayComp?.timeouts
            
            // 🔥 DEBUG: Log team info and scores
            DebugPrint(mode: .nflData, "🔍   Teams: \(awayTeam) @ \(homeTeam), Score: \(awayScore ?? 0)-\(homeScore ?? 0)")
            DebugPrint(mode: .nflData, "⏱️   Timeouts: Home \(homeTimeouts ?? -1), Away \(awayTimeouts ?? -1)")
            
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
            
            // Create playoff teams with scores and timeouts
            let homePlayoffTeam = PlayoffTeam(
                abbreviation: homeTeam,
                name: homeNFLTeam?.fullName ?? homeTeam,
                seed: homeSeed,
                score: homeScore,
                logoURL: nil,
                timeoutsRemaining: homeTimeouts
            )
            
            let awayPlayoffTeam = PlayoffTeam(
                abbreviation: awayTeam,
                name: awayNFLTeam?.fullName ?? awayTeam,
                seed: awaySeed,
                score: awayScore,
                logoURL: nil,
                timeoutsRemaining: awayTimeouts
            )

            // Parse game date
            let gameDate: Date = {
                if let dateString = event.date {
                    DebugPrint(mode: .nflData, "📅 RAW ESPN date string: '\(dateString)' for game \(awayTeam) @ \(homeTeam)")
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: dateString) {
                        DebugPrint(mode: .nflData, "✅ Parsed date WITH fractional: \(date)")
                        return date
                    }
                    
                    // Try without fractional seconds
                    formatter.formatOptions = [.withInternetDateTime]
                    if let date = formatter.date(from: dateString) {
                        DebugPrint(mode: .nflData, "✅ Parsed date WITHOUT fractional: \(date)")
                        return date
                    }
                    
                    // Try with Z timezone
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
                    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                    if let date = dateFormatter.date(from: dateString) {
                        DebugPrint(mode: .nflData, "✅ Parsed date with Z format: \(date)")
                        return date
                    }
                    
                    DebugPrint(mode: .nflData, "❌ ALL DATE PARSING FAILED for '\(dateString)'")
                }
                DebugPrint(mode: .nflData, "⚠️ No date string provided - using current date")
                return Date()
            }()
            
            // Parse venue
            let venueData = event.venue ?? competition.venue
            let venue: PlayoffGame.Venue? = {
                guard let v = venueData else { return nil }
                return PlayoffGame.Venue(
                    fullName: v.fullName,
                    city: v.address?.city,
                    state: v.address?.state
                )
            }()
            
            // Parse broadcasts
            let broadcastData = event.broadcasts ?? competition.broadcasts
            let broadcasts: [String]? = {
                guard let bcasts = broadcastData else { return nil }
                var networks: [String] = []
                for broadcast in bcasts {
                    if let market = broadcast.market {
                        networks.append(market)
                    }
                    if let names = broadcast.names {
                        networks.append(contentsOf: names)
                    }
                }
                return networks.isEmpty ? nil : Array(Set(networks))  // Remove duplicates
            }()
            
            // Determine game status
            let status: PlayoffGame.GameStatus
            if competition.status?.type?.completed == true {
                status = .final
            } else if competition.status?.type?.state == "in" {
                let quarter = "Q\(competition.status?.period ?? 1)"
                let time = competition.status?.displayClock ?? ""
                status = .inProgress(quarter: quarter, timeRemaining: time)
                DebugPrint(mode: .nflData, "🔍 [LIVE GAME DETECTED] \(awayTeam) @ \(homeTeam) is live: \(quarter) \(time)")
            } else {
                status = .scheduled
            }
            
            // Determine conference
            let conference: PlayoffGame.Conference
            if round == .superBowl {
                conference = .none
            } else if homeNFLTeam?.conference == .afc && awayNFLTeam?.conference == .afc {
                conference = .afc
            } else if homeNFLTeam?.conference == .nfc && awayNFLTeam?.conference == .nfc {
                conference = .nfc
            } else {
                // Mixed conference or missing team data - shouldn't happen in playoffs except Super Bowl
                DebugPrint(mode: .nflData, "⚠️ Mixed conference game detected: \(awayTeam) @ \(homeTeam) in round \(round.rawValue)")
                DebugPrint(mode: .nflData, "   Home: \(homeTeam) = \(homeNFLTeam?.conference.rawValue ?? "UNKNOWN")")
                DebugPrint(mode: .nflData, "   Away: \(awayTeam) = \(awayNFLTeam?.conference.rawValue ?? "UNKNOWN")")
                
                // Default to the home team's conference if available, otherwise away team's conference
                if let homeConf = homeNFLTeam?.conference {
                    conference = homeConf == .afc ? .afc : .nfc
                } else if let awayConf = awayNFLTeam?.conference {
                    conference = awayConf == .afc ? .afc : .nfc
                } else {
                    conference = .none
                }
            }
            
            var liveSituation: LiveGameSituation? = nil
            var lastKnownDownDistance: CachedDownDistance? = nil
            
            if case .inProgress = status, let gameID = event.id {
                DebugPrint(mode: .bracketTimer, "🔍 [FETCHING LIVE SITUATION] For game \(gameID): \(awayTeam) @ \(homeTeam)")
                liveSituation = await fetchLiveGameSituation(gameID: gameID)
                
                if let situation = liveSituation,
                   let down = situation.down,
                   let distance = situation.distance,
                   down > 0, distance > 0 {
                    lastKnownDownDistance = CachedDownDistance(down: down, distance: distance)
                } else {
                    if let existing = (afcGames + nfcGames).first(where: { $0.id == gameID }),
                       let cached = existing.lastKnownDownDistance {
                        lastKnownDownDistance = cached
                        DebugPrint(mode: .bracketTimer, "🔄 [CACHED DOWN/DIST] Using cached: \(cached.display)")
                    }
                }
                
                if liveSituation != nil {
                    DebugPrint(mode: .bracketTimer, "✅ [LIVE SITUATION] Successfully fetched for game \(gameID)")
                } else {
                    DebugPrint(mode: .bracketTimer, "⚠️ [LIVE SITUATION] Failed to fetch for game \(gameID)")
                }
            }
            
            let finalHomeTimeouts = liveSituation?.homeTimeouts ?? homeTimeouts
            let finalAwayTimeouts = liveSituation?.awayTimeouts ?? awayTimeouts
            
            let homePlayoffTeamWithTimeouts = PlayoffTeam(
                abbreviation: homePlayoffTeam.abbreviation,
                name: homePlayoffTeam.name,
                seed: homePlayoffTeam.seed,
                score: homePlayoffTeam.score,
                logoURL: homePlayoffTeam.logoURL,
                timeoutsRemaining: finalHomeTimeouts
            )
            
            let awayPlayoffTeamWithTimeouts = PlayoffTeam(
                abbreviation: awayPlayoffTeam.abbreviation,
                name: awayPlayoffTeam.name,
                seed: awayPlayoffTeam.seed,
                score: awayPlayoffTeam.score,
                logoURL: awayPlayoffTeam.logoURL,
                timeoutsRemaining: finalAwayTimeouts
            )
            
            DebugPrint(mode: .bracketTimer, "⏱️ [TIMEOUT FINAL] \(awayTeam)@\(homeTeam): Home=\(finalHomeTimeouts?.description ?? "nil"), Away=\(finalAwayTimeouts?.description ?? "nil")")
            
            let game = PlayoffGame(
                id: event.id ?? UUID().uuidString,
                round: round,
                conference: conference,
                homeTeam: homePlayoffTeamWithTimeouts,
                awayTeam: awayPlayoffTeamWithTimeouts,
                gameDate: gameDate,
                status: status,
                venue: venue,
                broadcasts: broadcasts,
                liveSituation: liveSituation,
                lastKnownDownDistance: lastKnownDownDistance
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
        
        DebugPrint(mode: .appLoad, "✅ [BRACKET SET] currentBracket updated - AFC:\(afcGames.count), NFC:\(nfcGames.count), SB:\(superBowl != nil)")
        
        // Fetch odds for playoff games
        await fetchPlayoffGameOdds(bracket: bracket, season: season)
        
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
        // 🔥 DEBUG: Log what we're checking
        let weekNum = event.week?.number ?? -1
        let eventName = event.name ?? ""
        DebugPrint(mode: .nflData, "🔍 determinePlayoffRound: week=\(weekNum), name='\(eventName)'")
        
        // 🔥 SKIP PRO BOWL - it's tagged as postseason but isn't part of the bracket
        let nameLower = eventName.lowercased()
        if nameLower.contains("all-star") || nameLower.contains("pro bowl") {
            DebugPrint(mode: .nflData, "⏭️ Skipping Pro Bowl game: '\(eventName)'")
            return nil
        }
        
        if let week = event.week?.number {
            // Postseason weeks from weekly fetch (weeks 1..5 with seasontype=3)
            // Note: ESPN includes Pro Bowl as week 4, actual Super Bowl is week 5
            switch week {
            case 1: 
                DebugPrint(mode: .nflData, "✅ Week 1 -> wildCard")
                return .wildCard
            case 2: 
                DebugPrint(mode: .nflData, "✅ Week 2 -> divisional")
                return .divisional
            case 3: 
                DebugPrint(mode: .nflData, "✅ Week 3 -> conference")
                return .conference
            case 4, 5:  // Super Bowl can be week 4 or 5 depending on Pro Bowl
                DebugPrint(mode: .nflData, "✅ Week \(week) -> checking if superBowl")
                // Double-check it's actually the Super Bowl by name
                if nameLower.contains("super bowl") || 
                   (!nameLower.contains("all-star") && !nameLower.contains("pro bowl")) {
                    DebugPrint(mode: .nflData, "✅ Confirmed superBowl")
                    return .superBowl
                }
                DebugPrint(mode: .nflData, "⚠️ Week \(week) but not Super Bowl name")
                break
            default: 
                DebugPrint(mode: .nflData, "⚠️ Week \(week) doesn't match postseason weeks 1-5")
                break
            }
            
            // Legacy: absolute week numbers (shouldn't hit these with seasontype=3)
            switch week {
            case 19: return .wildCard
            case 20: return .wildCard
            case 21: return .conference
            case 22: return .superBowl
            default: break
            }
            switch week {
            case 20: return .divisional
            case 21: return .conference
            case 22: return .superBowl
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
        
        // Fallback to name parsing
        let name = (event.name ?? "").lowercased()
        if name.contains("super bowl")       { 
            DebugPrint(mode: .nflData, "✅ Name contains 'super bowl' -> superBowl")
            return .superBowl 
        }
        if name.contains("championship")     { 
            DebugPrint(mode: .nflData, "✅ Name contains 'championship' -> conference")
            return .conference 
        }
        if name.contains("divisional")       { 
            DebugPrint(mode: .nflData, "✅ Name contains 'divisional' -> divisional")
            return .divisional 
        }
        if name.contains("wild card") || name.contains("wild-card") { 
            DebugPrint(mode: .nflData, "✅ Name contains 'wild card' -> wildCard")
            return .wildCard 
        }
        
        // Unknown/non-postseason event
        DebugPrint(mode: .nflData, "❌ Could not determine round - returning nil")
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
                status: .scheduled,
                venue: nil,
                broadcasts: nil,
                liveSituation: nil,
                lastKnownDownDistance: nil
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
    
    /// Fetch live play-by-play situation for an in-progress game
    private func fetchLiveGameSituation(gameID: String) async -> LiveGameSituation? {
        let summaryURL = "https://site.web.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=\(gameID)"

        DebugPrint(mode: .fieldPosition, "🏈 [FIELD POS API] Starting fetch for game \(gameID)")

        guard let url = URL(string: summaryURL) else {
            DebugPrint(mode: [.bracketTimer, .fieldPosition], "❌ Failed to build summary URL for game \(gameID)")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            DebugPrint(mode: .fieldPosition, "✅ [FIELD POS API] Successfully fetched JSON for game \(gameID)")

            // 🏈 NEW: Calculate timeouts by counting timeout plays
            var homeTimeouts: Int = 3  // Start with 3 timeouts per team
            var awayTimeouts: Int = 3

            // Get team IDs first
            var homeTeamID: String? = nil
            var awayTeamID: String? = nil
            
            // 🏈 NEW: Get current period to handle timeout refreshes
            var currentPeriod: Int = 1

            if let header = json?["header"] as? [String: Any],
               let competitions = header["competitions"] as? [[String: Any]],
               let competition = competitions.first,
               let competitors = competition["competitors"] as? [[String: Any]] {

                for competitor in competitors {
                    if let homeAway = competitor["homeAway"] as? String,
                       let teamInfo = competitor["team"] as? [String: Any],
                       let teamID = teamInfo["id"] as? String {
                        if homeAway == "home" {
                            homeTeamID = teamID
                        } else {
                            awayTeamID = teamID
                        }
                    }
                }
                
                // 🏈 NEW: Extract current period from status
                if let status = competition["status"] as? [String: Any],
                   let period = status["period"] as? Int {
                    currentPeriod = period
                    DebugPrint(mode: .nflData, "🏈 [TIMEOUT PERIOD] Current period: \(currentPeriod)")
                }
            }
            
            // 🏈 NEW: Determine starting timeouts and which periods to count based on current period
            homeTimeouts = 3
            awayTimeouts = 3
            
            DebugPrint(mode: .nflData, "🏈 [TIMEOUT RULES] Period \(currentPeriod): Starting with \(3) TOs, counting from period \(1)+")

            // Count timeout plays from drives
            if let drives = json?["drives"] as? [String: Any],
               let previous = drives["previous"] as? [[String: Any]] {
                
                DebugPrint(mode: .nflData, "🔍 [TIMEOUT DEBUG] Found \(previous.count) previous drives to check")
                
                for (driveIndex, drive) in previous.enumerated() {
                    if let plays = drive["plays"] as? [[String: Any]] {
                        
                        for (playIndex, play) in plays.enumerated() {
                            // Check if this is a timeout play (type 21)
                            if let playType = play["type"] as? [String: Any],
                               let typeID = playType["id"] as? String {
                                
                                if typeID == "21" {
                                    // 🏈 NEW: Get the period this timeout occurred in
                                    if let period = play["period"] as? [String: Any],
                                       let periodNumber = period["number"] as? Int {
                                        
                                        // 🏈 NEW: Only count timeouts from relevant periods
                                        if periodNumber >= 1 {
                                            DebugPrint(mode: .nflData, "🎯 [TIMEOUT FOUND] Drive \(driveIndex) Play \(playIndex) in period \(periodNumber) (counting it)")
                                            
                                            if let teamParticipants = play["teamParticipants"] as? [[String: Any]] {
                                                for participant in teamParticipants {
                                                    if let isTimeout = participant["timeout"] as? Bool,
                                                       isTimeout {
                                                        
                                                        // Try to extract team ID from the nested structure
                                                        var teamID: String? = nil
                                                        
                                                        // Parse team ID from $ref URL
                                                        if let teamRef = participant["team"] as? [String: Any],
                                                           let ref = teamRef["$ref"] as? String {
                                                            if let url = URL(string: ref) {
                                                                let pathComponents = url.pathComponents
                                                                if let teamsIndex = pathComponents.firstIndex(of: "teams"),
                                                                   teamsIndex + 1 < pathComponents.count {
                                                                    teamID = pathComponents[teamsIndex + 1]
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Fallback: try direct ID field
                                                        if teamID == nil {
                                                            teamID = participant["id"] as? String
                                                        }
                                                        
                                                        if let tid = teamID {
                                                            if tid == homeTeamID {
                                                                homeTimeouts -= 1
                                                                DebugPrint(mode: .nflData, "⏱️ [TIMEOUT DETECTED] Period \(periodNumber): Home team timeout used, remaining: \(homeTimeouts)")
                                                            } else if tid == awayTeamID {
                                                                awayTimeouts -= 1
                                                                DebugPrint(mode: .nflData, "⏱️ [TIMEOUT DETECTED] Period \(periodNumber): Away team timeout used, remaining: \(awayTimeouts)")
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            DebugPrint(mode: .nflData, "⏭️ [TIMEOUT SKIPPED] Drive \(driveIndex) Play \(playIndex) in period \(periodNumber) (before period \(1) - ignoring due to refresh)")
                                        }
                                    } else {
                                        DebugPrint(mode: .nflData, "⚠️ [TIMEOUT] No period info for drive \(driveIndex) play \(playIndex) - assuming current period")
                                        // If no period info, count it (defensive fallback)
                                        if let teamParticipants = play["teamParticipants"] as? [[String: Any]] {
                                            for participant in teamParticipants {
                                                if let isTimeout = participant["timeout"] as? Bool,
                                                   isTimeout {
                                                    var teamID: String? = nil
                                                    
                                                    if let teamRef = participant["team"] as? [String: Any],
                                                       let ref = teamRef["$ref"] as? String {
                                                        if let url = URL(string: ref) {
                                                            let pathComponents = url.pathComponents
                                                            if let teamsIndex = pathComponents.firstIndex(of: "teams"),
                                                               teamsIndex + 1 < pathComponents.count {
                                                                teamID = pathComponents[teamsIndex + 1]
                                                            }
                                                        }
                                                    }
                                                    
                                                    if teamID == nil {
                                                        teamID = participant["id"] as? String
                                                    }
                                                    
                                                    if let tid = teamID {
                                                        if tid == homeTeamID {
                                                            homeTimeouts -= 1
                                                            DebugPrint(mode: .nflData, "⏱️ [TIMEOUT DETECTED] (no period): Home team timeout used, remaining: \(homeTimeouts)")
                                                        } else if tid == awayTeamID {
                                                            awayTimeouts -= 1
                                                            DebugPrint(mode: .nflData, "⏱️ [TIMEOUT DETECTED] (no period): Away team timeout used, remaining: \(awayTimeouts)")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Ensure timeouts don't go below 0
            homeTimeouts = max(0, homeTimeouts)
            awayTimeouts = max(0, awayTimeouts)

            DebugPrint(mode: .bracketTimer, "⏱️ [LIVE SITUATION] Game \(gameID) - Home TOs: \(homeTimeouts), Away TOs: \(awayTimeouts)")

            var down: Int? = nil
            var distance: Int? = nil
            var yardLine: String? = nil

            if let drives = json?["drives"] as? [String: Any],
               let currentDrive = drives["current"] as? [String: Any] {
                
                DebugPrint(mode: .fieldPosition, "🔍 [FIELD POS API] Found drives.current")
                DebugPrint(mode: .fieldPosition, "   drives.current keys: \(Array(currentDrive.keys).sorted().joined(separator: ", "))")
                
                // Try to get field position from drives.current directly
                if let yardLineValue = currentDrive["yardLine"] as? Int {
                    yardLine = "\(yardLineValue)"
                    DebugPrint(mode: .fieldPosition, "   ✅ Found yardLine in drives.current: \(yardLineValue)")
                }
                
                if let possText = currentDrive["possessionText"] as? String {
                    yardLine = possText
                    DebugPrint(mode: .fieldPosition, "   ✅ Found possessionText in drives.current: '\(possText)'")
                }
                
                // Try to get from start situation
                if yardLine == nil, let startSituation = currentDrive["start"] as? [String: Any] {
                    DebugPrint(mode: .fieldPosition, "   🔍 Checking drives.current.start")
                    DebugPrint(mode: .fieldPosition, "      start keys: \(Array(startSituation.keys).sorted().joined(separator: ", "))")
                    
                    if let possText = startSituation["possessionText"] as? String {
                        yardLine = possText
                        DebugPrint(mode: .fieldPosition, "      ✅ Found possessionText in start: '\(possText)'")
                    } else if let yl = startSituation["yardLine"] as? Int {
                        // 🔥 FIX: ESPN gives us just a number - we need to construct the full field position
                        // Get possession team to build proper format like "HOU 47"
                        if let team = currentDrive["team"] as? [String: Any],
                           let abbr = team["abbreviation"] as? String {
                            let teamCode = normalizeTeamCode(abbr.uppercased())
                            
                            // Handle 50 yard line specially
                            if yl == 50 {
                                yardLine = "50"
                                DebugPrint(mode: .fieldPosition, "      ✅ 50 yard line")
                            } else if yl > 50 {
                                // Ball is past midfield (on opponent's side)
                                // Convert: 65 → 35 yard line (100-65=35)
                                let normalizedYards = 100 - yl
                                yardLine = "\(normalizedYards)"
                                DebugPrint(mode: .fieldPosition, "      ✅ Converted absolute \(yl) to \(normalizedYards) yard line (opponent territory)")
                            } else {
                                // Ball is on possession team's own side (0-49)
                                yardLine = "\(teamCode) \(yl)"
                                DebugPrint(mode: .fieldPosition, "      ✅ Constructed field position: '\(yardLine!)'")
                            }
                        } else {
                            // Fallback: normalize the number if > 50
                            let normalizedYL = yl > 50 ? (100 - yl) : yl
                            yardLine = "\(normalizedYL)"
                            DebugPrint(mode: .fieldPosition, "      ⚠️ No team found - using normalized number: \(normalizedYL)")
                        }
                    }
                }
                
                // 🔥 NEW: Try to get down/distance from drives.current.end (when drive is complete/scored)
                if let endSituation = currentDrive["end"] as? [String: Any] {
                    DebugPrint(mode: .fieldPosition, "   🔍 Checking drives.current.end")
                    DebugPrint(mode: .fieldPosition, "      end keys: \(Array(endSituation.keys).sorted().joined(separator: ", "))")
                    
                    down = endSituation["down"] as? Int
                    distance = endSituation["distance"] as? Int
                    
                    DebugPrint(mode: .fieldPosition, "      ✅ Extracted from end: down=\(down?.description ?? "nil"), distance=\(distance?.description ?? "nil")")
                }
                
                // 🔥 NEW: Try to get down/distance from last play in current drive
                if let plays = currentDrive["plays"] as? [[String: Any]], !plays.isEmpty {
                    DebugPrint(mode: .fieldPosition, "   🔍 Checking drives.current.plays (total: \(plays.count))")
                    
                    if let lastPlay = plays.last {
                        DebugPrint(mode: .fieldPosition, "      lastPlay keys: \(Array(lastPlay.keys).sorted().joined(separator: ", "))")
                        
                        if let playEndSituation = lastPlay["end"] as? [String: Any] {
                            DebugPrint(mode: .fieldPosition, "      Found lastPlay.end")
                            DebugPrint(mode: .fieldPosition, "      end keys: \(Array(playEndSituation.keys).sorted().joined(separator: ", "))")
                            
                            // 🔍 DEBUG: Let's see ALL the data in playEndSituation
                            for (key, value) in playEndSituation {
                                DebugPrint(mode: .fieldPosition, "         🔍 end[\(key)] = \(value)")
                            }
                            
                            // 🏈 CRITICAL: Extract CURRENT field position from last play's end
                            // First check if possessionText has the formatted position
                            if let possText = playEndSituation["possessionText"] as? String {
                                yardLine = possText
                                DebugPrint(mode: .fieldPosition, "      ✅ [CURRENT POS from possessionText] '\(possText)'")
                            } else if let endYardLine = playEndSituation["yardLine"] as? Int {
                                
                                DebugPrint(mode: .fieldPosition, "      🎯 [LAST PLAY END YARDLINE] Raw value: \(endYardLine)")
                                
                                if let team = currentDrive["team"] as? [String: Any],
                                   let abbr = team["abbreviation"] as? String {
                                    let teamCode = normalizeTeamCode(abbr.uppercased())
                                    
                                    if endYardLine == 50 {
                                        yardLine = "50"
                                        DebugPrint(mode: .fieldPosition, "      ✅ 50 yard line")
                                    } else if endYardLine > 50 {
                                        let normalizedYards = 100 - endYardLine
                                        yardLine = "\(normalizedYards)"
                                        DebugPrint(mode: .fieldPosition, "      ✅ Converted \(endYardLine) → \(normalizedYards) yard line (opponent territory)")
                                    } else {
                                        yardLine = "\(teamCode) \(endYardLine)"
                                        DebugPrint(mode: .fieldPosition, "      ✅ Constructed field position: '\(yardLine!)'")
                                    }
                                } else {
                                    let normalizedYL = endYardLine > 50 ? (100 - endYardLine) : endYardLine
                                    yardLine = "\(normalizedYL)"
                                    DebugPrint(mode: .fieldPosition, "      ✅ Normalized: \(normalizedYL)")
                                }
                            } else {
                                DebugPrint(mode: .fieldPosition, "      ⚠️ No yardLine in lastPlay.end")
                            }
                            
                            // Extract down/distance if we don't have them yet
                            if down == nil {
                                down = playEndSituation["down"] as? Int
                                DebugPrint(mode: .fieldPosition, "         Extracted down = \(down?.description ?? "nil")")
                            }
                            if distance == nil {
                                distance = playEndSituation["distance"] as? Int
                                DebugPrint(mode: .fieldPosition, "         Extracted distance = \(distance?.description ?? "nil")")
                            }
                        } else {
                            DebugPrint(mode: .fieldPosition, "      ❌ No 'end' in last play")
                        }
                    }
                } else {
                    DebugPrint(mode: .fieldPosition, "   ❌ No plays array or empty")
                }

                DebugPrint(mode: .fieldPosition, "   📊 [FINAL EXTRACTION] down=\(down?.description ?? "nil"), distance=\(distance?.description ?? "nil"), yardLine='\(yardLine ?? "nil")'")
                
            } else {
                DebugPrint(mode: .fieldPosition, "❌ [FIELD POS API] Could not find drives.current in JSON")
                
                if let drives = json?["drives"] as? [String: Any] {
                    DebugPrint(mode: .fieldPosition, "   drives keys: \(Array(drives.keys).joined(separator: ", "))")
                } else {
                    DebugPrint(mode: .fieldPosition, "   NO drives object in JSON")
                }
            }

            var possessionTeam: String? = nil
            var drivePlayCount: Int? = nil
            var driveYards: Int? = nil
            var topDisplay: String? = nil
            var lastPlay: String? = nil

            if let drives = json?["drives"] as? [String: Any],
               let currentDrive = drives["current"] as? [String: Any] {

                if let team = currentDrive["team"] as? [String: Any],
                   let abbr = team["abbreviation"] as? String {
                    possessionTeam = normalizeTeamCode(abbr.uppercased())
                }

                drivePlayCount = currentDrive["offensivePlays"] as? Int
                driveYards = currentDrive["yards"] as? Int

                if let timeElapsed = currentDrive["timeElapsed"] as? [String: Any] {
                    topDisplay = timeElapsed["displayValue"] as? String
                }

                if let plays = currentDrive["plays"] as? [[String: Any]],
                   let lastPlayObj = plays.last,
                   let text = lastPlayObj["text"] as? String {
                    lastPlay = text
                }
            }

            DebugPrint(mode: [.bracketTimer, .fieldPosition], "🏈 [LIVE] Game \(gameID): \(possessionTeam ?? "?") has ball, \(down ?? 0) & \(distance ?? 0) at \(yardLine ?? "?")")

            let finalSituation = LiveGameSituation(
                down: down,
                distance: distance,
                yardLine: yardLine,
                possession: possessionTeam,
                lastPlay: lastPlay,
                drivePlayCount: drivePlayCount,
                driveYards: driveYards,
                timeOfPossession: topDisplay,
                homeTimeouts: homeTimeouts,
                awayTimeouts: awayTimeouts
            )
            
            DebugPrint(mode: .fieldPosition, "📦 [FIELD POS API] Returning LiveGameSituation with yardLine='\(finalSituation.yardLine ?? "NIL")'")
            
            return finalSituation

        } catch {
            DebugPrint(mode: [.bracketTimer, .fieldPosition], "❌ Failed to fetch live situation for game \(gameID): \(error)")
            return nil
        }
    }

    private func refreshLiveSituations(for bracket: PlayoffBracket) async {
        DebugPrint(mode: .bracketTimer, "🔄 [REFRESH LIVE SITUATIONS] Updating play-by-play data")

        var updatedAFCGames: [PlayoffGame] = []
        var updatedNFCGames: [PlayoffGame] = []
        var updatedSuperBowl: PlayoffGame? = bracket.superBowl

        for game in bracket.afcGames {
            if game.isLive {
                let situation = await fetchLiveGameSituation(gameID: game.id)

                var downDist = game.lastKnownDownDistance
                if let sit = situation,
                   let down = sit.down,
                   let distance = sit.distance,
                   down > 0, distance > 0 {
                    downDist = CachedDownDistance(down: down, distance: distance)
                    DebugPrint(mode: .bracketTimer, "🆕 [NEW DOWN/DIST] \(game.id): \(downDist!.display)")
                } else {
                    if let cached = game.lastKnownDownDistance {
                        downDist = cached
                        DebugPrint(mode: .bracketTimer, "🔄 [CACHED DOWN/DIST] Using cached: \(cached.display)")
                    }
                }

                let updatedHomeTeam = PlayoffTeam(
                    abbreviation: game.homeTeam.abbreviation,
                    name: game.homeTeam.name,
                    seed: game.homeTeam.seed,
                    score: game.homeTeam.score,
                    logoURL: game.homeTeam.logoURL,
                    timeoutsRemaining: situation?.homeTimeouts ?? game.homeTeam.timeoutsRemaining
                )

                let updatedAwayTeam = PlayoffTeam(
                    abbreviation: game.awayTeam.abbreviation,
                    name: game.awayTeam.name,
                    seed: game.awayTeam.seed,
                    score: game.awayTeam.score,
                    logoURL: game.awayTeam.logoURL,
                    timeoutsRemaining: situation?.awayTimeouts ?? game.awayTeam.timeoutsRemaining
                )

                let updated = PlayoffGame(
                    id: game.id,
                    round: game.round,
                    conference: game.conference,
                    homeTeam: updatedHomeTeam,
                    awayTeam: updatedAwayTeam,
                    gameDate: game.gameDate,
                    status: game.status,
                    venue: game.venue,
                    broadcasts: game.broadcasts,
                    liveSituation: situation,
                    lastKnownDownDistance: downDist
                )
                updatedAFCGames.append(updated)
            } else {
                updatedAFCGames.append(game)
            }
        }

        for game in bracket.nfcGames {
            if game.isLive {
                let situation = await fetchLiveGameSituation(gameID: game.id)

                var downDist = game.lastKnownDownDistance
                if let sit = situation,
                   let down = sit.down,
                   let distance = sit.distance,
                   down > 0, distance > 0 {
                    downDist = CachedDownDistance(down: down, distance: distance)
                    DebugPrint(mode: .bracketTimer, "🆕 [NEW DOWN/DIST] \(game.id): \(downDist!.display)")
                } else {
                    if let cached = game.lastKnownDownDistance {
                        downDist = cached
                        DebugPrint(mode: .bracketTimer, "🔄 [CACHED DOWN/DIST] Using cached: \(cached.display)")
                    }
                }

                let updatedHomeTeam = PlayoffTeam(
                    abbreviation: game.homeTeam.abbreviation,
                    name: game.homeTeam.name,
                    seed: game.homeTeam.seed,
                    score: game.homeTeam.score,
                    logoURL: game.homeTeam.logoURL,
                    timeoutsRemaining: situation?.homeTimeouts ?? game.homeTeam.timeoutsRemaining
                )

                let updatedAwayTeam = PlayoffTeam(
                    abbreviation: game.awayTeam.abbreviation,
                    name: game.awayTeam.name,
                    seed: game.awayTeam.seed,
                    score: game.awayTeam.score,
                    logoURL: game.awayTeam.logoURL,
                    timeoutsRemaining: situation?.awayTimeouts ?? game.awayTeam.timeoutsRemaining
                )

                let updated = PlayoffGame(
                    id: game.id,
                    round: game.round,
                    conference: game.conference,
                    homeTeam: updatedHomeTeam,
                    awayTeam: updatedAwayTeam,
                    gameDate: game.gameDate,
                    status: game.status,
                    venue: game.venue,
                    broadcasts: game.broadcasts,
                    liveSituation: situation,
                    lastKnownDownDistance: downDist
                )
                updatedNFCGames.append(updated)
            } else {
                updatedNFCGames.append(game)
            }
        }

        if let sb = bracket.superBowl, sb.isLive {
            let situation = await fetchLiveGameSituation(gameID: sb.id)

            var downDist = sb.lastKnownDownDistance
            if let sit = situation,
               let down = sit.down,
               let distance = sit.distance,
               down > 0, distance > 0 {
                downDist = CachedDownDistance(down: down, distance: distance)
                DebugPrint(mode: .bracketTimer, "🆕 [NEW DOWN/DIST] \(sb.id): \(downDist!.display)")
            } else {
                if let cached = sb.lastKnownDownDistance {
                    downDist = cached
                    DebugPrint(mode: .bracketTimer, "🔄 [CACHED DOWN/DIST] Using cached: \(cached.display)")
                }
            }

            let updatedHomeTeam = PlayoffTeam(
                abbreviation: sb.homeTeam.abbreviation,
                name: sb.homeTeam.name,
                seed: sb.homeTeam.seed,
                score: sb.homeTeam.score,
                logoURL: sb.homeTeam.logoURL,
                timeoutsRemaining: situation?.homeTimeouts ?? sb.homeTeam.timeoutsRemaining
            )

            let updatedAwayTeam = PlayoffTeam(
                abbreviation: sb.awayTeam.abbreviation,
                name: sb.awayTeam.name,
                seed: sb.awayTeam.seed,
                score: sb.awayTeam.score,
                logoURL: sb.awayTeam.logoURL,
                timeoutsRemaining: situation?.awayTimeouts ?? sb.awayTeam.timeoutsRemaining
            )

            updatedSuperBowl = PlayoffGame(
                id: sb.id,
                round: sb.round,
                conference: sb.conference,
                homeTeam: updatedHomeTeam,
                awayTeam: updatedAwayTeam,
                gameDate: sb.gameDate,
                status: sb.status,
                venue: sb.venue,
                broadcasts: sb.broadcasts,
                liveSituation: situation,
                lastKnownDownDistance: downDist
            )
        }

        let updatedBracket = PlayoffBracket(
            season: bracket.season,
            afcGames: updatedAFCGames,
            nfcGames: updatedNFCGames,
            superBowl: updatedSuperBowl,
            afcSeed1: bracket.afcSeed1,
            nfcSeed1: bracket.nfcSeed1
        )

        cache[bracket.season] = updatedBracket
        currentBracket = updatedBracket

        DebugPrint(mode: .bracketTimer, "✅ [REFRESH LIVE SITUATIONS] Updated play-by-play data")
    }
    
    // MARK: - Fetch Playoff Game Odds
    
    private func fetchPlayoffGameOdds(bracket: PlayoffBracket, season: Int) async {
        // 🔥 NEW: Local throttle to prevent excessive API calls
        let playoffYear = season + 1
        let oddsKey = "playoff_\(season)_\(playoffYear)"
        
        // Check if we should skip this fetch due to throttling
        if lastOddsFetchKey == oddsKey,
           let lastAt = lastOddsFetchAt,
           Date().timeIntervalSince(lastAt) < oddsFetchThrottleInterval {
            let secondsSinceLastFetch = Int(Date().timeIntervalSince(lastAt))
            let secondsUntilNextFetch = Int(oddsFetchThrottleInterval - Date().timeIntervalSince(lastAt))
            DebugPrint(mode: .bettingOdds, "⏱️ [PLAYOFF ODDS THROTTLED] Last fetch was \(secondsSinceLastFetch)s ago, next fetch in \(secondsUntilNextFetch)s")
            return
        }
        
        // Convert playoff games to schedule game format for odds API
        let allGames = bracket.afcGames + bracket.nfcGames + (bracket.superBowl != nil ? [bracket.superBowl!] : [])
        
        DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS] Fetching odds for \(allGames.count) playoff games (season \(season))")
        
        var scheduleGames: [ScheduleGame] = []
        for game in allGames {
            let gameID = "\(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation)"
            DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS] Creating ScheduleGame with ID: '\(gameID)' - \(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
            DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS]   Round: \(game.round.rawValue), Date: \(game.gameDate)")
            
            let scheduleGame = ScheduleGame(
                id: gameID,
                awayTeam: game.awayTeam.abbreviation,
                homeTeam: game.homeTeam.abbreviation,
                awayScore: game.awayTeam.score ?? 0,
                homeScore: game.homeTeam.score ?? 0,
                gameStatus: game.status.isCompleted ? "final" : "pre",
                gameTime: "",
                startDate: game.gameDate,
                isLive: game.isLive
            )
            scheduleGames.append(scheduleGame)
        }
        
        // Fetch odds (playoffs are in following year)
        let week = 19 // Use week 19 as proxy for playoffs
        
        DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS] Calling bettingOddsService.fetchGameOdds for week \(week), year \(playoffYear)")
        let odds = await bettingOddsService.fetchGameOdds(for: scheduleGames, week: week, year: playoffYear)
        
        // Store odds keyed by game ID
        gameOdds = odds
        
        // 🔥 NEW: Update throttle tracking
        lastOddsFetchKey = oddsKey
        lastOddsFetchAt = Date()
        
        DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS] Fetched odds for \(odds.count) playoff games (throttle updated)")
        DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS] Odds keys: \(odds.keys.sorted().joined(separator: ", "))")
        
        for (gameID, gameOdds) in odds {
            DebugPrint(mode: .bettingOdds, "🎰 [PLAYOFF ODDS]   \(gameID): spread=\(gameOdds.spreadDisplay ?? "N/A"), total=\(gameOdds.totalDisplay ?? "N/A"), book=\(gameOdds.sportsbook ?? "N/A")")
        }
    }
    
    // 🔥 NEW: Reset local throttle (called when user manually refreshes from Settings)
    private func resetOddsThrottle() async {
        lastOddsFetchKey = nil
        lastOddsFetchAt = nil
        DebugPrint(mode: .bettingOdds, "🔄 [PLAYOFF ODDS] Local throttle reset - next fetch will be immediate")
        
        // Trigger immediate odds refresh if we have a bracket
        if let bracket = currentBracket {
            await fetchPlayoffGameOdds(bracket: bracket, season: bracket.season)
        }
    }
    
    // MARK: - Weekly Postseason Fetch
    
    private func fetchWeeklyPlayoffEvents(for season: Int) async throws -> [ESPNScoreboardResponse.Event] {
        var all: [ESPNScoreboardResponse.Event] = []
        for wk in 1...5 {
            guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/scoreboard?season=\(season)&seasontype=3&week=\(wk)") else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let resp = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: data)
                let events = resp.events ?? []
                DebugPrint(mode: .nflData, "📥 Week \(wk) postseason events fetched: \(events.count)")
                all.append(contentsOf: events)
            } catch {
                DebugPrint(mode: .nflData, "⚠️ Failed weekly fetch for week \(wk), season \(season): \(error)")
            }
        }
        return all
    }
    
    // MARK: - Super Bowl Detection & Fallback
    
    private func isGenericSuperBowl(_ game: PlayoffGame) -> Bool {
        let home = game.homeTeam.abbreviation.uppercased()
        let away = game.awayTeam.abbreviation.uppercased()
        let isGenericHome = (home == "AFC" || home == "NFC" || home == "TBD" || home.isEmpty)
        let isGenericAway = (away == "AFC" || away == "NFC" || away == "TBD" || away.isEmpty)
        let missingScores = (game.homeTeam.score == nil && game.awayTeam.score == nil)
        return isGenericHome || isGenericAway || missingScores
    }
    
    private func fallbackSuperBowl(for season: Int) -> PlayoffGame? {
        let results: [Int: (winner: String, loser: String, wScore: Int, lScore: Int, venue: String, city: String, state: String)] = [
            2012: ("BAL","SF",34,31, "Mercedes-Benz Superdome", "New Orleans", "LA"),
            2013: ("SEA","DEN",43,8, "MetLife Stadium", "East Rutherford", "NJ"),
            2014: ("NE","SEA",28,24, "University of Phoenix Stadium", "Glendale", "AZ"),
            2015: ("DEN","CAR",24,10, "Levi's Stadium", "Santa Clara", "CA"),
            2016: ("NE","ATL",34,28, "NRG Stadium", "Houston", "TX"),
            2017: ("PHI","NE",41,33, "U.S. Bank Stadium", "Minneapolis", "MN"),
            2018: ("NE","LAR",13,3, "Mercedes-Benz Stadium", "Atlanta", "GA"),
            2019: ("KC","SF",31,20, "Hard Rock Stadium", "Miami Gardens", "FL"),
            2020: ("TB","KC",31,9, "Raymond James Stadium", "Tampa", "FL"),
            2021: ("LAR","CIN",23,20, "SoFi Stadium", "Inglewood", "CA"),
            2022: ("KC","PHI",38,35, "State Farm Stadium", "Glendale", "AZ"),
            2023: ("KC","SF",25,22, "Allegiant Stadium", "Las Vegas", "NV"),
            2024: ("PHI","KC",40,22, "Caesars Superdome", "New Orleans", "LA")
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
        
        let home = PlayoffTeam(abbreviation: nfcAbbr, name: nfcName, seed: nil, score: nfcScore, logoURL: nil, timeoutsRemaining: nil)
        
        let away = PlayoffTeam(abbreviation: afcAbbr, name: afcName, seed: nil, score: afcScore, logoURL: nil, timeoutsRemaining: nil)
        
        let venue = PlayoffGame.Venue(
            fullName: r.venue,
            city: r.city,
            state: r.state
        )
        
        return PlayoffGame(
            id: "SB_\(season)",
            round: .superBowl,
            conference: .none,
            homeTeam: home,
            awayTeam: away,
            gameDate: date,
            status: .final,
            venue: venue,
            broadcasts: nil,
            liveSituation: nil,
            lastKnownDownDistance: nil
        )
    }
    
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
    
    deinit {
        DebugPrint(mode: .nflData, "♻️ NFLPlayoffBracketService deinit - cleaning up")
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellable?.cancel()
        cancellable = nil
        if let observer = manualRefreshObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}