//
//  RecommendedChangesView.swift
//  BigWarRoom
//
//  Recommended lineup changes section for Lineup RX
//

import SwiftUI

struct RecommendedChangesView: View {
    let result: LineupOptimizerService.OptimizationResult
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Recommended Lineup Changes", color: .gpGreen)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gpGreen)
                }
            }
            
            if isExpanded {
                LazyVStack(spacing: 12) {
                    ForEach(result.changes.indices, id: \.self) { index in
                        ChangeCard(
                            change: result.changes[index],
                            sleeperPlayerCache: sleeperPlayerCache,
                            matchupInfoCache: matchupInfoCache,
                            gameTimeCache: gameTimeCache
                        )
                        .id("change_\(index)")
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpRedPink, lineWidth: 2)
                )
        )
        .shadow(color: Color.gpRedPink.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

struct ChangeCard: View {
    let change: LineupOptimizerService.LineupChange
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    var body: some View {
        VStack(spacing: 12) {
            // Position header
            HStack {
                Text(change.position)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.gpGreen)
                    Text(change.reason)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gpGreen)
                        .lineLimit(1)
                }
            }
            
            // BENCH player (if exists)
            if let playerOut = change.playerOut {
                PlayerComparisonRow(
                    player: playerOut,
                    label: "BENCH",
                    labelColor: .gpRedPink,
                    projectedPoints: change.projectedPointsOut,
                    iconName: "arrow.down",
                    sleeperPlayerCache: sleeperPlayerCache,
                    matchupInfoCache: matchupInfoCache,
                    gameTimeCache: gameTimeCache
                )
                
                Divider()
                    .background(Color.gray.opacity(0.3))
            }
            
            // PLAY player
            PlayerComparisonRow(
                player: change.playerIn,
                label: "PLAY",
                labelColor: .gpGreen,
                projectedPoints: change.projectedPointsIn,
                iconName: "arrow.up",
                sleeperPlayerCache: sleeperPlayerCache,
                matchupInfoCache: matchupInfoCache,
                gameTimeCache: gameTimeCache
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct PlayerComparisonRow: View {
    let player: FantasyPlayer
    let label: String
    let labelColor: Color
    let projectedPoints: Double
    let iconName: String?
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    // Pre-compute sleeper player
    private var sleeperPlayer: SleeperPlayer? {
        player.sleeperID.flatMap { sleeperPlayerCache[$0] }
    }
    
    // Get matchup info for this player
    private var matchupInfo: LineupRXView.MatchupInfo? {
        guard let team = player.team else { return nil }
        let cacheKey = "\(team)_\(player.position)"
        return matchupInfoCache[cacheKey]
    }
    
    // Get game time for this player's team
    private var gameTime: String? {
        guard let team = player.team else { return nil }
        return gameTimeCache[team]
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon (optional)
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(labelColor)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 20)
            }
            
            // Player headshot - CLICKABLE to player stats
            ClickablePlayerImage(
                sleeperPlayer: sleeperPlayer,
                size: 40,
                borderColor: labelColor
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(label):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(labelColor)
                    
                    Text(player.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Position and team logo
                    HStack(spacing: 4) {
                        Text(player.position)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        if let team = player.team {
                            TeamLogoView(teamCode: team, size: 20)
                        }
                    }
                }
                
                // Matchup info (vs opponent, OPRK, game time)
                if let matchupInfo = matchupInfo {
                    HStack(spacing: 6) {
                        Text("vs")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        TeamLogoView(teamCode: matchupInfo.opponentTeam, size: 18)
                        
                        if let oprk = matchupInfo.oprk {
                            Text("#\(oprk)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(oprkColor(oprk))
                        }
                        
                        if let gameTime = gameTime {
                            Text("•")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text(gameTime)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                }
            }
            
            Spacer()
            
            // Projected points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", projectedPoints))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(labelColor)
                
                Text("pts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Color OPRK based on ranking (1-10 green, 11-20 yellow, 21+ red)
    private func oprkColor(_ oprk: Int) -> Color {
        if oprk <= 10 {
            return .gpGreen
        } else if oprk <= 20 {
            return .yellow
        } else {
            return .gpRedPink
        }
    }
}