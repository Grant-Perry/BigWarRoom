//
//  PlayerExtensions.swift
//  BigWarRoom
//
//  🔥 PHASE 1 CLEANUP: Unified injury status logic to eliminate DRY violations
//

import Foundation

// MARK: - FantasyPlayer Extensions

extension FantasyPlayer {
    /// Get formatted injury status string
    /// Replaces 4+ duplicate getInjuryStatus() implementations across views
    var injuryStatus: String? {
        guard let nflPlayer = nflPlayer else { return nil }
        return nflPlayer.injuryStatus?.lowercased().capitalized
    }
}

// MARK: - SleeperPlayer Extensions

extension SleeperPlayer {
    /// Get formatted injury status string
    var injuryStatus: String? {
        return injury_status?.lowercased().capitalized
    }
}

// MARK: - NFLPlayer Extensions

extension NFLPlayer {
    /// Get formatted injury status with proper capitalization
    var formattedInjuryStatus: String? {
        return injuryStatus?.lowercased().capitalized
    }
}