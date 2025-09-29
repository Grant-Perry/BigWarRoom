//
//  PlayerStatsLoadingView.swift
//  BigWarRoom
//
//  🔧 BLANK SHEET FIX: NEW FILE - Created dedicated loading view component
//  to replace the blank screen that was showing during 4-6 second data loading periods.
//  
//  This view shows player basic info IMMEDIATELY while stats load in the background,
//  providing visual feedback instead of a frustrating blank screen experience.
//

import SwiftUI

/// 🔧 BLANK SHEET FIX: Loading view that shows while player stats are being loaded
/// SOLVES: The blank screen problem by displaying player info + loading indicator instantly
struct PlayerStatsLoadingView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    let loadingMessage: String
    
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // 🔧 BLANK SHEET FIX: Use same background as main view for visual consistency
            Image("BG1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 24) {
                Spacer()
                
                // 🔧 BLANK SHEET FIX: Show player basic info IMMEDIATELY (no loading required)
                // This eliminates the blank screen by displaying something useful instantly
                VStack(spacing: 16) {
                    // Player image - loads asynchronously but has fallback
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
                    
                    // Player name and position - available immediately from player object
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
                                // 🔧 BLANK SHEET FIX: Fixed property name - NFLTeam uses .id not .abbreviation
                                Text(team.id) // FIXED: Use team.id instead of team.abbreviation
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
                
                // 🔧 BLANK SHEET FIX: Visual loading feedback section
                // Animated spinner + progress messages keep user informed of what's happening
                VStack(spacing: 16) {
                    // 🔧 BLANK SHEET FIX: Animated loading spinner with app brand colors
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
                            // Continuous rotation animation
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                    
                    // 🔧 BLANK SHEET FIX: Dynamic loading message from ViewModel
                    // Shows progressive status: "Loading player data..." -> "Loading league statistics..." etc.
                    Text(loadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Helper Functions
    
    // 🔧 BLANK SHEET FIX: Position-based color coding (same as main app styling)
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