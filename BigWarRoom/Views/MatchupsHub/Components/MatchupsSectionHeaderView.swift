//
//  MatchupsSectionHeaderView.swift
//  BigWarRoom
//
//  #GoodNav Template - Clickable controls row
//

import SwiftUI

/// #GoodNav Template: Controls row with clickable text toggles and timer
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
            
            // #GoodNav: Clickable control toggles
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
        .padding(.top, 16)
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

/// #GoodNav: Row containing all clickable control toggles
private struct ControlTogglesRow: View {
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let autoRefreshEnabled: Bool
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onAutoRefreshToggle: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            // #GoodNav: Clickable toggle controls
            ClickableToggleControlView(
                title: sortByWinning ? "Winning" : "Losing",
                subtitle: "Sort",
                color: sortByWinning ? .gpGreen : .gpRedPink,
                onToggle: onSortToggle
            )
            
            Spacer()
            
            ClickableToggleControlView(
                title: dualViewMode ? "Dual" : "Single",
                subtitle: "View",
                color: dualViewMode ? .blue : .orange,
                onToggle: onDualViewToggle
            )
            
            Spacer()
            
            ClickableToggleControlView(
                title: autoRefreshEnabled ? "On" : "Off",
                subtitle: "Auto-refresh",
                color: autoRefreshEnabled ? .gpGreen : .gpRedPink,
                onToggle: onAutoRefreshToggle
            )
            
            Spacer()
            
            ClickableToggleControlView(
                title: microMode ? "On" : "Off",
                subtitle: "Just me",
                color: microMode ? .gpGreen : .gpRedPink,
                onToggle: onMicroModeToggle
            )
            
            Spacer()
        }
    }
}

/// #GoodNav: Individual clickable toggle control component
private struct ClickableToggleControlView: View {
    let title: String
    let subtitle: String
    let color: Color
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}