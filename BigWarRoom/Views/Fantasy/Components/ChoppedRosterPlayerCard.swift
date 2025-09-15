//
//  ChoppedRosterPlayerCard.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER PLAYER CARD 🏈
//  Enhanced player card for roster view with team styling and stats
//

import SwiftUI

/// **ChoppedRosterPlayerCard**
/// 
/// Enhanced player card displaying:
/// - Player image and info
/// - Jersey number background
/// - Live stats and points
/// - Team colors and styling
/// - Matchup information
/// - Dynamic gradient backgrounds based on performance
/// - Compact mode for condensed layouts
struct ChoppedRosterPlayerCard: View {
    @StateObject private var viewModel: ChoppedPlayerCardViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    let compact: Bool
    
    init(player: FantasyPlayer, isStarter: Bool, parentViewModel: ChoppedTeamRosterViewModel, onPlayerTap: @escaping (SleeperPlayer) -> Void, compact: Bool = false) {
        self._viewModel = StateObject(wrappedValue: ChoppedPlayerCardViewModel(
            player: player,
            isStarter: isStarter,
            parentViewModel: parentViewModel
        ))
        self.onPlayerTap = onPlayerTap
        self.compact = compact
    }
    
    // MARK: - Computed Properties for Sizing
    
    /// Card height based on compact mode
    private var cardHeight: CGFloat {
        compact ? 70 : 140
    }
    
    /// Player image size based on compact mode
    private var playerImageSize: CGFloat {
        compact ? 70 : 140
    }
    
    /// Jersey number font size based on compact mode
    private var jerseyNumberSize: CGFloat {
        compact ? 80 : 100
    }
    
    /// Hash symbol font size based on compact mode
    private var hashSize: CGFloat {
        compact ? 25 : 50
    }
    
    /// Points font size based on compact mode
    private var pointsFontSize: CGFloat {
        compact ? 18 : 32
    }
    
    /// Player name font size based on compact mode
    private var nameFontSize: CGFloat {
        compact ? 12 : 18
    }
    
    /// Badge font size based on compact mode
    private var badgeFontSize: CGFloat {
        compact ? 8 : 11
    }
    
    /// Team logo size based on compact mode
    private var logoSize: CGFloat {
        compact ? 90 : 180
    }
    
