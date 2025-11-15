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
    let timeAgoString: String?
    let onWeekPickerTapped: () -> Void
    
    // #GoodNav: Intelligence-style actions
    let onFiltersToggle: () -> Void
    let onWatchedPlayersToggle: () -> Void
    let onRefreshTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            MissionControlHeaderView(
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString,
                connectedLeaguesCount: connectedLeaguesCount,
                winningCount: winningCount,
                losingCount: losingCount,
                selectedWeek: selectedWeek,
                onWeekPickerTapped: onWeekPickerTapped,
                onWatchedPlayersToggle: onWatchedPlayersToggle,
                onRefreshTapped: onRefreshTapped
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}