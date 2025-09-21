//
//  MatchupsHubView+UI.swift
//  BigWarRoom
//
//  Clean UI coordinator for MatchupsHubView components - NO VIEW COMPUTED PROPERTIES
//

import SwiftUI

// MARK: - Clean UI Coordinator (NO COMPUTED VIEW PROPERTIES)
extension MatchupsHubView {
    
    // MARK: - Component Builders (Return Configured Views)
    
    func buildBackgroundView() -> some View {
        MatchupsHubBackgroundView()
    }
    
    func buildLoadingStateView() -> some View {
        MatchupsHubLoadingStateView(
            currentLeague: matchupsHubViewModel.currentLoadingLeague,
            progress: matchupsHubViewModel.loadingProgress,
            loadingStates: matchupsHubViewModel.loadingStates
        )
    }
    
    func buildContentView() -> some View {
        MatchupsHubContentView(
            heroHeaderView: AnyView(buildHeroHeaderView()),
            matchupsSectionView: AnyView(buildMatchupsSectionView()),
            poweredByExpanded: $poweredByExpanded
        )
    }
    
    func buildHeroHeaderView() -> some View {
        MatchupsHubHeroHeaderView(
            matchupsCount: matchupsHubViewModel.myMatchups.count,
            selectedWeek: weekManager.selectedWeek,
            connectedLeaguesCount: matchupsHubViewModel.connectedLeaguesCount,
            lastUpdateTime: matchupsHubViewModel.lastUpdateTime,
            autoRefreshEnabled: matchupsHubViewModel.autoRefreshEnabled,
            timeAgoString: matchupsHubViewModel.timeAgo(matchupsHubViewModel.lastUpdateTime),
            onWeekPickerTapped: showWeekPicker,
            onAutoRefreshToggle: toggleAutoRefresh
        )
    }
    
    func buildMatchupsSectionView() -> some View {
        MatchupsHubMatchupsSectionView(
            poweredByExpanded: $poweredByExpanded,
            sortByWinning: sortByWinning,
            dualViewMode: dualViewMode,
            microMode: matchupsHubViewModel.microModeEnabled,
            justMeModeBannerVisible: matchupsHubViewModel.justMeModeBannerVisible,
            refreshCountdown: refreshCountdown,
            autoRefreshEnabled: matchupsHubViewModel.autoRefreshEnabled,
            sortedMatchups: sortedMatchups,
            expandedCardId: matchupsHubViewModel.expandedCardId,
            onPoweredByToggle: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    poweredByExpanded.toggle()
                }
            },
            onSortToggle: toggleSortOrder,
            onDualViewToggle: toggleDualViewMode,
            onMicroModeToggle: toggleMicroMode,
            onAutoRefreshToggle: toggleAutoRefresh,
            onRefreshTapped: {
                Task {
                    await handlePullToRefresh()
                }
            },
            onShowDetail: showMatchupDetail,
            onMicroCardTap: handleMicroCardTap,
            onExpandedCardDismiss: {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    matchupsHubViewModel.expandedCardId = nil
                }
            },
            getWinningStatus: matchupsHubViewModel.getWinningStatusForMatchup
        )
    }
    
    // MARK: - Simple Computed Properties (Data Only)
    
    var sortedMatchups: [UnifiedMatchup] {
        matchupsHubViewModel.sortedMatchups(sortByWinning: sortByWinning)
    }
    
    // MARK: - Sheet Views
    
    func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        MatchupDetailSheetsView(matchup: matchup)
    }

    func buildWeekPickerSheet() -> some View {
        WeekPickerView(isPresented: $showingWeekPicker)
    }
    
    func buildEmptyStateView() -> some View {
        MatchupsHubEmptyStateView(
            onSettingsTap: { showingSettings = true }
        )
    }
}