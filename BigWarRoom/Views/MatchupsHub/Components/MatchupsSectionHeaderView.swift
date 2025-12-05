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
    let onPoweredByToggle: () -> Void
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    let onRefreshTapped: () -> Void
    
    // 🔥 Timer color and progress (uses SmartRefreshManager)
    private var timerColor: Color {
        let progress = refreshCountdown / SmartRefreshManager.shared.currentRefreshInterval
        
        if progress > 0.66 {
            return .gpGreen
        } else if progress > 0.33 {
            return .orange
        } else {
            return .gpRedPink
        }
    }
    
    private var timerProgress: Double {
        refreshCountdown / SmartRefreshManager.shared.currentRefreshInterval
    }
    
    var body: some View {
        HStack {
            // #GoodNav: Clickable control toggles
            ControlTogglesRow(
                sortByWinning: sortByWinning,
                dualViewMode: dualViewMode,
                microMode: microMode,
                onSortToggle: onSortToggle,
                onDualViewToggle: onDualViewToggle,
                onMicroModeToggle: onMicroModeToggle
            )
            
            // 🔋 SMART REFRESH: Only show timer when actively refreshing
            if SmartRefreshManager.shared.shouldShowCountdownTimer {
                // 🔥 EXACT Live Players Timer (replacing PollingCountdownDial)
                ZStack {
                    // 🔥 External glow layers (multiple for depth)
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(timerColor.opacity(0.15 - Double(index) * 0.05))
                            .frame(width: 45 + CGFloat(index * 8), height: 45 + CGFloat(index * 8))
                            .blur(radius: CGFloat(4 + index * 3))
                            .animation(.easeInOut(duration: 0.8), value: timerColor)
                            .scaleEffect(refreshCountdown < 3 ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: refreshCountdown < 3)
                    }
                    
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
                            .frame(width: 32, height: 32)
                        
                        // 🔥 Circular sweep progress
                        Circle()
                            .trim(from: 0, to: timerProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [timerColor, timerColor.opacity(0.6), timerColor],
                                    center: .center,
                                    startAngle: .degrees(-90),
                                    endAngle: .degrees(270)
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: timerProgress)
                        
                        // Center fill
                        Circle()
                            .fill(timerColor.opacity(0.15))
                            .frame(width: 27, height: 27)
                            .animation(.easeInOut(duration: 0.3), value: timerColor)
                        
                        // 🔥 Timer text with swipe animation
                        ZStack {
                            Text("\(Int(refreshCountdown))")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: timerColor.opacity(0.8), radius: 2, x: 0, y: 1)
                                .scaleEffect(refreshCountdown < 3 ? 1.1 : 1.0)
                                .id("mission-timer-\(Int(refreshCountdown))") // 🔥 Unique ID for transition
                                .transition(
                                    .asymmetric(
                                        insertion: AnyTransition.move(edge: .leading)
                                            .combined(with: .scale(scale: 0.8))
                                            .combined(with: .opacity),
                                        removal: AnyTransition.move(edge: .trailing)
                                            .combined(with: .scale(scale: 1.2))
                                            .combined(with: .opacity)
                                    )
                                )
                        }
                        .frame(width: 14, height: 14) // Fixed frame to prevent layout shifts
                        .clipped()
                        .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1), value: Int(refreshCountdown))
                    }
                }
                .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Supporting Components

/// #GoodNav: Row containing all clickable control toggles
private struct ControlTogglesRow: View {
    let sortByWinning: Bool
    let dualViewMode: Bool
    let microMode: Bool
    let onSortToggle: () -> Void
    let onDualViewToggle: () -> Void
    let onMicroModeToggle: () -> Void
    
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