    /// Stats font size based on compact mode
    private var statsFontSize: CGFloat {
        compact ? 7 : 9
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background jersey number with proper shadows for contrast
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Spacer()
                            .frame(width: geometry.size.width * 0.6)
                        
                        HStack(alignment: .top, spacing: 2) {
                            // Small "#" symbol with outline effect
                            Text("#")
                                .font(.system(size: hashSize, weight: .thin))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -1, y: -1)
                                .shadow(color: .black, radius: 0, x: 1, y: -1)
                                .shadow(color: .black, radius: 0, x: -1, y: 1)
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                                .offset(x: compact ? 15 : 22, y: compact ? 15 : 25)
                                .opacity(0.2)

                            // Big jersey number with outline effect
                            Text(viewModel.jerseyNumber)
                                .font(.system(size: jerseyNumberSize, weight: .thin))
                                .italic()
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -2, y: -2)
                                .shadow(color: .black, radius: 0, x: 2, y: -2)
                                .shadow(color: .black, radius: 0, x: -2, y: 2)
                                .shadow(color: .black, radius: 0, x: 2, y: 2)
                                .shadow(color: .black, radius: 1, x: 0, y: 0)
                                .offset(x: 2, y: compact ? 8 : 15)
                                .opacity(0.2)
                        }
						.offset(x: compact ? 5 : 0, y: compact ? 5 : 10)

                        Spacer()
                    }
                    Spacer()
                }
				.offset(x: -10, y: -10)
				.opacity(0.85)
            }
            
            // Dynamic performance-based gradient background
            RoundedRectangle(cornerRadius: compact ? 10 : 15)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: performanceGradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.3)
            
            // Team accent gradient overlay
            RoundedRectangle(cornerRadius: compact ? 10 : 15)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            viewModel.teamPrimaryColor.opacity(0.4),
                            Color.clear,
                            viewModel.teamPrimaryColor.opacity(0.2)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Team logo (subtle background)
            Group {
                if let team = viewModel.player.team {
                    TeamAssetManager.shared.logoOrFallback(for: team)
                        .frame(width: logoSize, height: logoSize)
                        .offset(x: compact ? 15 : 30, y: compact ? -15 : -30)
                        .opacity(viewModel.actualPoints != nil ? 0.4 : 0.2)
                        .shadow(color: viewModel.teamPrimaryColor.opacity(0.3), radius: compact ? 4 : 8, x: 0, y: 0)
                }
            }
            
            // Main content stack - Player image
            HStack(spacing: compact ? 6 : 12) {
                // Player headshot
                ChoppedPlayerImageView(viewModel: viewModel)
                    .frame(width: playerImageSize, height: playerImageSize)
                    .offset(x: compact ? 12 : 5, y: compact ? -3 : -6)
                    .zIndex(2)
                
                Spacer()
                
                // Score display (trailing)
                VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: compact ? 2 : 4) {
                        Spacer()
                        
                        // Points display
                        VStack(alignment: .trailing, spacing: 1) {
                            if let points = viewModel.actualPoints, points > 0 {
                                Text(String(format: "%.1f", points))
                                    .font(.system(size: pointsFontSize, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .shadow(color: .black.opacity(0.9), radius: compact ? 2 : 3, x: 0, y: compact ? 1 : 2)
                            } else {
                                Text("0.0")
                                    .font(.system(size: pointsFontSize, weight: .light))
                                    .foregroundColor(.gray)
                                    .shadow(color: .black.opacity(0.9), radius: compact ? 2 : 3, x: 0, y: compact ? 1 : 2)
                            }
                        }
                    }
                    .padding(.bottom, compact ? 10 : 20)
                    .padding(.trailing, compact ? 6 : 12)
                    .offset(y: compact ? -5 : -10)
                }
                .zIndex(3)
            }
            
            // Player name and position (right-justified)
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: compact ? 2 : 4) {
                    Text(viewModel.player.fullName)
                        .font(.system(size: nameFontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.9), radius: compact ? 2 : 4, x: 0, y: compact ? 1 : 2)
                    
                    // Positional ranking badge with enhanced styling
                    Text(viewModel.badgeText)
                        .font(.system(size: badgeFontSize, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, compact ? 4 : 8)
                        .padding(.vertical, compact ? 2 : 3)
                        .background(
                            RoundedRectangle(cornerRadius: compact ? 4 : 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            badgeGradientColors.0,
                                            badgeGradientColors.1
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: compact ? 4 : 8)
                                        .stroke(viewModel.badgeColor.opacity(0.6), lineWidth: 1)
                                )
                        )
                        .shadow(color: badgeGradientColors.0.opacity(0.4), radius: compact ? 2 : 3, x: 0, y: compact ? 1 : 2)
                }
            }
            .offset(y: compact ? 15 : 30)
            .padding(.trailing, compact ? 4 : 8)
            .zIndex(4)
            
            // Game matchup (centered) with DRY component
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MatchupTeamFinalView(player: viewModel.player, scaleEffect: 1.2)
                    Spacer()
                }
                .padding(.bottom, compact ? 22 : 45)
            }
            .zIndex(5)
            
            // Stats section with reserved space
            if !compact {
                VStack {
                    Spacer()
                    HStack {
                        if viewModel.shouldShowStats {
                            Text(viewModel.statBreakdown!)
                                .font(.system(size: statsFontSize, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.8),
                                                    Color.black.opacity(0.6)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(viewModel.teamPrimaryColor.opacity(0.4), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        } else {
                            // Invisible spacer to reserve space when no stats
                            Text(" ")
                                .font(.system(size: statsFontSize, weight: .bold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.clear)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .zIndex(6)
            }
        }
        .frame(height: cardHeight)
        .background(
            // Enhanced card background with performance-based gradients
            RoundedRectangle(cornerRadius: compact ? 10 : 15)
                .fill(
                    LinearGradient(
                        colors: backgroundGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: shadowColor.opacity(0.4),
                    radius: compact ? 5 : 10,
                    x: 0,
                    y: compact ? 2 : 4
                )
        )
        .overlay(
            // Enhanced card border with dynamic colors
            RoundedRectangle(cornerRadius: compact ? 10 : 15)
                .stroke(
                    LinearGradient(
                        colors: borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: compact ? 1 : 2
                )
                .opacity(0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 15))
        .onTapGesture {
            if let sleeperPlayer = viewModel.sleeperPlayer {
                onPlayerTap(sleeperPlayer)
            }
        }
    }
    
    // MARK: - Dynamic Gradient Computed Properties
    
    /// Performance-based gradient colors for the main background overlay
    private var performanceGradientColors: [Color] {
        if let points = viewModel.actualPoints {
            if points >= 20 {
                // Elite performance - gold/green gradient
                return [Color.green.opacity(0.1), Color.yellow.opacity(0.05), Color.green.opacity(0.03)]
            } else if points >= 12 {
                // Good performance - green gradient
                return [Color.green.opacity(0.08), Color.green.opacity(0.04), Color.clear]
            } else if points >= 8 {
                // Average performance - blue gradient
                return [Color.blue.opacity(0.06), Color.blue.opacity(0.03), Color.clear]
            } else if points >= 4 {
                // Below average - orange gradient
                return [Color.orange.opacity(0.06), Color.orange.opacity(0.03), Color.clear]
            } else {
                // Poor performance - red gradient
                return [Color.red.opacity(0.06), Color.red.opacity(0.03), Color.clear]
            }
        } else {
            // No scoring data yet - neutral gradient
            return [Color.gray.opacity(0.05), Color.gray.opacity(0.02), Color.clear]
        }
    }
    
    /// Background gradient colors based on starter status and performance
    private var backgroundGradientColors: [Color] {
        // Unified base gradient for all cards regardless of performance
        if viewModel.isStarter {
            return [Color.black, viewModel.teamPrimaryColor.opacity(0.08), Color.black]
        } else {
            // Bench player - slightly more muted
            return [Color.black, Color.gray.opacity(0.06), Color.black]
        }
    }
    
    /// Border gradient colors based on performance
    private var borderGradientColors: [Color] {
        if let points = viewModel.actualPoints {
            if points >= 20 {
                return [Color.green.opacity(0.8), Color.yellow.opacity(0.6), Color.green.opacity(0.8)]
            } else if points >= 12 {
                return [Color.green.opacity(0.6), viewModel.teamPrimaryColor.opacity(0.4), Color.green.opacity(0.6)]
            } else if points >= 8 {
                return [viewModel.teamPrimaryColor.opacity(0.6), Color.clear, viewModel.teamPrimaryColor.opacity(0.6)]
            } else {
                return [Color.red.opacity(0.4), viewModel.teamPrimaryColor.opacity(0.3), Color.red.opacity(0.4)]
            }
        } else {
            return [viewModel.teamPrimaryColor.opacity(0.6), Color.clear, viewModel.teamPrimaryColor.opacity(0.6)]
        }
    }
    
    /// Badge gradient colors based on position ranking
    private var badgeGradientColors: (Color, Color) {
        if viewModel.isStarter {
            let position = viewModel.player.position.uppercased()
            switch position {
            case "QB":
                return (Color.blue.opacity(0.8), Color.blue.opacity(0.6))
            case "RB":
                return (Color.red.opacity(0.8), Color.red.opacity(0.6))
            case "WR":
                return (Color.green.opacity(0.8), Color.green.opacity(0.6))
            case "TE":
                return (Color.orange.opacity(0.8), Color.orange.opacity(0.6))
            case "K":
                return (Color.purple.opacity(0.8), Color.purple.opacity(0.6))
            case "DEF", "DST":
                return (Color.gray.opacity(0.8), Color.gray.opacity(0.6))
            default:
                return (viewModel.badgeColor.opacity(0.8), viewModel.badgeColor.opacity(0.6))
            }
        } else {
            return (Color.gray.opacity(0.8), Color.gray.opacity(0.6))
        }
    }
    
    /// Shadow color based on performance
    private var shadowColor: Color {
        if let points = viewModel.actualPoints {
            if points >= 20 {
                return Color.green
            } else if points >= 12 {
                return viewModel.teamPrimaryColor
            } else if points < 5 {
                return Color.red
            }
        }
        return viewModel.teamPrimaryColor
    }
}

#Preview {
    // Cannot preview without proper ViewModel setup
    Text("ChoppedRosterPlayerCard Preview")
        .foregroundColor(.white)
        .background(Color.black)
}