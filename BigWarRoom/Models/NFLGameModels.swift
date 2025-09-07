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
            // Handle various ESPN formats for game time
            if !gameTime.isEmpty {
                // Check if it's already in a simple format like "Q2" or "2:00"
                if gameTime.starts(with: "Q") || gameTime.contains(":") {
                    return gameTime
                }
                
                // Parse ESPN format like "2nd Quarter" or "1st 14:32"
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
            // Only show FINAL for actually completed games with scores
            if homeScore > 0 || awayScore > 0 {
                return "FINAL"
            } else {
                // No score yet, probably pregame with wrong status - show start time
                if let date = startDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "E h:mm a"  // "Sun 1:00 PM"
                    return formatter.string(from: date)
                }
                return "PREGAME"
            }
        default:
            // Fallback: try to show date if available, but avoid showing weird numbers
            if let date = startDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "E h:mm a"  // "Sun 1:00 PM"
                return formatter.string(from: date)
            }
            
            // If gameTime looks like a score or weird numbers, just return status
            if gameTime.contains("-") && gameTime.count < 10 {
                return gameStatus.uppercased()
            }
            
            return gameTime.isEmpty ? gameStatus.uppercased() : gameTime
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
            // Only gray for actually completed games
            if homeScore > 0 || awayScore > 0 {
                return .gray
            } else {
                return .orange // Pregame with wrong status
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
    
    private init() {}
    
    /// Fetch real NFL game data from ESPN API
    func fetchGameData(forWeek week: Int, year: Int = 2024, forceRefresh: Bool = false) {
        // Check cache first
        if !forceRefresh, 
           let cache = cache,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            processGameData(cache)
            return
        }
        
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?seasontype=2&week=\(week)&dates=\(year)") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid API URL"
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: NFLScoreboardResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to fetch NFL data: \(error.localizedDescription)"
                        // xprint("🏈 NFLGameDataService Error: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.cache = response
                    self?.cacheTimestamp = Date()
                    self?.processGameData(response)
                    // xprint("🏈 Successfully fetched NFL data for Week \(week)")
                }
            )
    }
    
    /// Process ESPN API response into game info
    private func processGameData(_ response: NFLScoreboardResponse) {
        var newGameData: [String: NFLGameInfo] = [:]
        
        print("🏈 Processing \(response.events.count) NFL events from ESPN API")
        
        for event in response.events {
            guard let competition = event.competitions.first else { continue }
            
            let competitors = competition.competitors
            guard competitors.count == 2,
                  let awayComp = competitors.first(where: { $0.homeAway == "away" }),
                  let homeComp = competitors.first(where: { $0.homeAway == "home" }) else {
                continue
            }
            
            let homeTeam = homeComp.team.abbreviation
            let awayTeam = awayComp.team.abbreviation
            let homeScore = Int(homeComp.score) ?? 0
            let awayScore = Int(awayComp.score) ?? 0
            
            let status = competition.status.type
            let gameStatus = status.state
            let gameTime = status.detail
            let isLive = gameStatus == "in"
            
            // Parse start date with better error handling
            var startDate: Date?
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startDate = isoFormatter.date(from: competition.date)
            
            // Try alternative format if ISO failed
            if startDate == nil {
                let fallbackFormatter = DateFormatter()
                fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                startDate = fallbackFormatter.date(from: competition.date)
            }
            
            // Try another common format
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
                startDate: startDate
            )
            
            // Debug logging to see what ESPN is actually returning
            print("🏈 GAME FOUND: \(awayTeam) @ \(homeTeam) | Status: '\(gameStatus)' | Score: \(awayScore)-\(homeScore)")
            
            // Map both teams to this game info
            newGameData[homeTeam] = gameInfo
            newGameData[awayTeam] = gameInfo
        }
        
        self.gameData = newGameData
        print("🏈 FINAL TEAMS in game data: \(Array(newGameData.keys).sorted())")
        
        // 🔍 SPECIFIC DEBUG: Check if Washington is missing
        if newGameData["WAS"] == nil {
            print("🚨 MISSING: Washington (WAS) NOT found in ESPN NFL API data!")
            print("🔍 Available teams: \(Array(newGameData.keys).sorted())")
        } else {
            print("✅ FOUND: Washington game data exists")
        }
    }
    
    /// Get game info for a specific team
    func getGameInfo(for team: String) -> NFLGameInfo? {
        // 🔥 FIX: Handle ESPN API team abbreviation inconsistencies
        let normalizedTeam = normalizeTeamAbbreviation(team.uppercased())
        print("🔧 TEAM LOOKUP: '\(team)' -> '\(normalizedTeam)' | Found: \(gameData[normalizedTeam] != nil)")
        return gameData[normalizedTeam]
    }
    
    /// Normalize team abbreviations to match ESPN's NFL API
    private func normalizeTeamAbbreviation(_ team: String) -> String {
        switch team.uppercased() {
        case "WAS":
            print("🔧 NORMALIZING: WAS -> WSH")
            return "WSH"  // ESPN uses WSH for Washington
        default:
            return team.uppercased()
        }
    }
    
    /// Start auto-refresh for live games using AppConstants timing
    func startLiveUpdates(forWeek week: Int, year: Int = 2024) {
        let refreshInterval = TimeInterval(AppConstants.MatchupRefresh)
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            // Only refresh if we have live games
            let hasLiveGames = self?.gameData.values.contains { $0.isLive } ?? false
            if hasLiveGames {
                // xprint("🏈 NFL Live Update: Refreshing game data (every \(AppConstants.MatchupRefresh)s)")
                self?.fetchGameData(forWeek: week, year: year, forceRefresh: true)
            }
        }
    }
}