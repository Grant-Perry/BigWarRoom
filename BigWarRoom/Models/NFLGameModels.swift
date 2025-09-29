//
//  NFLGameModels.swift
//  BigWarRoom
//
//  Real NFL game data models using ESPN API
//
// MARK: -> NFL Game Data Models

import Foundation
import SwiftUI
import Combine

// MARK: -> ESPN NFL Scoreboard API Response Models
struct NFLScoreboardResponse: Codable {
    let events: [NFLGameEvent]
}

struct NFLGameEvent: Codable {
    let id: String
    let name: String
    let date: String
    let competitions: [NFLGameCompetition]
}

struct NFLGameCompetition: Codable {
    let competitors: [NFLGameCompetitor]
    let status: NFLGameStatus
    let date: String
}

struct NFLGameCompetitor: Codable {
    let id: String
    let homeAway: String
    let score: String
    let team: NFLGameTeam
}

struct NFLGameTeam: Codable {
    let abbreviation: String
}

struct NFLGameStatus: Codable {
    let type: NFLGameStatusType
}

struct NFLGameStatusType: Codable {
    let state: String
    let detail: String
    let shortDetail: String
    let completed: Bool
    let description: String
}

// MARK: -> Processed Game Info
struct NFLGameInfo {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let gameStatus: String
    let gameTime: String
    let isLive: Bool
    let isCompleted: Bool // 🔥 NEW: Track if ESPN says the game is actually completed
    let startDate: Date?
    
    /// Formatted matchup string (e.g., "KC vs LAC")
    var matchupString: String {
        return "\(awayTeam) vs \(homeTeam)"
    }
    
    /// Score difference for display
    var scoreDifference: Int {
        return abs(homeScore - awayScore)
    }
    
    /// Formatted score string
    var scoreString: String {
        return "\(awayScore)-\(homeScore)"
    }
    
    /// Game time display for player cards - FIXED to show proper format as requested by Gp
    var formattedGameTime: String {
        // 🔥 ULTRA CONSERVATIVE: If there are any stats/scores, assume LIVE unless we're 100% sure it's final
        let hasScores = homeScore > 0 || awayScore > 0
        
        switch gameStatus.lowercased() {
        case "pre", "pregame":
            // Show game start time like "Sun 1:00 PM"
            if let date = startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "E h:mm a"  // "Sun 1:00 PM"
                return formatter.string(from: date)
            }
            return "PREGAME"
            
        case "in", "live":
            // Show quarter and time like "Q2 2:30"
            if !gameTime.isEmpty {
                // Parse ESPN format for quarter and time
                let components = gameTime.components(separatedBy: " ")
                if components.count >= 1 {
                    let firstComponent = components[0].lowercased()
                    
                    // Extract quarter number
                    var quarterNum = ""
                    if firstComponent.contains("1st") || firstComponent.contains("1") {
                        quarterNum = "1"
                    } else if firstComponent.contains("2nd") || firstComponent.contains("2") {
                        quarterNum = "2" 
                    } else if firstComponent.contains("3rd") || firstComponent.contains("3") {
                        quarterNum = "3"
                    } else if firstComponent.contains("4th") || firstComponent.contains("4") {
                        quarterNum = "4"
                    } else if firstComponent.contains("ot") || firstComponent.contains("overtime") {
                        quarterNum = "OT"
                    }
                    
                    // Look for time component
                    let timeComponent = components.first { $0.contains(":") }
                    
                    if !quarterNum.isEmpty {
                        if let time = timeComponent {
                            return "Q\(quarterNum) \(time)"
                        } else {
                            return "Q\(quarterNum)"
                        }
                    }
                }
            }
            return "LIVE"
            
        case "post", "final":
            // 🔥 FIX: Don't trust ESPN's 'post' status - if we have active stats, it's still LIVE
            if hasScores && !isCompleted {
                // Game has scores but not marked as completed = still playing
                return "LIVE"
            }
            
            // 🔥 ADDITIONAL CHECK: Look for quarter/time indicators in gameTime
            if gameTime.lowercased().contains("quarter") || 
               gameTime.lowercased().contains("q1") || 
               gameTime.lowercased().contains("q2") || 
               gameTime.lowercased().contains("q3") || 
               gameTime.lowercased().contains("q4") ||
               gameTime.contains(":") {
                return "LIVE"  // Still has quarter/time info, must be live
            }
            
            // Only show FINAL if explicitly completed AND no time indicators
            if isCompleted {
                return "FINAL"
            } else {
                // Not explicitly completed, assume still playing
                return "LIVE"
            }
            
        default:
            // 🔥 DEFAULT: If there are scores, assume LIVE
            if hasScores {
                return "LIVE"
            }
            
            // No scores, try to show start time
            if let date = startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "E h:mm a"
                return formatter.string(from: date)
            }
            
