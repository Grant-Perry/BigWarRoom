//
//  ByeWeekImpactModels.swift
//  BigWarRoom
//
//  Models for Bye Week Impact Analysis
//  Shows which fantasy teams are affected by NFL bye weeks
//

import Foundation
import SwiftUI

// MARK: - Bye Week Impact

/// Represents the fantasy impact of an NFL team being on bye
struct ByeWeekImpact: Identifiable {
    let id = UUID()
    let teamCode: String
    let affectedPlayers: [AffectedPlayer]
    
    /// Whether this bye week affects any of the user's active lineups
    var hasProblem: Bool {
        !affectedPlayers.isEmpty
    }
    
    /// Count of affected players across all leagues
    var affectedPlayerCount: Int {
        affectedPlayers.count
    }
    
    /// Grouped by league for display
    var groupedByLeague: [String: [AffectedPlayer]] {
        Dictionary(grouping: affectedPlayers) { $0.leagueName }
    }
}

// MARK: - Affected Player

/// A fantasy player in an active lineup affected by the bye week
struct AffectedPlayer: Identifiable {
    let id = UUID()
    let playerName: String
    let position: String
    let nflTeam: String
    let leagueName: String
    let fantasyTeamName: String
    let currentPoints: Double?
    let projectedPoints: Double?
    let sleeperID: String?
    
    /// Full display name for the player
    var displayName: String {
        playerName
    }
    
    /// Position and team display (e.g., "WR - KC")
    var positionTeamDisplay: String {
        "\(position) - \(nflTeam)"
    }
}