//
//  HeaderComponents.swift
//  BigWarRoom
//
//  🔥 PHASE 2 DRY REFACTOR: Reusable header components
//  Extracts common patterns from multiple header views without forced unification
//  Smart DRY approach - consolidate what's truly duplicated, preserve domain-specific logic
//

import SwiftUI

// MARK: - Status Badge Component

/// **Unified Status Badge**
/// **Used across multiple headers for Live, Winning, Turn indicators, etc.**
struct UnifiedStatusBadge: View {
    let configuration: StatusBadgeConfiguration
    
    var body: some View {
        HStack(spacing: configuration.spacing) {
            // Icon (optional)
            if let icon = configuration.icon {
                Group {
                    if let systemName = icon.systemName {
                        Image(systemName: systemName)
                            .font(icon.font)
                    } else if icon.isCircle {
                        Circle()
                            .fill(configuration.color)
                            .frame(width: icon.circleSize, height: icon.circleSize)
                    }
                }
                .foregroundColor(configuration.color)
            }
            
            // Text
            Text(configuration.text)
                .font(configuration.font)
                .fontWeight(configuration.fontWeight)
                .foregroundColor(configuration.color)
        }
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, configuration.verticalPadding)
        .background(configuration.backgroundColor)
        .modifier(BadgeClipModifier(shape: configuration.shape))
    }
}

/// **Badge Clip Modifier**
/// **Handles different badge shapes properly**
struct BadgeClipModifier: ViewModifier {
    let shape: BadgeShape
    
    func body(content: Content) -> some View {
        switch shape {
        case .capsule:
            content.clipShape(Capsule())
        case .roundedRectangle(let radius):
            content.clipShape(RoundedRectangle(cornerRadius: radius))
        }
    }
}

/// **Status Badge Configuration**
struct StatusBadgeConfiguration {
    let text: String
    let color: Color
    let backgroundColor: Color
    let font: Font
    let fontWeight: Font.Weight
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let spacing: CGFloat
    let icon: IconConfiguration?
    let shape: BadgeShape
    
    init(
        text: String,
        color: Color,
        backgroundColor: Color? = nil,
        font: Font = .caption,
        fontWeight: Font.Weight = .bold,
        horizontalPadding: CGFloat = 8,
        verticalPadding: CGFloat = 4,
        spacing: CGFloat = 4,
        icon: IconConfiguration? = nil,
        shape: BadgeShape = .capsule
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor ?? color.opacity(0.1)
        self.font = font
        self.fontWeight = fontWeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.spacing = spacing
        self.icon = icon
        self.shape = shape
    }
    
    /// **Live Status Badge Factory**
    static func liveStatus(count: Int) -> StatusBadgeConfiguration {
        StatusBadgeConfiguration(
            text: "LIVE",
            color: .green,
            icon: IconConfiguration.circle(size: 8),
            shape: .roundedRectangle(6)
        )
    }
    
    /// **Winning Status Badge Factory**
    static func winning() -> StatusBadgeConfiguration {
        StatusBadgeConfiguration(
            text: "WINNING",
            color: .gpGreen,
            font: .caption,
            icon: IconConfiguration.circle(size: 6)
        )
    }
    
    /// **Your Turn Badge Factory**
    static func yourTurn() -> StatusBadgeConfiguration {
        StatusBadgeConfiguration(
            text: "YOUR TURN",
            color: .red,
            font: .caption,
            fontWeight: .bold,
            icon: IconConfiguration.circle(size: 6)
        )
    }
    
    /// **Week Badge Factory**
    static func week(_ week: Int) -> StatusBadgeConfiguration {
        StatusBadgeConfiguration(
            text: "Week \(week)",
            color: .gpGreen,
            backgroundColor: Color.gpGreen.opacity(0.1),
            font: .subheadline,
            fontWeight: .bold,
            horizontalPadding: 12,
            verticalPadding: 6,
            shape: .roundedRectangle(16)
        )
    }
}

/// **Icon Configuration**
struct IconConfiguration {
    let systemName: String?
    let isCircle: Bool
    let circleSize: CGFloat
    let font: Font
    
    static func systemIcon(_ name: String, font: Font = .caption) -> IconConfiguration {
        IconConfiguration(systemName: name, isCircle: false, circleSize: 0, font: font)
    }
    
