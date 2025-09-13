//
//  ChoppedTeamRosterModels.swift
//  BigWarRoom
//
//  Models for Chopped Team Roster functionality
//

import SwiftUI

/// **ChoppedTeamRoster**
/// 
/// Represents a team's roster in Chopped leagues with starters and bench
struct ChoppedTeamRoster {
    let starters: [FantasyPlayer]
    let bench: [FantasyPlayer]
}

/// **ChoppedRosterError**
/// 
/// Errors that can occur when loading Chopped team rosters
enum ChoppedRosterError: LocalizedError {
    case teamNotFound
    case invalidRosterData
    
    var errorDescription: String? {
        switch self {
        case .teamNotFound:
            return "Team not found in matchup data"
        case .invalidRosterData:
            return "Invalid roster data"
        }
    }
}

/// **OpponentInfo**
/// 
/// Information about the opposing team in a matchup
struct OpponentInfo {
    let ownerName: String
    let score: Double
    let rankDisplay: String
    let teamColor: Color
    let teamInitials: String
    let avatarURL: URL?
}