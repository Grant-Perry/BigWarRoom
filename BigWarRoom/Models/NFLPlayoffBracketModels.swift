//
//  NFLPlayoffBracketModels.swift
//  BigWarRoom
//
//  NFL Playoff Bracket Data Models
//  Supports current season playoffs & historical brackets
//

import Foundation
import SwiftUI

// MARK: - Playoff Round Types

/// Represents the different rounds of NFL playoffs
enum PlayoffRound: String, Codable, CaseIterable {
    case wildCard = "wildcard"
    case divisional = "division"
    case conference = "conference"
    case superBowl = "final"
    
    var displayName: String {
        switch self {
        case .wildCard: return "Wild Card"
        case .divisional: return "Divisional"
        case .conference: return "Conference"
        case .superBowl: return "Super Bowl"
        }
    }
    
    var shortName: String {
        switch self {
        case .wildCard: return "WC"
        case .divisional: return "DIV"
        case .conference: return "CONF"
        case .superBowl: return "SB"
        }
    }
    
    /// Order in bracket display (lower = earlier round)
    var order: Int {
        switch self {
        case .wildCard: return 0
        case .divisional: return 1
        case .conference: return 2
        case .superBowl: return 3
        }
    }
}

// MARK: - Live Game Situation

/// Cached down and distance info
struct CachedDownDistance: Codable, Equatable {
    let down: Int
    let distance: Int
    
    /// Display string for down & distance (e.g., "3rd & 7")
    var display: String {
        let suffix: String
        switch down {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(down)\(suffix) & \(distance)"
    }
}

/// Current play-by-play situation for live games
struct LiveGameSituation: Codable, Equatable {
    let down: Int?                  // Current down (1-4)
    let distance: Int?              // Yards to go for first down
    let yardLine: String?           // Field position (e.g., "OPP 25", "OWN 40")
    let possession: String?         // Team abbreviation that has the ball
    let lastPlay: String?           // Description of last play
    let drivePlayCount: Int?        // Number of plays in current drive
    let driveYards: Int?            // Yards gained in current drive
    let timeOfPossession: String?   // Time of possession for current drive (e.g., "3:45")
    let homeTimeouts: Int?          // 🏈 NEW: Home team timeouts remaining
    let awayTimeouts: Int?          // 🏈 NEW: Away team timeouts remaining
    
    /// Display string for down & distance (e.g., "3rd & 7")
    var downDistanceDisplay: String? {
        guard let down = down, let distance = distance else { return nil }
        let suffix: String
        switch down {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(down)\(suffix) & \(distance)"
    }
    
    /// Display string for field position with team context
    var fieldPositionDisplay: String? {
        yardLine
    }
}

// MARK: - Playoff Game Models

/// Represents a single playoff game
struct PlayoffGame: Identifiable, Codable, Equatable {
    let id: String  // ESPN event ID
    let round: PlayoffRound
    let conference: Conference  // AFC or NFC (or .none for Super Bowl)
    
    let homeTeam: PlayoffTeam
    let awayTeam: PlayoffTeam
    
    let gameDate: Date
    let status: GameStatus
    let venue: Venue?
    let broadcasts: [String]?  // Network names: ["CBS", "Paramount+"]
    let liveSituation: LiveGameSituation?  // 🏈 NEW: Live play-by-play data
    let lastKnownDownDistance: CachedDownDistance?  // 🏈 NEW: Cached down/distance
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, M/d/yy"  // "Saturday, 1/10/26"
        formatter.timeZone = .current  // Use local timezone
        return formatter.string(from: gameDate)
    }
    
    var smartFormattedDate: String {
        let now = Date()
        let daysUntilGame = Calendar.current.dateComponents([.day], from: now, to: gameDate).day ?? 999
        
        // If game is within 7 days, just show day name
        if daysUntilGame >= 0 && daysUntilGame <= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // "SUNDAY"
            formatter.timeZone = .current
            return formatter.string(from: gameDate).uppercased()
        }
        
        // Otherwise show full date
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, M/d/yy"  // "SUNDAY, 1/11/26"
        formatter.timeZone = .current
        return formatter.string(from: gameDate)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // "4:30 PM"
        formatter.timeZone = .current  // Use local timezone
        return formatter.string(from: gameDate)
    }
    
    var formattedDateTime: String {
        "\(formattedDate) • \(formattedTime)"
    }
    
    var fullGameDateTime: String {
        "\(formattedDate) \(formattedTime)"
    }
    
    /// Check if this game is currently live
    var isLive: Bool {
        status.isLive
    }
    
    /// Check if game is completed
    var isCompleted: Bool {
        status.isCompleted
    }
    
    enum Conference: String, Codable {
        case afc = "AFC"
        case nfc = "NFC"
        case none = "NONE"  // For Super Bowl
    }
    
    enum GameStatus: Codable, Equatable {
        case scheduled
        case inProgress(quarter: String, timeRemaining: String)
        case final
        
        var isLive: Bool {
            if case .inProgress = self {
                return true
            }
            return false
        }
        
