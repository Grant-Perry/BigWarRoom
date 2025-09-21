//
//  MatchupsHubMatchupsSectionView.swift
//  BigWarRoom
//
//  Matchups section component for MatchupsHub
//

import SwiftUI

/// Matchups section for MatchupsHub
struct MatchupsHubMatchupsSectionView: View {
    @Binding var poweredByExpanded: Bool
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let justMeModeBannerVisible: Bool
    let refreshCountdown: Double
    let autoRefreshEnabled: Bool
    let sortedMatchups: [UnifiedMatchup]
    let expandedCardId: String?
    let onPoweredByToggle: () -> Void
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onAutoRefreshToggle: () -> Void
    let onRefreshTapped: () -> Void
    let onShowDetail: (UnifiedMatchup) -> Void
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    
    var body: some View {
        VStack(spacing: 20) {
            MatchupsSectionHeaderView(
                poweredByExpanded: poweredByExpanded,
                sortByWinning: sortByWinning,
                dualViewMode: dualViewMode,
                microMode: microMode,
                refreshCountdown: refreshCountdown,
                autoRefreshEnabled: autoRefreshEnabled,
                onPoweredByToggle: onPoweredByToggle,
                onSortToggle: onSortToggle,
                onDualViewToggle: onDualViewToggle,
                onMicroModeToggle: onMicroModeToggle,
                onRefreshTapped: onRefreshTapped,
                onAutoRefreshToggle: onAutoRefreshToggle
            )
            
            // Conditional sections
            if poweredByExpanded {
                PoweredByBrandingView()
            }
            
            // Show banner only when explicitly visible, not when microMode is on
            if justMeModeBannerVisible {
                JustMeModeBannerView()
            }
            
            if !poweredByExpanded {
                Color.clear.frame(height: 4)
            }
            
            // Matchup cards grid
            MatchupCardsGridView(
                sortedMatchups: sortedMatchups,
                microMode: microMode,
                dualViewMode: dualViewMode,
                expandedCardId: expandedCardId,
                onShowDetail: onShowDetail,
                onMicroCardTap: onMicroCardTap,
                onExpandedCardDismiss: onExpandedCardDismiss,
                getWinningStatus: getWinningStatus
            )
        }
    }
}