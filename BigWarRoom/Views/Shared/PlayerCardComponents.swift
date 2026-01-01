//
//  PlayerCardComponents.swift
//  BigWarRoom
//
//  🔥 PHASE 2 DRY REFACTOR: Shared player card components library
//  Extracts commonly used patterns from multiple player card variants
//  Smart DRY approach - consolidate shared logic, preserve domain-specific layouts
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI

// MARK: - Shared Player Card Components

/// **Unified Position Color System - DEPRECATED**
/// **Use ColorThemeService.shared instead**
struct PlayerCardPositionColorSystem {
    
    /// **Get position color consistently across all card types**
    static func color(for position: String) -> Color {
        // 🔥 DRY: Delegate to ColorThemeService
        return ColorThemeService.shared.positionColor(for: position)
    }
    
    /// **Get position color with opacity**
    static func color(for position: String, opacity: Double) -> Color {
        return color(for: position).opacity(opacity)
    }
}

/// **Unified Player Image System**
/// **Standardized player image rendering with team context**
struct UnifiedPlayerImageView: View {
    let configuration: PlayerImageConfiguration
    
    var body: some View {
        switch configuration.imageSource {
        case .sleeper(let player):
            buildSleeperPlayerImage(player: player)
        case .enhanced(let pick):
            buildEnhancedPickImage(pick: pick)
        case .url(let url):
            buildURLImage(url: url)
        }
    }
    
    @ViewBuilder
    private func buildSleeperPlayerImage(player: SleeperPlayer) -> some View {
        PlayerImageView(
            player: player,
            size: configuration.size,
            team: configuration.team
        )
        .applyImageStyling(configuration: configuration)
    }
    
    @ViewBuilder
    private func buildEnhancedPickImage(pick: EnhancedPick) -> some View {
        // For EnhancedPick, try to find real Sleeper player first
        if let realPlayer = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            PlayerImageView(
                player: realPlayer,
                size: configuration.size,
                team: pick.team
            )
            .applyImageStyling(configuration: configuration)
        } else {
            PlayerImageView(
                player: pick.player,
                size: configuration.size,
                team: pick.team
            )
            .applyImageStyling(configuration: configuration)
        }
    }
    
    @ViewBuilder
    private func buildURLImage(url: URL) -> some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(configuration.fallbackColor)
                .overlay(
                    Text(configuration.fallbackText)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
        .frame(width: configuration.size, height: configuration.size)
        .applyImageStyling(configuration: configuration)
    }
}

/// **Player Image Configuration**
struct PlayerImageConfiguration {
    let imageSource: PlayerImageSource
    let size: CGFloat
    let team: NFLTeam?
    let borderStyle: ImageBorderStyle
    let fallbackColor: Color
    let fallbackText: String
    
    init(
        imageSource: PlayerImageSource,
        size: CGFloat,
        team: NFLTeam? = nil,
        borderStyle: ImageBorderStyle = .none,
        fallbackColor: Color? = nil,
        fallbackText: String = "?"
    ) {
        self.imageSource = imageSource
        self.size = size
        self.team = team
        self.borderStyle = borderStyle
        self.fallbackColor = fallbackColor ?? team?.primaryColor ?? .gray
        self.fallbackText = fallbackText
    }
    
    /// **Factory for Sleeper Player**
    static func sleeper(
        player: SleeperPlayer,
        size: CGFloat,
        borderStyle: ImageBorderStyle = .none
    ) -> PlayerImageConfiguration {
        let team = NFLTeam.team(for: player.team ?? "")
        return PlayerImageConfiguration(
            imageSource: .sleeper(player),
            size: size,
            team: team,
            borderStyle: borderStyle,
            fallbackText: player.firstName?.prefix(1).uppercased() ?? "?"
        )
    }
    
