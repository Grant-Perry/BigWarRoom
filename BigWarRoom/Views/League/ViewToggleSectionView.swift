//
//  ViewToggleSectionView.swift
//  BigWarRoom
//
//  Toggle section component for switching between draft views
//

import SwiftUI

/// Component for view toggle controls between rounds and teams
struct ViewToggleSectionView: View {
    let totalPicksCount: Int
    let onTeamsViewTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("View Options")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Round View Button (current view - active state)
                RoundViewButton()
                
                // Team View Button
                TeamViewButton(action: onTeamsViewTapped)
                
                Spacer()
                
                // Info indicator
                if totalPicksCount > 0 {
                    PicksCountIndicator(count: totalPicksCount)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Components

/// Active round view button component
private struct RoundViewButton: View {
    var body: some View {
        ViewToggleButton(
            icon: "list.number",
            title: "Rounds",
            isActive: true,
            action: { /* Already on round view */ }
        )
    }
}

/// Team view button component  
private struct TeamViewButton: View {
    let action: () -> Void
    
    var body: some View {
        ViewToggleButton(
            icon: "person.3",
            title: "Teams",
            isActive: false,
            action: action
        )
    }
}

/// Generic view toggle button component
private struct ViewToggleButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue : Color(.systemGray5))
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Picks count indicator component
private struct PicksCountIndicator: View {
    let count: Int
    
    var body: some View {
        Text("\(count) picks")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}