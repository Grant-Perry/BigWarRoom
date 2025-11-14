//
//  WaiverWireView.swift
//  BigWarRoom
//
//  Waiver wire recommendations section for Lineup RX
//

import SwiftUI

struct WaiverWireView: View {
    let groupedWaivers: [WaiverGroup]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "person.badge.plus.fill", title: "Waiver Wire Targets", color: .purple)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                }
            }
            
            if isExpanded {
                ForEach(groupedWaivers, id: \.dropPlayer.id) { group in
                    GroupedWaiverCard(
                        group: group,
                        sleeperPlayerCache: sleeperPlayerCache,
                        matchupInfoCache: matchupInfoCache,
                        gameTimeCache: gameTimeCache
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct WaiverGroup {
    let dropPlayer: FantasyPlayer
    let dropProjectedPoints: Double
    var addOptions: [WaiverAddOption]
}

struct WaiverAddOption {
    let playerID: String
    let name: String
    let position: String
    let team: String
    let projectedPoints: Double
    let reason: String
    let improvement: Double
}

struct GroupedWaiverCard: View {
    let group: WaiverGroup
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // DROP player (shown once)
            PlayerComparisonRow(
                player: group.dropPlayer,
                label: "DROP",
                labelColor: .gpRedPink,
                projectedPoints: group.dropProjectedPoints,
                iconName: nil,
                sleeperPlayerCache: sleeperPlayerCache,
                matchupInfoCache: matchupInfoCache,
                gameTimeCache: gameTimeCache
            )
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Multiple ADD options
            ForEach(group.addOptions.indices, id: \.self) { index in
                let option = group.addOptions[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    WaiverPlayerRow(
                        playerID: option.playerID,
                        name: option.name,
                        position: option.position,
                        team: option.team,
                        projectedPoints: option.projectedPoints,
                        improvement: option.improvement,
                        sleeperPlayerCache: sleeperPlayerCache,
                        matchupInfoCache: matchupInfoCache,
                        gameTimeCache: gameTimeCache
                    )
                    
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.purple)
                        
                        Text("Projected +\(String(format: "%.1f", option.improvement)) pts over \(group.dropPlayer.fullName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                if index < group.addOptions.count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

struct WaiverPlayerRow: View {
    let playerID: String
    let name: String
    let position: String
    let team: String
    let projectedPoints: Double
    let improvement: Double
    let sleeperPlayerCache: [String: SleeperPlayer]
    let matchupInfoCache: [String: LineupRXView.MatchupInfo]
    let gameTimeCache: [String: String]
    
    // Get matchup info for this player
    private var matchupInfo: LineupRXView.MatchupInfo? {
        let cacheKey = "\(team)_\(position)"
        return matchupInfoCache[cacheKey]
    }
    
    // Get game time for this player's team
    private var gameTime: String? {
        return gameTimeCache[team]
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Player headshot from Sleeper
            if let sleeperPlayer = sleeperPlayerCache[playerID] {
                AsyncImage(url: sleeperPlayer.headshotURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gpGreen.opacity(0.5), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("ADD:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gpGreen)
                    
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Text(position)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TeamLogoView(teamCode: team, size: 20)
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
            
            // Projected points with delta stacked vertically
            VStack(alignment: .trailing, spacing: 2) {
                // Projected points
                Text(String(format: "%.1f", projectedPoints))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                // Delta improvement (smaller, below)
                Text("+\(String(format: "%.1f", improvement))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
                
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