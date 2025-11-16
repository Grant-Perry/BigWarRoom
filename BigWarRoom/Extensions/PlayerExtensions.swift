//
//  PlayerExtensions.swift
//  BigWarRoom
//
//  🔥 PHASE 1 CLEANUP: Unified injury status logic to eliminate DRY violations
//

import Foundation

// MARK: - FantasyPlayer Extensions

extension FantasyPlayer {
    // 🔥 REMOVED: injuryStatus is now a stored property on the model itself!
    // Access directly via: player.injuryStatus
    // This eliminates the O(n) lookup that was happening here
}

// MARK: - SleeperPlayer Extensions

extension SleeperPlayer {
    /// Get formatted injury status string with proper capitalization
    var formattedInjuryStatus: String? {
        return injuryStatus?.lowercased().capitalized
    }
    
    /// Get positional rank (e.g., "RB12", "WR5") from PlayerDirectoryStore
    var positionalRank: String? {
        return PlayerDirectoryStore.shared.positionalRank(for: playerID)
    }
    
    /// Get numeric positional rank (e.g., 12 for "RB12") from PlayerDirectoryStore
    var numericPositionalRank: Int? {
        return PlayerDirectoryStore.shared.numericPositionalRank(for: playerID)
    }
}