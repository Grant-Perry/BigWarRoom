//
//  PlayerStatsData.swift
//  BigWarRoom
//
//  Data models for player statistics display
//

import Foundation
import SwiftUI

/// Model for player live statistics data
struct PlayerStatsData {
    let playerID: String
    let stats: [String: Double]
    let position: String
    
    // MARK: - Fantasy Points
    
    var pprPoints: Double {
        stats["pts_ppr"] ?? 0.0
    }
    
    var halfPprPoints: Double {
        stats["pts_half_ppr"] ?? 0.0
    }
    
    var standardPoints: Double {
        stats["pts_std"] ?? 0.0
    }
    
    // MARK: - Position-Specific Stats
    
    // Quarterback Stats
    var passingCompletions: Int { Int(stats["pass_cmp"] ?? 0) }
    var passingAttempts: Int { Int(stats["pass_att"] ?? 0) }
    var passingYards: Int { Int(stats["pass_yd"] ?? 0) }
    var passingTouchdowns: Int { Int(stats["pass_td"] ?? 0) }
    var interceptions: Int { Int(stats["pass_int"] ?? 0) }
    var passingFirstDowns: Int { Int(stats["pass_fd"] ?? 0) }
    
    // Rushing Stats
    var rushingAttempts: Int { Int(stats["rush_att"] ?? 0) }
    var rushingYards: Int { Int(stats["rush_yd"] ?? 0) }
    var rushingTouchdowns: Int { Int(stats["rush_td"] ?? 0) }
    var rushingFirstDowns: Int { Int(stats["rush_fd"] ?? 0) }
    
    // Receiving Stats
    var receptions: Int { Int(stats["rec"] ?? 0) }
    var targets: Int { Int(stats["rec_tgt"] ?? 0) }
    var receivingYards: Int { Int(stats["rec_yd"] ?? 0) }
    var receivingTouchdowns: Int { Int(stats["rec_td"] ?? 0) }
    var receivingFirstDowns: Int { Int(stats["rec_fd"] ?? 0) }
    
    // Kicker Stats
    var fieldGoalsMade: Int { Int(stats["fgm"] ?? 0) }
    var fieldGoalsAttempted: Int { Int(stats["fga"] ?? 0) }
    var extraPointsMade: Int { Int(stats["xpm"] ?? 0) }
    
    // Defense Stats
    var sacks: Int { Int(stats["def_sack"] ?? 0) }
    var defensiveInterceptions: Int { Int(stats["def_int"] ?? 0) }
    var fumbleRecoveries: Int { Int(stats["def_fum_rec"] ?? 0) }
    
    // MARK: - Helper Properties
    
    var hasStats: Bool {
        pprPoints > 0 || passingAttempts > 0 || rushingAttempts > 0 || receptions > 0
    }
}

/// Model for team depth chart information
struct DepthChartData {
    let position: String
    let players: [DepthChartPlayer]
    
    var positionColor: Color {
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
}

/// Model for individual player in depth chart
struct DepthChartPlayer {
    let player: SleeperPlayer
    let depth: Int
    let isCurrentPlayer: Bool
    
    var depthColor: Color {
        switch depth {
        case 1: return .green
        case 2: return .orange
        case 3: return .purple
        case 4: return .red
        default: return .gray
        }
    }
}

/// Model for fantasy analysis data
struct FantasyAnalysisData {
    let searchRank: Int
    let position: String
    let tier: Int
    let tierDescription: String
    let positionAnalysis: String
    
    var tierColor: Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }
}