        var isCompleted: Bool {
            if case .final = self {
                return true
            }
            return false
        }
        
        var displayText: String {
            switch self {
            case .scheduled:
                return "SCHEDULED"
            case .inProgress(let quarter, let time):
                if !time.isEmpty {
                    return "\(quarter) \(time)"
                }
                return quarter
            case .final:
                return "FINAL"
            }
        }
        
        var statusColor: Color {
            switch self {
            case .scheduled:
                return .secondary
            case .inProgress:
                return .red
            case .final:
                return .gray
            }
        }
    }
    
    struct Venue: Codable, Equatable {
        let fullName: String?
        let city: String?
        let state: String?
        
        var displayName: String {
            guard let name = fullName else { return "TBD" }
            if let city = city, let state = state {
                return "\(name) – \(city), \(state)"
            } else if let city = city {
                return "\(name) – \(city)"
            }
            return name
        }
        
        var shortName: String {
            fullName ?? "TBD"
        }
    }
}

/// Represents a team in the playoff bracket
struct PlayoffTeam: Codable, Equatable {
    let abbreviation: String
    let name: String
    let seed: Int?
    let score: Int?
    let logoURL: String?
    let timeoutsRemaining: Int?  // 🏈 NEW: Timeouts remaining (0-3)
    
    var displayName: String {
        name
    }
    
    var seedDisplay: String? {
        guard let seed = seed else { return nil }
        return "\(seed)"
    }
    
    var scoreDisplay: String {
        guard let score = score else { return "-" }
        return "\(score)"
    }
}

// MARK: - Playoff Bracket Container

/// Complete playoff bracket for a season
struct PlayoffBracket: Codable {
    let season: Int
    let afcGames: [PlayoffGame]
    let nfcGames: [PlayoffGame]
    let superBowl: PlayoffGame?
    let afcSeed1: PlayoffTeam?
    let nfcSeed1: PlayoffTeam?
    
    /// All games organized by round
    var gamesByRound: [PlayoffRound: [PlayoffGame]] {
        var result: [PlayoffRound: [PlayoffGame]] = [:]
        
        for round in PlayoffRound.allCases {
            let games = (afcGames + nfcGames).filter { $0.round == round }
            if !games.isEmpty {
                result[round] = games
            }
        }
        
        if let sb = superBowl {
            result[.superBowl] = [sb]
        }
        
        return result
    }
    
    /// AFC games organized by round
    var afcByRound: [PlayoffRound: [PlayoffGame]] {
        Dictionary(grouping: afcGames, by: { $0.round })
    }
    
    /// NFC games organized by round
    var nfcByRound: [PlayoffRound: [PlayoffGame]] {
        Dictionary(grouping: nfcGames, by: { $0.round })
    }
    
    /// Check if any games are currently live
    var hasLiveGames: Bool {
        let allGames = afcGames + nfcGames + (superBowl != nil ? [superBowl!] : [])
        return allGames.contains { $0.isLive }
    }
    
    /// Count of completed games
    var completedGamesCount: Int {
        let allGames = afcGames + nfcGames + (superBowl != nil ? [superBowl!] : [])
        return allGames.filter { $0.isCompleted }.count
    }
    
    /// Total games in bracket
    var totalGamesCount: Int {
        afcGames.count + nfcGames.count + (superBowl != nil ? 1 : 0)
    }
}

// MARK: - ESPN API Response Models

/// ESPN playoff scoreboard response
struct ESPNPlayoffScoreboardResponse: Codable {
    let events: [ESPNPlayoffEvent]
    let season: ESPNSeason?
    
    struct ESPNSeason: Codable {
        let year: Int
        let type: Int  // 3 = playoffs
    }
}

struct ESPNPlayoffEvent: Codable {
    let id: String
    let name: String
    let date: String
    let competitions: [ESPNPlayoffCompetition]
    let season: ESPNEventSeason?
    
    struct ESPNEventSeason: Codable {
        let year: Int
    }
}

struct ESPNPlayoffCompetition: Codable {
    let id: String
    let competitors: [ESPNPlayoffCompetitor]
    let status: ESPNPlayoffStatus
    let notes: [ESPNNote]?
    
    struct ESPNNote: Codable {
        let headline: String?
    }
}

struct ESPNPlayoffCompetitor: Codable {
    let id: String
    let homeAway: String
    let team: ESPNTeamInfo
    let score: String?
    let curatedRank: ESPNCuratedRank?
    let timeouts: Int?  // 🏈 NEW: Timeouts remaining
    
    struct ESPNCuratedRank: Codable {
        let current: Int
    }
}

struct ESPNTeamInfo: Codable {
    let id: String
    let abbreviation: String
    let displayName: String
    let logo: String?
}

struct ESPNPlayoffStatus: Codable {
    let type: ESPNStatusType
    
    struct ESPNStatusType: Codable {
        let id: String
        let name: String
        let state: String
        let completed: Bool
        let description: String
        let detail: String
        let shortDetail: String
    }
}