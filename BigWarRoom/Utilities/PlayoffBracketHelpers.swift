//
//  PlayoffBracketHelpers.swift
//  BigWarRoom
//
//  Helper utilities for playoff bracket calculations and mappings
//

import Foundation

enum PlayoffBracketHelpers {
    
    /// Map week number to playoff round
    static func weekToPlayoffRound(_ week: Int) -> PlayoffRound {
        switch week {
        case 19: return .wildCard
        case 20: return .divisional
        case 21: return .conference
        case 23: return .superBowl
        default: return .wildCard
        }
    }
    
    /// Get title for playoff round
    static func playoffRoundTitle(_ round: PlayoffRound) -> String {
        switch round {
        case .wildCard: return "WILD CARD ROUND"
        case .divisional: return "DIVISIONAL ROUND"
        case .conference: return "CONFERENCE CHAMPIONSHIPS"
        case .superBowl: return "SUPER BOWL"
        }
    }
    
    /// Check if we should show the game time (hide if it's 12:00 AM which is clearly wrong)
    static func shouldShowGameTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        return !(hour == 0 && minute == 0)
    }
    
    /// Extract team code from yard line string (e.g., "BUF 33" -> "BUF")
    static func extractTeamCode(from yardLine: String) -> String? {
        let components = yardLine.split(separator: " ")
        guard components.count >= 1 else { return nil }
        return String(components[0])
    }
}