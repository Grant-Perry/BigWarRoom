//
//  PlayerCardBackgroundView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedPlayerCardBackground
//  This file now serves as a simple wrapper for backward compatibility
//

import SwiftUI

/// **Legacy wrapper for UnifiedPlayerCardBackground**
/// **Maintains backward compatibility while using the new unified system**
struct PlayerCardBackgroundView: View {
    let team: NFLTeam?
    
    var body: some View {
        UnifiedPlayerCardBackground(
            configuration: .simple(team: team)
        )
    }
}