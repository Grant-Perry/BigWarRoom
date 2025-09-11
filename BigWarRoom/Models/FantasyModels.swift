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
    let projected_points: Double?  // Added projected points support
    let matchup_id: Int
    let starters: [String]?
    let players: [String]?
    
    /// Projected points formatted
    var projectedPointsString: String {
        guard let projected_points = projected_points else { return "0.00" }
        return String(format: "%.2f", projected_points)
    }
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
    
    // MARK: -> CENTRALIZED LIVE DETECTION - CLEAN & RELIABLE 🔥
    
    /// Single source of truth for live status using NFLGameDataService
    var isLive: Bool {
        guard let team = self.team else { return false }
        
        // Use NFLGameDataService as the authoritative source
        if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
            return gameInfo.isLive
        }
        
        return false
    }
    
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
    
    /// Player headshot URL (try multiple sources like SleepThis)
    var headshotURL: URL? {
        // Try Sleeper first (best quality)
        if let sleeperID = sleeperID {
            return URL(string: "https://sleepercdn.com/content/nfl/players/\(sleeperID).jpg")
        }
        
        // Try ESPN headshots for ESPN players
        if let espnID = espnID {
            return URL(string: "https://a.espncdn.com/i/headshots/nfl/players/full/\(espnID).png")
        }
        
        // Fallback: try to construct ESPN URL from name
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            let cleanFirst = firstName.replacingOccurrences(of: " ", with: "").lowercased()
            let cleanLast = lastName.replacingOccurrences(of: " ", with: "").lowercased()
            return URL(string: "https://a.espncdn.com/i/headshots/nfl/players/full/\(cleanFirst)-\(cleanLast).png")
        }
        
        return nil
    }
    
    /// ESPN player image URL (alternative)
    var espnHeadshotURL: URL? {
        if let espnID = espnID {
            return URL(string: "https://a.espncdn.com/i/headshots/nfl/players/full/\(espnID).png")
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
    /// 🔥 PRIORITY FIX: Always return a color, never gray delay
    var teamColor: Color {
        // Fast path: If team is known, return immediately
        if let team = team, !team.isEmpty {
            return NFLTeamColors.color(for: team)
        }
        
        // Fallback: Use position-based colors for instant visual feedback
        return NFLTeamColors.fallbackColor(for: position)
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
        case "live", "in":
            if let quarter = quarter, let timeRemaining = timeRemaining {
                return "\(quarter) \(timeRemaining)"
            }
            return "LIVE"
        case "postgame", "final", "post":
            return "FINAL"
        case "pregame", "pre":
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
    
    /// Initialize from NFL game info
    init(from gameInfo: NFLGameInfo) {
        self.status = gameInfo.gameStatus
        self.startTime = gameInfo.startDate
        self.timeRemaining = gameInfo.gameTime
        self.quarter = nil // ESPN API includes quarter in gameTime
        self.homeScore = gameInfo.homeScore
        self.awayScore = gameInfo.awayScore
    }
    
    /// Standard initializer
    init(status: String, startTime: Date? = nil, timeRemaining: String? = nil, quarter: String? = nil, homeScore: Int? = nil, awayScore: Int? = nil) {
        self.status = status
        self.startTime = startTime
        self.timeRemaining = timeRemaining
        self.quarter = quarter
        self.homeScore = homeScore
        self.awayScore = awayScore
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

// MARK: -> CHOPPED LEAGUE BATTLE ROYALE MODELS 🔥💀🏆

/// Chopped League Team Ranking - APOCALYPTIC EDITION
struct FantasyTeamRanking: Identifiable {
    let id: String
    let team: FantasyTeam
    let weeklyPoints: Double
    let rank: Int
    let eliminationStatus: EliminationStatus
    let isEliminated: Bool
    let survivalProbability: Double // 0.0 - 1.0
    let pointsFromSafety: Double // How many points above/below safety line
    let weeksAlive: Int
    
    /// Weekly points formatted
    var weeklyPointsString: String {
        return String(format: "%.2f", weeklyPoints)
    }
    
    /// Rank display (e.g., "1st", "2nd", "3rd")
    var rankDisplay: String {
        let suffix: String
        switch rank {
        case 1: suffix = "st"
        case 2: suffix = "nd" 
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(rank)\(suffix)"
    }
    
    /// Survival probability as percentage
    var survivalPercentage: String {
        return String(format: "%.0f%%", survivalProbability * 100)
    }
    
    /// Points from safety line display
    var safetyMarginDisplay: String {
        if pointsFromSafety >= 0 {
            return "+\(String(format: "%.1f", pointsFromSafety))"
        } else {
            return String(format: "%.1f", pointsFromSafety)
        }
    }
}

/// Elimination Status - DEATH GAME EDITION
enum EliminationStatus: String, CaseIterable {
    case champion = "champion"      // #1 seed, untouchable
    case safe = "safe"             // Comfortably safe
    case warning = "warning"       // Getting close to danger
    case danger = "danger"         // Bottom 25%, in real danger
    case critical = "critical"     // Last place, about to be chopped
    case eliminated = "eliminated"  // DEAD 💀
    
    var displayName: String {
        switch self {
        case .champion: return "Champion"
        case .safe: return "Safe"
        case .warning: return "Warning"
        case .danger: return "DANGER ZONE"
        case .critical: return "CRITICAL"
        case .eliminated: return "ELIMINATED"
        }
    }
    
    var color: Color {
        switch self {
        case .champion: return .yellow
        case .safe: return .green
        case .warning: return .blue
        case .danger: return .orange
        case .critical: return .red
        case .eliminated: return .black
        }
    }
    
    var emoji: String {
        switch self {
        case .champion: return "👑"
        case .safe: return "✅"
        case .warning: return "⚡"
        case .danger: return "⚠️"
        case .critical: return "🚨"
        case .eliminated: return "💀"
        }
    }
    
    var dramaticMessage: String {
        switch self {
        case .champion: return "REIGNING SUPREME"
        case .safe: return "Living to fight another day"
        case .warning: return "Treading dangerous waters"
        case .danger: return "ON THE CHOPPING BLOCK"
        case .critical: return "MOMENTS FROM ELIMINATION"
        case .eliminated: return "CHOPPED AND OUT"
        }
    }
}

/// Chopped Week Summary - ENHANCED WITH ELIMINATION HISTORY
struct ChoppedWeekSummary: Identifiable {
    let id: String
    let week: Int
    let rankings: [FantasyTeamRanking]
    let eliminatedTeam: FantasyTeamRanking?
    let cutoffScore: Double
    let isComplete: Bool
    let totalSurvivors: Int
    let averageScore: Double
    let highestScore: Double
    let lowestScore: Double
    let eliminationHistory: [EliminationEvent] // Track all previous eliminations
    
    /// Teams still alive (not eliminated)
    var aliveTeams: [FantasyTeamRanking] {
        return rankings.filter { !$0.isEliminated }
    }
    
    /// Teams in critical danger (last place)
    var criticalTeams: [FantasyTeamRanking] {
        return aliveTeams.filter { $0.eliminationStatus == .critical }
    }
    
    /// Teams in danger zone (bottom 25%)
    var dangerZoneTeams: [FantasyTeamRanking] {
        return aliveTeams.filter { $0.eliminationStatus == .danger }
    }
    
    /// Teams with warning status
    var warningTeams: [FantasyTeamRanking] {
        return aliveTeams.filter { $0.eliminationStatus == .warning }
    }
    
    /// Safe teams
    var safeTeams: [FantasyTeamRanking] {
        return aliveTeams.filter { $0.eliminationStatus == .safe }
    }
    
    /// Champion (top team)
    var champion: FantasyTeamRanking? {
        return aliveTeams.first { $0.eliminationStatus == .champion }
    }
    
    /// All eliminated teams from current week
    var eliminatedTeams: [FantasyTeamRanking] {
        return rankings.filter { $0.isEliminated }
    }
    
    /// Is this week scheduled (no scoring yet)?
    var isScheduled: Bool {
        return !rankings.contains { $0.weeklyPoints > 0 }
    }
    
    /// All teams historically eliminated (from eliminationHistory)
    var historicallyEliminatedTeams: [FantasyTeamRanking] {
        return eliminationHistory.map { $0.eliminatedTeam }
    }
}

/// Elimination Event - DRAMATIC CEREMONY DATA
struct EliminationEvent: Identifiable {
    let id: String
    let week: Int
    let eliminatedTeam: FantasyTeamRanking
    let eliminationScore: Double
    let margin: Double // How close was it?
    let dramaMeter: Double // 0.0 - 1.0, how dramatic was this elimination?
    let lastWords: String? // Optional dramatic message
    let timestamp: Date
    
    var dramaMeterDisplay: String {
        switch dramaMeter {
        case 0.8...1.0: return "HEARTBREAKING"
        case 0.6..<0.8: return "Dramatic"
        case 0.4..<0.6: return "Close Call"
        case 0.2..<0.4: return "Expected"
        default: return "Blowout"
        }
    }
    
    var marginDisplay: String {
        return String(format: "%.2f pts", margin)
    }
}

/// Elimination Probability Calculator - THE SLEEPER SAUCE 🔥
struct EliminationProbabilityCalculator {
    
    /// Calculate elimination probability like Sleeper's "SAFE %" 
    static func calculateSafetyPercentage(
        currentRank: Int,
        totalTeams: Int,
        projectedPoints: Double,
        averageProjected: Double,
        weeklyVariance: Double,
        weeksRemaining: Int,
        historicalPerformance: [Double] = []
    ) -> Double {
        
        // Base safety calculation
        let rankPercentile = Double(totalTeams - currentRank) / Double(totalTeams)
        
        // Projected points factor (how much above/below average)
        let projectedFactor = projectedPoints / averageProjected
        let projectedBonus = (projectedFactor - 1.0) * 0.3  // 30% weight to projections
        
        // Historical consistency factor
        let consistencyFactor: Double
        if !historicalPerformance.isEmpty {
            let variance = calculateVariance(historicalPerformance)
            consistencyFactor = max(0.0, 1.0 - (variance / averageProjected))
        } else {
            consistencyFactor = 0.5  // Neutral if no history
        }
        
        // Weeks remaining factor (more weeks = more opportunity to recover)
        let timeRemaining = Double(weeksRemaining) / 17.0  // NFL season length
        let timeFactor = timeRemaining * 0.2  // 20% weight to time remaining
        
        // Combine all factors
        var safetyPercentage = rankPercentile + projectedBonus + (consistencyFactor * 0.2) + timeFactor
        
        // Apply weekly variance adjustment (high variance = more unpredictable)
        let varianceFactor = min(weeklyVariance / averageProjected, 0.5)  // Cap at 50%
        safetyPercentage *= (1.0 - varianceFactor * 0.1)  // Slight penalty for high variance
        
        // Clamp between 1% and 99% (never 0% or 100%)
        return max(0.01, min(0.99, safetyPercentage))
    }
    
    /// Calculate variance of historical performance
    private static func calculateVariance(_ scores: [Double]) -> Double {
        guard scores.count > 1 else { return 0.0 }
        
        let mean = scores.reduce(0, +) / Double(scores.count)
        let squaredDifferences = scores.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(scores.count - 1)
    }
    
    /// Determine elimination status based on safety percentage
    static func determineEliminationStatus(
        safetyPercentage: Double, 
        rank: Int, 
        totalTeams: Int
    ) -> EliminationStatus {
        
        // Champion (top 10% with >80% safety)
        if rank == 1 || (rank <= max(1, totalTeams / 10) && safetyPercentage > 0.8) {
            return .champion
        }
        
        // Critical (bottom team or very low safety)
        if rank == totalTeams || safetyPercentage < 0.15 {
            return .critical
        }
        
        // Danger zone (bottom 25% or safety < 30%)
        if rank > (totalTeams * 3 / 4) || safetyPercentage < 0.30 {
            return .danger
        }
        
        // Warning (safety 30-60%)
        if safetyPercentage < 0.60 {
            return .warning
        }
        
        // Safe (everything else)
        return .safe
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
    
    /// 🔥 NEW: Position-based fallback colors for instant visual feedback
    static func fallbackColor(for position: String) -> Color {
        switch position.uppercased() {
        case "QB": return Color(red: 0.2, green: 0.4, blue: 0.8) // Blue
        case "RB": return Color(red: 0.8, green: 0.2, blue: 0.2) // Red  
        case "WR": return Color(red: 0.2, green: 0.7, blue: 0.2) // Green
        case "TE": return Color(red: 0.8, green: 0.5, blue: 0.1) // Orange
        case "K": return Color(red: 0.6, green: 0.3, blue: 0.8) // Purple
        case "D/ST", "DEF": return Color(red: 0.3, green: 0.3, blue: 0.3) // Dark Gray
        default: return Color(red: 0.4, green: 0.4, blue: 0.6) // Default Blue-Gray
        }
    }
    
    /// Get secondary/accent color for team
    static func accentColor(for team: String) -> Color {
        switch team.uppercased() {
        case "DAL": return .gray
        case "NYG": return .red
        case "PHI": return .gray        case "WSH": return .yellow
        case "CHI": return .orange
        case "DET": return .gray
        case "GB": return .yellow
        case "MIN": return .yellow
        default: return .white
        }
    }
}