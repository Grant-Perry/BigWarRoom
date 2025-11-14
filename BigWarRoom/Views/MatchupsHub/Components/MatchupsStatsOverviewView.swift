//
//  MatchupsStatsOverviewView.swift
//  BigWarRoom
//
//  #GoodNav Template - Week picker with Intelligence-style icon controls
//

import SwiftUI

/// #GoodNav Template: Week selector with navigation icons (filters, watch, refresh)
struct MatchupsStatsOverviewView: View {
    let matchupsCount: Int
    let selectedWeek: Int
    let connectedLeaguesCount: Int
    let winningCount: Int
    let losingCount: Int
    let onWeekPickerTapped: () -> Void
    let onFiltersToggle: () -> Void
    let onWatchedPlayersToggle: () -> Void
    let onRefreshTapped: () -> Void
    let watchedPlayersCount: Int
    
    // 🔥 USE .shared internally
    private var watchService: PlayerWatchService { PlayerWatchService.shared }
    
    var body: some View {
        HStack {
            // #GoodNav: WEEK picker (left side)
            Button(action: onWeekPickerTapped) {
                HStack(spacing: 6) {
                    Text("WEEK \(selectedWeek)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // #GoodNav: Intelligence-style icon controls (right side)
            HStack(spacing: 12) {
                // Filters button
                Button(action: onFiltersToggle) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Watched players button with badge
                Button(action: onWatchedPlayersToggle) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                        .notificationBadge(count: watchService.watchCount)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh button
                Button(action: onRefreshTapped) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}