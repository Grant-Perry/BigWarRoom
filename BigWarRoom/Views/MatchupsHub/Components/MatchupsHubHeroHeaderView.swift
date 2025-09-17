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
        .background(
            // Add semi-transparent background to entire hero section
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}