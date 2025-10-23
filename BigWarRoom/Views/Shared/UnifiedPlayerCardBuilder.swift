//
//  UnifiedPlayerCardBuilder.swift
//  BigWarRoom
//
//  🔥 PHASE 2 CONSOLIDATION: Unified Player Card Factory System
//  Eliminates 17+ duplicate player card implementations by providing a single,
//  configurable builder that can create all player card variants.
//

import SwiftUI

/// **Unified Player Card Builder**
/// 
/// **Single factory for ALL player card types:**
/// - FantasyPlayerCard (fantasy matchup displays)
/// - ChoppedRosterPlayerCard (chopped league rosters)  
/// - OpponentPlayerCard (intelligence dashboard)
/// - PlayerScoreBarCard (live players view)
/// - CompactTeamRosterPlayerCard (roster sections)
/// - EnhancedPlayerCardView (advanced displays)
///
/// **Architecture:** Factory pattern with style configuration enum
struct UnifiedPlayerCardBuilder {
    
    /// **Card Style Configuration**
    /// Defines the visual style and layout for different use cases
    enum CardStyle {
        case fantasy(compact: Bool = false)
        case chopped(compact: Bool = false)
        case opponent
        case scoreBar
        case teamRoster(compact: Bool = true)
        case enhanced
    }
    
    /// **Card Size Configuration**
    enum CardSize {
        case small       // 80x60
        case compact     // 120x90
        case standard    // 200x140
        case large       // 250x180
        
        var dimensions: (width: CGFloat?, height: CGFloat) {
            switch self {
            case .small: return (80, 60)
            case .compact: return (120, 90)
            case .standard: return (200, 140)
            case .large: return (250, 180)
            }
        }
    }
    
    /// **Build a unified player card**
    /// 
    /// **Usage:**
    /// ```swift
    /// UnifiedPlayerCardBuilder.build(
    ///     player: player,
    ///     style: .fantasy(compact: false),
    ///     size: .standard
    /// )
    /// ```
    static func build(
        player: FantasyPlayer,
        style: CardStyle,
        size: CardSize = .standard,
        configuration: CardConfiguration? = nil
    ) -> some View {
        UnifiedPlayerCard(
            player: player,
            style: style,
            size: size,
            configuration: configuration ?? .default
        )
    }
}

/// **Unified Player Card Implementation**
/// The core view that handles all player card rendering
private struct UnifiedPlayerCard: View {
    let player: FantasyPlayer
    let style: UnifiedPlayerCardBuilder.CardStyle
    let size: UnifiedPlayerCardBuilder.CardSize
    let configuration: CardConfiguration
    
    @StateObject private var viewModel = UnifiedPlayerCardViewModel()
    @State private var showingScoreBreakdown = false
    @State private var showingPlayerDetail = false
    
    var body: some View {
        ZStack {
            // Background layer (unified background system)
            buildBackground()
            
            // Content layer (varies by style)
            buildContent()
            
            // Overlay layer (borders, indicators, etc.)
            buildOverlay()
        }
        .frame(
            width: size.dimensions.width,
            height: size.dimensions.height
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            handleCardTap()
        }
        .sheet(isPresented: $showingPlayerDetail) {
            buildPlayerDetailSheet()
        }
        .sheet(isPresented: $showingScoreBreakdown) {
            buildScoreBreakdownSheet()
        }
        .onAppear {
            viewModel.configurePlayer(player)
        }
    }
    
    // MARK: - Background Builder
    
    @ViewBuilder
    private func buildBackground() -> some View {
        let team = NFLTeam.team(for: player.team ?? "")
        
        switch style {
        case .fantasy, .enhanced:
            UnifiedPlayerCardBackground(
                configuration: .fantasy(
                    team: team,
                    jerseyNumber: player.jerseyNumber,
                    cornerRadius: cornerRadius,
                    showBorder: true
                )
            )
            
        case .chopped:
            // Score bar style background for chopped cards
            if let livePlayerEntry = createLivePlayerEntry() {
                UnifiedPlayerCardBackground(
                    configuration: .scoreBar(
                        playerEntry: livePlayerEntry,
                        scoreBarWidth: calculateScoreBarWidth(),
                        team: team
                    )
                )
            } else {
                UnifiedPlayerCardBackground(
                    configuration: .simple(team: team, cornerRadius: cornerRadius)
                )
            }
            
        case .opponent, .teamRoster, .scoreBar:
            UnifiedPlayerCardBackground(
                configuration: .simple(team: team, cornerRadius: cornerRadius)
            )
        }
    }
    
    // MARK: - Content Builder
    