    static func circle(size: CGFloat) -> IconConfiguration {
        IconConfiguration(systemName: nil, isCircle: true, circleSize: size, font: .caption)
    }
}

/// **Badge Shape**
enum BadgeShape {
    case capsule
    case roundedRectangle(CGFloat)
}

// MARK: - Header Background Component

/// **Unified Header Background**
/// **Standardized gradient backgrounds used across multiple headers**
struct UnifiedHeaderBackground: View {
    let style: HeaderBackgroundStyle
    
    var body: some View {
        switch style {
        case .standard(let primaryColor, let cornerRadius):
            buildStandardBackground(primaryColor: primaryColor, cornerRadius: cornerRadius)
        case .dramatic(let primaryColor, let cornerRadius):
            buildDramaticBackground(primaryColor: primaryColor, cornerRadius: cornerRadius)
        case .subtle(let cornerRadius):
            buildSubtleBackground(cornerRadius: cornerRadius)
        }
    }
    
    @ViewBuilder
    private func buildStandardBackground(primaryColor: Color, cornerRadius: CGFloat) -> some View {
        ZStack {
            // Main gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    primaryColor.opacity(0.9),
                    Color.black.opacity(0.7),
                    primaryColor.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle overlay pattern
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    primaryColor.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.8),
                            Color.white.opacity(0.2),
                            primaryColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: primaryColor.opacity(0.4),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    @ViewBuilder
    private func buildDramaticBackground(primaryColor: Color, cornerRadius: CGFloat) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [
                primaryColor.opacity(0.1),
                Color.blue.opacity(0.05)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func buildSubtleBackground(cornerRadius: CGFloat) -> some View {
        Color(.systemGray6)
            .opacity(0.3)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// **Header Background Style**
enum HeaderBackgroundStyle {
    case standard(Color, CGFloat) // primaryColor, cornerRadius
    case dramatic(Color, CGFloat) // primaryColor, cornerRadius  
    case subtle(CGFloat) // cornerRadius only
}

// MARK: - Manager Avatar Component

/// **Unified Manager Avatar**
/// **Standardized avatar display with winning indicators used across headers**
struct UnifiedManagerAvatar: View {
    let configuration: AvatarConfiguration
    
    var body: some View {
        ZStack {
            // Avatar image
            Group {
                if let url = configuration.avatarURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: configuration.size, height: configuration.size)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: configuration.size, height: configuration.size)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: configuration.size, height: configuration.size)
                        .foregroundColor(.gray)
                }
            }
            
            // Winning border (optional)
            if configuration.showWinningBorder {
                Circle()
                    .strokeBorder(Color.gpGreen, lineWidth: 2.5)
                    .frame(
                        width: configuration.size + 4, 
                        height: configuration.size + 4
                    )
            }
        }
    }
}

/// **Avatar Configuration**
struct AvatarConfiguration {
    let avatarURL: URL?
    let size: CGFloat
    let showWinningBorder: Bool
    
    init(avatarURL: URL?, size: CGFloat = 48, showWinningBorder: Bool = false) {
        self.avatarURL = avatarURL
        self.size = size
        self.showWinningBorder = showWinningBorder
    }
}

// MARK: - Sorting Controls Component

/// **Unified Sorting Controls**
/// **Reusable sorting UI used across multiple detail views**
struct UnifiedSortingControls: View {
    let sortingMethod: MatchupSortingMethod
    let sortHighToLow: Bool
    let onSortingMethodChanged: (MatchupSortingMethod) -> Void
    let onSortDirectionChanged: () -> Void
    
    /// Dynamic sort direction text based on current method and direction
    private var sortDirectionText: String {
        switch sortingMethod {
        case .score, .recentActivity:
            return sortHighToLow ? "↓" : "↑"
        case .name, .position, .team:
            return sortHighToLow ? "Z-A" : "A-Z"
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Sort method picker
            Menu {
                ForEach(MatchupSortingMethod.allCases) { method in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onSortingMethodChanged(method)
                        }
                    }) {
                        HStack {
                            Text(method.displayName)
                            if sortingMethod == method {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(sortingMethod.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Sort direction toggle
            Button(action: {
                onSortDirectionChanged()
            }) {
                Text(sortDirectionText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
