//
//  MatchupsHubHeroHeaderView.swift
//  BigWarRoom
//
//  #GoodNav Template - Hero header with Intelligence-style navigation
//

import SwiftUI

/// #GoodNav Template: Hero header section for MatchupsHub
struct MatchupsHubHeroHeaderView: View {
    let matchupsCount: Int
    let selectedWeek: Int
    let connectedLeaguesCount: Int
    let winningCount: Int
    let losingCount: Int
    let lastUpdateTime: Date?
    let autoRefreshEnabled: Bool
    let timeAgoString: String?
    let onWeekPickerTapped: () -> Void
    let onAutoRefreshToggle: () -> Void
    
    // #GoodNav: Intelligence-style actions
    let onFiltersToggle: () -> Void
    let onWatchedPlayersToggle: () -> Void
    let onRefreshTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            MissionControlHeaderView(
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString,
                connectedLeaguesCount: connectedLeaguesCount,
                winningCount: winningCount,
                losingCount: losingCount
            )
            
            // #GoodNav: Week picker with Intelligence-style icons
            MatchupsStatsOverviewView(
                matchupsCount: matchupsCount,
                selectedWeek: selectedWeek,
                connectedLeaguesCount: connectedLeaguesCount,
                winningCount: winningCount,
                losingCount: losingCount,
                onWeekPickerTapped: onWeekPickerTapped,
                onFiltersToggle: onFiltersToggle,
                onWatchedPlayersToggle: onWatchedPlayersToggle,
                onRefreshTapped: onRefreshTapped,
                watchedPlayersCount: 0 // Will be handled by watchService internally
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}