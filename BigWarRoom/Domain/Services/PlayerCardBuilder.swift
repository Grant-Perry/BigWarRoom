//
//  PlayerCardBuilder.swift
//  BigWarRoom
//
//  🔥 DRY CONSOLIDATION: Unified player card system
//  Eliminates 70%+ duplication across 8+ player card variants
//

import SwiftUI

// MARK: - Unified Player Card Data

/// **Unified Player Card Data**
/// **Single data interface for all player card types**
struct PlayerCardData {
    // Core player info
    let playerID: String
    let fullName: String
    let shortName: String
    let position: String
    let team: String?
    let jerseyNumber: String?
    
    // Sleeper player reference (optional)
    let sleeperPlayer: SleeperPlayer?
    
    // Scoring data
    let currentScore: Double
    let projectedScore: Double?
    let previousScore: Double?
    
    // Status flags
    let isStarter: Bool
    let isLive: Bool
    let isOnBye: Bool
    let injuryStatus: String?
    
    // Context-specific data
    let leagueName: String?
    let leagueSource: String?
    let opponentTeam: String?
    let matchupInfo: String?
    
    // Stats and performance
    let statLine: String?
    let threatLevel: PlayerThreatLevel?
    let positionalRank: String?
    
    // Factory: Create from FantasyPlayer
    static func from(
        _ player: FantasyPlayer,
        sleeperPlayer: SleeperPlayer? = nil,
        leagueName: String? = nil,
        leagueSource: String? = nil,
        isLive: Bool = false,
        isOnBye: Bool = false,
        statLine: String? = nil
    ) -> PlayerCardData {
        PlayerCardData(
            playerID: player.id,
            fullName: player.fullName,
            shortName: player.shortName,
            position: player.position,
            team: player.team,
            jerseyNumber: player.jerseyNumber,
            sleeperPlayer: sleeperPlayer,
            currentScore: player.currentPoints ?? 0.0,
            projectedScore: player.projectedPoints,
            previousScore: nil,
            isStarter: player.isStarter,
            isLive: isLive,
            isOnBye: isOnBye,
            injuryStatus: player.injuryStatus,
            leagueName: leagueName,
            leagueSource: leagueSource,
            opponentTeam: nil,
            matchupInfo: nil,
            statLine: statLine,
            threatLevel: nil,
            positionalRank: sleeperPlayer?.positionalRank
        )
    }
    
    // Factory: Create from OpponentPlayer
    static func from(_ opponent: OpponentPlayer) -> PlayerCardData {
        PlayerCardData(
            playerID: opponent.player.id,
            fullName: opponent.player.fullName,
            shortName: opponent.player.shortName,
            position: opponent.position,
            team: opponent.team,
            jerseyNumber: opponent.player.jerseyNumber,
            sleeperPlayer: nil,
            currentScore: opponent.currentScore,
            projectedScore: opponent.projectedScore,
            previousScore: nil,
            isStarter: opponent.isStarter,
            isLive: false,
            isOnBye: false,
            injuryStatus: opponent.player.injuryStatus,
            leagueName: nil,
            leagueSource: nil,
            opponentTeam: nil,
            matchupInfo: nil,
            statLine: nil,
            threatLevel: opponent.threatLevel,
            positionalRank: nil
        )
    }
}

// MARK: - Player Card Layout

/// **Player Card Layout Variants**
enum PlayerCardLayout {
    case vertical          // Standard vertical card (FantasyPlayerCard, OpponentPlayerCard)
    case horizontal        // Horizontal bar (PlayerScoreBarCard, ChoppedRosterPlayerCard)
    case compact           // Small card for lists (EnhancedPlayerCardView)
    case draft             // Draft pick display (DraftPickCard, CompactTeamRosterPlayerCard)
    
    var cardHeight: CGFloat {
        switch self {
        case .vertical: return 125
        case .horizontal: return 110
        case .compact: return 60
        case .draft: return 80
        }
    }
    
    var cardWidth: CGFloat? {
        switch self {
        case .vertical: return 190
        case .horizontal: return nil // Full width
        case .compact: return nil // Full width
        case .draft: return nil // Full width
        }
    }
}

