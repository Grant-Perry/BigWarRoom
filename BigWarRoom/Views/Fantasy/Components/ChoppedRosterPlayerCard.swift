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
struct ChoppedRosterPlayerCard: View {
    @StateObject private var viewModel: ChoppedPlayerCardViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    
    init(player: FantasyPlayer, isStarter: Bool, parentViewModel: ChoppedTeamRosterViewModel, onPlayerTap: @escaping (SleeperPlayer) -> Void) {
        self._viewModel = StateObject(wrappedValue: ChoppedPlayerCardViewModel(
            player: player,
            isStarter: isStarter,
            parentViewModel: parentViewModel
        ))
        self.onPlayerTap = onPlayerTap
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
                                .font(.system(size: 40, weight: .thin))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -1, y: -1)
                                .shadow(color: .black, radius: 0, x: 1, y: -1)
                                .shadow(color: .black, radius: 0, x: -1, y: 1)
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                                .offset(x: 20, y: 25)
                                .opacity(0.6)

                            // Big jersey number with outline effect
                            Text(viewModel.jerseyNumber)
                                .font(.system(size: 80, weight: .thin))
                                .italic()
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -2, y: -2)
                                .shadow(color: .black, radius: 0, x: 2, y: -2)
                                .shadow(color: .black, radius: 0, x: -2, y: 2)
                                .shadow(color: .black, radius: 0, x: 2, y: 2)
                                .shadow(color: .black, radius: 1, x: 0, y: 0)
                                .offset(x: 0, y: 15)
                                .opacity(0.4)
                        }
                        .offset(y: 10)

                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Dynamic performance-based gradient background
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: performanceGradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.8)
            
            // Team accent gradient overlay
            RoundedRectangle(cornerRadius: 15)
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
                    let logoSize: CGFloat = 180
                    TeamAssetManager.shared.logoOrFallback(for: team)
                        .frame(width: logoSize, height: logoSize)
                        .offset(x: 30, y: -30)
                        .opacity(viewModel.actualPoints != nil ? 0.4 : 0.2)
                        .shadow(color: viewModel.teamPrimaryColor.opacity(0.3), radius: 8, x: 0, y: 0)
                }
            }
            
            // Main content stack - Player image
            HStack(spacing: 12) {
                // Player headshot
                ChoppedPlayerImageView(viewModel: viewModel)
                    .frame(width: 140, height: 140)
                    .offset(x: -15, y: -6)
                    .zIndex(2)
                
                Spacer()
                
                // Score display (trailing)
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Spacer()
                        
                        // Points display
                        VStack(alignment: .trailing, spacing: 1) {
                            if let points = viewModel.actualPoints, points > 0 {
                                Text(String(format: "%.1f", points))
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                            } else {
                                Text("0.0")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.gray)
                                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 12)
                    .offset(y: -10)
                }
                .zIndex(3)
            }
            
            // Player name and position (right-justified)
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.player.fullName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                    
                    // Positional ranking badge with enhanced styling
                    Text(viewModel.badgeText)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
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
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(viewModel.badgeColor.opacity(0.6), lineWidth: 1)
                                )
                        )
                        .shadow(color: badgeGradientColors.0.opacity(0.4), radius: 3, x: 0, y: 2)
                }
            }
            .offset(y: 30)
            .padding(.trailing, 8)
            .zIndex(4)
            
            // Game matchup (centered) with DRY component
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MatchupTeamFinalView(player: viewModel.player, scaleEffect: 1.1)
                    Spacer()
                }
                .padding(.bottom, 45)
            }
            .zIndex(5)
            
            // Stats section with reserved space
            VStack {
                Spacer()
                HStack {
                    if viewModel.shouldShowStats {
                        Text(viewModel.statBreakdown!)
                            .font(.system(size: 9, weight: .bold))
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
                            .font(.system(size: 9, weight: .bold))
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
        .frame(height: 140)
        .background(
            // Enhanced card background with performance-based gradients
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: backgroundGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: shadowColor.opacity(0.4),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            // Enhanced card border with dynamic colors
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        colors: borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .opacity(0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
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
                return [Color.green.opacity(0.3), Color.yellow.opacity(0.2), Color.green.opacity(0.1)]
            } else if points >= 12 {
                // Good performance - green gradient
                return [Color.green.opacity(0.2), Color.green.opacity(0.1), Color.clear]
            } else if points >= 8 {
                // Average performance - blue gradient
                return [Color.blue.opacity(0.2), Color.blue.opacity(0.1), Color.clear]
            } else if points >= 4 {
                // Below average - orange gradient
                return [Color.orange.opacity(0.2), Color.orange.opacity(0.1), Color.clear]
            } else {
                // Poor performance - red gradient
                return [Color.red.opacity(0.2), Color.red.opacity(0.1), Color.clear]
            }
        } else {
            // No scoring data yet - neutral gradient
            return [Color.gray.opacity(0.15), Color.gray.opacity(0.05), Color.clear]
        }
    }
    
    /// Background gradient colors based on starter status and performance
    private var backgroundGradientColors: [Color] {
        if viewModel.isStarter {
            if let points = viewModel.actualPoints {
                if points >= 15 {
                    return [Color.black, viewModel.teamPrimaryColor.opacity(0.2), Color.green.opacity(0.1), Color.black]
                } else if points >= 8 {
                    return [Color.black, viewModel.teamPrimaryColor.opacity(0.15), Color.black]
                } else {
                    return [Color.black, viewModel.teamPrimaryColor.opacity(0.1), Color.red.opacity(0.05), Color.black]
                }
            } else {
                return [Color.black, viewModel.teamPrimaryColor.opacity(0.1), Color.black]
            }
        } else {
            // Bench player - more muted
            return [Color.black, Color.gray.opacity(0.1), Color.black]
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