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
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Away team logo (left side, full height, bleeding off card)
                ZStack {
                    TeamLogoView(teamCode: game.awayTeam, size: 140) // Larger base logo
                        .scaleEffect(1.1) // Much less zoom - closer to original size
                        .clipped() // Crop to the frame
                }
                .frame(width: 90, height: 64) // Even wider logos (85->90), same height
                .clipShape(Rectangle()) // Sharp rectangular clip
                .overlay(
                    Rectangle()
                        .stroke(getTeamColor(for: game.awayTeam), lineWidth: 2)
                )
                // No padding - bleeds directly from card edge
                
                Spacer()
                
                // Game info (center) - slightly smaller fonts for shorter card
                VStack(spacing: 2) {
                    if game.isLive {
                        // Live game - show scores
                        VStack(spacing: 1) {
                            Text(game.scoreDisplay)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
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
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                
                                Text("-")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                
                                // Home team score
                                Text("\(game.homeScore)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(game.homeScore > game.awayScore ? .gpGreen : .white)
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
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                            
                            Text(game.startTime)
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                
                Spacer()
                
                // Home team logo (right side, full height, bleeding off card)
                ZStack {
                    TeamLogoView(teamCode: game.homeTeam, size: 140) // Larger base logo
                        .scaleEffect(1.1) // Much less zoom - closer to original size
                        .clipped() // Crop to the frame
                }
                .frame(width: 90, height: 64) // Even wider logos (85->90), same height
                .clipShape(Rectangle()) // Sharp rectangular clip
                .overlay(
                    Rectangle()
                        .stroke(getTeamColor(for: game.homeTeam), lineWidth: 2)
                )
                // No padding - bleeds directly from card edge
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
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .clipShape(Rectangle()) // Clip the entire card as rectangle
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper function to get team color
    private func getTeamColor(for teamCode: String) -> Color {
        return teamAssets.team(for: teamCode)?.primaryColor ?? Color.white
    }
}

// MARK: -> Team Logo Component
struct TeamLogoView: View {
    let teamCode: String
    let size: CGFloat
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
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