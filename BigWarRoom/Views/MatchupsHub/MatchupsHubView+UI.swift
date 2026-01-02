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
            getOptimizationStatus: matchupsHubViewModel.isLineupOptimized,
            allMatchups: matchupsHubViewModel.myMatchups
        )
    }
    
    // MARK: - Simple Computed Properties (Data Only)
    
    var sortedMatchups: [UnifiedMatchup] {
        let allMatchups = matchupsHubViewModel.sortedMatchups(sortByWinning: sortByWinning)
        
        // Get both toggle settings
        let showChoppedEliminated = UserDefaults.standard.showEliminatedChoppedLeagues
        let showPlayoffEliminated = UserDefaults.standard.showEliminatedPlayoffLeagues
        
        // Filter based on settings
        return allMatchups.filter { matchup in
            // Check if this is a playoff-eliminated league (opponent = "Dreams Deferred")
            // IMPORTANT: This must run BEFORE ghost filtering because the placeholder opponent has no starters.
            let isPlayoffEliminated = matchup.opponentTeam?.name == "Dreams Deferred"
            if isPlayoffEliminated {
                return showPlayoffEliminated
            }

            // 🔒 SAFETY: If we can't resolve my team/opponent for a non-Chopped matchup,
            // it's not a real head-to-head matchup and should never render a card.
            if !matchup.isChoppedLeague && (matchup.myTeam == nil || matchup.opponentTeam == nil) {
                DebugPrint(
                    mode: .matchupLoading,
                    limit: 10,
                    "❌ FILTER OUT: \(matchup.league.league.name) (invalid matchup: myTeam/opponentTeam missing)"
                )
                return false
            }

            // 🔒 SAFETY 2: Ghost matchups often have an empty opponent name and/or no starters with team metadata.
            if !matchup.isChoppedLeague, let opponent = matchup.opponentTeam {
                let opponentNameEmpty = opponent.ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let opponentHasAnyStarterWithTeam = opponent.roster.contains { $0.isStarter && $0.team != nil }
                if opponentNameEmpty || !opponentHasAnyStarterWithTeam {
                    DebugPrint(
                        mode: .matchupLoading,
                        limit: 10,
                        "❌ FILTER OUT: \(matchup.league.league.name) (ghost opponent: nameEmpty=\(opponentNameEmpty), startersWithTeam=\(opponentHasAnyStarterWithTeam))"
                    )
                    return false
                }
            }

            // Check Chopped league elimination
            if matchup.isChoppedLeague {
                // Filter out eliminated chopped leagues if setting is disabled.
                // Source of truth for chopped elimination: the computed ranking we built.
                let isEliminated = (matchup.myTeamRanking?.isEliminated == true)
                return showChoppedEliminated || !isEliminated
            }
            
            return true // Show all other matchups
        }
    }
    
    // MARK: - Sheet Views
    
    func buildMatchupDetailSheet(for matchup: UnifiedMatchup) -> some View {
        // 🔥 FIXED: Use the pre-loaded allLeagueMatchups from the matchup object
        // This ensures we have ALL matchups from the league (including active playoff matchups)
        // regardless of filter settings that might hide eliminated matchups in the main view
        let leagueMatchups: [UnifiedMatchup]
        
        if let storedMatchups = matchup.allLeagueMatchups, !storedMatchups.isEmpty {
            // Convert FantasyMatchup array to UnifiedMatchup array
            leagueMatchups = storedMatchups.map { fantasyMatchup in
                UnifiedMatchup(
                    id: "\(matchup.league.id)_\(fantasyMatchup.id)",
                    league: matchup.league,
                    fantasyMatchup: fantasyMatchup,
                    choppedSummary: nil,
                    lastUpdated: matchup.lastUpdated,
                    myTeamRanking: nil,
                    myIdentifiedTeamID: matchup.myIdentifiedTeamID,
                    authenticatedUsername: "",
                    gameDataService: matchup.gameDataService
                )
            }
        } else {
            // Fallback: Filter from myMatchups (for backward compatibility)
            leagueMatchups = matchupsHubViewModel.myMatchups.filter { otherMatchup in
                otherMatchup.league.id == matchup.league.id
            }
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