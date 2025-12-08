//
//  UnifiedPlayerCardBackground.swift
//  BigWarRoom
//
//  🔥 PHASE 2 DRY REFACTOR: Unified background system for ALL player cards
//  Consolidates PlayerCardBackgroundView, FantasyPlayerCardBackgroundView, and PlayerScoreBarCardBackgroundView
//  into a single, configurable, reusable component following DRY principles.
//

import SwiftUI

/// **Unified Player Card Background System**
/// 
/// **Handles all player card background patterns:**
/// - Simple team-colored backgrounds (PlayerCardView)
/// - Complex fantasy card backgrounds with gradients (FantasyPlayerCard) 
/// - Score bar backgrounds with performance indicators (PlayerScoreBarCard)
/// - Jersey number overlays and team gradients
/// - Performance indicators and elimination status
///
/// **Architecture:** Single component with configuration enum for different styles
struct UnifiedPlayerCardBackground: View {
    let configuration: BackgroundConfiguration
    
    var body: some View {
        switch configuration.style {
        case .simple:
            buildSimpleBackground()
        case .fantasy:
            buildFantasyBackground()
        case .scoreBar(let entry, let scoreBarWidth):
            buildScoreBarBackground(playerEntry: entry, scoreBarWidth: scoreBarWidth)
        }
    }
    
    // MARK: - Background Styles
    
    /// Simple background for basic player cards
    @ViewBuilder
    private func buildSimpleBackground() -> some View {
        Group {
            if let team = configuration.team {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: configuration.cornerRadius)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: configuration.cornerRadius)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
    }
    
    /// Fantasy card background with gradients and jersey numbers
    @ViewBuilder
    private func buildFantasyBackground() -> some View {
        ZStack {
            // Base background with team gradient
            buildFantasyBaseBackground()
            
            // Optional jersey number overlay
            if let jerseyNumber = configuration.jerseyNumber {
                buildJerseyOverlay(jerseyNumber: jerseyNumber)
            }
            
            // Border overlay
            if configuration.showBorder {
                buildFantasyBorder()
            }
        }
    }
    
    /// Score bar background with performance indicators
    @ViewBuilder 
    private func buildScoreBarBackground(playerEntry: PlayerEntry, scoreBarWidth: Double) -> some View {
        ZStack {
            // Base team background
            buildScoreBarBaseBackground()
            
            // 🚫 COMMENTED OUT: Score bar overlay (animated green bar behind cards)
            // Score bar overlay (only for players with points)
            // if playerEntry.currentScore > 0 {
            //     buildScoreBarOverlay(playerEntry: playerEntry, scoreBarWidth: scoreBarWidth)
            // }
            
            // Performance indicator
            if playerEntry.currentScore > 0 {
                buildPerformanceIndicator(playerEntry: playerEntry)
            }
        }
    }
    
    // MARK: - Fantasy Background Components
    
    @ViewBuilder
    private func buildFantasyBaseBackground() -> some View {
        RoundedRectangle(cornerRadius: configuration.cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        configuration.teamColor.opacity(0.9),
                        Color.black.opacity(0.7), 
                        configuration.teamColor.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: configuration.teamColor.opacity(0.4),
                radius: configuration.shadowRadius,
                x: 0,
                y: 0
            )
    }
    
