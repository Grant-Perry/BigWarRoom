//
//  MatchupSortingMethod.swift
//  BigWarRoom
//
//  Enum for sorting methods in fantasy matchup details
//

import Foundation

/// Enumeration defining available sorting methods for fantasy matchup displays
enum MatchupSortingMethod: String, CaseIterable, Identifiable {
    case position = "position"
    case score = "score" 
    case name = "name"
    case team = "team" // NEW: Team sorting
    
    var id: String { rawValue }
    
    /// Human-readable display name for the sorting method
    var displayName: String {
        switch self {
        case .position: return "Position"
        case .score: return "Score" 
        case .name: return "Name"
        case .team: return "Team" // NEW
        }
    }
}