            return gameTime.isEmpty ? "PREGAME" : gameTime
        }
    }
    
    /// Legacy displayTime for backward compatibility
    var displayTime: String {
        return formattedGameTime
    }
    
    /// Status color for UI - FIXED to handle pregame properly
    var statusColor: Color {
        switch gameStatus.lowercased() {
        case "in", "live": return .red
        case "pre", "pregame": return .orange
        case "post", "final":
            // 🔥 CRITICAL FIX: Only gray for games that ESPN marks as completed
            if isCompleted && (homeScore > 0 || awayScore > 0) {
                return .gray
            } else {
                return .red // Game in progress with scores, show as live
            }
        default: return .orange // Default to pregame color
        }
    }
}

// MARK: -> NFL Game Data Service
class NFLGameDataService: ObservableObject {
    static let shared = NFLGameDataService()
    @Published var gameData: [String: NFLGameInfo] = [:] // Team -> GameInfo mapping
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellable: AnyCancellable?
    private var cache: NFLScoreboardResponse?
    private var cacheTimestamp: Date?
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // 🔧 BLANK SHEET FIX: Add request deduplication to prevent API spam
    private var pendingRequests: Set<String> = []
    private var lastRequestTimestamp: Date?
    private let minimumRequestInterval: TimeInterval = 2.0 // Minimum 2 seconds between requests
    
    private init() {}
    
