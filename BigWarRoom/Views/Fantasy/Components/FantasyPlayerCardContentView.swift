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
    
    // 🔥 FIXED: Add FantasyViewModel to get corrected ESPN scores
    let fantasyViewModel: FantasyViewModel?
    
    init(player: FantasyPlayer, isPlayerLive: Bool, glowIntensity: Double, onScoreTap: (() -> Void)? = nil, fantasyViewModel: FantasyViewModel? = nil) {
        self.player = player
        self.isPlayerLive = isPlayerLive
        self.glowIntensity = glowIntensity
        self.onScoreTap = onScoreTap
        self.fantasyViewModel = fantasyViewModel
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
        // 🔥 FIXED: Use corrected score from FantasyViewModel when available
        let displayScore: String
        if let fantasyViewModel = fantasyViewModel {
            let correctedScore = fantasyViewModel.getCorrectedPlayerScore(for: player)
            displayScore = String(format: "%.2f", correctedScore)
        } else {
            displayScore = player.currentPointsString
        }
        
        // 🔥 DEBUG: Log which score is being used for Daniel Jones
        if player.fullName.contains("Daniel Jones") {
            print("🎯 FANTASY CARD FINAL DEBUG: \(player.fullName)")
            print("   Player ID: \(player.id)")
            print("   Original Score: \(player.currentPoints ?? 0.0)")
            print("   Display Score: \(displayScore)")
            print("   Has FantasyViewModel: \(fantasyViewModel != nil)")
        }
        
        return Text(displayScore)
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
}

/// Player headshot component
struct FantasyPlayerCardHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    var body: some View {
        ZStack {
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
            
            // 🔥 NEW: Injury Status Badge (positioned at bottom-right of headshot)
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -4, y: -4) // Position as subscript to headshot
                    }
                }
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
        ZStack {
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
            
            // 🔥 NEW: Injury Status Badge (for fallback images too)
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -4, y: -4)
                    }
                }
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
            
            // 🔥 NEW: Injury Status Badge (even for default circles)
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -4, y: -4)
                    }
                }
            }
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