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
    
    // NEW: Week picker binding and action callbacks
    @Binding var showingWeekPicker: Bool
    let onWatchedPlayersToggle: () -> Void
    
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
            
            // Right side controls: eyeball, week picker
            HStack(spacing: isCompactScreen ? 8 : 12) {
                // Watched players button with badge
                Button(action: onWatchedPlayersToggle) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: isCompactScreen ? 20 : 22))
                        .foregroundColor(watchService.watchCount > 0 ? .gpOrange : .white)
                        .notificationBadge(count: watchService.watchCount)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Week picker - using TheWeekPicker component
                TheWeekPicker(
                    showingWeekPicker: $showingWeekPicker,
                    labelFontSize: isCompactScreen ? 10 : 11,
                    weekNumberFontSize: isCompactScreen ? 16 : 18,
                    chevronSize: isCompactScreen ? 9 : 10,
                    cornerRadius: 12,
                    horizontalPadding: isCompactScreen ? 10 : 12,
                    verticalPadding: isCompactScreen ? 5 : 6,
                    yearFontSize: 8
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}