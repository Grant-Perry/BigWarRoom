//
//  DashboardSummaryCard.swift
//  BigWarRoom
//
//  Clean summary card replacing the 3-card chaos
//

import SwiftUI

/// Single clean card showing essential fantasy status
struct DashboardSummaryCard: View {
    let winningCount: Int
    let losingCount: Int
    let connectedLeaguesCount: Int
    let lastUpdateTime: Date?
    let timeAgoString: String?
    
    var body: some View {
        VStack(spacing: 12) {
            // Main status line
            HStack(spacing: 0) {
                Text("\(winningCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("-")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                Text("\(losingCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.gpRedPink)
                
                Spacer()
                
                // Overall status indicator
                StatusIndicator(
                    winningCount: winningCount,
                    losingCount: losingCount
                )
            }
            
            // Secondary info
            HStack {
                Text("across \(connectedLeaguesCount) leagues")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeAgoString {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text(timeAgoString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Components

/// Clean status indicator based on win/loss ratio
private struct StatusIndicator: View {
    let winningCount: Int
    let losingCount: Int
    
    private var statusColor: Color {
        if winningCount > losingCount {
            return .gpGreen
        } else if losingCount > winningCount {
            return .gpRedPink
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if winningCount > losingCount {
            return "Winning"
        } else if losingCount > winningCount {
            return "Losing"
        } else {
            return "Tied"
        }
    }
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(statusColor.opacity(0.15))
            )
    }
}