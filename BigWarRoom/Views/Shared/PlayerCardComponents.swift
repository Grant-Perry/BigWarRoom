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

// MARK: - REMOVED: ImageStylingModifier moved to /Extensions/View+Extensions.swift

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

// MARK: - 🔥 NEW: Missing Reusable Components

/// **Watch Toggle Button Component**
/// **Standardized watch/unwatch button across all player cards**
struct WatchToggleButton: View {
    let playerID: String
    // 🔥 FIX: Make watchService a parameter instead of using .shared in default
    let watchService: PlayerWatchService
    let size: CGFloat
    let onToggle: ((Bool) -> Void)?
    
    init(
        playerID: String,
        // 🔥 FIX: Remove default value that causes MainActor isolation issue
        watchService: PlayerWatchService,
        size: CGFloat = 24,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self.playerID = playerID
        self.watchService = watchService
        self.size = size
        self.onToggle = onToggle
    }
    
    private var isWatching: Bool {
        watchService.isWatching(playerID)
    }
    
    var body: some View {
        Button(action: {
            // Toggle watch status
            let newStatus = !isWatching
            onToggle?(newStatus)
        }) {
            Image(systemName: isWatching ? "eye.fill" : "eye")
                .font(.system(size: size * 0.67, weight: .medium))
                .foregroundColor(isWatching ? .gpOrange : .white.opacity(0.6))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isWatching ? Color.gpOrange.opacity(0.2) : Color.black.opacity(0.5))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// **Score Display Component**
/// **Standardized score display with breakdown button**
struct ScoreDisplayButton: View {
    let score: Double
    let onTap: () -> Void
    let style: ScoreDisplayStyle
    
    // 🔥 DRY: Use ColorThemeService for score colors
    private let colorService = ColorThemeService.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(formatScore(score))
                    .font(style.scoreFont)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                Text("pts")
                    .font(style.labelFont)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(scoreColor.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(scoreColor.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var scoreColor: Color {
        if score >= 20 { return .gpGreen }
        else if score >= 12 { return .blue }
        else if score >= 8 { return .orange }
        else { return .gpRedPink }
    }
    
    private func formatScore(_ score: Double) -> String {
        String(format: "%.1f", score)
    }
}

/// **Score Display Style**
struct ScoreDisplayStyle {
    let scoreFont: Font
    let labelFont: Font
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    
    static var standard: ScoreDisplayStyle {
        ScoreDisplayStyle(
            scoreFont: .callout,
            labelFont: .caption,
            horizontalPadding: 8,
            verticalPadding: 4,
            cornerRadius: 6
        )
    }
    
    static var large: ScoreDisplayStyle {
        ScoreDisplayStyle(
            scoreFont: .system(size: 20, weight: .bold),
            labelFont: .caption,
            horizontalPadding: 8,
            verticalPadding: 4,
            cornerRadius: 6
        )
    }
    
    static var compact: ScoreDisplayStyle {
        ScoreDisplayStyle(
            scoreFont: .caption,
            labelFont: .caption2,
            horizontalPadding: 6,
            verticalPadding: 3,
            cornerRadius: 4
        )
    }
}

/// **Player Card Game Status Enum**
/// Note: Different from FantasyModels.GameStatus (which is a struct)
enum PlayerCardGameStatus {
    case live(String)
    case final
    case upcoming
    case inProgress(String)
    
    var displayText: String {
        switch self {
        case .live(let time): return time.isEmpty ? "LIVE" : time
        case .final: return "FINAL"
        case .upcoming: return "UPCOMING"
        case .inProgress(let time): return time
        }
    }
    
    var color: Color {
        switch self {
        case .live, .inProgress: return .red
        case .final: return .gray
        case .upcoming: return .orange
        }
    }
}

/// **Player Card Game Status Badge Component**
struct PlayerCardGameStatusBadge: View {
    let status: PlayerCardGameStatus
    let style: GameStatusBadgeStyle
    
    var body: some View {
        Text(status.displayText)
            .font(style.font)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(status.color)
            )
    }
}

/// **Game Status Badge Style**
struct GameStatusBadgeStyle {
    let font: Font
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let cornerRadius: CGFloat
    
    static var standard: GameStatusBadgeStyle {
        GameStatusBadgeStyle(
            font: .system(size: 10, weight: .bold),
            horizontalPadding: 6,
            verticalPadding: 2,
            cornerRadius: 3
        )
    }
    
    static var large: GameStatusBadgeStyle {
        GameStatusBadgeStyle(
            font: .system(size: 12, weight: .bold),
            horizontalPadding: 10,
            verticalPadding: 3,
            cornerRadius: 8
        )
    }
}

/// **Team Logo Overlay Component**
/// **Large team logo background overlay for player cards**
struct TeamLogoOverlay: View {
    let team: NFLTeam?
    let size: CGFloat
    let opacity: Double
    let offset: CGSize
    
    @Environment(TeamAssetManager.self) private var teamAssets
    
    init(
        team: NFLTeam?,
        size: CGFloat = 140,
        opacity: Double = 0.25,
        offset: CGSize = CGSize(width: 20, height: 15)
    ) {
        self.team = team
        self.size = size
        self.opacity = opacity
        self.offset = offset
    }
    
    var body: some View {
        Group {
            if let team = team {
                teamAssets.logoOrFallback(for: team.id)
                    .frame(width: size, height: size)
                    .opacity(opacity)
                    .offset(x: offset.width, y: offset.height)
            }
        }
    }
}

/// **Jersey Number Overlay Component**
/// **Large jersey number background for player cards**
struct JerseyNumberOverlay: View {
    let jerseyNumber: String
    let teamColor: Color
    let size: CGFloat
    let opacity: Double
    
    init(
        jerseyNumber: String,
        teamColor: Color,
        size: CGFloat = 90,
        opacity: Double = 0.65
    ) {
        self.jerseyNumber = jerseyNumber
        self.teamColor = teamColor
        self.size = size
        self.opacity = opacity
    }
    
    var body: some View {
        Text(jerseyNumber)
            .font(.system(size: size, weight: .black))
            .italic()
            .foregroundColor(teamColor)
            .opacity(opacity)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
    }
}

/// **Stat Display Component**
/// **Standardized stat text display**
struct StatDisplayText: View {
    let text: String
    let style: StatDisplayStyle
    
    var body: some View {
        Text(text)
            .font(style.font)
            .fontWeight(style.fontWeight)
            .foregroundColor(style.textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// **Stat Display Style**
struct StatDisplayStyle {
    let font: Font
    let fontWeight: Font.Weight
    let textColor: Color
    
    static var standard: StatDisplayStyle {
        StatDisplayStyle(
            font: .system(size: 9, weight: .bold),
            fontWeight: .bold,
            textColor: .white
        )
    }
    
    static var prominent: StatDisplayStyle {
        StatDisplayStyle(
            font: .system(size: 11, weight: .bold),
            fontWeight: .bold,
            textColor: .gpGreen
        )
    }
}

/// **Player Name Display Component**
/// **Standardized player name formatting and display**
struct PlayerNameDisplay: View {
    let playerName: String
    let style: PlayerNameStyle
    
    var body: some View {
        Text(formatPlayerName())
            .font(style.font)
            .fontWeight(style.fontWeight)
            .foregroundColor(style.textColor)
            .lineLimit(1)
            .minimumScaleFactor(style.minimumScaleFactor)
    }
    
    private func formatPlayerName() -> String {
        // Smart name formatting: prefer full name, fallback to short name
        let components = playerName.split(separator: " ")
        
        if components.count >= 2 {
            let firstName = String(components[0])
            // If first name is just initial, try to expand
            if firstName.count == 1 {
                return playerName // Keep as-is if already abbreviated
            }
        }
        
        return playerName
    }
}

/// **Player Name Style**
struct PlayerNameStyle {
    let font: Font
    let fontWeight: Font.Weight
    let textColor: Color
    let minimumScaleFactor: CGFloat
    
    static var standard: PlayerNameStyle {
        PlayerNameStyle(
            font: .system(size: 18, weight: .bold),
            fontWeight: .bold,
            textColor: .primary,
            minimumScaleFactor: 0.7
        )
    }
    
    static var large: PlayerNameStyle {
        PlayerNameStyle(
            font: .system(size: 22, weight: .black),
            fontWeight: .black,
            textColor: .primary,
            minimumScaleFactor: 0.6
        )
    }
    
    static var compact: PlayerNameStyle {
        PlayerNameStyle(
            font: .system(size: 14, weight: .bold),
            fontWeight: .bold,
            textColor: .white,
            minimumScaleFactor: 0.8
        )
    }
}