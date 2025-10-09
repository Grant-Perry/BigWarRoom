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
    
    var emoji: String {
        switch self {
        case .critical: return "🔴"
        case .high: return "🟠"
        case .medium: return "🟡"
        case .low: return "🟢"
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
    
    var emoji: String {
        switch self {
        case .explosive: return "💥"
        case .dangerous: return "⚠️"
        case .moderate: return "📊"
        case .minimal: return "💤"
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
    
    var emoji: String {
        switch self {
        case .ownAndFace: return "⚖️"
        case .multipleOpponents: return "🎯"
        case .mutualOwnership: return "🤝"
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
    
    enum RecommendationType: String, CaseIterable {
        case lineupAdjustment = "LINEUP_ADJUSTMENT"
        case conflictWarning = "CONFLICT_WARNING"
        case opportunityAlert = "OPPORTUNITY_ALERT"
        case threatAssessment = "THREAT_ASSESSMENT"
        
        var emoji: String {
            switch self {
            case .lineupAdjustment: return "🔄"
            case .conflictWarning: return "⚠️"
            case .opportunityAlert: return "🎯"
            case .threatAssessment: return "🛡️"
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