//
//  PlayerStatsLoadingView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedLoadingView while preserving animations
//  All original player info display and spinner animation are maintained
//

import SwiftUI

/// **PlayerStats Loading View** - Now using UnifiedLoadingSystem
/// **All animations preserved:** rotation animation, player info layout, background
struct PlayerStatsLoadingView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    let loadingMessage: String
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        UnifiedLoadingView(
            configuration: .playerStats(
                player: player,
                team: team,
                loadingMessage: loadingMessage,
                rotationAngle: $rotationAngle
            )
        )
    }
}