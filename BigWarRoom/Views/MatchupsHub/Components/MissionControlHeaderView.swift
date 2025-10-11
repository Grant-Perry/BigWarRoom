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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Mission Control title with leagues indicator
            HStack(spacing: 0) {
                Text("Mission Control")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .notificationBadge(count: connectedLeaguesCount, xOffset: 24, yOffset: -8) // Fixed parameters
                
                Spacer()
            }
            
            // Last Update
            if let timeAgoString {
                Text("Last Update: \(timeAgoString)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                Text("Ready to load your battles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