// MARK: - Player Card Context

/// **Player Card Context**
/// **Different contexts determine which sections to show**
enum PlayerCardContext {
    case fantasy           // Fantasy matchup context
    case roster            // Team roster context
    case opponent          // Opponent intelligence context
    case liveScoring       // All Live Players context
    case draft             // Draft context
    case chopped           // Chopped league context
    
    var showsWatchButton: Bool {
        switch self {
        case .fantasy, .opponent, .liveScoring, .chopped: return true
        case .roster, .draft: return false
        }
    }
    
    var showsScoreBreakdown: Bool {
        switch self {
        case .fantasy, .liveScoring, .chopped: return true
        case .roster, .opponent, .draft: return false
        }
    }
    
    var showsGameStatus: Bool {
        switch self {
        case .liveScoring, .chopped: return true
        case .fantasy, .roster, .opponent, .draft: return false
        }
    }
    
    var showsThreatLevel: Bool {
        switch self {
        case .opponent: return true
        default: return false
        }
    }
}

// MARK: - Unified Player Card Configuration

/// **Unified Player Card Configuration**
/// **Single configuration object for all card variants**
struct PlayerCardConfiguration {
    let data: PlayerCardData
    let layout: PlayerCardLayout
    let context: PlayerCardContext
    
    // Optional overrides
    let customBackground: BackgroundConfiguration?
    let hideElements: [CardElement]
    let onTap: (() -> Void)?
    let onScoreBreakdownTap: (() -> Void)?
    let onWatchToggle: ((Bool) -> Void)?
    
    init(
        data: PlayerCardData,
        layout: PlayerCardLayout = .vertical,
        context: PlayerCardContext = .fantasy,
        customBackground: BackgroundConfiguration? = nil,
        hideElements: [CardElement] = [],
        onTap: (() -> Void)? = nil,
        onScoreBreakdownTap: (() -> Void)? = nil,
        onWatchToggle: ((Bool) -> Void)? = nil
    ) {
        self.data = data
        self.layout = layout
        self.context = context
        self.customBackground = customBackground
        self.hideElements = hideElements
        self.onTap = onTap
        self.onScoreBreakdownTap = onScoreBreakdownTap
        self.onWatchToggle = onWatchToggle
    }
    
    func shouldShow(_ element: CardElement) -> Bool {
        !hideElements.contains(element)
    }
}

/// **Card Elements**
/// **Toggleable card sections**
enum CardElement {
    case playerImage
    case teamLogo
    case jerseyNumber
    case positionBadge
    case score
    case stats
    case gameStatus
    case watchButton
    case threatLevel
    case injuryBadge
}

// MARK: - Unified Player Card View

/// **Unified Player Card View**
/// **Single view that renders all player card variants**
struct UnifiedPlayerCard: View {
    let configuration: PlayerCardConfiguration
    
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(NFLGameDataService.self) private var nflGameDataService
    