    /// **Factory for Enhanced Pick**
    static func enhancedPick(
        pick: EnhancedPick,
        size: CGFloat,
        borderStyle: ImageBorderStyle = .none
    ) -> PlayerImageConfiguration {
        PlayerImageConfiguration(
            imageSource: .enhanced(pick),
            size: size,
            team: pick.team,
            borderStyle: borderStyle,
            fallbackText: pick.player.firstName?.prefix(1).uppercased() ?? "?"
        )
    }
}

/// **Player Image Source**
enum PlayerImageSource {
    case sleeper(SleeperPlayer)
    case enhanced(EnhancedPick)
    case url(URL)
}

/// **Image Border Style**
enum ImageBorderStyle {
    case none
    case position(String) // Border color based on position
    case team(NFLTeam) // Border color based on team
    case custom(Color, CGFloat) // Custom color and width
}

/// **Image Styling View Modifier**
struct ImageStylingModifier: ViewModifier {
    let configuration: PlayerImageConfiguration
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    func body(content: Content) -> some View {
        switch configuration.borderStyle {
        case .none:
            content.clipShape(Circle())
            
        case .position(let position):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            colorService.positionColor(for: position).opacity(0.6),
                            lineWidth: 2
                        )
                )
                
        case .team(let team):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(team.primaryColor.opacity(0.6), lineWidth: 2)
                )
                
        case .custom(let color, let width):
            content
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: width)
                )
        }
    }
}

extension View {
    func applyImageStyling(configuration: PlayerImageConfiguration) -> some View {
        self.modifier(ImageStylingModifier(configuration: configuration))
    }
}

/// **Unified Position Badge**
/// **Standardized position badges across all card types**
struct UnifiedPositionBadge: View {
    let configuration: PositionBadgeConfiguration
    
    var body: some View {
        Text(configuration.displayText)
            .font(.system(size: configuration.fontSize, weight: configuration.fontWeight))
            .foregroundColor(.white)
            .padding(.horizontal, configuration.horizontalPadding)
            .padding(.vertical, configuration.verticalPadding)
            .background(
                Group {
                    switch configuration.shape {
                    case .capsule:
                        Capsule().fill(configuration.backgroundColor)
                    case .roundedRectangle(let radius):
                        RoundedRectangle(cornerRadius: radius).fill(configuration.backgroundColor)
                    }
                }
            )
    }
}

/// **Position Badge Configuration**
struct PositionBadgeConfiguration {
    let position: String
    let displayText: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let backgroundColor: Color
    let shape: BadgeShapeType
    
    // 🔥 DRY: Use centralized ColorThemeService
    private static let colorService = ColorThemeService.shared
    
    init(
        position: String,
        displayText: String? = nil,
        fontSize: CGFloat = 8,
        fontWeight: Font.Weight = .bold,
        horizontalPadding: CGFloat = 6,
        verticalPadding: CGFloat = 2,
        backgroundColor: Color? = nil,
        shape: BadgeShapeType = .capsule
    ) {
        self.position = position
        self.displayText = displayText ?? position
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backgroundColor = backgroundColor ?? Self.colorService.positionColor(for: position)
        self.shape = shape
    }
    
    /// **Small Badge Factory**
    static func small(position: String) -> PositionBadgeConfiguration {
        PositionBadgeConfiguration(
            position: position,
            fontSize: 8,
            horizontalPadding: 6,
            verticalPadding: 2
        )
    }
    
    /// **Medium Badge Factory**
    static func medium(position: String) -> PositionBadgeConfiguration {
        PositionBadgeConfiguration(
            position: position,
            fontSize: 10,
            horizontalPadding: 8,
            verticalPadding: 3
        )
    }
    
    /// **Large Badge Factory**
    static func large(position: String) -> PositionBadgeConfiguration {
        PositionBadgeConfiguration(
            position: position,
            fontSize: 12,
            horizontalPadding: 10,
            verticalPadding: 4
        )
    }
    
