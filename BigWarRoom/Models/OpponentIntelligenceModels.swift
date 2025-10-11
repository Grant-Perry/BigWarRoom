//
//  OpponentIntelligenceModels.swift
//  BigWarRoom
//
//  Data models for Opponent Intelligence Dashboard (OID)
//

import Foundation
import SwiftUI

// MARK: - Core Intelligence Models

/// Complete opponent analysis for a single league matchup
struct OpponentIntelligence: Identifiable {
    let id: String
    let opponentTeam: FantasyTeam
    let myTeam: FantasyTeam
    let leagueName: String
    let leagueSource: LeagueSource
    let matchup: UnifiedMatchup
    let players: [OpponentPlayer]
    let conflictPlayers: [ConflictPlayer]
    let threatLevel: ThreatLevel
    let strategicNotes: [String]
    
    /// Computed properties for quick analysis
    var totalOpponentScore: Double {
        opponentTeam.currentScore ?? 0.0
    }
    
    var projectedOpponentScore: Double {
        opponentTeam.projectedScore ?? 0.0
    }
    
    var scoreDifferential: Double {
        (myTeam.currentScore ?? 0.0) - totalOpponentScore
    }
    
    var isLosingTo: Bool {
        scoreDifferential < 0
    }
    
    var topThreatPlayer: OpponentPlayer? {
        players.max { $0.currentScore < $1.currentScore }
    }
}

/// Individual opponent player analysis
struct OpponentPlayer: Identifiable {
    let id: String
    let player: FantasyPlayer
    let isStarter: Bool
    let currentScore: Double
    let projectedScore: Double
    let threatLevel: PlayerThreatLevel
    let matchupAdvantage: MatchupAdvantage
    let percentageOfOpponentTotal: Double
    
    /// Quick access properties
    var playerName: String { player.fullName }
    var position: String { player.position }
    var team: String { player.team ?? "FA" }
    var isExploding: Bool { currentScore > 20.0 }
    var isStruggling: Bool { currentScore < 5.0 }
    
    /// Display formatting
    var scoreDisplay: String {
        String(format: "%.1f", currentScore)
    }
    
    var projectionDisplay: String {
        String(format: "%.1f", projectedScore)
    }
}

/// Player conflict analysis - when you own/face same player across leagues
struct ConflictPlayer: Identifiable {
    let id: String
    let player: FantasyPlayer
    let myLeagues: [LeagueReference]
    let opponentLeagues: [LeagueReference]
    let conflictType: ConflictType
    let netImpact: Double // Positive = good for me overall, negative = bad
    let severity: ConflictSeverity
    
    /// Strategic recommendation based on conflict
    var recommendation: String {
        switch conflictType {
        case .ownAndFace:
            return netImpact > 0 
                ? "Start \(player.fullName) - net positive across leagues"
                : "Consider benching \(player.fullName) - hurts you more than helps"
        case .multipleOpponents:
            return "ROOT AGAINST \(player.fullName) - facing in \(opponentLeagues.count) leagues"
        case .mutualOwnership:
            return "Monitor \(player.fullName) closely - owned by multiple parties"
        }
    }
}

/// Reference to a league where conflict occurs
struct LeagueReference: Identifiable {
    let id: String
    let name: String
    let isMyTeam: Bool
    let opponentName: String?
}

// MARK: - Enumerations

/// Overall threat level for an opponent team
enum ThreatLevel: String, CaseIterable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "bolt.fill"
        case .low: return "checkmark.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .critical: return "Crushing you - immediate attention needed"
        case .high: return "Strong opponent - monitor closely"
        case .medium: return "Competitive matchup - could go either way"
        case .low: return "Manageable opponent - you're in control"
        }
    }
}

/// Individual player threat assessment
enum PlayerThreatLevel: String, CaseIterable {
    case explosive = "EXPLOSIVE"
    case dangerous = "DANGEROUS"
    case moderate = "MODERATE" 
    case minimal = "MINIMAL"
    
