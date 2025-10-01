//
//  PlayerScoreBarCardBackgroundView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedPlayerCardBackground
//  This file now serves as a wrapper for backward compatibility
//

import SwiftUI

/// **Legacy wrapper for UnifiedPlayerCardBackground - Score Bar Style**
/// **Maintains backward compatibility while using the new unified system**
struct PlayerScoreBarCardBackgroundView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    
    var body: some View {
        let team = NFLTeam.team(for: playerEntry.player.team ?? "")
        
        UnifiedPlayerCardBackground(
            configuration: .scoreBar(
                playerEntry: playerEntry,
                scoreBarWidth: scoreBarWidth,
                team: team
            )
        )
    }
}