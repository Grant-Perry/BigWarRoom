//
//  MatchupsHubHeroHeaderView.swift
//  BigWarRoom
//
//  Hero header section for MatchupsHub
//

import SwiftUI

/// Hero header section for MatchupsHub
struct MatchupsHubHeroHeaderView: View {
    let matchupsCount: Int
    let selectedWeek: Int
    let connectedLeaguesCount: Int
    let lastUpdateTime: Date?
    let autoRefreshEnabled: Bool
    let timeAgoString: String?
    let onWeekPickerTapped: () -> Void
    let onAutoRefreshToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            MissionControlHeaderView()
            
            MatchupsStatsOverviewView(
                matchupsCount: matchupsCount,
                selectedWeek: selectedWeek,
                connectedLeaguesCount: connectedLeaguesCount,
                onWeekPickerTapped: onWeekPickerTapped
            )
            
            LastUpdateInfoView(
                lastUpdateTime: lastUpdateTime,
                autoRefreshEnabled: autoRefreshEnabled,
                timeAgoString: timeAgoString,
                onAutoRefreshToggle: onAutoRefreshToggle
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}