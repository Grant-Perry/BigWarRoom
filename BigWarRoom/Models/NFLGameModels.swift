//
//  NFLGameModels.swift
//  BigWarRoom
//
//  Real NFL game data models using ESPN API
//
// MARK: -> NFL Game Data Models

import Foundation
import SwiftUI
import Observation
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
struct NFLGameInfo: Equatable {
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int
    let awayScore: Int
    let gameStatus: String
    let gameTime: String
    let isLive: Bool
    let isCompleted: Bool
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
    
    /// Game time display for player cards
    var formattedGameTime: String {
        // Conservative: If there are any stats/scores, assume LIVE unless we're 100% sure it's final
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
                // 🔥 FIXED: ESPN sends formats like "15:00 - 4th Quarter", "2:30 - 3rd Quarter"
                let lowercaseTime = gameTime.lowercased()
                
                var quarterDisplay = ""
                var timeDisplay = ""
                
                // 🔥 FIXED: Look for quarter information in the full string first
                if lowercaseTime.contains("1st quarter") || lowercaseTime.contains("1st qtr") {
                    quarterDisplay = "Q1"
                } else if lowercaseTime.contains("2nd quarter") || lowercaseTime.contains("2nd qtr") {
                    quarterDisplay = "Q2"
                } else if lowercaseTime.contains("3rd quarter") || lowercaseTime.contains("3rd qtr") {
                    quarterDisplay = "Q3"
                } else if lowercaseTime.contains("4th quarter") || lowercaseTime.contains("4th qtr") {
                    quarterDisplay = "Q4"
                } else if lowercaseTime.contains("1st") {
                    quarterDisplay = "Q1"
                } else if lowercaseTime.contains("2nd") {
                    quarterDisplay = "Q2" 
                } else if lowercaseTime.contains("3rd") {
                    quarterDisplay = "Q3"
                } else if lowercaseTime.contains("4th") {
                    quarterDisplay = "Q4"
                } else if lowercaseTime.contains("ot") || lowercaseTime.contains("overtime") {
                    quarterDisplay = "OT"
                } else if lowercaseTime.contains("halftime") || lowercaseTime.contains("half") {
                    return "HALFTIME"
                } else if lowercaseTime.contains("final") {
                    return "FINAL"
                } else {
                    // 🔥 DEBUG: Log unexpected format for debugging
                    DebugPrint(mode: .nflData, "Unexpected gameTime format: '\(gameTime)' -> using LIVE")
                    return "LIVE"
                }
                
                // 🔥 FIXED: Extract time component from beginning of string (before the dash)
                if let dashIndex = gameTime.firstIndex(of: "-") {
                    let timeString = String(gameTime[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                    if timeString.contains(":") {
                        timeDisplay = timeString
                    }
                } else {
                    // Fallback: look for MM:SS pattern anywhere
                    let timeRegex = try? NSRegularExpression(pattern: "\\d{1,2}:\\d{2}", options: [])
                    if let regex = timeRegex {
                        let nsString = gameTime as NSString
                        let results = regex.matches(in: gameTime, options: [], range: NSRange(location: 0, length: nsString.length))
                        if let match = results.first {
                            timeDisplay = nsString.substring(with: match.range)
                        }
                    }
                }
                
                // Return formatted quarter and time
                if !quarterDisplay.isEmpty {
                    if !timeDisplay.isEmpty {
                        let result = "\(quarterDisplay) \(timeDisplay)"
                        DebugPrint(mode: .nflData, limit: 3, "'\(gameTime)' -> '\(result)'")
                        return result
                    } else {
                        let result = quarterDisplay
                        DebugPrint(mode: .nflData, limit: 3, "'\(gameTime)' -> '\(result)' (no time)")
                        return result
                    }
                }
            }
            return "LIVE"
            
        case "post", "final":
            // Don't trust ESPN's 'post' status - if we have active stats, it's still LIVE
            if hasScores && !isCompleted {
                // Game has scores but not marked as completed = still playing
                return "LIVE"
            }
            
            // Additional check: Look for quarter/time indicators in gameTime
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
            // Default: If there are scores, assume LIVE
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
    
    /// Status color for UI
    var statusColor: Color {
        switch gameStatus.lowercased() {
        case "in", "live": return .red
        case "pre", "pregame": return .orange
        case "post", "final":
            // Only gray for games that ESPN marks as completed
            if isCompleted && (homeScore > 0 || awayScore > 0) {
                return .gray
            } else {
                return .red // Game in progress with scores, show as live
            }
        default: return .orange // Default to pregame color
        }
    }
    
    /// Simple status badge text (PREGAME, LIVE, FINAL)
    var statusBadgeText: String {
        let hasScores = homeScore > 0 || awayScore > 0
        
        switch gameStatus.lowercased() {
        case "pre", "pregame":
            return "PREGAME"
        case "in", "live":
            return "LIVE"
        case "post", "final":
            // Don't show FINAL unless game is actually completed
            if hasScores && !isCompleted {
                return "LIVE"
            }
            return "FINAL"
        default:
            return "PREGAME"
        }
    }
}

// MARK: -> NFL Game Data Service
@Observable
@MainActor
final class NFLGameDataService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: NFLGameDataService?
    
    static var shared: NFLGameDataService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = NFLGameDataService()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: NFLGameDataService) {
        _shared = instance
    }
    
