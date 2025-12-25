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
    let action: () -> Void
    
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .kerning(1.5)
                            .rotationEffect(.degrees(90))
                            .fixedSize()
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
                    // Upcoming game - show day and time
                    VStack(spacing: 2) {
                        // Show day name for all games
                        if !game.dayName.isEmpty && game.dayName != "TBD" {
                            Text(game.dayName.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                        
                        Text(game.startTime)
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .kerning(1.5)
                            .rotationEffect(.degrees(90))
                            .fixedSize()
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
        case .eliminated: return "NIXED"
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

#Preview("Schedule Game Card - Final") {
    ScheduleGameCard(
        game: ScheduleGame(
            id: "DAL@PHI",
            awayTeam: "DAL",
            homeTeam: "PHI",
            awayScore: 18,
            homeScore: 27,
            gameStatus: "final",
            gameTime: "",
            startDate: Date(),
            isLive: false
        ),
        action: {}
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Schedule Game Card - Upcoming") {
    ScheduleGameCard(
        game: ScheduleGame(
            id: "KC@BUF",
            awayTeam: "KC",
            homeTeam: "BUF",
            awayScore: 0,
            homeScore: 0,
            gameStatus: "pre",
            gameTime: "",
            startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 11))!, // Thursday
            isLive: false
        ),
        action: {}
    )
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
