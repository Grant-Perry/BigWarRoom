//
//  MatchupsHubMatchupsSectionView.swift
//  BigWarRoom
//
//  Clean matchups section with collapsible advanced controls
//

import SwiftUI

/// Clean matchups section with hidden advanced controls
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
    let onMicroCardTap: (String) -> Void
    let onExpandedCardDismiss: () -> Void
    let getWinningStatus: (UnifiedMatchup) -> Bool
    
    // State for collapsible advanced controls
    @State private var advancedControlsExpanded = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Advanced controls section (collapsible)
            AdvancedControlsSection(
                isExpanded: $advancedControlsExpanded,
                sortByWinning: sortByWinning,
                dualViewMode: dualViewMode,
                microMode: microMode,
                autoRefreshEnabled: autoRefreshEnabled,
                refreshCountdown: refreshCountdown,
                onSortToggle: onSortToggle,
                onDualViewToggle: onDualViewToggle,
                onMicroModeToggle: onMicroModeToggle,
                onAutoRefreshToggle: onAutoRefreshToggle,
                onRefreshTapped: onRefreshTapped
            )
            
            // Powered by branding (keep existing functionality)
            if poweredByExpanded {
                PoweredByBrandingView()
            }
            
            // Show banner only when explicitly visible
            if justMeModeBannerVisible {
                JustMeModeBannerView()
            }
            
            // More breathing room before matchup cards
            Color.clear.frame(height: 8)
            
            // Matchup cards grid with more space
            MatchupCardsGridView(
                sortedMatchups: sortedMatchups,
                microMode: microMode,
                dualViewMode: dualViewMode,
                expandedCardId: expandedCardId,
                onMicroCardTap: onMicroCardTap,
                onExpandedCardDismiss: onExpandedCardDismiss,
                getWinningStatus: getWinningStatus
            )
        }
    }
}