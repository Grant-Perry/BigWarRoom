//
//  UnifiedLoadingSystem.swift
//  BigWarRoom
//
//  🔥 PHASE 2 DRY REFACTOR: Unified loading system for all loading views
//  Consolidates loading patterns while preserving unique animations for each context
//  Follows DRY principles without compromising visual design consistency
//

import SwiftUI

/// **Unified Loading View System**
/// 
/// **Handles all loading view patterns while preserving animations:**
/// - AllLivePlayersLoadingView: Dramatic background with pulsing rings
/// - PlayerStatsLoadingView: Player info with spinner
/// - FantasyLoadingView: Simple centered indicator
/// - MatchupsHub loading states: Hero animations and progress bars
///
/// **Architecture:** Base system + specific animation providers
struct UnifiedLoadingView: View {
    let configuration: LoadingConfiguration
    
    var body: some View {
        ZStack {
            // Background layer (shared structure)
            buildBackground()
            
            // Content layer (specific to each loading type)
            buildContent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Background System
    
    @ViewBuilder
    private func buildBackground() -> some View {
        switch configuration.backgroundStyle {
        case .dramatic(let gradientAnimation):
            DramaticLoadingBackground(gradientAnimation: gradientAnimation)
        case .simple:
            Color.clear
        case .image(let imageName, let opacity):
            ImageLoadingBackground(imageName: imageName, opacity: opacity)
        case .custom(let backgroundView):
            AnyView(backgroundView)
        }
    }
    
    // MARK: - Content System
    
    @ViewBuilder 
    private func buildContent() -> some View {
        VStack(spacing: configuration.spacing) {
            if configuration.showTopSpacer {
                Spacer()
            }
            
            // Main loading indicator section
            buildLoadingIndicator()
            
            // Text content section
            buildTextContent()
            
            if configuration.showBottomSpacer {
                Spacer()
            }
        }
        .padding(.horizontal, configuration.horizontalPadding)
    }
    
    @ViewBuilder
    private func buildLoadingIndicator() -> some View {
        switch configuration.indicatorStyle {
        case .enhanced(let pulseAnimation, let glowAnimation):
            EnhancedLoadingIndicator(
                pulseAnimation: pulseAnimation,
                glowAnimation: glowAnimation
            )
        case .playerInfo(let player, let team, let rotationAngle):
            PlayerInfoLoadingIndicator(
                player: player,
                team: team, 
                rotationAngle: rotationAngle
            )
        case .simple:
            FantasyLoadingIndicator()
        case .custom(let indicatorView):
            AnyView(indicatorView)
        }
    }
    
    @ViewBuilder
    private func buildTextContent() -> some View {
        if let textConfig = configuration.textContent {
            VStack(spacing: textConfig.spacing) {
                if let title = textConfig.title {
                    Text(title)
                        .font(textConfig.titleFont)
                        .fontWeight(textConfig.titleWeight)
                        .foregroundColor(textConfig.titleColor)
                        .scaleEffect(textConfig.titleAnimation?.scale ?? 1.0)
                        .animation(textConfig.titleAnimation?.animation, value: textConfig.titleAnimation?.binding)
                }
                
                if let subtitle = textConfig.subtitle {
                    Text(subtitle)
                        .font(textConfig.subtitleFont)
                        .foregroundColor(textConfig.subtitleColor)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Configuration System

/// **Loading Configuration**
struct LoadingConfiguration {
    let backgroundStyle: LoadingBackgroundStyle
    let indicatorStyle: LoadingIndicatorStyle
    let textContent: LoadingTextContent?
    let spacing: CGFloat
    let horizontalPadding: CGFloat
    let showTopSpacer: Bool
    let showBottomSpacer: Bool
    
    /// **All Live Players Loading Factory**
    static func allLivePlayers(
        pulseAnimation: Binding<Bool>,
        gradientAnimation: Binding<Bool>,
        glowAnimation: Binding<Bool>
    ) -> LoadingConfiguration {
        LoadingConfiguration(
            backgroundStyle: .dramatic(gradientAnimation),
            indicatorStyle: .enhanced(pulseAnimation, glowAnimation),
            textContent: LoadingTextContent(
                title: "Loading Players",
                subtitle: "Fetching live player data from your leagues...",
                titleAnimation: TextAnimationConfig(
                    scale: pulseAnimation.wrappedValue ? 1.05 : 1.0,
                    animation: .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    binding: pulseAnimation.wrappedValue
                )
            ),
            spacing: 32,
            horizontalPadding: 32,
            showTopSpacer: true,
            showBottomSpacer: true
        )
    }
    
    /// **Player Stats Loading Factory**
    static func playerStats(
        player: SleeperPlayer,
        team: NFLTeam?,
        loadingMessage: String,
        rotationAngle: Binding<Double>
    ) -> LoadingConfiguration {
        LoadingConfiguration(
            backgroundStyle: .image("BG1", 0.25),
            indicatorStyle: .playerInfo(player, team, rotationAngle),
            textContent: LoadingTextContent(
                title: nil,
                subtitle: loadingMessage
            ),
            spacing: 24,
            horizontalPadding: 24,
            showTopSpacer: true,
            showBottomSpacer: true
        )
    }
    
    /// **Fantasy Loading Factory**
    static func fantasy() -> LoadingConfiguration {
        LoadingConfiguration(
            backgroundStyle: .simple,
            indicatorStyle: .simple,
            textContent: nil,
            spacing: 0,
            horizontalPadding: 0,
            showTopSpacer: false,
            showBottomSpacer: false
        )
    }
}

/// **Background Style Enum**
enum LoadingBackgroundStyle {
    case dramatic(Binding<Bool>) // gradientAnimation binding
    case simple
    case image(String, Double) // imageName, opacity
    case custom(any View)
}

/// **Indicator Style Enum**
enum LoadingIndicatorStyle {
    case enhanced(Binding<Bool>, Binding<Bool>) // pulseAnimation, glowAnimation
    case playerInfo(SleeperPlayer, NFLTeam?, Binding<Double>) // player, team, rotationAngle
    case simple
    case custom(any View)
}

/// **Text Content Configuration**
struct LoadingTextContent {
    let title: String?
    let subtitle: String?
    let spacing: CGFloat
    let titleFont: Font
    let titleWeight: Font.Weight
    let titleColor: Color
    let subtitleFont: Font
    let subtitleColor: Color
    let titleAnimation: TextAnimationConfig?
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        spacing: CGFloat = 12,
        titleFont: Font = .title2,
        titleWeight: Font.Weight = .semibold,
        titleColor: Color = .white,
        subtitleFont: Font = .subheadline,
        subtitleColor: Color = .secondary,
        titleAnimation: TextAnimationConfig? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.spacing = spacing
        self.titleFont = titleFont
        self.titleWeight = titleWeight
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.titleAnimation = titleAnimation
    }
}

/// **Text Animation Configuration**
struct TextAnimationConfig {
    let scale: CGFloat
    let animation: Animation?
    let binding: Bool
}

// MARK: - Background Components (Preserve Original Animations)

/// **Dramatic Loading Background** - Preserves AllLivePlayersLoadingView animations
struct DramaticLoadingBackground: View {
    @Binding var gradientAnimation: Bool
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(.systemGray6).opacity(0.1),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay gradient - PRESERVE ORIGINAL ANIMATION
            RadialGradient(
                colors: [
                    Color.gpGreen.opacity(gradientAnimation ? 0.3 : 0.1),
                    Color.blue.opacity(gradientAnimation ? 0.2 : 0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: gradientAnimation ? 50 : 200,
                endRadius: gradientAnimation ? 400 : 100
            )
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: gradientAnimation)
            
            // Subtle noise texture
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .blendMode(.overlay)
        }
    }
}

/// **Image Loading Background**
struct ImageLoadingBackground: View {
    let imageName: String
    let opacity: Double
    
    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(opacity)
            .ignoresSafeArea(.all)
    }
}

// MARK: - Indicator Components (Preserve Original Animations)

/// **Enhanced Loading Indicator** - Preserves AllLivePlayersLoadingView indicator animations
struct EnhancedLoadingIndicator: View {
    @Binding var pulseAnimation: Bool
    @Binding var glowAnimation: Bool
    
    var body: some View {
        ZStack {
            // 🔥 PRESERVED: Pulsing glow rings around the football
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.gpGreen.opacity(glowAnimation ? 0.6 : 0.2),
                                Color.blue.opacity(glowAnimation ? 0.4 : 0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(80 + index * 25))
                    .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                    .opacity(0.7 - Double(index) * 0.15)
                    .animation(
                        .easeInOut(duration: 1.8 + Double(index) * 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: pulseAnimation
                    )
            }
            
            // 🔥 PRESERVED: Large pulsing background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gpGreen.opacity(pulseAnimation ? 0.4 : 0.1),
                            Color.blue.opacity(pulseAnimation ? 0.2 : 0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: pulseAnimation ? 120 : 100)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulseAnimation)
            
            // 🔥 PRESERVED: Original spinning football with enhanced scaling
            FantasyLoadingIndicator()
                .scaleEffect(pulseAnimation ? 1.3 : 1.1)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
        }
    }
}

/// **Player Info Loading Indicator** - Preserves PlayerStatsLoadingView layout and animations
struct PlayerInfoLoadingIndicator: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    @Binding var rotationAngle: Double
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 🔥 PRESERVED: Player basic info section (shows immediately)
            VStack(spacing: 16) {
                // Player image with background
                PlayerImageView(
                    player: player,
                    size: 120,
                    team: team
                )
                .background(
                    Circle()
                        .fill(team?.primaryColor.opacity(0.2) ?? .gray.opacity(0.2))
                        .frame(width: 140, height: 140)
                )
                
                // Player name and position
                VStack(spacing: 4) {
                    Text(player.fullName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        if let position = player.position {
                            Text(position)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(positionColor(position))
                                )
                        }
                        
                        if let team = team {
                            Text(team.id)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(team.primaryColor)
                                )
                        }
                    }
                }
            }
            
            Spacer()
            
            // 🔥 PRESERVED: Visual loading feedback section with spinner animation
            VStack(spacing: 16) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .gpGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        // 🔥 PRESERVED: Continuous rotation animation
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // 🔥 PRESERVED: Position-based color coding
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}