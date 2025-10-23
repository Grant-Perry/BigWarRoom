//
//  UnifiedPlayerImageView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 CONSOLIDATION: Unified Player Image System
//  Eliminates duplicate image rendering logic across 20+ player card components
//

import SwiftUI

/// **Unified Player Image View**
/// 
/// **Handles all player image rendering patterns:**
/// - AsyncImage loading with multiple fallbacks
/// - Team logo overlays and backgrounds
/// - Position-based fallback displays
/// - Injury status badges
/// - Live game indicators
/// - Circular and rectangular clipping
///
/// **Replaces:** PlayerCardImageView, FantasyPlayerCardHeadshotView, 
/// PlayerScoreBarCardPlayerImageView, ChoppedPlayerImageView, and 8+ others
struct UnifiedPlayerImageView: View {
    let player: FantasyPlayer
    let size: ImageSize
    let configuration: ImageConfiguration
    
    var body: some View {
        ZStack {
            // Background layer (team logo if enabled)
            if configuration.showTeamLogo {
                buildTeamLogoBackground()
            }
            
            // Main image layer
            buildMainImage()
            
            // Overlay layer (injury status, live indicators, etc.)
            buildOverlays()
        }
        .frame(width: size.dimensions, height: size.dimensions)
        .clipShape(configuration.clipShape.shape)
    }
    
    // MARK: - Main Image Builder
    
    @ViewBuilder
    private func buildMainImage() -> some View {
        AsyncImage(url: player.headshotURL) { phase in
            switch phase {
            case .empty:
                buildLoadingState()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                // Try alternative URL before falling back
                AsyncImage(url: player.espnHeadshotURL) { altPhase in
                    switch altPhase {
                    case .success(let altImage):
                        altImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        buildFallbackImage()
                    }
                }
            @unknown default:
                buildFallbackImage()
            }
        }
    }
    
    // MARK: - Component Builders
    
    @ViewBuilder
    private func buildLoadingState() -> some View {
        ZStack {
            buildFallbackBackground()
            
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
    }
    
    @ViewBuilder
    private func buildFallbackImage() -> some View {
        ZStack {
            buildFallbackBackground()
            buildFallbackContent()
        }
    }
    
    @ViewBuilder
    private func buildFallbackBackground() -> some View {
        Rectangle()
            .fill(teamColor.opacity(0.8))
    }
    
    @ViewBuilder
    private func buildFallbackContent() -> some View {
        switch configuration.fallbackStyle {
        case .initials:
            Text(playerInitials)
                .font(.system(size: fallbackFontSize, weight: .bold))
                .foregroundColor(.white)
                
        case .position:
            Text(player.position)
                .font(.system(size: fallbackFontSize * 0.8, weight: .bold))
                .foregroundColor(.white)
                
        case .teamColor:
            // Just the background color, no text
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func buildTeamLogoBackground() -> some View {
        if let team = NFLTeam.team(for: player.team ?? "") {
            TeamAssetManager.shared.logoOrFallback(for: team.id)
                .opacity(0.25)
                .scaleEffect(1.2)
        }
    }
    
    @ViewBuilder
    private func buildOverlays() -> some View {
        ZStack {
            // Injury status badge
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                buildInjuryBadge(injuryStatus: injuryStatus)
            }
            
            // Live game indicator
            if player.isLive && configuration.showLiveIndicator {
                buildLiveIndicator()
            }
            
            // Border overlay
            if configuration.showBorder {
                buildBorderOverlay()
            }
        }
    }
    
    @ViewBuilder
    private func buildInjuryBadge(injuryStatus: String) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                InjuryStatusBadgeView(injuryStatus: injuryStatus)
                    .scaleEffect(configuration.badgeScale)
                    .offset(x: -2, y: -2)
            }
        }
    }
    
    @ViewBuilder
    private func buildLiveIndicator() -> some View {
        VStack {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(Color.red)
                            .scaleEffect(1.5)
                            .opacity(0.3)
                            .animation(.easeInOut(duration: 1.0).repeatForever(), value: player.isLive)
                    )
                Spacer()
            }
            Spacer()
        }
        .padding(4)
    }
    
    @ViewBuilder
    private func buildBorderOverlay() -> some View {
        configuration.clipShape.shape
            .stroke(
                LinearGradient(
                    colors: [teamColor.opacity(0.8), teamColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: configuration.borderWidth
            )
    }
    
    // MARK: - Computed Properties
    
    private var teamColor: Color {
        if let team = player.team {
            return NFLTeamColors.color(for: team)
        }
        return NFLTeamColors.fallbackColor(for: player.position)
    }
    
    private var playerInitials: String {
        let firstName = player.firstName ?? ""
        let lastName = player.lastName ?? ""
        let firstInitial = String(firstName.prefix(1))
        let lastInitial = String(lastName.prefix(1))
        return (firstInitial + lastInitial).uppercased()
    }
    
    private var fallbackFontSize: CGFloat {
        switch size {
        case .small: return 12
        case .compact: return 16
        case .standard: return 20
        case .large: return 24
        }
    }
}

// MARK: - Image Configuration Extensions

extension ImageConfiguration {
    var clipShape: ClipShapeConfig {
        switch fallbackStyle {
        case .initials, .teamColor:
            return .circle
        case .position:
            return .roundedRectangle(radius: 8)
        }
    }
    
    var showLiveIndicator: Bool {
        return true // Can be configured later
    }
    
    var showBorder: Bool {
        return false // Can be configured later
    }
    
    var borderWidth: CGFloat {
        return 1.5
    }
    
    var badgeScale: CGFloat {
        return 0.8
    }
}

/// **Clip Shape Configuration**
enum ClipShapeConfig {
    case circle
    case roundedRectangle(radius: CGFloat)
    
    @ViewBuilder
    var shape: some Shape {
        switch self {
        case .circle:
            Circle()
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: radius)
        }
    }
}