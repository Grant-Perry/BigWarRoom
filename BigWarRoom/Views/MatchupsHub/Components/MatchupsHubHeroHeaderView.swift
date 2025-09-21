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
            
            // 🔥 MOVED: Last Update info now goes between stat boxes and controls
            CompactLastUpdateView(
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString
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

// MARK: - Supporting Components

/// Compact last update display (no auto-refresh toggle)
private struct CompactLastUpdateView: View {
    let lastUpdateTime: Date?
    let timeAgoString: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(.gpGreen)
            
            if let timeAgoString {
                Text("Last Update: \(timeAgoString)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("Ready to load your battles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
    }
}