    var color: Color {
        switch self {
        case .explosive: return .red
        case .dangerous: return .orange
        case .moderate: return .blue
        case .minimal: return .gray
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .explosive: return "flame.fill"
        case .dangerous: return "exclamationmark.triangle.fill"
        case .moderate: return "chart.bar.fill"
        case .minimal: return "zzz"
        }
    }
}

/// Matchup advantage assessment for opponent players
enum MatchupAdvantage: String, CaseIterable {
    case elite = "ELITE"
    case favorable = "FAVORABLE"
    case neutral = "NEUTRAL"
    case difficult = "DIFFICULT"
    
    var color: Color {
        switch self {
        case .elite: return .red // Bad for us
        case .favorable: return .orange
        case .neutral: return .gray
        case .difficult: return .green // Good for us
        }
    }
    
    var description: String {
        switch self {
        case .elite: return "Prime matchup - expect big game"
        case .favorable: return "Good spot - above average performance likely"
        case .neutral: return "Average matchup - typical performance expected"
        case .difficult: return "Tough matchup - performance may suffer"
        }
    }
}

/// Type of conflict when same player appears across leagues
enum ConflictType: String, CaseIterable {
    case ownAndFace = "OWN_AND_FACE"
    case multipleOpponents = "MULTIPLE_OPPONENTS"
    case mutualOwnership = "MUTUAL_OWNERSHIP"
    
    var sfSymbol: String {
        switch self {
        case .ownAndFace: return "scale.3d"
        case .multipleOpponents: return "target"
        case .mutualOwnership: return "handshake.fill"
        }
    }
    
    var description: String {
        switch self {
        case .ownAndFace: return "You own this player in one league but face them in another"
        case .multipleOpponents: return "Multiple opponents across leagues own this player"
        case .mutualOwnership: return "Both you and opponent own this player in different leagues"
        }
    }
}

/// Severity level for conflicts
enum ConflictSeverity: String, CaseIterable {
    case extreme = "EXTREME"
    case high = "HIGH"
    case moderate = "MODERATE"
    case low = "LOW"
    
    var color: Color {
        switch self {
        case .extreme: return .red
        case .high: return .orange
        case .moderate: return .yellow
        case .low: return .blue
        }
    }
}

// MARK: - Strategic Recommendation Types

/// Strategic insights generated from opponent analysis
struct StrategicRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let actionable: Bool
    let opponentTeam: FantasyTeam? // Include opponent team for avatar display
    let matchup: UnifiedMatchup? // Single matchup for legacy compatibility
    let injuryAlert: InjuryAlert? // NEW: Full injury alert data for multi-league navigation
    
    // Convenience init for backward compatibility
    init(type: RecommendationType, title: String, description: String, priority: Priority, actionable: Bool, opponentTeam: FantasyTeam?) {
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionable = actionable
        self.opponentTeam = opponentTeam
        self.matchup = nil
        self.injuryAlert = nil
    }
    
    // Full init with matchup
    init(type: RecommendationType, title: String, description: String, priority: Priority, actionable: Bool, opponentTeam: FantasyTeam?, matchup: UnifiedMatchup?) {
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionable = actionable
        self.opponentTeam = opponentTeam
        self.matchup = matchup
        self.injuryAlert = nil
    }
    
    // NEW: Injury alert init with full injury data
    init(type: RecommendationType, title: String, description: String, priority: Priority, actionable: Bool, injuryAlert: InjuryAlert) {
        self.type = type
        self.title = title
        self.description = description
        self.priority = priority
        self.actionable = actionable
        self.opponentTeam = nil
        self.matchup = injuryAlert.leagueRosters.first?.matchup // First matchup for legacy compatibility
        self.injuryAlert = injuryAlert
    }
    
    enum RecommendationType: String, CaseIterable {
        case lineupAdjustment = "LINEUP_ADJUSTMENT"
        case conflictWarning = "CONFLICT_WARNING"
        case opportunityAlert = "OPPORTUNITY_ALERT"
        case threatAssessment = "THREAT_ASSESSMENT"
        case injuryAlert = "INJURY_ALERT"
        
        var sfSymbol: String {
            switch self {
            case .lineupAdjustment: return "arrow.triangle.2.circlepath"
            case .conflictWarning: return "exclamationmark.triangle.fill"
            case .opportunityAlert: return "target"
            case .threatAssessment: return "shield.fill"
            case .injuryAlert: return "cross.case.fill"
            }
        }
    }
    
    enum Priority: Int, CaseIterable {
        case critical = 1
        case high = 2
        case medium = 3
        case low = 4
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .blue
            case .low: return .gray
            }
        }
    }
}

