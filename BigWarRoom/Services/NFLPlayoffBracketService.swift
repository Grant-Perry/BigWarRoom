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
        
        guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/standings?season=\(season)") else {
            errorMessage = "Failed to build standings API URL"
            return
        }
        
        DebugPrint(mode: .nflData, "🌐 Fetching standings from: \(url.absoluteString)")
        
        isLoading = true
        errorMessage = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                DebugPrint(mode: .nflData, "📦 Received \(data.count) bytes from ESPN")
                return data
            }
            .decode(type: ESPNStandingsV2Response.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        DebugPrint(mode: .nflData, "❌ Standings fetch failed: \(error)")
                        self?.errorMessage = "Failed to load standings: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] response in
                    DebugPrint(mode: .nflData, "✅ Received standings data")
                    self?.processStandingsData(response, season: season)
                }
            )
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
    
    /// Process standings data and build playoff bracket from seeds
    private func processStandingsData(_ response: ESPNStandingsV2Response, season: Int) {
        var afcSeeds: [Int: PlayoffTeam] = [:]
        var nfcSeeds: [Int: PlayoffTeam] = [:]
        
        let children = response.children ?? []
        for child in children {
            let entries = child.standings?.entries ?? []
            for entry in entries {
                let teamAbbr = entry.team.abbreviation.uppercased()
                
                // Get playoff seed
                guard let seedValue = entry.stats?.first(where: { ($0.name ?? $0.type) == "playoffSeed" })?.value else {
                    continue
                }
                
                let seed = Int(seedValue)
                guard seed >= 1 && seed <= 7 else {
                    continue
                }
                
                // Get team info
                guard let nflTeam = NFLTeam.team(for: teamAbbr) else {
                    continue
                }
                
                let team = PlayoffTeam(
                    abbreviation: teamAbbr,
                    name: nflTeam.fullName,
                    seed: seed,
                    score: nil,
                    logoURL: nil  // We can add this later if needed
                )
                
                // Sort into conference
                if nflTeam.conference == .afc {
                    afcSeeds[seed] = team
                } else {
                    nfcSeeds[seed] = team
                }
            }
        }
        
        DebugPrint(mode: .nflData, """
        ✅ Extracted playoff seeds:
           - AFC: \(afcSeeds.keys.sorted().map { "#\($0) \(afcSeeds[$0]?.abbreviation ?? "")" }.joined(separator: ", "))
           - NFC: \(nfcSeeds.keys.sorted().map { "#\($0) \(nfcSeeds[$0]?.abbreviation ?? "")" }.joined(separator: ", "))
        """)
        
        // Build Wild Card matchups
        let afcGames = buildWildCardGames(seeds: afcSeeds, conference: .afc, season: season)
        let nfcGames = buildWildCardGames(seeds: nfcSeeds, conference: .nfc, season: season)
        
        // Get #1 seeds
        let afcSeed1 = afcSeeds[1]
        let nfcSeed1 = nfcSeeds[1]
        
        let bracket = PlayoffBracket(
            season: season,
            afcGames: afcGames,
            nfcGames: nfcGames,
            superBowl: nil,
            afcSeed1: afcSeed1,
            nfcSeed1: nfcSeed1
        )
        
        // Update cache
        cache[season] = bracket
        cacheTimestamps[season] = Date()
        currentBracket = bracket
        
        DebugPrint(mode: .nflData, """
        ✅ Built playoff bracket:
           - Season: \(season)
           - AFC Games: \(afcGames.count)
           - NFC Games: \(nfcGames.count)
        """)
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