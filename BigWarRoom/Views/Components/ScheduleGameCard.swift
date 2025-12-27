//
//  ScheduleGameCard.swift
//  BigWarRoom
//
//  NFL Schedule Game Card - FOX NFL Style Layout
//
// MARK: -> Schedule Game Card Component

import SwiftUI

struct ScheduleGameCard: View {
    let game: ScheduleGame
    let odds: GameBettingOdds?
    let action: () -> Void
    var showDayTime: Bool = false  // For classic mode - shows day/time in center
    
    @State private var teamAssets = TeamAssetManager.shared
    @State private var standingsService = NFLStandingsService.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Away team logo (left side, full height, bleeding off card)
            HStack(spacing: 0) {
                // Away team record - white vertical bar with rotated text (LEADING side)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 64)
                    .overlay(
                        Text(getTeamRecord(for: game.awayTeam))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .kerning(1.0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 58) // Constrain width for scaling (slightly less than 64 height)
                            .rotationEffect(.degrees(90))
                    )
                
                TeamLogoView(teamCode: game.awayTeam, size: 140)
                    .scaleEffect(1.05)
                    .clipped()
                    .shadow(color: .black.opacity(0.6), radius: 8, x: 2, y: 4)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 2)
                    .frame(width: 90, height: 64)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .stroke(getTeamColor(for: game.awayTeam), lineWidth: 2)
                    )
                
                // Away team status badge - styled exactly like record bar (TRAILING side)
                playoffStatusBadge(for: game.awayTeam, isHome: false)
            }
            
            Spacer()
            
            // Game info (center) - slightly smaller fonts for shorter card
            VStack(spacing: 2) {
                if game.isLive {
                    // Live game - show scores
                    VStack(spacing: 1) {
                        Text(game.scoreDisplay)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        
                        Text(game.displayTime.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                } else if game.gameStatus.lowercased().contains("final") || game.gameStatus.lowercased().contains("post") || (game.awayScore > 0 || game.homeScore > 0) {
                    // Completed game - show final scores with winning team in green AND day name
                    VStack(spacing: 1) {
                        // Show day name for completed games too
                        if !game.dayName.isEmpty && game.dayName != "TBD" {
                            Text(game.dayName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .default))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                        
                        HStack(spacing: 8) {
                            // Away team score
                            Text("\(game.awayScore)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(game.awayScore > game.homeScore ? .gpGreen : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
                            Text("-")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
                            // Home team score
                            Text("\(game.homeScore)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(game.homeScore > game.awayScore ? .gpGreen : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                        
                        Text("FINAL")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    // Upcoming game
                    VStack(spacing: 1) {
                        // Show day/time (Classic mode)
                        if showDayTime {
                            // Day name
						   let dayNameSize = 10.0
                            if !game.dayName.isEmpty && game.dayName != "TBD" {
                                Text(game.dayName.uppercased())
								  .font(
									.system(
									   size: dayNameSize,
									   weight: .bold,
									   design: .default
									)
								  )
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                            
                            // Start time - same size as day name
                            Text(game.startTime)
							  .font(
								 .system(
									size: dayNameSize,
									weight: .bold,
									design: .default
								 )
							  )
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
                            // Moneyline under time - smaller
                            if let odds = odds,
                               let team = odds.favoriteMoneylineTeamCode,
                               let ml = odds.favoriteMoneylineOdds {
                                Text("\(team) \(ml)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
									.padding(.top, 2)
                            }
                        } else {
                            // Non-classic mode: show odds prominently
                            if let odds = odds {
                                VStack(spacing: 2) {
                                    // Moneyline
                                    if let team = odds.favoriteMoneylineTeamCode,
                                       let ml = odds.favoriteMoneylineOdds {
                                        HStack(spacing: 4) {
                                            Text(team)
                                                .font(.system(size: 16, weight: .black))
                                                .foregroundColor(.white)
                                            Text(ml)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.gpGreen)
                                        }
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                    } else if let spread = odds.spreadDisplay {
                                        Text(spread)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                    }
                                    
                                    // O/U + sportsbook badge
                                    HStack(spacing: 4) {
                                        if let total = odds.totalPoints {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white.opacity(0.6))
                                            
                                            Text(total)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                        
                                        if let book = odds.sportsbookEnum {
                                            SportsbookBadge(book: book, size: 8)
                                        }
                                    }
                                    .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                                }
                            } else {
                                // No odds - show placeholder
                                Text("—")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Home team logo (right side, full height, bleeding off card)
            HStack(spacing: 0) {
                // Home team record - white vertical bar with rotated text (LEADING side)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 64)
                    .overlay(
                        Text(getTeamRecord(for: game.homeTeam))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .kerning(1.0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 58) // Constrain width for scaling (slightly less than 64 height)
                            .rotationEffect(.degrees(90))
                    )
                
                TeamLogoView(teamCode: game.homeTeam, size: 140)
                    .scaleEffect(1.05)
                    .clipped()
                    .shadow(color: .black.opacity(0.6), radius: 8, x: -2, y: 4)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: -1, y: 2)
                    .frame(width: 90, height: 64)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle()
                            .stroke(getTeamColor(for: game.homeTeam), lineWidth: 2)
                    )
                
                // Home team status badge - styled exactly like record bar (TRAILING side)
                playoffStatusBadge(for: game.homeTeam, isHome: true)
            }
        }
        .frame(height: 64) // Card height
        .background(
            // GRADIENT from away team color to home team color (left to right)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            getTeamColor(for: game.awayTeam).opacity(0.7), // Away team color on left
                            getTeamColor(for: game.awayTeam).opacity(0.5), // Blend
                            getTeamColor(for: game.homeTeam).opacity(0.5), // Blend
                            getTeamColor(for: game.homeTeam).opacity(0.7)  // Home team color on right
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            // 3px gradient border from away team color to home team color
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            getTeamColor(for: game.awayTeam), // Away team color on left
                            getTeamColor(for: game.homeTeam)  // Home team color on right
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .clipShape(Rectangle()) // Clip the entire card as rectangle
        .overlay(
            EmptyView()
        )
    }
    
    // 🔥 Playoff status badge styled EXACTLY like record bar
    @ViewBuilder
    private func playoffStatusBadge(for teamCode: String, isHome: Bool) -> some View {
        let status = standingsService.getPlayoffStatus(for: teamCode)
        let _ = DebugPrint(mode: .contention, "📛 Status Badge Check: \(teamCode) -> \(status.displayText)")
        
        if status != .unknown {
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [getStatusColor(for: teamCode), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 32
                    )
                )
                .frame(width: 20, height: 64)
                .overlay(
                    Text(getStatusText(for: teamCode) ?? "")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                        .kerning(1.2)
                        .rotationEffect(.degrees(90))
                        .fixedSize()
                )
        } else {
            let _ = DebugPrint(mode: .contention, "⚠️  No badge for \(teamCode) - status is UNKNOWN")
            EmptyView()
        }
    }
    
    // Helper to get status text
    private func getStatusText(for teamCode: String) -> String? {
        let status = standingsService.getPlayoffStatus(for: teamCode)
        switch status {
        case .eliminated: return "OUT"
        case .bubble: return "BUBBLE"
        case .clinched: return "CLINCH"
        case .alive: return "HUNT"
        case .unknown: return nil
        }
    }
    
    // Helper to get status color
    private func getStatusColor(for teamCode: String) -> Color {
        let status = standingsService.getPlayoffStatus(for: teamCode)
        switch status {
        case .eliminated: return .red
        case .bubble: return .orange
        case .clinched: return .blue
        case .alive: return .green
        case .unknown: return .white
        }
    } 
    
    // Helper function to get team color
    private func getTeamColor(for teamCode: String) -> Color {
        return teamAssets.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    // Helper function to get team record
    private func getTeamRecord(for teamCode: String) -> String {
        let record = standingsService.getTeamRecord(for: teamCode)
        let _ = DebugPrint(mode: .contention, "📊 Record fetch: \(teamCode) -> \(record)")
        return record
    }
}

// MARK: -> Compact Schedule Game Card (for collapsible time slots)
struct ScheduleGameCardCompact: View {
    let game: ScheduleGame
    let odds: GameBettingOdds?
    
    @State private var teamAssets = TeamAssetManager.shared
    @State private var standingsService = NFLStandingsService.shared
    
    private let cardHeight: CGFloat = 52
    
    var body: some View {
        HStack(spacing: 0) {
            // Away Team Section
            HStack(spacing: 8) {
                // Playoff badge (if applicable)
                compactPlayoffBadge(for: game.awayTeam)
                
                // Logo
                TeamLogoView(teamCode: game.awayTeam, size: 40)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                
                // Team code + record
                VStack(alignment: .leading, spacing: 1) {
                    Text(game.awayTeam)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(getTeamRecord(for: game.awayTeam))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Center: Score or minimal info
            if game.isLive || game.awayScore > 0 || game.homeScore > 0 {
                // Score display
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(game.awayScore)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(game.awayScore > game.homeScore ? .gpGreen : .white)
                        
                        Text("-")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("\(game.homeScore)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(game.homeScore > game.awayScore ? .gpGreen : .white)
                    }
                    
                    if game.isLive {
                        Text(game.displayTime)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    } else {
                        Text("FINAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .frame(width: 80)
            } else {
                // Upcoming - just show odds on the right side
                Spacer()
            }
            
            // Home Team Section
            HStack(spacing: 8) {
                // Team code + record (trailing aligned)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(game.homeTeam)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(getTeamRecord(for: game.homeTeam))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Logo
                TeamLogoView(teamCode: game.homeTeam, size: 40)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.4), radius: 2, x: -1, y: 1)
                
                // Playoff badge (if applicable)
                compactPlayoffBadge(for: game.homeTeam)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Odds preview for upcoming games (far right)
            if !game.isLive && game.awayScore == 0 && game.homeScore == 0 {
                if let odds = odds,
                   let team = odds.favoriteMoneylineTeamCode,
                   let ml = odds.favoriteMoneylineOdds {
                    Text("\(team) \(ml)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 70, alignment: .trailing)
                        .padding(.leading, 8)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func getTeamColor(for teamCode: String) -> Color {
        return teamAssets.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    private func getTeamRecord(for teamCode: String) -> String {
        return standingsService.getTeamRecord(for: teamCode)
    }
    
    // 🔥 Compact playoff badge - small colored dot
    @ViewBuilder
    private func compactPlayoffBadge(for teamCode: String) -> some View {
        let status = standingsService.getPlayoffStatus(for: teamCode)
        
        if status != .unknown {
            Circle()
                .fill(getStatusColor(for: status))
                .frame(width: 8, height: 8)
                .shadow(color: getStatusColor(for: status).opacity(0.6), radius: 3)
        }
    }
    
    private func getStatusColor(for status: PlayoffStatus) -> Color {
        switch status {
        case .eliminated: return .red
        case .bubble: return .orange
        case .clinched: return .blue
        case .alive: return .green
        case .unknown: return .clear
        }
    }
}

// MARK: -> Team Logo Component
struct TeamLogoView: View {
    let teamCode: String
    let size: CGFloat
    
    @State private var teamAssets = TeamAssetManager.shared
    
    var body: some View {
        Group {
            if let logoImage = teamAssets.logo(for: teamCode) {
                logoImage
                    .resizable()
                    .aspectRatio(contentMode: .fill) // Fill to ensure it covers the full frame
                    .frame(width: size, height: size)
            } else {
                // Fallback with team colors
                ZStack {
                    Rectangle()
                        .fill(teamColor)
                    
                    Text(teamCode)
                        .font(.system(size: size * 0.25, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
            }
        }
    }
    
    private var teamColor: Color {
        teamAssets.team(for: teamCode)?.primaryColor ?? Color.gray
    }
}