// MARK: - Injury Status Alert Models

/// Individual injury status alert for a rostered player (potentially across multiple leagues)
struct InjuryAlert: Identifiable {
    let id = UUID()
    let player: FantasyPlayer
    let injuryStatus: InjuryStatusType
    let leagueRosters: [InjuryLeagueRoster] // NEW: All leagues where this player is rostered
    let isStarter: Bool // True if starter in ANY of the leagues
    let priority: InjuryPriority
    
    /// Generate recommendation description with all league contexts
    var alertDescription: String {
        let statusDescription: String
        switch injuryStatus {
        case .bye:
            statusDescription = "\(player.fullName) is on BYE Week"
        case .injuredReserve:
            statusDescription = "\(player.fullName) is on Injured Reserve (IR)"
        case .out:
            statusDescription = "\(player.fullName) status is O for game"
        case .doubtful:
            statusDescription = "\(player.fullName) is DOUBTFUL"
        case .questionable:
            statusDescription = "\(player.fullName) is QUESTIONABLE"
        case .pup:
            statusDescription = "\(player.fullName) is on PUP List"
        case .nfi:
            statusDescription = "\(player.fullName) is on NFI List"
        }
        
        // Add league context
        if leagueRosters.count == 1 {
            let league = leagueRosters.first!
            return "\(statusDescription) in \(league.leagueName). \(getActionText())"
        } else {
            let leagueNames = leagueRosters.map { $0.leagueName }.joined(separator: ", ")
            return "\(statusDescription) in \(leagueRosters.count) leagues: \(leagueNames). \(getActionText())"
        }
    }
    
    private func getActionText() -> String {
        switch injuryStatus {
        case .bye:
            return "Replace immediately - won't play this week."
        case .injuredReserve:
            return "Move to IR slot or find replacement."
        case .out:
            return "Replace immediately."
        case .doubtful:
            return "Very unlikely to play - prepare backup."
        case .questionable:
            return "Keep an eye on them before their start."
        case .pup:
            return "Expected out at least 6 weeks - find replacement."
        case .nfi:
            return "Non-football injury - monitor status updates."
        }
    }
    
    /// Convert to StrategicRecommendation
    func asStrategicRecommendation() -> StrategicRecommendation {
        return StrategicRecommendation(
            type: .injuryAlert,
            title: injuryStatus.alertTitle,
            description: alertDescription,
            priority: priority.strategicPriority,
            actionable: true,
            injuryAlert: self // Pass the full InjuryAlert data
        )
    }
}

/// League roster information for injured player
struct InjuryLeagueRoster: Identifiable {
    let id = UUID()
    let leagueName: String
    let leagueSource: LeagueSource
    let myTeam: FantasyTeam
    let matchup: UnifiedMatchup
    let isStarterInThisLeague: Bool
    
    /// Display text for this league roster
    var displayText: String {
        let starterText = isStarterInThisLeague ? "STARTING" : "BENCH"
        return "\(leagueName) (\(starterText))"
    }
}

/// Injury status types with priority ordering
enum InjuryStatusType: String, CaseIterable {
    case bye = "BYE"
    case injuredReserve = "IR"
    case out = "O"
    case doubtful = "D"
    case questionable = "Q"
    case pup = "PUP"
    case nfi = "NFI"
    
    var displayName: String {
        switch self {
        case .bye: return "BYE Week"
        case .injuredReserve: return "Injured Reserve"
        case .out: return "Out"
        case .doubtful: return "Doubtful"
        case .questionable: return "Questionable"
        case .pup: return "Physically Unable to Perform"
        case .nfi: return "Non-Football Injury"
        }
    }
    
