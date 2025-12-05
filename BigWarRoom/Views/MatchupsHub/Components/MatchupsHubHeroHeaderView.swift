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
    let connectedLeaguesCount: Int
    let winningCount: Int
    let losingCount: Int
    let lastUpdateTime: Date?
    let timeAgoString: String?
    @Binding var showingWeekPicker: Bool
    
    // #GoodNav: Intelligence-style actions
    let onFiltersToggle: () -> Void
    let onWatchedPlayersToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            MissionControlHeaderView(
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString,
                connectedLeaguesCount: connectedLeaguesCount,
                winningCount: winningCount,
                losingCount: losingCount,
                showingWeekPicker: $showingWeekPicker,
                onWatchedPlayersToggle: onWatchedPlayersToggle
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}