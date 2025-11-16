//
//  MatchupsHubMatchupsSectionView.swift
//  BigWarRoom
//
//  Matchups section component for MatchupsHub
//

import SwiftUI

/// Matchups section for MatchupsHub
struct MatchupsHubMatchupsSectionView: View {
    // State bindings
    @Binding var poweredByExpanded: Bool
    
    // Data
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let justMeModeBannerVisible: Bool
    let refreshCountdown: Double
    let sortedMatchups: [UnifiedMatchup]
    let expandedCardId: String?
    
    // Actions
    let onPoweredByToggle: () -> Void
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onRefreshTapped: () -> Void
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    let getOptimizationStatus: (UnifiedMatchup) -> Bool  // 💊 RX: Get optimization status (legacy)
    let getRXStatus: (UnifiedMatchup) -> LineupRXStatus  // 💊 RX: Get 3-state status
    
    var body: some View {
        VStack(spacing: 12) {
            MatchupsSectionHeaderView(
                poweredByExpanded: poweredByExpanded,
                sortByWinning: sortByWinning,
                dualViewMode: dualViewMode,
                microMode: microMode,
                refreshCountdown: refreshCountdown,
                onPoweredByToggle: onPoweredByToggle,
                onSortToggle: onSortToggle,
                onDualViewToggle: onDualViewToggle,
                onMicroModeToggle: onMicroModeToggle,
                onRefreshTapped: onRefreshTapped
            )
            
            // Matchup cards grid - tight spacing
            MatchupCardsGridView(
                sortedMatchups: sortedMatchups,
                microMode: microMode,
                dualViewMode: dualViewMode,
                expandedCardId: expandedCardId,
                // 🏈 NAVIGATION FREEDOM: Remove onShowDetail callback - using NavigationLinks instead
                // onShowDetail: onShowDetail,
                onMicroCardTap: onMicroCardTap,
                onExpandedCardDismiss: onExpandedCardDismiss,
                getWinningStatus: getWinningStatus,
                getOptimizationStatus: getOptimizationStatus,
                getRXStatus: getRXStatus
            )
        }
    }
}