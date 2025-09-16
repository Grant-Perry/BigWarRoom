//
//  LastUpdateInfoView.swift
//  BigWarRoom
//
//  Last update information with auto-refresh toggle component
//

import SwiftUI

/// Component showing last update time and auto-refresh toggle
struct LastUpdateInfoView: View {
    let lastUpdateTime: Date?
    let autoRefreshEnabled: Bool
    let timeAgoString: String?
    let onAutoRefreshToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(.gpGreen)
            
            LastUpdateTimeDisplay(
                lastUpdateTime: lastUpdateTime,
                timeAgoString: timeAgoString
            )
            
            Spacer()
            
            AutoRefreshToggleView(
                autoRefreshEnabled: autoRefreshEnabled,
                onToggle: onAutoRefreshToggle
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - Supporting Components

/// Last update time display component
private struct LastUpdateTimeDisplay: View {
    let lastUpdateTime: Date?
    let timeAgoString: String?
    
    var body: some View {
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
}

/// Auto-refresh toggle component
private struct AutoRefreshToggleView: View {
    let autoRefreshEnabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Text(autoRefreshEnabled ? "On" : "Off")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(autoRefreshEnabled ? .gpGreen : .gpRedPink)
                .onTapGesture {
                    onToggle()
                }
            
            Text("Auto-refresh")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}