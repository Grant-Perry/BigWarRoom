//
//  FantasyModels.swift
//  BigWarRoom
//
//  Fantasy-specific models for matchup and player data
//
// MARK: -> Fantasy Models

import Foundation
import SwiftUI

// MARK: -> Sleeper Matchup Models (from SleepThis - CORRECT implementation)
struct SleeperMatchup: Codable {
    let roster_id: Int
    let points: Double?
    let matchup_id: Int
    let starters: [String]?
    let players: [String]?
}

// MARK: -> Fantasy Matchup (not Codable due to complex nested structures)
struct FantasyMatchup: Identifiable {
    let id: String
    let leagueID: String
    let week: Int
    let year: String
    let homeTeam: FantasyTeam
    let awayTeam: FantasyTeam
    let status: MatchupStatus
    let winProbability: Double? // 0.0 to 1.0, for home team
    let startTime: Date?
    
    let sleeperMatchups: (SleeperMatchup, SleeperMatchup)?
    
    init(
        id: String,
        leagueID: String,
        week: Int,
        year: String,
        homeTeam: FantasyTeam,
        awayTeam: FantasyTeam,
        status: MatchupStatus,
        winProbability: Double? = nil,
        startTime: Date? = nil,
        sleeperMatchups: (SleeperMatchup, SleeperMatchup)? = nil
    ) {
        self.id = id
        self.leagueID = leagueID
        self.week = week
        self.year = year
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.status = status
        self.winProbability = winProbability
        self.startTime = startTime
        self.sleeperMatchups = sleeperMatchups
    }
    
    /// Win probability as percentage string
    var winProbabilityString: String {
        guard let prob = winProbability else { return "50.0" }
        return String(format: "%.1f", prob * 100)
    }
    
    /// Away team win probability
    var awayWinProbability: Double {
        guard let homeProb = winProbability else { return 0.5 }
        return 1.0 - homeProb
    }
    
    /// Away win probability as percentage string
    var awayWinProbabilityString: String {
        return String(format: "%.1f", awayWinProbability * 100)
    }
}

// MARK: -> Fantasy Team
struct FantasyTeam: Identifiable, Codable {
    let id: String
    let name: String
    let ownerName: String
    let record: TeamRecord?
    let avatar: String?
    let currentScore: Double?
    let projectedScore: Double?
    let roster: [FantasyPlayer]
    let rosterID: Int?
    
    /// Team avatar URL - FIXED to handle both avatar IDs and full URLs
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        
        // If it's already a full URL, use it directly
        if avatar.starts(with: "http") {
            return URL(string: avatar)
        } else {
            // If it's just an avatar ID, construct Sleeper URL
            return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
        }
    }
    
    /// ESPN team color based on team name hash
    var espnTeamColor: Color {
        let colors: [Color] = [
            .red, .blue, .green, .orange, .purple, .pink,
            .yellow, .cyan, .mint, .indigo, .teal, .brown
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
    
    /// ESPN team initials (first 2 letters)
    var teamInitials: String {
        String(name.prefix(2)).uppercased()
    }
    
    /// Current score formatted
    var currentScoreString: String {
        guard let score = currentScore else { return "0.00" }
        return String(format: "%.2f", score)
    }
    
    /// Projected score formatted  
    var projectedScoreString: String {
        guard let score = projectedScore else { return "0.00" }
        return String(format: "%.2f", score)
    }
}

// MARK: -> Team Record
struct TeamRecord: Codable {
    let wins: Int
    let losses: Int
    let ties: Int?
    
    /// Record display string (e.g., "8-3-1")
    var displayString: String {
        if let ties = ties, ties > 0 {
            return "\(wins)-\(losses)-\(ties)"
        }
        return "\(wins)-\(losses)"
    }
}

// MARK: -> Fantasy Player
struct FantasyPlayer: Identifiable, Codable {
    let id: String
    let sleeperID: String?
    let espnID: String?
    let firstName: String?
    let lastName: String?
    let position: String
    let team: String?
    let jerseyNumber: String?
    let currentPoints: Double?
    let projectedPoints: Double?
    let gameStatus: GameStatus?
    let isStarter: Bool
    let lineupSlot: String?
    
    /// Full player name
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    /// Short display name (e.g., "J Chase")
    var shortName: String {
        let firstInitial = firstName?.prefix(1).uppercased() ?? ""
        let last = lastName ?? ""
        return "\(firstInitial) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    /// Player headshot URL (try Sleeper first, then fallbacks)
    var headshotURL: URL? {
        if let sleeperID = sleeperID {
            return URL(string: "https://sleepercdn.com/content/nfl/players/\(sleeperID).jpg")
        }
        return nil
    }
    
    /// Current points formatted
    var currentPointsString: String {
        guard let points = currentPoints else { return "0.00" }
        return String(format: "%.2f", points)
    }
    
    /// Projected points formatted
    var projectedPointsString: String {
        guard let points = projectedPoints else { return "0.00" }
        return String(format: "%.2f", points)
    }
    
    /// NFL team color (for player card backgrounds)
    var teamColor: Color {
        guard let team = team else { return .gray }
        return NFLTeamColors.color(for: team)
    }
    
    /// Game time display string
    var gameTimeString: String {
        guard let gameStatus = gameStatus else { return "" }
        return gameStatus.timeString
    }
}

// MARK: -> Game Status
struct GameStatus: Codable {
    let status: String // "pregame", "live", "postgame", "bye"
    let startTime: Date?
    let timeRemaining: String?
    let quarter: String?
    let homeScore: Int?
    let awayScore: Int?
    
    /// User-friendly time string
    var timeString: String {
        switch status.lowercased() {
        case "bye":
            return "BYE"
        case "live":
            if let quarter = quarter, let timeRemaining = timeRemaining {
                return "\(quarter) \(timeRemaining)"
            }
            return "LIVE"
        case "postgame", "final":
            return "FINAL"
        case "pregame":
            if let startTime = startTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return formatter.string(from: startTime)
            }
            return "SOON"
        default:
            return ""
        }
    }
    
    /// Game score string if available
    var scoreString: String? {
        guard let homeScore = homeScore, let awayScore = awayScore else { return nil }
        return "\(awayScore)-\(homeScore)"
    }
}

// MARK: -> Matchup Status
enum MatchupStatus: String, Codable, CaseIterable {
    case upcoming = "upcoming"
    case live = "live" 
    case complete = "complete"
    
    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .live: return "Live"
        case .complete: return "Final"
        }
    }
    
    var emoji: String {
        switch self {
        case .upcoming: return "⏰"
        case .live: return "🔴"
        case .complete: return "✅"
        }
    }
}