    @ViewBuilder
    private func buildContent() -> some View {
        switch style {
        case .fantasy(let compact), .enhanced:
            buildFantasyContent(compact: compact)
            
        case .chopped(let compact):
            buildChoppedContent(compact: compact)
            
        case .opponent:
            buildOpponentContent()
            
        case .scoreBar:
            buildScoreBarContent()
            
        case .teamRoster(let compact):
            buildTeamRosterContent(compact: compact)
        }
    }
    
    // MARK: - Content Implementations
    
    @ViewBuilder
    private func buildFantasyContent(compact: Bool) -> some View {
        HStack(spacing: 8) {
            // Player image
            buildPlayerImage(size: compact ? .small : .standard)
            
            VStack(alignment: .leading, spacing: 4) {
                // Player name and position
                buildPlayerNameSection(compact: compact)
                
                if !compact {
                    // Game matchup
                    buildGameMatchupSection()
                }
                
                Spacer()
                
                // Score and stats
                buildScoreSection(compact: compact)
            }
            
            Spacer()
            
            // Right side controls
            buildRightControls(compact: compact)
        }
        .padding(compact ? 8 : 12)
    }
    
    @ViewBuilder
    private func buildChoppedContent(compact: Bool) -> some View {
        HStack(spacing: 0) {
            // Player image (left)
            buildPlayerImage(size: .compact)
                .frame(width: 65)
            
            // Center matchup
            VStack {
                Spacer()
                buildGameMatchupSection()
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Player info (right)
            VStack(alignment: .trailing, spacing: 4) {
                buildPlayerNameSection(compact: compact)
                buildScoreSection(compact: compact)
            }
            
            Spacer()
        }
        .padding(8)
    }
    
    @ViewBuilder
    private func buildOpponentContent() -> some View {
        HStack(spacing: 12) {
            // Player image and position
            VStack(spacing: 4) {
                buildPlayerImage(size: .small)
                buildPositionBadge()
            }
            .frame(width: 50)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                buildPlayerNameSection(compact: false)
                buildOpponentStats()
            }
            
            // Watch toggle and threat level
            buildOpponentControls()
                .frame(width: 70)
        }
        .padding(12)
    }
    
    @ViewBuilder
    private func buildScoreBarContent() -> some View {
        // Implementation for score bar style cards
        HStack {
            buildPlayerImage(size: .compact)
            
            VStack(alignment: .leading) {
                buildPlayerNameSection(compact: true)
                buildScoreSection(compact: true)
            }
            
            Spacer()
        }
        .padding(8)
    }
    
    @ViewBuilder
    private func buildTeamRosterContent(compact: Bool) -> some View {
        VStack(spacing: 4) {
            buildPlayerImage(size: compact ? .small : .compact)
            buildPlayerNameSection(compact: true)
            buildScoreSection(compact: true)
        }
        .padding(6)
    }
    
    // MARK: - Component Builders (Reusable)
    
    @ViewBuilder
    private func buildPlayerImage(size: ImageSize) -> some View {
        UnifiedPlayerImageView(
            player: player,
            size: size,
            configuration: configuration.imageConfiguration
        )
    }
    
