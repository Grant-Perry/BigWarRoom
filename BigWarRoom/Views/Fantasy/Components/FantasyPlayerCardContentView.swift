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
    
    let fantasyViewModel: FantasyViewModel?
    
    @State private var projectedPoints: Double = 0.0
    @State private var projectionsLoaded = false
    
    init(player: FantasyPlayer, isPlayerLive: Bool, glowIntensity: Double, onScoreTap: (() -> Void)? = nil, fantasyViewModel: FantasyViewModel? = nil) {
        self.player = player
        self.isPlayerLive = isPlayerLive
        self.glowIntensity = glowIntensity
        self.onScoreTap = onScoreTap
        self.fantasyViewModel = fantasyViewModel
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Player headshot
            FantasyPlayerCardHeadshotView(
                player: player,
                isPlayerLive: isPlayerLive
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
        if let fantasyViewModel = fantasyViewModel {
            let correctedScore = fantasyViewModel.getCorrectedPlayerScore(for: player)
            displayScore = String(format: "%.2f", correctedScore)
        } else {
            displayScore = player.currentPointsString
        }
        
        return Text(displayScore)
            .font(.system(size: 16, weight: .black))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .scaleEffect(isPlayerLive ? (glowIntensity > 0.5 ? 1.15 : 1.0) : 1.0)
            .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(minWidth: 50)
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
        
        return HStack(spacing: 2) {
            Text("Proj:")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("\(String(format: "%.1f", projectedPoints))")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
            
            Text("|")
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
        // Try to get league context from fantasyViewModel
        if let fantasyViewModel = fantasyViewModel,
           let selectedLeague = fantasyViewModel.selectedLeague {
            let leagueID = selectedLeague.league.id
            let source: LeagueSource = selectedLeague.source == .espn ? .espn : .sleeper
            
            // Use custom projections with league scoring rules
            if let projection = await ProjectedPointsManager.shared.getCustomProjectedPoints(
                for: player,
                leagueID: leagueID,
                source: source
            ) {
                await MainActor.run {
                    self.projectedPoints = projection
                    self.projectionsLoaded = true
                }
                return
            }
        }
        
        // Fallback to generic projection if no league context
        if let projection = try? await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
            await MainActor.run {
                self.projectedPoints = projection
                self.projectionsLoaded = true
            }
        }
    }
}

/// Player headshot component
struct FantasyPlayerCardHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: player.headshotURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 65, height: 65)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 65, height: 65)
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
            
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                InjuryStatusBadgeView(injuryStatus: injuryStatus)
                    .scaleEffect(0.7)
                    .offset(x: 3, y: -3)
            }
        }
        .offset(x: -6)
        .clipped()
        .zIndex(2)
    }
}

/// Fallback headshot component
struct FantasyPlayerCardFallbackHeadshotView: View {
    let player: FantasyPlayer
    let isPlayerLive: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
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
                InjuryStatusBadgeView(injuryStatus: injuryStatus)
                    .scaleEffect(0.7)
                    .offset(x: 3, y: -3)
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
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(teamColor.opacity(0.8))
                .frame(width: 65, height: 65)
            
            Text(player.shortName.prefix(2))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                InjuryStatusBadgeView(injuryStatus: injuryStatus)
                    .scaleEffect(0.7)
                    .offset(x: 3, y: -3)
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
    let isPlayerWatched: Bool
    let onWatchToggle: () -> Void
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 6) {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(player.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                    
                    // Position badge and watch button on same line
                    HStack(spacing: 4) {
                        // Watch button - small and before position
                        Button(action: onWatchToggle) {
                            Image(systemName: isPlayerWatched ? "eye.fill" : "eye")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(isPlayerWatched ? .gpYellow : .white.opacity(0.6))
                                .frame(width: 14, height: 14)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(positionalRanking)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.8))
                                    .stroke(teamColor.opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.trailing, 6)
            .offset(x: -6, y: 10)

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
                MatchupTeamFinalView(player: player, scaleEffect: 1.0)
                Spacer()
            }
            .padding(.bottom, 30)
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