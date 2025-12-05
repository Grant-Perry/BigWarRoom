//
//  OptimalLineupView.swift
//  BigWarRoom
//
//  Optimal lineup display section for Lineup RX
//

import SwiftUI

struct OptimalLineupView: View {
    let result: LineupOptimizerService.OptimizationResult
    let sleeperPlayerCache: [String: SleeperPlayer]
    let changeInfoCache: [String: (isChanged: Bool, improvement: Double?)]
    
    @State private var isExpanded: Bool = false
    
    // Calculate active and bench totals
    private var activeTotal: Double {
        var total: Double = 0
        let activePositions = ["QB", "RB", "WR", "WR/TE", "TE", "FLEX", "SUPERFLEX", "SUPER_FLEX", "WRRB_FLEX", "REC_FLEX", "D/ST", "DEF", "K"]
        
        for position in activePositions {
            if let players = result.optimalLineup[position] {
                for player in players {
                    if let sleeperID = player.sleeperID,
                       let projection = result.playerProjections[sleeperID] {
                        total += projection
                    }
                }
            }
        }
        
        return total
    }
    
    private var benchTotal: Double {
        var total: Double = 0
        
        if let benchPlayers = result.optimalLineup["BENCH"] {
            for player in benchPlayers {
                if let sleeperID = player.sleeperID,
                   let projection = result.playerProjections[sleeperID] {
                    total += projection
                }
            }
        }
        
        return total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "star.fill", title: "Optimal Lineup", color: .gpGreen)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", result.projectedPoints))
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.gpGreen)
                        
                        Text("TOTAL PTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.leading, 8)
                }
            }
            .padding(.bottom, 4)
            
            if isExpanded {
                let positionOrder = ["QB", "RB", "WR", "WR/TE", "TE", "FLEX", "SUPERFLEX", "SUPER_FLEX", "WRRB_FLEX", "REC_FLEX", "D/ST", "DEF", "K"]
                
                ForEach(positionOrder.indices, id: \.self) { idx in
                    let position = positionOrder[idx]
                    if let players = result.optimalLineup[position], !players.isEmpty {
                        PositionGroupView(
                            position: position,
                            players: players,
                            projections: result.playerProjections,
                            changes: result.changes,
                            sleeperPlayerCache: sleeperPlayerCache,
                            changeInfoCache: changeInfoCache
                        )
                        .id("position_\(position)")
                    }
                }
                
                // Active Total
                HStack {
                    Text("Active Total:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", activeTotal))
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.gpGreen)
                    
                    Text("pts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gpGreen.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.vertical, 8)
                
                if let benchPlayers = result.optimalLineup["BENCH"], !benchPlayers.isEmpty {
                    BenchGroupView(
                        players: benchPlayers,
                        changes: result.changes,
                        sleeperPlayerCache: sleeperPlayerCache,
                        projections: result.playerProjections
                    )
                    .id("bench")
                    
                    // Bench Total
                    HStack {
                        Text("Bench Total:")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", benchTotal))
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.gray)
                        
                        Text("pts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct PositionGroupView: View {
    let position: String
    let players: [FantasyPlayer]
    let projections: [String: Double]
    let changes: [LineupOptimizerService.LineupChange]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let changeInfoCache: [String: (isChanged: Bool, improvement: Double?)]
    
    // Format position name for display
    private var formattedPosition: String {
        let withoutUnderscore = position.replacingOccurrences(of: "_", with: " ")
        
        // Handle flex positions with pipes
        switch withoutUnderscore.uppercased() {
        case "WRRB FLEX":
            return "WR|RB Flex"
        case "REC FLEX", "WRTE FLEX", "WR/TE":
            return "WR|TE Flex"
        case "RBWRTE FLEX":
            return "RB|WR|TE Flex"
        case "SUPER FLEX", "SUPERFLEX":
            return "Super Flex"
        default:
            return withoutUnderscore
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedPosition)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gpYellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gpGreen.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gpGreen.opacity(0.3), lineWidth: 1)
                        )
                )
            
            LazyVStack(spacing: 4) {
                ForEach(players.indices, id: \.self) { idx in
                    OptimalLineupPlayerRow(
                        player: players[idx],
                        position: position,
                        projections: projections,
                        changes: changes,
                        sleeperPlayerCache: sleeperPlayerCache,
                        changeInfoCache: changeInfoCache
                    )
                    .id("\(players[idx].id)_\(position)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

struct BenchGroupView: View {
    let players: [FantasyPlayer]
    let changes: [LineupOptimizerService.LineupChange]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let projections: [String: Double]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("BENCH")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                
                Text("(\(players.count) players)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            
            LazyVStack(spacing: 4) {
                ForEach(players.indices, id: \.self) { idx in
                    BenchPlayerRow(
                        player: players[idx],
                        changes: changes,
                        sleeperPlayerCache: sleeperPlayerCache,
                        projections: projections
                    )
                    .id(players[idx].id)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
    }
}

struct OptimalLineupPlayerRow: View {
    let player: FantasyPlayer
    let position: String
    let projections: [String: Double]
    let changes: [LineupOptimizerService.LineupChange]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let changeInfoCache: [String: (isChanged: Bool, improvement: Double?)]
    
    // Pre-compute everything for performance
    private var cacheKey: String {
        "\(player.id)_\(position)"
    }
    
    private var changeInfo: (isChanged: Bool, improvement: Double?) {
        changeInfoCache[cacheKey] ?? (
            changes.contains(where: { $0.playerIn.id == player.id && $0.position == position }),
            changes.first(where: { $0.playerIn.id == player.id && $0.position == position })?.improvement
        )
    }
    
    private var sleeperPlayer: SleeperPlayer? {
        player.sleeperID.flatMap { sleeperPlayerCache[$0] }
    }
    
    private var projectedPts: Double {
        player.sleeperID.flatMap { projections[$0] } ?? 0.0
    }
    
    private var isChanged: Bool {
        changeInfo.isChanged
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // SWAP SYMBOL for changed players
            Image(systemName: isChanged ? "arrow.triangle.swap" : "checkmark.circle.fill")
                .foregroundColor(isChanged ? .gpBlue : .gpGreen)
                .font(.system(size: 16))
            
            // Player headshot - CLICKABLE to player stats
            ClickablePlayerImage(
                sleeperPlayer: sleeperPlayer,
                size: 40,
                borderColor: .gpGreen
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let depth = sleeperPlayer?.depthChartPosition {
                        Text("\(player.position)\(depth)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gpGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gpGreen.opacity(0.2))
                            )
                    } else {
                        Text(player.position)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gpGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gpGreen.opacity(0.2))
                            )
                    }
                    
                    if let teamCode = player.team {
                        TeamLogoView(teamCode: teamCode, size: 20)
                    }
                }
            }
            
            Spacer()
            
            // Projected points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", projectedPts))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("pts")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isChanged ? Color.gpBlue.opacity(0.15) : Color.black.opacity(0.4))
        )
    }
}

struct BenchPlayerRow: View {
    let player: FantasyPlayer
    let changes: [LineupOptimizerService.LineupChange]
    let sleeperPlayerCache: [String: SleeperPlayer]
    let projections: [String: Double]
    
    // Pre-compute for performance
    private var wasStarting: Bool {
        changes.contains(where: { $0.playerOut?.id == player.id })
    }
    
    private var sleeperPlayer: SleeperPlayer? {
        player.sleeperID.flatMap { sleeperPlayerCache[$0] }
    }
    
    private var projectedPts: Double {
        player.sleeperID.flatMap { projections[$0] } ?? 0.0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // SWAP SYMBOL for benched players
            Image(systemName: wasStarting ? "arrow.triangle.swap" : "circle.fill")
                .foregroundColor(wasStarting ? .gpRedPink : .gray.opacity(0.3))
                .font(.system(size: wasStarting ? 16 : 8))
            
            // Player headshot - CLICKABLE to player stats
            ClickablePlayerImage(
                sleeperPlayer: sleeperPlayer,
                size: 32,
                borderColor: .gray
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(player.position)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    if let teamCode = player.team {
                        TeamLogoView(teamCode: teamCode, size: 16)
                    }
                }
            }
            
            Spacer()
            
            // Projected points
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", projectedPts))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                
                Text("pts")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(wasStarting ? Color.gpRedPink.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Optimized Cached Player Image Component

struct CachedPlayerImage: View {
    let url: URL?
    let size: CGFloat
    
    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            placeholderView
                .frame(width: size, height: size)
        }
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
    }
}

// MARK: - Clickable Player Image with Navigation to Stats

struct ClickablePlayerImage: View {
    let sleeperPlayer: SleeperPlayer?
    let size: CGFloat
    var borderColor: Color = .gpGreen
    var borderWidth: CGFloat = 2
    
    var body: some View {
        if let player = sleeperPlayer {
            NavigationLink(destination: PlayerStatsCardView(player: player, team: nil)) {
                playerImageContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            playerImageContent
        }
    }
    
    private var playerImageContent: some View {
        Group {
            if let url = sleeperPlayer?.headshotURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(borderColor.opacity(0.5), lineWidth: borderWidth)
                )
            } else {
                placeholderView
                    .frame(width: size, height: size)
            }
        }
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
    }
}

// MARK: - Section Header Component

struct SectionHeader: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}