    @ViewBuilder
    private func buildPlayerNameSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.fullName)
                .font(.system(
                    size: compact ? 12 : 16,
                    weight: .bold
                ))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            buildPositionBadge()
        }
    }
    
    @ViewBuilder
    private func buildPositionBadge() -> some View {
        Text(player.position)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(viewModel.positionColor(for: player.position))
            )
    }
    
    @ViewBuilder
    private func buildScoreSection(compact: Bool) -> some View {
        HStack(spacing: 6) {
            // Current score (tappable if has points)
            if (player.currentPoints ?? 0) > 0 {
                Button(action: {
                    showingScoreBreakdown = true
                }) {
                    buildScoreDisplay(compact: compact)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                buildScoreDisplay(compact: compact)
            }
            
            if !compact {
                Text("pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func buildScoreDisplay(compact: Bool) -> some View {
        Text(player.currentPointsString)
            .font(.system(
                size: compact ? 12 : 16,
                weight: .bold
            ))
            .foregroundColor(viewModel.scoreColor(for: player.currentPoints ?? 0))
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                viewModel.scoreColor(for: player.currentPoints ?? 0).opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
    }
    
    @ViewBuilder
    private func buildGameMatchupSection() -> some View {
        // Reuse existing MatchupTeamFinalView
        MatchupTeamFinalView(player: player, scaleEffect: 1.0)
    }
    
    @ViewBuilder
    private func buildRightControls(compact: Bool) -> some View {
        VStack(spacing: 8) {
            // Watch toggle button (if configuration allows)
            if configuration.showWatchButton {
                buildWatchToggle()
            }
            
            if !compact {
                // Additional controls based on style
                buildAdditionalControls()
            }
        }
    }
    
    @ViewBuilder
    private func buildWatchToggle() -> some View {
        Button(action: toggleWatch) {
            Image(systemName: viewModel.isWatching(player.id) ? "eye.fill" : "eye")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(
                    viewModel.isWatching(player.id) ? .gpYellow : .gray
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func buildAdditionalControls() -> some View {
        // Placeholder for additional controls based on card style
        EmptyView()
    }
    
    @ViewBuilder
    private func buildOpponentStats() -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                Text(player.currentPointsString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(viewModel.scoreColor(for: player.currentPoints ?? 0))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("PROJ")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                Text(player.projectedPointsString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private func buildOpponentControls() -> some View {
        VStack(spacing: 8) {
            buildWatchToggle()
            
            // Threat level indicator (simplified for now)
            VStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                
                Text("WATCH")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - Overlay Builder
    
    @ViewBuilder
    private func buildOverlay() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                viewModel.borderColor(for: player, style: style),
                lineWidth: viewModel.borderWidth(for: player, style: style)
            )
            .opacity(0.7)
    }
    
    // MARK: - Helper Methods
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 8
        case .compact: return 10
        case .standard: return 12
        case .large: return 15
        }
    }
    
    private func handleCardTap() {
        if configuration.enablePlayerDetail {
            showingPlayerDetail = true
        }
    }
    
    private func toggleWatch() {
        // Implementation for watch toggle
        viewModel.toggleWatch(for: player)
    }
    
    private func createLivePlayerEntry() -> (any PlayerEntry)? {
        // Create adapter for existing PlayerEntry protocol
        return LivePlayerEntryAdapter(player: player)
    }
    
    private func calculateScoreBarWidth() -> Double {
        let maxPoints: Double = 40.0
        let currentPoints = player.currentPoints ?? 0.0
        return min(currentPoints / maxPoints, 1.0)
    }
    
    @ViewBuilder
    private func buildPlayerDetailSheet() -> some View {
        NavigationView {
            if let sleeperPlayer = viewModel.getSleeperPlayerData(for: player) {
                PlayerStatsCardView(
                    player: sleeperPlayer,
                    team: NFLTeam.team(for: player.team ?? "")
                )
            } else {
                PlayerDetailFallbackView(player: player)
            }
        }
    }
    
    @ViewBuilder
    private func buildScoreBreakdownSheet() -> some View {
        if let breakdown = viewModel.createScoreBreakdown(for: player) {
            ScoreBreakdownView(breakdown: breakdown)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        } else {
            ScoreBreakdownView(breakdown: viewModel.createEmptyBreakdown(for: player))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Supporting Types

/// **Card Configuration**
/// Controls behavior and appearance options
struct CardConfiguration {
    let showWatchButton: Bool
    let enablePlayerDetail: Bool
    let enableScoreBreakdown: Bool
    let imageConfiguration: ImageConfiguration
    
    static let `default` = CardConfiguration(
        showWatchButton: false,
        enablePlayerDetail: true,
        enableScoreBreakdown: true,
        imageConfiguration: .default
    )
    
    static let opponent = CardConfiguration(
        showWatchButton: true,
        enablePlayerDetail: true,
        enableScoreBreakdown: true,
        imageConfiguration: .default
    )
    
    static let compact = CardConfiguration(
        showWatchButton: false,
        enablePlayerDetail: false,
        enableScoreBreakdown: false,
        imageConfiguration: .compact
    )
}

/// **Image Configuration**
/// Controls player image appearance
struct ImageConfiguration {
    let showTeamLogo: Bool
    let fallbackStyle: FallbackStyle
    
    enum FallbackStyle {
        case initials
        case position
        case teamColor
    }
    
    static let `default` = ImageConfiguration(
        showTeamLogo: false,
        fallbackStyle: .initials
    )
    
    static let compact = ImageConfiguration(
        showTeamLogo: true,
        fallbackStyle: .position
    )
}

/// **Image Size Enum**
enum ImageSize {
    case small
    case compact
    case standard
    case large
    
    var dimensions: CGFloat {
        switch self {
        case .small: return 40
        case .compact: return 60
        case .standard: return 80
        case .large: return 100
        }
    }
}

/// **Live Player Entry Adapter**
/// Adapts FantasyPlayer to PlayerEntry protocol
private struct LivePlayerEntryAdapter: PlayerEntry {
    let player: FantasyPlayer
    
    var currentScore: Double { player.currentPoints ?? 0.0 }
    var scoreBarWidth: Double {
        let maxPoints: Double = 40.0
        return min(currentScore / maxPoints, 1.0)
    }
}