    /// **Positional Rank Badge Factory** (e.g., "RB12", "WR5")
    static func positionalRank(
        position: String,
        rank: String,
        size: BadgeSize = .small
    ) -> PositionBadgeConfiguration {
        let config = PositionBadgeConfiguration(
            position: position,
            displayText: rank
        )
        
        switch size {
        case .small: return config
        case .medium: return medium(position: position).withDisplayText(rank)
        case .large: return large(position: position).withDisplayText(rank)
        }
    }
    
    /// **Update display text**
    func withDisplayText(_ text: String) -> PositionBadgeConfiguration {
        PositionBadgeConfiguration(
            position: position,
            displayText: text,
            fontSize: fontSize,
            fontWeight: fontWeight,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            backgroundColor: backgroundColor,
            shape: shape
        )
    }
}

/// **Badge Size**
enum BadgeSize {
    case small, medium, large
}

/// **Badge Shape Type**
enum BadgeShapeType {
    case capsule
    case roundedRectangle(CGFloat)
}

/// **Unified Pick Number Display**
/// **Standardized pick number formatting across draft card types**
struct UnifiedPickNumberDisplay: View {
    let configuration: PickNumberConfiguration
    
    var body: some View {
        Text(configuration.displayText)
            .font(.system(size: configuration.fontSize, weight: configuration.fontWeight))
            .foregroundColor(configuration.textColor)
            .frame(width: configuration.width, height: configuration.height)
            .background(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(configuration.backgroundColor)
            )
    }
}

/// **Pick Number Configuration**
struct PickNumberConfiguration {
    let displayText: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    let backgroundColor: Color
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    /// **Compact Pick Factory**
    static func compact(round: Int, pick: Int, order: Int) -> PickNumberConfiguration {
        PickNumberConfiguration(
            displayText: "\(round).\(pick).\(order)",
            fontSize: 8,
            fontWeight: .bold,
            textColor: .white,
            backgroundColor: .gpBlue,
            width: 32,
            height: 16,
            cornerRadius: 4
        )
    }
    
    /// **Standard Pick Factory**
    static func standard(round: Int, pick: Int) -> PickNumberConfiguration {
        PickNumberConfiguration(
            displayText: "R\(round) P\(pick)",
            fontSize: 10,
            fontWeight: .bold,
            textColor: .white,
            backgroundColor: .gpGreen,
            width: 50,
            height: 20,
            cornerRadius: 6
        )
    }
}

/// **Shared Player Card Gradient System**
/// **Standardized gradient patterns for consistent theming**
struct PlayerCardGradientSystem {
    
    // 🔥 DRY: Use centralized ColorThemeService
    private static let colorService = ColorThemeService.shared
    
    /// **Position-based gradient**
    static func positionGradient(for position: String) -> LinearGradient {
        let positionColor = colorService.positionColor(for: position)
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.7), location: 0.0),
                .init(color: positionColor.opacity(0.2), location: 0.5),
                .init(color: Color.black.opacity(0.8), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// **Team-based gradient**
    static func teamGradient(for team: NFLTeam?) -> LinearGradient {
        guard let team = team else {
            return LinearGradient(
                colors: [Color.black.opacity(0.7), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.7), location: 0.0),
                .init(color: team.primaryColor.opacity(0.3), location: 0.5),
                .init(color: Color.black.opacity(0.8), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// **Performance-based gradient** (for scoring/stats)
    static func performanceGradient(score: Double, maxScore: Double) -> LinearGradient {
        let percentage = maxScore > 0 ? score / maxScore : 0
        let performanceColor: Color
        
        if percentage >= 0.8 { performanceColor = .gpGreen }
        else if percentage >= 0.5 { performanceColor = .blue }
        else if percentage >= 0.25 { performanceColor = .orange }
        else { performanceColor = .red }
        
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.7), location: 0.0),
                .init(color: performanceColor.opacity(0.3), location: 0.5),
                .init(color: Color.black.opacity(0.8), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}