//
//  PlayerScoreBarCardPositionBadgeView.swift
//  BigWarRoom
//
//  Position badge component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI

struct PlayerScoreBarCardPositionBadgeView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    var body: some View {
        Text(playerEntry.position)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(colorService.positionTextColor(for: playerEntry.position))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colorService.positionColor(for: playerEntry.position))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}