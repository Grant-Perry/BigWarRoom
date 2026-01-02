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
    let isBench: Bool
    
    let onScoreTap: (() -> Void)?
    
    let fantasyViewModel: FantasyViewModel?
    
    // 🔥 NEW: Add matchupsHubViewModel for corrected score calculation
    let matchupsHubViewModel: MatchupsHubViewModel?
    
    // 🔥 NEW: Add navigation trigger
    let sleeperPlayer: SleeperPlayer?
    let onPlayerImageTap: (() -> Void)?
    
    @State private var projectedPoints: Double = 0.0
    @State private var projectionsLoaded = false
    
    init(
        player: FantasyPlayer,
        isPlayerLive: Bool,
        glowIntensity: Double,
        isBench: Bool = false,
        onScoreTap: (() -> Void)? = nil,
        fantasyViewModel: FantasyViewModel? = nil,
        matchupsHubViewModel: MatchupsHubViewModel? = nil,
        sleeperPlayer: SleeperPlayer? = nil,
        onPlayerImageTap: (() -> Void)? = nil
    ) {
        self.player = player
        self.isPlayerLive = isPlayerLive
        self.glowIntensity = glowIntensity
        self.isBench = isBench
        self.onScoreTap = onScoreTap
        self.fantasyViewModel = fantasyViewModel
        self.matchupsHubViewModel = matchupsHubViewModel
        self.sleeperPlayer = sleeperPlayer
        self.onPlayerImageTap = onPlayerImageTap
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Player headshot
            FantasyPlayerCardHeadshotView(
                player: player,
                isPlayerLive: isPlayerLive,
                isBench: isBench,
                sleeperPlayer: sleeperPlayer,
                onPlayerImageTap: onPlayerImageTap
            )
            
            // Score display with projections
            VStack(alignment: .trailing, spacing: 2) {
                Spacer()
                
                HStack(alignment: .bottom, spacing: 4) {
                    Spacer()
                    
                    if let onScoreTap = onScoreTap {
                        scoreText
                            .onTapGesture {
                                onScoreTap()
                            }
                    } else {
                        scoreText
                    }
                }
                
                // Projected points and difference - single line, trailing alignment
                if projectionsLoaded {
                    projectedPointsView
                }
                
                Spacer()
                    .frame(height: 20)
            }
            .padding(.trailing, 4)
            .zIndex(3)
        }
        .task {
            await loadProjectedPoints()
        }
    }
    
    // MARK: - Helper Views
    
    private var scoreText: some View {
        let displayScore: String
        if let fantasyViewModel = fantasyViewModel,
           let matchupsHubViewModel = matchupsHubViewModel {
            let correctedScore = fantasyViewModel.getCorrectedPlayerScore(for: player, matchupsHubViewModel: matchupsHubViewModel)
            displayScore = String(format: "%.2f", correctedScore)
        } else {
            displayScore = player.currentPointsString
        }
        
        return Text(displayScore)
            .font(.system(size: 18, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(minWidth: 55)
            .overlay(
                onScoreTap != nil ? 
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.2))
                    )
                : nil
            )
    }
    
    private var projectedPointsView: some View {
        let currentPoints = player.currentPoints ?? 0.0
        let difference = currentPoints - projectedPoints
        let differenceText = difference >= 0 ? "+\(String(format: "%.1f", difference))" : String(format: "%.1f", difference)
        let differenceColor: Color = difference >= 0 ? .gpGreen : .gpRedPink
        
        return HStack(spacing: 3) {
            Text("Proj:")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("\(String(format: "%.1f", projectedPoints))")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
            
            Text("~")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            
            Text(differenceText)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(differenceColor)
        }
        .lineLimit(1)
        .frame(alignment: .trailing)
    }
    
    private func loadProjectedPoints() async {
        // Try normal projection first
        var projection: Double? = try? await ProjectedPointsManager.shared.getProjectedPoints(for: player)
        
        // Fallback for DEF/ST and Kicker if missing or 0
        let pos = player.position.uppercased()
        if (projection == nil || projection == 0.0) {
            if pos == "DEF" || pos == "DST" || pos == "D/ST" || pos == "K" || pos == "KICKER" {
                projection = player.projectedPoints ?? 0.0
            }
        }

        await MainActor.run {
            self.projectedPoints = projection ?? 0.0
            self.projectionsLoaded = true
        }
    }
}

/// Player headshot component
struct FantasyPlayerCardHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    let isBench: Bool
    let sleeperPlayer: SleeperPlayer?
    let onPlayerImageTap: (() -> Void)?
    
    // 🔥 NEW: Check if this is a DST player
    private var isDefenseOrSpecialTeams: Bool {
        let position = player.position.uppercased()
        return position.contains("DEF") || position.contains("DST") || position.contains("D/ST")
    }
    
    @Environment(TeamAssetManager.self) private var teamAssets
    
    var body: some View {
        ZStack {
            // 🔥 MODIFIED: Use tap gesture instead of NavigationLink
            Group {
                if isDefenseOrSpecialTeams {
                    dstTeamLogo
                } else {
                    playerHeadshot
                }
            }
            // Bench headshots should be black & white (only the image/logo, not badges/UI)
            .saturation(isBench ? 0.0 : 1.0)
            .opacity(isBench ? 0.65 : 1.0)
            .onTapGesture {
                onPlayerImageTap?()
            }
            
            // Injury badge
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -3, y: -3)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .offset(x: -20, y: -8)
        .zIndex(2)
    }
    
    // 🔥 NEW: Team logo for DST players
    @ViewBuilder
    private var dstTeamLogo: some View {
        let teamCode = player.team ?? ""
        let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
        
        if let team = NFLTeam.team(for: normalizedTeamCode) {
            teamAssets.logoOrFallback(for: team.id)
                .frame(width: 90, height: 90)
                .opacity(isPlayerLive ? 1.0 : 0.85)
        } else {
            // Fallback if team not found
            Circle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 90, height: 90)
                .overlay(
                    Text("DEF")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
                .opacity(isPlayerLive ? 1.0 : 0.85)
        }
    }
    
    // 🔥 EXTRACTED: Regular player headshot logic
    @ViewBuilder
    private var playerHeadshot: some View {
        AsyncImage(url: player.headshotURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 80, height: 80)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
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
                                .frame(width: 65, height: 65)
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
            
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -3, y: -3)
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
                .frame(width: 65, height: 65)
            
            Text(player.shortName.prefix(2))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -3, y: -3)
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
        VStack {
            HStack(alignment: .top, spacing: 6) {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(player.fullName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                    
                    // Position badge - smaller, under name
                    Text(positionalRanking)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.black.opacity(0.8))
                                .stroke(teamColor.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            
            Spacer()
        }
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
                MatchupTeamFinalView(player: player, scaleEffect: 0.8)
                Spacer()
            }
            .padding(.bottom, 35)
        }
        .zIndex(1)
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
                // 🔥 COMMENTED OUT: Stats taking up too much space
                /*
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
                */
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 9)
        }
        .zIndex(6)
    }
}