//
//  FantasyPlayerCardContentView.swift
//  BigWarRoom
//
//  Main content components for FantasyPlayerCard
//

import SwiftUI

/// Main content stack with headshot and score
struct FantasyPlayerCardMainContentView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    let glowIntensity: Double
    
    let onScoreTap: (() -> Void)?
    
    // 🔥 NEW: Add dependency for live score calculation
    @StateObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    @StateObject private var playerDirectory = PlayerDirectoryStore.shared
    
    init(player: FantasyPlayer, isPlayerLive: Bool, glowIntensity: Double, onScoreTap: (() -> Void)? = nil) {
        self.player = player
        self.isPlayerLive = isPlayerLive
        self.glowIntensity = glowIntensity
        self.onScoreTap = onScoreTap
    }
    
    var body: some View {
        HStack(spacing: 8) { // 🔥 FIX: Reduced spacing from 12 to 8 to give score area more room
            // Player headshot
            FantasyPlayerCardHeadshotView(
                player: player,
                isPlayerLive: isPlayerLive
            )
            
            // Score display - UPDATED: Make tappable when action provided
            VStack(alignment: .trailing, spacing: 4) {
                Spacer()
                
                HStack(alignment: .bottom, spacing: 4) {
                    Spacer()
                    
                    // 🔥 FIX: Wrap score in button if tap action provided with proper gesture handling
                    if let onScoreTap = onScoreTap {
                        scoreText
                            .onTapGesture {
                                onScoreTap()
                            }
                            // 🔥 CRITICAL: Remove .allowsHitTesting and .zIndex that were blocking parent card taps
                    } else {
                        scoreText
                    }
                }
                .padding(.bottom, 36)
                .padding(.trailing, 4) // 🔥 FIXED: Reduced from 8 to 4 to give even more space
            }
            .zIndex(3)
        }
    }
    
    // MARK: - Helper Views
    
    private var scoreText: some View {
        // 🔥 FIX: Use live calculated score instead of stale player.currentPoints
        Text(liveScoreString)
            .font(.system(size: 22, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5) // 🔥 FIXED: Lowered from 0.7 to 0.5 to prevent truncation
            .scaleEffect(isPlayerLive ? (glowIntensity > 0.5 ? 1.15 : 1.0) : 1.0)
            .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
            .padding(.horizontal, 4) // 🔥 FIXED: Reduced from 6 to 4 for more space
            .padding(.vertical, 4)
            .frame(minWidth: 70) // 🔥 FIXED: Increased from 60 to 70 for more space
            .overlay(
                onScoreTap != nil ? 
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5) // 🔥 FIX: Make border more visible
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.2)) // 🔥 FIX: Add subtle background to indicate tappable
                    )
                : nil
            )
    }
    
    // 🔥 NEW: Calculate live score using same logic as AllLivePlayersViewModel
    private var liveScoreString: String {
        // First try to get live calculated score
        if let liveScore = calculateLiveScore() {
            return String(format: "%.2f", liveScore)
        }
        
        // Fallback to original player score
        return player.currentPointsString
    }
    
    // 🔥 NEW: Calculate live score from stats (same as AllLivePlayersViewModel)
    private func calculateLiveScore() -> Double? {
        guard let sleeperPlayer = getSleeperPlayerData() else { return nil }
        guard let stats = livePlayersViewModel.playerStats[sleeperPlayer.playerID] else { return nil }
        
        // Use PPR scoring by default (most common)
        if let pprPoints = stats["pts_ppr"] {
            return pprPoints
        } else if let halfPprPoints = stats["pts_half_ppr"] {
            return halfPprPoints
        } else if let stdPoints = stats["pts_std"] {
            return stdPoints
        }
        
        return nil
    }
    
    // 🔥 NEW: Get Sleeper player data for stats lookup
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = player.fullName.lowercased()
        
        return playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == player.shortName.lowercased() &&
             sleeperPlayer.team?.lowercased() == player.team?.lowercased())
        }
    }
}

/// Player headshot component
struct FantasyPlayerCardHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    var body: some View {
        AsyncImage(url: player.headshotURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 95, height: 95)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 95, height: 95)
                    .clipped()
                    .opacity(isPlayerLive ? 1.0 : 0.85)
            case .failure:
                FantasyPlayerCardFallbackHeadshotView(
                    player: player,
                    isPlayerLive: isPlayerLive
                )
            @unknown default:
                EmptyView()
            }
        }
        .offset(x: -20, y: -8)
        .zIndex(2)
    }
}

/// Fallback headshot component
struct FantasyPlayerCardFallbackHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    var body: some View {
        Group {
            if let espnURL = player.espnHeadshotURL {
                AsyncImage(url: espnURL) { phase2 in
                    switch phase2 {
                    case .success(let image2):
                        image2
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 95, height: 95)
                            .clipped()
                            .opacity(isPlayerLive ? 1.0 : 0.85)
                    default:
                        FantasyPlayerCardDefaultCircleView(
                            player: player,
                            isPlayerLive: isPlayerLive
                        )
                    }
                }
            } else {
                FantasyPlayerCardDefaultCircleView(
                    player: player,
                    isPlayerLive: isPlayerLive
                )
            }
        }
    }
}

/// Default player circle component
struct FantasyPlayerCardDefaultCircleView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    private var teamColor: Color {
        if let team = player.team, let nflTeam = NFLTeam.team(for: team) {
            return nflTeam.primaryColor
        }
        return .gray
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(teamColor.opacity(0.8))
                .frame(width: 95, height: 95)
            
            Text(player.shortName.prefix(2))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .opacity(isPlayerLive ? 1.0 : 0.85)
    }
}

/// Player name and position component
struct FantasyPlayerCardNamePositionView: View {
    let player: FantasyPlayer
    let positionalRanking: String
    let teamColor: Color
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(player.fullName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                
                // UPDATED: Remove tap action - just display the badge
                Text(positionalRanking)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .stroke(teamColor.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.top, 8)
        .padding(.trailing, 8)
        .zIndex(4)
    }
}

/// Game matchup section component
struct FantasyPlayerCardMatchupView: View {
    let player: FantasyPlayer
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                MatchupTeamFinalView(player: player, scaleEffect: 1.2)
                Spacer()
            }
            .padding(.bottom, 45)
        }
        .zIndex(5)
    }
}

/// Stats section component
struct FantasyPlayerCardStatsView: View {
    let player: FantasyPlayer
    let statLine: String?
    let teamColor: Color
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if player.currentPoints ?? 0.0 > 0, let statLine = statLine {
                    Text(statLine)
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
                                .fill(Color.black.opacity(0.7))
                                .stroke(teamColor.opacity(0.4), lineWidth: 1)
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
            .padding(.bottom, 9)
        }
        .zIndex(6)
    }
}