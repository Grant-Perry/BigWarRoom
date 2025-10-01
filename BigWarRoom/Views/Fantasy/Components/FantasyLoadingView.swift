//
//  FantasyLoadingView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 REFACTOR: Migrated to use UnifiedLoadingView
//  Simple loading view now uses unified system for consistency
//

import SwiftUI

/// **Fantasy Loading View** - Now using UnifiedLoadingSystem
/// **Simple implementation maintained**
struct FantasyLoadingView: View {
    var body: some View {
        UnifiedLoadingView(
            configuration: .fantasy()
        )
    }
}