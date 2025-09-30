//
//  MatchupsStatsOverviewView.swift
//  BigWarRoom
//
//  Stats overview component showing winning, losing, and leagues count
//

import SwiftUI

/// Component displaying key win/loss stats in card format
struct MatchupsStatsOverviewView: View {
    let matchupsCount: Int
    let selectedWeek: Int
    let connectedLeaguesCount: Int
    let winningCount: Int
    let losingCount: Int
    let onWeekPickerTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            StatCardView(
                value: "\(winningCount)",
                label: "WINNING",
                color: .gpGreen
            )
            
            Button(action: onWeekPickerTapped) {
                StatCardView(
                    value: "WEEK \(selectedWeek)",
                    label: "\(connectedLeaguesCount) LEAGUES",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            StatCardView(
                value: "\(losingCount)",
                label: "LOSING",
                color: .gpRedPink
            )
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Supporting Components

/// Individual stat card component
private struct StatCardView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.2)) // Increased from 0.1 to 0.2 for higher opacity
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.5), lineWidth: 1) // Increased from 0.3 to 0.5 for more visible border
                )
        )
    }
}