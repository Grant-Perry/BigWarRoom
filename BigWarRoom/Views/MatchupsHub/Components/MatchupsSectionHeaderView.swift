//
//  MatchupsSectionHeaderView.swift
//  BigWarRoom
//
//  Complex header component with toggles and timer for matchups section
//

import SwiftUI

/// Header component with collapse toggle, control toggles, and countdown timer
struct MatchupsSectionHeaderView: View {
    let poweredByExpanded: Bool
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let refreshCountdown: Double
    let autoRefreshEnabled: Bool
    let onPoweredByToggle: () -> Void
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onRefreshTapped: () -> Void
    let onAutoRefreshToggle: () -> Void
    
    var body: some View {
        HStack {
            CollapseButton(
                isExpanded: poweredByExpanded,
                onToggle: onPoweredByToggle
            )
            
            // Control toggles with even spacing
            ControlTogglesRow(
                sortByWinning: sortByWinning,
                dualViewMode: dualViewMode,
                microMode: microMode,
                autoRefreshEnabled: autoRefreshEnabled,
                onSortToggle: onSortToggle,
                onDualViewToggle: onDualViewToggle,
                onMicroModeToggle: onMicroModeToggle,
                onAutoRefreshToggle: onAutoRefreshToggle
            )
            
            // Timer dial
            PollingCountdownDial(
                countdown: refreshCountdown,
                maxInterval: Double(AppConstants.MatchupRefresh),
                isPolling: autoRefreshEnabled,
                onRefresh: onRefreshTapped
            )
            .scaleEffect(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8) // 🔥 ADDED: Just a bit of breathing room at the top
    }
}

// MARK: - Supporting Components

/// Collapse/expand button for powered by section
private struct CollapseButton: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Row containing all control toggles
private struct ControlTogglesRow: View {
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let autoRefreshEnabled: Bool // NEW: Auto-refresh state
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onAutoRefreshToggle: () -> Void // NEW: Auto-refresh toggle
    
    var body: some View {
        HStack {
            Spacer()
            
            ToggleControlView(
                title: sortByWinning ? "Winning" : "Losing",
                subtitle: "Sort",
                color: sortByWinning ? .gpGreen : .gpRedPink,
                onToggle: onSortToggle
            )
            
            Spacer()
            
            ToggleControlView(
                title: dualViewMode ? "Dual" : "Single",
                subtitle: "View",
                color: dualViewMode ? .blue : .orange,
                onToggle: onDualViewToggle
            )
            
            Spacer()
            
            // 🔥 MOVED: Auto-refresh toggle now next to Dual View
            ToggleControlView(
                title: autoRefreshEnabled ? "On" : "Off",
                subtitle: "Auto-refresh",
                color: autoRefreshEnabled ? .gpGreen : .gpRedPink,
                onToggle: onAutoRefreshToggle
            )
            
            Spacer()
            
            ToggleControlView(
                title: microMode ? "On" : "Off",
                subtitle: "Just me",
                color: microMode ? .gpGreen : .gpRedPink,
                onToggle: onMicroModeToggle
            )
            
            Spacer()
        }
    }
}

/// Individual toggle control component
private struct ToggleControlView: View {
    let title: String
    let subtitle: String
    let color: Color
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .onTapGesture {
                    onToggle()
                }
            
            Text(subtitle)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}