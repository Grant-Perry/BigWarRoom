//
//  PlayerComparisonModels.swift
//  BigWarRoom
//
//  Models for player comparison feature (MVP - without betting odds)
//

import Foundation

// SleeperPlayer is defined in SleeperModels.swift in the same module
// No explicit import needed - same module visibility

// MARK: - Comparison Data Models

/// Player data prepared for comparison
struct ComparisonPlayer: Identifiable {
    let id: String
    let sleeperPlayer: SleeperPlayer
    let projectedPoints: Double?
    let recentForm: RecentForm?
    let matchupInfo: MatchupInfo?
    let injuryStatus: InjuryStatus
    
    var fullName: String { sleeperPlayer.fullName }
    var position: String { sleeperPlayer.position ?? "UNK" }
    var team: String? { sleeperPlayer.team }
}

/// Recent performance data (last 3 games)
struct RecentForm {
    let averagePoints: Double
    let lastThreeGames: [Double]
    let trend: FormTrend
    
    enum FormTrend {
        case trendingUp
        case trendingDown
        case stable
    }
    
    /// Calculate trend from last 3 scores
    static func calculate(from scores: [Double]) -> FormTrend {
        guard scores.count >= 2 else { return .stable }
        let recent = scores.suffix(2)
        let older = scores.prefix(1)
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        
        if recentAvg > olderAvg + 0.5 {
            return .trendingUp
        } else if recentAvg < olderAvg - 0.5 {
            return .trendingDown
        }
        return .stable
    }
}

/// Matchup information
struct MatchupInfo {
    let opponent: String?
    let isHome: Bool
    let gameTime: String?
}

/// Injury/availability status
struct InjuryStatus {
    let isHealthy: Bool
    let status: String?
    let description: String
    
    init(from sleeperPlayer: SleeperPlayer) {
        let status = sleeperPlayer.injuryStatus ?? sleeperPlayer.status
        self.status = status
        self.isHealthy = status == nil || 
                        status?.lowercased().contains("healthy") == true ||
                        status?.isEmpty == true
        self.description = status ?? "Healthy"
    }
}

// MARK: - Comparison Result

/// Final comparison recommendation
struct ComparisonRecommendation: Identifiable, Equatable {
    let id = UUID()
    let winner: ComparisonPlayer
    let loser: ComparisonPlayer
    let winnerGrade: LetterGrade
    let loserGrade: LetterGrade
    let scoreDifference: Double // Projected point difference
    let reasoning: [String] // List of reasons
    let confidence: ConfidenceLevel
    
    enum LetterGrade: String, Equatable {
        case aPlus = "A+"
        case a = "A"
        case aMinus = "A-"
        case bPlus = "B+"
        case b = "B"
        case bMinus = "B-"
        case cPlus = "C+"
        case c = "C"
        case cMinus = "C-"
        case d = "D"
        case f = "F"
        
        var color: String {
            switch self {
            case .aPlus, .a, .aMinus: return "green"
            case .bPlus, .b, .bMinus: return "blue"
            case .cPlus, .c, .cMinus: return "yellow"
            case .d: return "orange"
            case .f: return "red"
            }
        }
    }
    
    enum ConfidenceLevel: Equatable {
        case high    // Clear winner
        case medium  // Moderate difference
        case low     // Close call
        
        var description: String {
            switch self {
            case .high: return "Strong recommendation"
            case .medium: return "Moderate recommendation"
            case .low: return "Close call - use your judgment"
            }
        }
    }
    
    // Custom Equatable implementation
    static func == (lhs: ComparisonRecommendation, rhs: ComparisonRecommendation) -> Bool {
        lhs.id == rhs.id &&
        lhs.winnerGrade == rhs.winnerGrade &&
        lhs.loserGrade == rhs.loserGrade &&
        lhs.scoreDifference == rhs.scoreDifference &&
        lhs.reasoning == rhs.reasoning &&
        lhs.confidence == rhs.confidence
    }
}

// MARK: - Helper Extensions

extension Double {
    /// Format as fantasy points
    var fantasyPointsString: String {
        return String(format: "%.1f", self)
    }
}

