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
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"  // "Sun, Jan 14"
        return formatter.string(from: gameDate)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // "1:00 PM"
        return formatter.string(from: gameDate)
    }
    
    var formattedDateTime: String {
        "\(formattedDate) • \(formattedTime)"
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
}

/// Represents a team in the playoff bracket
struct PlayoffTeam: Codable, Equatable {
    let abbreviation: String
    let name: String
    let seed: Int?
    let score: Int?
    let logoURL: String?
    
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