    var gameData: [String: NFLGameInfo] = [:] // Team -> GameInfo mapping
    var isLoading = false
    var errorMessage: String?

    // Use @ObservationIgnored for internal properties that shouldn't trigger UI updates
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var cache: NFLScoreboardResponse?
    @ObservationIgnored private var cacheTimestamp: Date?
    @ObservationIgnored private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // Request deduplication to prevent API spam
    @ObservationIgnored private var pendingRequests: Set<String> = []
    @ObservationIgnored private var lastRequestTimestamp: Date?
    @ObservationIgnored private let minimumRequestInterval: TimeInterval = 2.0 // Minimum 2 seconds between requests
    
    // 🔥 PHASE 2 CORRECTED: Remove .shared singleton, use proper dependency injection
    init() {}
    
    /// Fetch real NFL game data from ESPN API with deduplication and throttling
    func fetchGameData(forWeek week: Int, year: Int? = nil, forceRefresh: Bool = false) {
        let currentYear = year ?? AppConstants.currentSeasonYearInt
        let requestKey = "\(week)_\(currentYear)"
        
        // Prevent duplicate requests
        guard !pendingRequests.contains(requestKey) else { return }
        
        // Throttle requests to prevent spam
        if !forceRefresh, let lastRequest = lastRequestTimestamp,
           Date().timeIntervalSince(lastRequest) < minimumRequestInterval { return }
        
        // 🔥 DEBUG: Always force refresh during debugging of quarter issues
        let shouldForceRefresh = forceRefresh || true  // Temporary: always refresh
        
        // Check cache first
        if !shouldForceRefresh, 
           let cache = cache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            DebugPrint(mode: .nflData, "Using cached data from \(timestamp)")
            processGameData(cache)
            return
        }
        
        DebugPrint(mode: .nflData, "Fetching fresh data for week \(week), year \(currentYear)")
        
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?seasontype=2&week=\(week)&dates=\(currentYear)") else {
            errorMessage = "Invalid API URL"
            return
        }
        
        // Track pending request and timestamp
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
                    // Remove from pending requests
                    self?.pendingRequests.remove(requestKey)
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        DebugPrint(mode: .nflData, "NFL ERROR: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to fetch NFL data: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] response in
                    // Remove from pending requests
                    self?.pendingRequests.remove(requestKey)
                    
                    DebugPrint(mode: .nflData, "Received fresh data with \(response.events.count) games")
                    
                    self?.cache = response
                    self?.cacheTimestamp = Date()
                    self?.processGameData(response)
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
            
            // 🔥 DEBUG: Log raw ESPN data for problematic games
            if homeTeam == "IND" || homeTeam == "TEN" || homeTeam == "DAL" || homeTeam == "DEN" {
                DebugPrint(mode: .nflData, limit: 2, """
                ESPN RAW DATA for \(awayTeam) vs \(homeTeam):
                   - status.state: '\(gameStatus)'
                   - status.detail: '\(gameTime)'
                   - status.shortDetail: '\(status.shortDetail)'
                   - status.description: '\(status.description)'
                   - status.completed: \(isCompleted)
                   - homeScore: \(homeScore), awayScore: \(awayScore)
                """)
            }
            
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
        
        gameData = newGameData
    }

    /// Get game info with enhanced error handling
    func getGameInfo(for team: String) -> NFLGameInfo? {
        let normalizedTeam = normalizeTeamAbbreviation(team.uppercased())
        let gameInfo = gameData[normalizedTeam]
        
        // If no data and not currently loading, trigger a fetch
        if gameInfo == nil && !isLoading {
            let currentWeek = NFLWeekCalculator.getCurrentWeek()
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
                self?.fetchGameData(forWeek: week, year: currentYear, forceRefresh: true)
            }
        }
    }
}