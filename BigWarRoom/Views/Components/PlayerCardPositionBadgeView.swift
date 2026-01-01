//
//  PlayerCardPositionBadgeView.swift
//  BigWarRoom
//
//  Position badge component for PlayerCardView - CLEAN ARCHITECTURE
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI

struct PlayerCardPositionBadgeView: View {
    let player: SleeperPlayer
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    var body: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(colorService.positionTextColor(for: player.position ?? ""))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colorService.positionColor(for: player.position ?? ""))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}