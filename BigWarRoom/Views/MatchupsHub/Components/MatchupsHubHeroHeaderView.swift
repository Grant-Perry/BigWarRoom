//
//  MatchupsHubHeroHeaderView.swift
//  BigWarRoom
//
//  Clean minimal hero header for Mission Control redesign
//

import SwiftUI

/// Clean minimal hero header - no more visual assault
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
    let onSettingsTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Minimal header with week selector and settings
            MinimalHeaderView(
                selectedWeek: selectedWeek,
                onWeekPickerTapped: onWeekPickerTapped,
                onSettingsTapped: onSettingsTapped
            )
            
            // Clean dashboard summary card
            DashboardSummaryCard(
                winningCount: winningCount,
                losingCount: losingCount,
                connectedLeaguesCount: connectedLeaguesCount,
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString
            )
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}