//
//  PlayerExtensions.swift
//  BigWarRoom
//
//  🔥 PHASE 1 CLEANUP: Unified injury status logic to eliminate DRY violations
//

import Foundation

// MARK: - FantasyPlayer Extensions

extension FantasyPlayer {
    /// Get formatted injury status string from PlayerDirectoryStore
    /// Replaces 4+ duplicate getInjuryStatus() implementations across views
    var injuryStatus: String? {
        // Get Sleeper player data from PlayerDirectoryStore
        guard let sleeperPlayer = PlayerDirectoryStore.shared.player(for: self.id) else {
            return nil
        }
        return sleeperPlayer.injuryStatus?.lowercased().capitalized
    }
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