//
//  AdvancedControlsSection.swift
//  BigWarRoom
//
//  Collapsible section for advanced controls - hidden by default
//

import SwiftUI

/// Collapsible advanced controls section
struct AdvancedControlsSection: View {
    @Binding var isExpanded: Bool
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let autoRefreshEnabled: Bool
    let refreshCountdown: Double
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onAutoRefreshToggle: () -> Void
    let onRefreshTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Collapse/Expand button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Advanced")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expandable controls
            if isExpanded {
                VStack(spacing: 16) {
                    // First row: Sort and View mode
                    HStack(spacing: 20) {
                        CompactToggle(
                            title: sortByWinning ? "Winning" : "Losing",
                            subtitle: "Sort",
                            isActive: sortByWinning,
                            activeColor: .gpGreen,
                            inactiveColor: .gpRedPink,
                            onToggle: onSortToggle
                        )
                        
                        CompactToggle(
                            title: dualViewMode ? "Dual" : "Single",
                            subtitle: "View",
                            isActive: dualViewMode,
                            activeColor: .blue,
                            inactiveColor: .orange,
                            onToggle: onDualViewToggle
                        )
                    }
                    
                    // Second row: Auto-refresh and Just me
                    HStack(spacing: 20) {
                        CompactToggle(
                            title: autoRefreshEnabled ? "On" : "Off",
                            subtitle: "Auto-refresh",
                            isActive: autoRefreshEnabled,
                            activeColor: .gpGreen,
                            inactiveColor: .secondary,
                            onToggle: onAutoRefreshToggle
                        )
                        
                        CompactToggle(
                            title: microMode ? "On" : "Off",
                            subtitle: "Just me",
                            isActive: microMode,
                            activeColor: .gpGreen,
                            inactiveColor: .secondary,
                            onToggle: onMicroModeToggle
                        )
                    }
                    
                    // Refresh timer (only when auto-refresh is on)
                    if autoRefreshEnabled {
                        HStack {
                            Spacer()
                            
                            PollingCountdownDial(
                                countdown: refreshCountdown,
                                maxInterval: Double(AppConstants.MatchupRefresh),
                                isPolling: autoRefreshEnabled,
                                onRefresh: onRefreshTapped
                            )
                            .scaleEffect(0.7)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.1))
                .opacity(isExpanded ? 1 : 0)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Components

/// Compact toggle control for advanced section
private struct CompactToggle: View {
    let title: String
    let subtitle: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isActive ? activeColor : inactiveColor)
            
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isActive ? activeColor : inactiveColor).opacity(0.1))
        )
        .onTapGesture {
            onToggle()
        }
    }
}