    var alertTitle: String {
        switch self {
        case .bye: return "Player on BYE Week"
        case .injuredReserve: return "Player on Injured Reserve"
        case .out: return "Player Out"
        case .doubtful: return "Player Doubtful"
        case .questionable: return "Player Questionable"
        case .pup: return "Player on PUP List"
        case .nfi: return "Player on NFI List"
        }
    }
    
    var color: Color {
        switch self {
        case .bye: return .orange
        case .injuredReserve, .pup, .nfi: return .red
        case .out, .doubtful: return .red
        case .questionable: return .yellow
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .bye: return "bed.double.fill"
        case .injuredReserve: return "cross.case.fill"
        case .out: return "xmark.circle.fill"
        case .doubtful: return "exclamationmark.triangle.fill"
        case .questionable: return "questionmark.circle.fill"
        case .pup: return "figure.walk.motion"
        case .nfi: return "bandage.fill"
        }
    }
    
    /// Priority ranking (lower number = higher priority)
    var priorityRanking: Int {
        switch self {
        case .bye: return 1 // Most important - player definitely won't play
        case .injuredReserve: return 2 // Very important - long-term injury
        case .pup, .nfi: return 3 // Long-term injuries
        case .out: return 4 // Important - definitely won't play this week
        case .doubtful: return 5 // Very unlikely to play
        case .questionable: return 6 // Monitor - might play
        }
    }
    
    /// Initialize from raw injury status string
    static func from(injuryStatus: String?, isByeWeek: Bool = false) -> InjuryStatusType? {
        // First check for BYE week (highest priority)
        if isByeWeek {
            return .bye
        }
        
        // Then check injury status string
        guard let status = injuryStatus?.uppercased() else { return nil }
        
        switch status {
        case "IR", "INJURED_RESERVE": return .injuredReserve
        case "O", "OUT": return .out
        case "D", "DOUBTFUL": return .doubtful
        case "Q", "QUESTIONABLE": return .questionable
        case "PUP", "PHYSICALLY_UNABLE_TO_PERFORM": return .pup
        case "NFI", "NON_FOOTBALL_INJURY": return .nfi
        default: return nil
        }
    }
}

/// Priority levels for injury alerts
enum InjuryPriority: Int, CaseIterable {
    case urgent = 1    // BYE, IR, OUT, PUP, NFI in starting lineup
    case attention = 2 // D, Q in starting lineup
    case low = 3       // Should not occur with current logic (only starters)
    
    /// Convert to StrategicRecommendation priority
    var strategicPriority: StrategicRecommendation.Priority {
        switch self {
        case .urgent: return .critical
        case .attention: return .high  
        case .low: return .medium
        }
    }
    
    /// Badge text for UI
    var badgeText: String {
        switch self {
        case .urgent: return "URGENT"
        case .attention: return "ATTENTION"
        case .low: return "ALERT"
        }
    }
    
    /// Determine priority based on injury status and roster position
    static func determine(status: InjuryStatusType, isStarter: Bool) -> InjuryPriority {
        // Only care about starters - bench players don't get alerts
        guard isStarter else { return .low }
        
        switch status {
        case .bye, .injuredReserve, .out, .pup, .nfi:
            return .urgent // Can't play = URGENT
        case .doubtful, .questionable:
            return .attention // Might not play = ATTENTION
        }
    }
}

// MARK: - Analytics Models

/// Week-over-week opponent performance tracking
struct OpponentPerformanceHistory {
    let opponentTeamId: String
    let weeklyScores: [Int: Double] // Week -> Score
    let averageScore: Double
    let consistency: PerformanceConsistency
    let trendDirection: TrendDirection
    
    enum PerformanceConsistency: String {
        case veryConsistent = "VERY_CONSISTENT"
        case consistent = "CONSISTENT" 
        case volatile = "VOLATILE"
        case veryVolatile = "VERY_VOLATILE"
    }
    
    enum TrendDirection: String {
        case improving = "IMPROVING"
        case declining = "DECLINING"
        case stable = "STABLE"
    }
}