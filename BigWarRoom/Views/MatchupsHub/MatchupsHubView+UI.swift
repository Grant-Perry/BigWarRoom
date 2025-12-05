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
        let winningCount = matchupsHubViewModel.winningMatchupsCount(from: matchupsHubViewModel.myMatchups)
        let losingCount = matchupsHubViewModel.myMatchups.count - winningCount
        
        return MatchupsHubHeroHeaderView(
            matchupsCount: matchupsHubViewModel.myMatchups.count,
            connectedLeaguesCount: matchupsHubViewModel.connectedLeaguesCount,
            winningCount: winningCount,
            losingCount: losingCount,
            lastUpdateTime: matchupsHubViewModel.lastUpdateTime,
            timeAgoString: matchupsHubViewModel.timeAgo(matchupsHubViewModel.lastUpdateTime),
            showingWeekPicker: $showingWeekPicker,
            // #GoodNav: Intelligence-style actions
            onFiltersToggle: {
                // TODO: Add filters functionality for Mission Control
                print("🔧 Mission Control filters - to be implemented")
            },
            onWatchedPlayersToggle: {
                showingWatchedPlayers = true
            }
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
            onRefreshTapped: {
                Task {
                    await handlePullToRefresh()
                }
            },
            // 🏈 NAVIGATION FREEDOM: Remove callback - NavigationLinks handle navigation directly
            // BEFORE: onShowDetail: showMatchupDetail,
            // AFTER: Components use NavigationLinks instead of callbacks
            onMicroCardTap: handleMicroCardTap,
            onExpandedCardDismiss: {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    matchupsHubViewModel.expandedCardId = nil
                }
            },
            getWinningStatus: matchupsHubViewModel.getWinningStatusForMatchup,
            getOptimizationStatus: matchupsHubViewModel.isLineupOptimized
        )
    }
    
    // MARK: - Simple Computed Properties (Data Only)
    
    var sortedMatchups: [UnifiedMatchup] {
        let allMatchups = matchupsHubViewModel.sortedMatchups(sortByWinning: sortByWinning)
        
        // Filter out eliminated chopped leagues if setting is disabled
        let showEliminated = UserDefaults.standard.showEliminatedChoppedLeagues
        if !showEliminated {
            return allMatchups.filter { matchup in
                // Keep non-chopped leagues
                guard matchup.isChoppedLeague else { return true }
                
                // For chopped leagues, check if I'm eliminated
                guard let myTeamRanking = matchup.myTeamRanking else { return true }
                
                // Filter out if eliminated
                return !myTeamRanking.isEliminated
            }
        }
        
        return allMatchups
    }
    
    // MARK: - Sheet Views
    
    func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIXED: Filter ALL matchups from the same league and pass them
        let leagueMatchups = matchupsHubViewModel.myMatchups.filter { otherMatchup in
            otherMatchup.league.id == matchup.league.id
        }
        
        return MatchupDetailSheetsView(matchup: matchup, allLeagueMatchups: leagueMatchups)
    }

    func buildWeekPickerSheet() -> some View {
        WeekPickerView(
            weekManager: weekManager,
            isPresented: $showingWeekPicker
        )
    }
    
    func buildEmptyStateView() -> some View {
        MatchupsHubEmptyStateView(
            onSettingsTap: { showingSettings = true }
        )
    }
}