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
    
    @State private var isExpanded: Bool = true
    
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
                ForEach(result.changes.indices, id: \.self) { index in
                    let change = result.changes[index]
                    ChangeCard(change: change, sleeperPlayerCache: sleeperPlayerCache)
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

struct ChangeCard: View {
    let change: LineupOptimizerService.LineupChange
    let sleeperPlayerCache: [String: SleeperPlayer]
    
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
                    sleeperPlayerCache: sleeperPlayerCache
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
                sleeperPlayerCache: sleeperPlayerCache
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon (optional)
            if let iconName = iconName {
                Image(systemName: iconName)
                    .foregroundColor(labelColor)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 20)
            }
            
            // Player headshot
            if let sleeperID = player.sleeperID,
               let sleeperPlayer = sleeperPlayerCache[sleeperID] {
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
                        .stroke(labelColor.opacity(0.5), lineWidth: 2)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(label):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(labelColor)
                    
                    Text(player.fullName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    // Position and team logo
                    HStack(spacing: 4) {
                        Text(player.position)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        
                        if let team = player.team {
                            TeamLogoView(teamCode: team, size: 24)
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
}