// MARK: -> NFL Team Colors
struct NFLTeamColors {
    private static let teamColors: [String: Color] = [
        // NFC East
        "DAL": Color(red: 0.0, green: 0.2, blue: 0.4), // Navy Blue
        "NYG": Color(red: 0.0, green: 0.2, blue: 0.6), // Blue
        "PHI": Color(red: 0.0, green: 0.3, blue: 0.2), // Midnight Green
        "WSH": Color(red: 0.5, green: 0.1, blue: 0.2), // Burgundy
        
        // NFC North
        "CHI": Color(red: 0.0, green: 0.1, blue: 0.3), // Navy Blue
        "DET": Color(red: 0.0, green: 0.4, blue: 0.7), // Honolulu Blue
        "GB": Color(red: 0.1, green: 0.3, blue: 0.1), // Dark Green
        "MIN": Color(red: 0.3, green: 0.1, blue: 0.5), // Purple
        
        // NFC South
        "ATL": Color(red: 0.6, green: 0.1, blue: 0.1), // Red
        "CAR": Color(red: 0.0, green: 0.5, blue: 0.8), // Panthers Blue
        "NO": Color(red: 0.8, green: 0.7, blue: 0.3), // Gold
        "TB": Color(red: 0.8, green: 0.2, blue: 0.1), // Pewter/Red
        
        // NFC West
        "ARI": Color(red: 0.6, green: 0.1, blue: 0.2), // Cardinal Red
        "LAR": Color(red: 0.0, green: 0.2, blue: 0.5), // Royal Blue
        "SF": Color(red: 0.7, green: 0.2, blue: 0.2), // Red
        "SEA": Color(red: 0.0, green: 0.2, blue: 0.3), // College Navy
        
        // AFC East
        "BUF": Color(red: 0.0, green: 0.2, blue: 0.5), // Royal Blue
        "MIA": Color(red: 0.0, green: 0.5, blue: 0.5), // Aqua
        "NE": Color(red: 0.0, green: 0.1, blue: 0.3), // Navy Blue
        "NYJ": Color(red: 0.1, green: 0.4, blue: 0.2), // Gotham Green
        
        // AFC North
        "BAL": Color(red: 0.2, green: 0.1, blue: 0.4), // Purple
        "CIN": Color(red: 0.8, green: 0.3, blue: 0.1), // Orange
        "CLE": Color(red: 0.3, green: 0.2, blue: 0.1), // Brown
        "PIT": Color(red: 0.8, green: 0.7, blue: 0.0), // Gold
        
        // AFC South
        "HOU": Color(red: 0.0, green: 0.1, blue: 0.3), // Deep Steel Blue
        "IND": Color(red: 0.0, green: 0.2, blue: 0.6), // Speed Blue
        "JAX": Color(red: 0.0, green: 0.4, blue: 0.4), // Teal
        "TEN": Color(red: 0.0, green: 0.2, blue: 0.4), // Titans Blue
        
        // AFC West
        "DEN": Color(red: 0.8, green: 0.3, blue: 0.1), // Orange
        "KC": Color(red: 0.8, green: 0.1, blue: 0.1), // Red
        "LV": Color(red: 0.6, green: 0.6, blue: 0.6), // Silver
        "LAC": Color(red: 0.0, green: 0.4, blue: 0.7) // Powder Blue
    ]
    
    static func color(for team: String) -> Color {
        return teamColors[team.uppercased()] ?? .gray
    }
    
    /// Get secondary/accent color for team
    static func accentColor(for team: String) -> Color {
        switch team.uppercased() {
        case "DAL": return .gray
        case "NYG": return .red
        case "PHI": return .gray
        case "WSH": return .yellow
        case "CHI": return .orange
        case "DET": return .gray
        case "GB": return .yellow
        case "MIN": return .yellow
        default: return .white
        }
    }
}