    /// 🔧 BLANK SHEET FIX: Enhanced fetch with deduplication and throttling
    /// Fetch real NFL game data from ESPN API
    func fetchGameData(forWeek week: Int, year: Int? = nil, forceRefresh: Bool = false) {
        let currentYear = year ?? AppConstants.currentSeasonYearInt
        let requestKey = "\(week)_\(currentYear)"
        
        // 🔧 BLANK SHEET FIX: Prevent duplicate requests
        guard !pendingRequests.contains(requestKey) else {
            print("🚨 DEBUG NFLGameData: Request already pending for Week \(week), Year \(currentYear) - skipping")
            return
        }
        
        // 🔧 BLANK SHEET FIX: Throttle requests to prevent spam
        if !forceRefresh, let lastRequest = lastRequestTimestamp,
           Date().timeIntervalSince(lastRequest) < minimumRequestInterval {
            print("🚨 DEBUG NFLGameData: Request throttled - too soon since last request")
            return
        }
        
        print("🚨 DEBUG NFLGameData: Fetching Week \(week) for Year \(currentYear)")
        
        // Check cache first
        if !forceRefresh, 
           let cache = cache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("🚨 DEBUG NFLGameData: Using cached data")
            processGameData(cache)
            return
        }
        
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?seasontype=2&week=\(week)&dates=\(currentYear)") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid API URL"
            }
            return
        }
        
        print("🚨 DEBUG NFLGameData: API URL = \(url.absoluteString)")
        
        // 🔧 BLANK SHEET FIX: Track pending request and timestamp
        pendingRequests.insert(requestKey)
        lastRequestTimestamp = Date()
        
        isLoading = true
        errorMessage = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: NFLScoreboardResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    // 🔧 BLANK SHEET FIX: Remove from pending requests
                    self?.pendingRequests.remove(requestKey)
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to fetch NFL data: \(error.localizedDescription)"
                        // x// x Print("🏈 NFLGameDataService Error: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    // 🔧 BLANK SHEET FIX: Remove from pending requests
                    self?.pendingRequests.remove(requestKey)
                    
                    self?.cache = response
                    self?.cacheTimestamp = Date()
                    self?.processGameData(response)
                    // x// x Print("🏈 Successfully fetched NFL data for Week \(week)")
                }
            )
    }
    
    /// Process ESPN API response into game info
    private func processGameData(_ response: NFLScoreboardResponse) {
        var newGameData: [String: NFLGameInfo] = [:]
        for event in response.events {
            guard let competition = event.competitions.first else { continue }
            let competitors = competition.competitors
            guard competitors.count == 2,
                  let awayComp = competitors.first(where: { $0.homeAway == "away" }),
                  let homeComp = competitors.first(where: { $0.homeAway == "home" }) else { continue }
            let homeTeam = homeComp.team.abbreviation
            let awayTeam = awayComp.team.abbreviation
            let homeScore = Int(homeComp.score) ?? 0
            let awayScore = Int(awayComp.score) ?? 0
            let status = competition.status.type
            let gameStatus = status.state
            let gameTime = status.detail
            let isCompleted = status.completed
            let isLive = gameStatus == "in"
            
            // 🔥 DEBUG: Log what ESPN is actually returning
            print("🏈 ESPN DEBUG: \(awayTeam) vs \(homeTeam)")
            print("   Status: '\(gameStatus)', Completed: \(isCompleted), Detail: '\(gameTime)'")
            print("   Scores: \(awayScore)-\(homeScore)")
            
            var startDate: Date?
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startDate = isoFormatter.date(from: competition.date)
            if startDate == nil {
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                startDate = fallbackFormatter.date(from: competition.date)
            }
            if startDate == nil {
                let fallbackFormatter2 = DateFormatter()
                fallbackFormatter2.dateFormat = "yyyy-MM-dd'T'HH:mmZ"
                startDate = fallbackFormatter2.date(from: competition.date)
            }
            let gameInfo = NFLGameInfo(
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeScore: homeScore,
                awayScore: awayScore,
                gameStatus: gameStatus,
                gameTime: gameTime,
                isLive: isLive,
                isCompleted: isCompleted,
                startDate: startDate
            )
            newGameData[homeTeam] = gameInfo
            newGameData[awayTeam] = gameInfo
        }
        self.gameData = newGameData
    }

    /// 🔧 BLANK SHEET FIX: Enhanced getGameInfo with better error handling
    func getGameInfo(for team: String) -> NFLGameInfo? {
        let normalizedTeam = normalizeTeamAbbreviation(team.uppercased())
        let gameInfo = gameData[normalizedTeam]
        
        // 🔧 BLANK SHEET FIX: If no data and not currently loading, trigger a fetch
        if gameInfo == nil && !isLoading {
            let currentWeek = NFLWeekCalculator.getCurrentWeek() // FIXED: Remove .shared, use static method directly
            // Only fetch if we haven't recently requested
            if lastRequestTimestamp == nil || 
               Date().timeIntervalSince(lastRequestTimestamp!) > minimumRequestInterval {
                fetchGameData(forWeek: currentWeek)
            }
        }
        
        return gameInfo
    }

    private func normalizeTeamAbbreviation(_ team: String) -> String {
        switch team.uppercased() {
        case "WAS":
            return "WSH"
        default:
            return team.uppercased()
        }
    }
    
    /// Start auto-refresh for live games using AppConstants timing
    func startLiveUpdates(forWeek week: Int, year: Int? = nil) {
        let currentYear = year ?? AppConstants.currentSeasonYearInt
        let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            // Only refresh if we have live games
            let hasLiveGames = self?.gameData.values.contains { $0.isLive } ?? false
            if hasLiveGames {
                // x// x Print("🏈 NFL Live Update: Refreshing game data (every \(AppConstants.MatchupRefresh)s)")
                self?.fetchGameData(forWeek: week, year: currentYear, forceRefresh: true)
            }
        }
    }
}