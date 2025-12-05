//
//  MissionControlHeaderView.swift
//  BigWarRoom
//
//  Mission Control hero header component
//

import SwiftUI

/// Hero header component for Mission Control with title and branding
struct MissionControlHeaderView: View {
    let lastUpdateTime: Date?
    let timeAgoString: String?
    let connectedLeaguesCount: Int
    let winningCount: Int
    let losingCount: Int
    
    // NEW: Week picker and action callbacks
    let selectedWeek: Int
    let onWeekPickerTapped: () -> Void
    let onWatchedPlayersToggle: () -> Void
    let onRefreshTapped: () -> Void
    
    // 🔥 USE .shared internally
    private var watchService: PlayerWatchService { PlayerWatchService.shared }
    
    // Detect screen size
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompactScreen: Bool {
        UIScreen.main.bounds.width <= 390 // iPhone 14 Pro and smaller
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: isCompactScreen ? 8 : 12) {
            // Mission Control title with leagues indicator
            Text("Mission Control")
                .font(.system(size: isCompactScreen ? 24 : 28, weight: .semibold))
                .foregroundColor(.white)
                .notificationBadge(count: connectedLeaguesCount, xOffset: isCompactScreen ? 20 : 24, yOffset: -8)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            // Right side controls: eyeball, refresh, week picker
            HStack(spacing: isCompactScreen ? 8 : 12) {
                // Watched players button with badge
                Button(action: onWatchedPlayersToggle) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: isCompactScreen ? 20 : 22))
                        .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                        .notificationBadge(count: watchService.watchCount)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Refresh button
                Button(action: onRefreshTapped) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: isCompactScreen ? 20 : 22))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Week picker - compact to prevent text wrapping
                Button(action: onWeekPickerTapped) {
                    HStack(spacing: 3) {
                        Text("WEEK")
                            .font(.system(size: isCompactScreen ? 10 : 12, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("\(selectedWeek)")
                            .font(.system(size: isCompactScreen ? 14 : 16, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: isCompactScreen ? 8 : 10, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, isCompactScreen ? 8 : 10)
                    .padding(.vertical, isCompactScreen ? 4 : 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .fixedSize(horizontal: true, vertical: false) // Prevent wrapping
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}