    var body: some View {
        Group {
            switch configuration.layout {
            case .vertical:
                buildVerticalCard()
            case .horizontal:
                buildHorizontalCard()
            case .compact:
                buildCompactCard()
            case .draft:
                buildDraftCard()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            configuration.onTap?()
        }
    }
    
    // MARK: - Layout Builders
    
    @ViewBuilder
    private func buildVerticalCard() -> some View {
        ZStack(alignment: .topLeading) {
            // Background
            buildBackground()
            
            // Team logo overlay
            if configuration.shouldShow(.teamLogo) {
                buildTeamLogoOverlay()
            }
            
            // Jersey number
            if configuration.shouldShow(.jerseyNumber),
               let jerseyNumber = configuration.data.jerseyNumber {
                buildJerseyNumberOverlay(jerseyNumber)
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                // Header: Player image + position badge
                buildVerticalHeader()
                
                Spacer()
                
                // Body: Player name + score
                buildVerticalBody()
                
                // Footer: Stats + game status
                buildVerticalFooter()
            }
            .padding(12)
            
            // Overlay elements: Watch button, injury badge
            buildOverlayElements()
        }
        .frame(width: configuration.layout.cardWidth, height: configuration.layout.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func buildHorizontalCard() -> some View {
        ZStack(alignment: .leading) {
            // Background
            buildBackground()
            
            HStack(spacing: 0) {
                // Player image section (left)
                if configuration.shouldShow(.playerImage) {
                    buildPlayerImageSection()
                        .frame(width: 80)
                }
                
                // Main content (center)
                VStack(alignment: .leading, spacing: 4) {
                    buildHorizontalBody()
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 8)
                
                // Score section (right)
                if configuration.shouldShow(.score) {
                    buildScoreSection()
                        .padding(.trailing, 12)
                }
            }
            
            // Overlay elements
            buildOverlayElements()
        }
        .frame(height: configuration.layout.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func buildCompactCard() -> some View {
        HStack(spacing: 12) {
            // Player image
            if configuration.shouldShow(.playerImage) {
                buildCompactPlayerImage()
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                PlayerNameDisplay(
                    playerName: configuration.data.fullName,
                    style: .compact
                )
                
                HStack(spacing: 8) {
                    // Position badge
                    if configuration.shouldShow(.positionBadge) {
                        UnifiedPositionBadge(
                            configuration: .small(position: configuration.data.position)
                        )
                    }
                    
                    // Score
                    if configuration.shouldShow(.score) {
                        Text("\(String(format: "%.1f", configuration.data.currentScore)) pts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(buildBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private func buildDraftCard() -> some View {
        // Similar to CompactCard but with draft-specific elements
        buildCompactCard()
    }
    
    // MARK: - Section Builders
    
    @ViewBuilder
    private func buildVerticalHeader() -> some View {
        HStack {
            if configuration.shouldShow(.playerImage) {
                buildPlayerImageSection()
            }
            
            Spacer()
            
            if configuration.shouldShow(.positionBadge) {
                UnifiedPositionBadge(
                    configuration: .medium(position: configuration.data.position)
                )
            }
        }
    }
    
    @ViewBuilder
    private func buildVerticalBody() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Player name
            PlayerNameDisplay(
                playerName: configuration.data.fullName,
                style: .standard
            )
            
            // Score
            if configuration.shouldShow(.score) {
                if let onScoreTap = configuration.onScoreBreakdownTap {
                    ScoreDisplayButton(
                        score: configuration.data.currentScore,
                        onTap: onScoreTap,
                        style: .standard
                    )
                } else {
                    Text("\(String(format: "%.1f", configuration.data.currentScore)) pts")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.gpGreen)
                }
            }
        }
    }
    
    @ViewBuilder
    private func buildVerticalFooter() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Stats
            if configuration.shouldShow(.stats), let statLine = configuration.data.statLine {
                StatDisplayText(text: statLine, style: .standard)
            }
            
            // Game status
            if configuration.shouldShow(.gameStatus) {
                buildGameStatusIndicator()
            }
        }
    }
    
    @ViewBuilder
    private func buildHorizontalBody() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Player name + position
            HStack(spacing: 8) {
                PlayerNameDisplay(
                    playerName: configuration.data.shortName,
                    style: .standard
                )
                
                if configuration.shouldShow(.positionBadge) {
                    UnifiedPositionBadge(
                        configuration: .small(position: configuration.data.position)
                    )
                }
            }
            
            // Stats or game status
            if configuration.shouldShow(.stats), let statLine = configuration.data.statLine {
                StatDisplayText(text: statLine, style: .standard)
            } else if configuration.shouldShow(.gameStatus) {
                buildGameStatusIndicator()
            }
        }
    }
    
    // MARK: - Component Builders
    
    @ViewBuilder
    private func buildBackground() -> some View {
        if let customBg = configuration.customBackground {
            UnifiedPlayerCardBackground(configuration: customBg)
        } else {
            // Default background based on context
            let team = NFLTeam.team(for: configuration.data.team ?? "")
            UnifiedPlayerCardBackground(
                configuration: .fantasy(
                    team: team,
                    jerseyNumber: configuration.data.jerseyNumber,
                    isLive: configuration.data.isLive,
                    isOnBye: configuration.data.isOnBye
                )
            )
        }
    }
    
    @ViewBuilder
    private func buildPlayerImageSection() -> some View {
        if let sleeperPlayer = configuration.data.sleeperPlayer {
            UnifiedPlayerImageView(
                configuration: .sleeper(
                    player: sleeperPlayer,
                    size: 60,
                    borderStyle: .position(configuration.data.position)
                )
            )
        } else {
            // Fallback image
            Circle()
                .fill(ColorThemeService.shared.positionColor(for: configuration.data.position).opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(configuration.data.fullName.prefix(2)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }
    
    @ViewBuilder
    private func buildCompactPlayerImage() -> some View {
        if let sleeperPlayer = configuration.data.sleeperPlayer {
            UnifiedPlayerImageView(
                configuration: .sleeper(
                    player: sleeperPlayer,
                    size: 40,
                    borderStyle: .position(configuration.data.position)
                )
            )
        } else {
            Circle()
                .fill(ColorThemeService.shared.positionColor(for: configuration.data.position).opacity(0.3))
                .frame(width: 40, height: 40)
        }
    }
    
    @ViewBuilder
    private func buildScoreSection() -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let onScoreTap = configuration.onScoreBreakdownTap {
                ScoreDisplayButton(
                    score: configuration.data.currentScore,
                    onTap: onScoreTap,
                    style: .large
                )
            } else {
                Text("\(String(format: "%.1f", configuration.data.currentScore))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
            }
            
            if let projected = configuration.data.projectedScore {
                Text("Proj: \(String(format: "%.1f", projected))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func buildTeamLogoOverlay() -> some View {
        HStack {
            Spacer()
            VStack {
                let team = NFLTeam.team(for: configuration.data.team ?? "")
                TeamLogoOverlay(
                    team: team,
                    opacity: configuration.data.isLive ? 0.4 : 0.25
                )
                Spacer()
            }
        }
        .padding(.top, 20)
        .padding(.trailing, 15)
    }
    
    @ViewBuilder
    private func buildJerseyNumberOverlay(_ jerseyNumber: String) -> some View {
        HStack {
            Spacer()
            VStack {
                let team = NFLTeam.team(for: configuration.data.team ?? "")
                JerseyNumberOverlay(
                    jerseyNumber: jerseyNumber,
                    teamColor: team?.primaryColor ?? .white
                )
                Spacer()
            }
        }
        .padding(.trailing, 60)
        .padding(.top, 15)
    }
    
    @ViewBuilder
    private func buildOverlayElements() -> some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    // Watch button
                    if configuration.shouldShow(.watchButton), configuration.context.showsWatchButton {
                        // 🔥 FIX: Pass watchService from shared instance
                        WatchToggleButton(
                            playerID: configuration.data.playerID,
                            watchService: PlayerWatchService.shared,
                            onToggle: configuration.onWatchToggle
                        )
                    }
                    
                    // Injury badge
                    if configuration.shouldShow(.injuryBadge),
                       let injuryStatus = configuration.data.injuryStatus,
                       !injuryStatus.isEmpty {
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .scaleEffect(0.8)
                    }
                    
                    // Threat level (for opponent context)
                    if configuration.shouldShow(.threatLevel),
                       let threatLevel = configuration.data.threatLevel {
                        buildThreatLevelIndicator(threatLevel)
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func buildGameStatusIndicator() -> some View {
        // Determine game status from NFLGameDataService
        if let team = configuration.data.team,
           let gameInfo = nflGameDataService.getGameInfo(for: team) {
            // 🔥 FIX: Use PlayerCardGameStatus to avoid ambiguity
            let status: PlayerCardGameStatus = GameStatusService.shared.isGameLive(for: team) ?
                .live(gameInfo.statusBadgeText) : .final
            
            PlayerCardGameStatusBadge(status: status, style: .standard)
        }
    }
    
    @ViewBuilder
    private func buildThreatLevelIndicator(_ threatLevel: PlayerThreatLevel) -> some View {
        VStack(spacing: 2) {
            Image(systemName: threatLevel.sfSymbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(threatLevel.color)
            
            Text(threatLevel.rawValue)
                .font(.system(size: 7, weight: .black))
                .foregroundColor(threatLevel.color)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(threatLevel.color.opacity(0.2))
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}