    @ViewBuilder
    private func buildJerseyOverlay(jerseyNumber: String) -> some View {
        VStack {
            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    Text(jerseyNumber)
                        .font(.system(size: 90, weight: .black))
                        .italic()
                        .foregroundColor(configuration.teamColor)
                        .opacity(0.65)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                }
            }
            .padding(.trailing, 8)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func buildFantasyBorder() -> some View {
        // BYE status takes precedence over live status
        if configuration.isOnBye {
            // 🔥 BYE WEEK: Pink border matching green live border style
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [.gpPink, .gpPink.opacity(0.8), .gpRedPink.opacity(0.6), .gpPink.opacity(0.9), .gpPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
                .opacity(0.9)
                .shadow(
                    color: .gpPink.opacity(0.8),
                    radius: 15,
                    x: 0,
                    y: 0
                )
        } else if configuration.isLive {
            // 🔥 LIVE: Bright green animated border with glow
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )
                .opacity(0.9)
                .shadow(
                    color: .gpGreen.opacity(0.8),
                    radius: 15,
                    x: 0,
                    y: 0
                )
        } else {
            // 🔥 NON-LIVE: Subtle border to indicate not live
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            configuration.teamColor.opacity(0.6),
                            Color.clear,
                            configuration.teamColor.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: configuration.borderWidth
                )
                .opacity(0.5)
        }
    }
    
    // MARK: - Score Bar Components
    
    @ViewBuilder
    private func buildScoreBarBaseBackground() -> some View {
        ZStack {
            // Main gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    configuration.teamColor.opacity(0.9),
                    Color.black.opacity(0.7),
                    configuration.teamColor.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle overlay pattern
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    configuration.teamColor.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Team-specific background overlay
            Group {
                if let team = configuration.team {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(team.backgroundColor.opacity(0.05))
                } else {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(Color(.systemGray6).opacity(0.05))
                }
            }
        }
    }
    
    @ViewBuilder
    private func buildScoreBarOverlay(playerEntry: PlayerEntry, scoreBarWidth: Double) -> some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.clear, location: 0.0),
                                .init(color: scoreBarColor(for: playerEntry).opacity(0.3), location: 0.3),
                                .init(color: scoreBarColor(for: playerEntry).opacity(0.5), location: 0.7),
                                .init(color: scoreBarColor(for: playerEntry).opacity(0.6), location: 0.95),
                                .init(color: scoreBarColor(for: playerEntry).opacity(0.6), location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Subtle overlay
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.03),
                                Color.clear,
                                Color.white.opacity(0.01)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: calculateScoreBarWidth(scoreBarWidth: scoreBarWidth))
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func buildPerformanceIndicator(playerEntry: PlayerEntry) -> some View {
        HStack {
            Spacer()
            VStack {
                Circle()
                    .fill(performanceColor(for: playerEntry))
                    .frame(width: 8, height: 8)
                    .opacity(0.7)
                Spacer()
            }
            .padding(.trailing, 8)
            .padding(.top, 6)
        }
    }
    
    // MARK: - Helper Methods
    
    private func scoreBarColor(for playerEntry: PlayerEntry) -> Color {
        let percentage = playerEntry.scoreBarWidth
        let scoreBarOpacity: Double = 0.35
        
        if percentage >= 0.8 { return .gpGreen.opacity(scoreBarOpacity) }
        else if percentage >= 0.5 { return .blue.opacity(scoreBarOpacity) }
        else if percentage >= 0.25 { return .orange.opacity(scoreBarOpacity) }
        else { return .red.opacity(scoreBarOpacity) }
    }
    
    private func performanceColor(for playerEntry: PlayerEntry) -> Color {
        let percentage = playerEntry.scoreBarWidth
        if percentage >= 0.8 { return .gpGreen }
        else if percentage >= 0.5 { return .blue }
        else if percentage >= 0.25 { return .orange }
        else { return .red }
    }
    
    private func calculateScoreBarWidth(scoreBarWidth: Double) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 32
        let minimumWidth = screenWidth * 0.15
        let calculatedWidth = screenWidth * scoreBarWidth
        
        return max(minimumWidth, calculatedWidth)
    }
}

// MARK: - Configuration System

/// **Background Configuration**
/// 
/// **Unified configuration system for all player card background styles**
struct BackgroundConfiguration {
    let style: BackgroundStyle
    let team: NFLTeam?
    let cornerRadius: CGFloat
    let teamColor: Color
    let shadowRadius: CGFloat
    let borderWidth: CGFloat
    let showBorder: Bool
    let jerseyNumber: String?
    let isLive: Bool
    let isOnBye: Bool
    
    /// **Simple Background Factory**
    static func simple(team: NFLTeam?, cornerRadius: CGFloat = 12) -> BackgroundConfiguration {
        BackgroundConfiguration(
            style: .simple,
            team: team,
            cornerRadius: cornerRadius,
            teamColor: team?.primaryColor ?? .nyyDark,
            shadowRadius: 0,
            borderWidth: 0,
            showBorder: false,
            jerseyNumber: nil,
            isLive: false,
            isOnBye: false
        )
    }
    
    /// **Fantasy Background Factory**
    static func fantasy(
        team: NFLTeam?,
        jerseyNumber: String? = nil,
        cornerRadius: CGFloat = 15,
        showBorder: Bool = true,
        isLive: Bool = false,
        isOnBye: Bool = false
    ) -> BackgroundConfiguration {
        let borderWidth: CGFloat = (isLive || isOnBye) ? 6 : 2
        let shadowRadius: CGFloat = (isLive || isOnBye) ? 15 : 8
        
        return BackgroundConfiguration(
            style: .fantasy,
            team: team,
            cornerRadius: cornerRadius,
            teamColor: team?.primaryColor ?? .nyyDark,
            shadowRadius: shadowRadius,
            borderWidth: borderWidth,
            showBorder: showBorder,
            jerseyNumber: jerseyNumber,
            isLive: isLive,
            isOnBye: isOnBye
        )
    }
    
    /// **Score Bar Background Factory**
    static func scoreBar(
        playerEntry: PlayerEntry,
        scoreBarWidth: Double,
        team: NFLTeam?
    ) -> BackgroundConfiguration {
        BackgroundConfiguration(
            style: .scoreBar(playerEntry, scoreBarWidth),
            team: team,
            cornerRadius: 12,
            teamColor: team?.primaryColor ?? .nyyDark,
            shadowRadius: 0,
            borderWidth: 0,
            showBorder: false,
            jerseyNumber: nil,
            isLive: false,
            isOnBye: false
        )
    }
}

/// **Background Style Enum**
enum BackgroundStyle {
    case simple
    case fantasy
    case scoreBar(PlayerEntry, Double) // playerEntry, scoreBarWidth
}

/// **Player Entry Protocol** 
/// Unified interface for different player entry types
protocol PlayerEntry {
    var currentScore: Double { get }
    var scoreBarWidth: Double { get }
}

/// **Extension for AllLivePlayersViewModel.LivePlayerEntry**
extension AllLivePlayersViewModel.LivePlayerEntry: PlayerEntry {}