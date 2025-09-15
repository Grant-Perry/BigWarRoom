//
//  DepthChartPlayerRowView.swift
//  BigWarRoom
//
//  Individual depth chart player row component
//

import SwiftUI

/// Individual player row in team depth chart
struct DepthChartPlayerRowView: View {
    let depthPlayer: DepthChartPlayer
    let team: NFLTeam?
    
    var body: some View {
        HStack(spacing: 14) {
            // Enhanced depth position number with gradient
            depthCircle
            
            // Enhanced player headshot with glow
            playerImageView
            
            // Enhanced player info section
            playerInfoSection
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(borderView)
        .shadow(
            color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.3) : Color.black.opacity(0.2),
            radius: depthPlayer.isCurrentPlayer ? 6 : 3,
            x: 0,
            y: depthPlayer.isCurrentPlayer ? 3 : 2
        )
        .scaleEffect(depthPlayer.isCurrentPlayer ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: depthPlayer.isCurrentPlayer)
    }
    
    // MARK: - Component Views
    
    private var depthCircle: some View {
        ZStack {
            // Glow effect behind number
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            depthPlayer.depthColor.opacity(0.8),
                            depthPlayer.depthColor.opacity(0.3)
                        ]),
                        center: .center,
                        startRadius: 2,
                        endRadius: 15
                    )
                )
                .frame(width: 28, height: 28)
                .blur(radius: 1)
            
            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            depthPlayer.depthColor,
                            depthPlayer.depthColor.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: depthPlayer.depthColor.opacity(0.4), radius: 3, x: 0, y: 2)
            
            Text("\(depthPlayer.depth)")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white)
        }
    }
    
    private var playerImageView: some View {
        ZStack {
            // Position-colored glow behind image
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            positionColor.opacity(0.6),
                            positionColor.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 38, height: 38)
                .blur(radius: 2)
            
            PlayerImageView(
                player: depthPlayer.player,
                size: 34,
                team: team
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                positionColor.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
    }
    
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(depthPlayer.player.shortName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(depthPlayer.isCurrentPlayer ? .white : .primary)
                
                if let number = depthPlayer.player.number {
                    Text("#\(number)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.8))
                        )
                }
                
                Spacer()
                
                // Enhanced fantasy rank with styling
                if let searchRank = depthPlayer.player.searchRank {
                    HStack(spacing: 3) {
                        Text("Rnk")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(searchRank)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gpBlue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.gpBlue.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            // Enhanced injury status with better styling
            if let injuryStatus = depthPlayer.player.injuryStatus, !injuryStatus.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    Text(String(injuryStatus.prefix(10)).capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Styling Helpers
    
    private var positionColor: Color {
        guard let position = depthPlayer.player.position else { return .gray }
        
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private var backgroundView: some View {
        ZStack {
            // Main gradient background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.4) : Color.black.opacity(0.6), location: 0.0),
                    .init(color: positionColor.opacity(0.15), location: 0.5),
                    .init(color: depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.2) : Color.black.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle overlay pattern
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.white.opacity(0.02)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var borderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        depthPlayer.isCurrentPlayer ? Color.gpGreen : Color.white.opacity(0.2),
                        depthPlayer.isCurrentPlayer ? Color.gpGreen.opacity(0.6) : positionColor.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: depthPlayer.isCurrentPlayer ? 2 : 1
            )
    }
}

#Preview {
    // Create a mock player with minimal required data
    let mockPlayerData = """
    {
        "player_id": "123",
        "first_name": "Josh",
        "last_name": "Allen",
        "position": "QB",
        "team": "BUF",
        "number": 17,
        "search_rank": 15
    }
    """.data(using: .utf8)!
    
    let mockPlayer = try! JSONDecoder().decode(SleeperPlayer.self, from: mockPlayerData)
    
    return DepthChartPlayerRowView(
        depthPlayer: DepthChartPlayer(
            player: mockPlayer,
            depth: 1,
            isCurrentPlayer: true
        ),
        team: nil
    )
    .padding()
}