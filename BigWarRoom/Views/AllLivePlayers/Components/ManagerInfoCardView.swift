//
//  ManagerInfoCardView.swift
//  BigWarRoom
//
//  Manager info display card for All Live Players
//

import SwiftUI

/// Displays manager information with avatar, name, and score
struct ManagerInfoCardView: View {
    let manager: ManagerInfo
    let style: Style
    let countdown: Double?
    let onRefresh: (() -> Void)?
    
    enum Style {
        case fullWidth
        case compact
    }
    
    // Default initializer for backward compatibility
    init(manager: ManagerInfo, style: Style, onRefresh: (() -> Void)? = nil) {
        self.manager = manager
        self.style = style
        self.countdown = nil
        self.onRefresh = onRefresh
    }
    
    // New initializer with countdown
    init(manager: ManagerInfo, style: Style, countdown: Double, onRefresh: (() -> Void)? = nil) {
        self.manager = manager
        self.style = style
        self.countdown = countdown
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        HStack(spacing: style == .fullWidth ? 12 : 8) {
            // Manager avatar
            Group {
                if let avatarURL = manager.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(manager.initials)
                                    .font(style == .fullWidth ? .caption : .caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(manager.initials)
                                .font(style == .fullWidth ? .caption : .caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(
                width: style == .fullWidth ? 32 : 24,
                height: style == .fullWidth ? 32 : 24
            )
            .clipShape(Circle())
            
            // Manager name and score
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.name)
                    .font(style == .fullWidth ? .title3 : .caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(String(format: "%.1f", manager.score))
                    .font(style == .fullWidth ? .caption : .caption2)
                    .fontWeight(.bold)
                    .foregroundColor(manager.scoreColor)
            }
            
            if style == .fullWidth {
                Spacer()
                
                // 🔥 NEW: Centered Refresh button - DOUBLE TAP required
                Button(action: {
                    // No single tap action
                }) {
                    Text("Refresh")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .onTapGesture(count: 2) {
                    onRefresh?()
                }
                
                Spacer()
                
                // Countdown timer for refresh (full width only)
                if let countdown = countdown {
                    PollingCountdownDial(
                        countdown: countdown,
                        maxInterval: Double(AppConstants.MatchupRefresh),
                        isPolling: true,
                        onRefresh: {
                            onRefresh?()
                        }
                    )
                    .scaleEffect(1.1)
                }
            }
        }
        .padding(.horizontal, style == .fullWidth ? 12 : 8)
        .padding(.vertical, style == .fullWidth ? 8 : 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ManagerInfoCardView(
            manager: ManagerInfo(
                name: "John Player",
                score: 87.5,
                scoreColor: .green
            ),
            style: .fullWidth,
            countdown: 12.0,
            onRefresh: {}
        )
        
        ManagerInfoCardView(
            manager: ManagerInfo(
                name: "Jane Manager",
                score: 45.2,
                scoreColor: .red
            ),
            style: .compact
        )
    }
    .padding()
}