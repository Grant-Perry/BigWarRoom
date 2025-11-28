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
                ZStack {
                    TeamLogoView(teamCode: game.awayTeam, size: 140) // Larger base logo
                        .scaleEffect(1.05) // Reduced from 1.1 to 1.05 for less zoom
                        .clipped() // Crop to the frame
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 2, y: 4) // Deep shadow for 3D depth
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 2) // Secondary shadow for more depth
                }
                .frame(width: 90, height: 64) // Even wider logos (85->90), same height
                .clipShape(Rectangle()) // Sharp rectangular clip
                .overlay(
                    Rectangle()
                        .stroke(getTeamColor(for: game.awayTeam), lineWidth: 2)
                )
                
                // Away team record - white vertical bar with rotated text
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 64) // 20px wide, full height
                    .overlay(
                        Text(getTeamRecord(for: game.awayTeam))
                            .font(.system(size: 13, weight: .bold)) // Increased from 11 to 13
                            .foregroundColor(.white)
                            .kerning(1.5) // Add letter spacing to spread out text
                            .rotationEffect(.degrees(90)) // Top to bottom
                            .fixedSize() // Prevent text wrapping
                    )
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
                        if !game.dayName.isEmpty && game.dayName != "TBD" && game.dayName.uppercased() != "SUNDAY" {
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
                    // Upcoming game - show day and time (no Sunday text for Sunday games)
                    VStack(spacing: 2) {
                        // Remove debug text and fix logic
                        if game.dayName.uppercased() != "SUNDAY" && !game.dayName.isEmpty && game.dayName != "TBD" {
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
                // Home team record - white vertical bar with rotated text (before logo)
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 20, height: 64) // 20px wide, full height
                    .overlay(
                        Text(getTeamRecord(for: game.homeTeam))
                            .font(.system(size: 13, weight: .bold)) // Increased from 11 to 13
                            .foregroundColor(.white)
                            .kerning(1.5) // Add letter spacing to spread out text
                            .rotationEffect(.degrees(90)) // Same direction as away team
                            .fixedSize() // Prevent text wrapping
                    )
                
                ZStack {
                    TeamLogoView(teamCode: game.homeTeam, size: 140) // Larger base logo
                        .scaleEffect(1.05) // Reduced from 1.1 to 1.05 for less zoom
                        .clipped() // Crop to the frame
                        .shadow(color: .black.opacity(0.6), radius: 8, x: -2, y: 4) // Deep shadow for 3D depth (opposite x for right side)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: -1, y: 2) // Secondary shadow for more depth
                }
                .frame(width: 90, height: 64) // Even wider logos (85->90), same height
                .clipShape(Rectangle()) // Sharp rectangular clip
                .overlay(
                    Rectangle()
                        .stroke(getTeamColor(for: game.homeTeam), lineWidth: 2)
                )
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
    }
    
    // Helper function to get team color
    private func getTeamColor(for teamCode: String) -> Color {
        return teamAssets.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    // Helper function to get team record
    private func getTeamRecord(for teamCode: String) -> String {
        let record = standingsService.getTeamRecord(for: teamCode)
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