//
//  DepthChartPlayerRowInfoSectionView.swift
//  BigWarRoom
//
//  Player info section component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowInfoSectionView: View {
    let depthPlayer: DepthChartPlayer
    
    // 🔥 PHASE 3 DI: Remove .shared assignment, will be injected
    @State private var livePlayersViewModel: AllLivePlayersViewModel
    
    // 🔥 PHASE 3 DI: Add initializer with dependency
    init(depthPlayer: DepthChartPlayer, livePlayersViewModel: AllLivePlayersViewModel) {
        self.depthPlayer = depthPlayer
        self._livePlayersViewModel = State(initialValue: livePlayersViewModel)
    }
    
    var body: some View {
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
                
                // 🔥 UPDATED: Show PPR points with clean styling, no rankings at all
                if let pprPoints = getPPRPoints() {
                    HStack(spacing: 3) {
                        Text("PPR")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f", pprPoints))
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
    
    // 🔥 NEW: Get PPR points for this player from live stats
    private func getPPRPoints() -> Double? {
        // Get player stats from AllLivePlayersViewModel
        guard let playerStats = livePlayersViewModel.playerStats[depthPlayer.player.playerID] else {
            return nil
        }
        
        // Try PPR points first, then half PPR, then standard as fallback
        if let pprPoints = playerStats["pts_ppr"], pprPoints > 0 {
            return pprPoints
        } else if let halfPprPoints = playerStats["pts_half_ppr"], halfPprPoints > 0 {
            return halfPprPoints
        } else if let stdPoints = playerStats["pts_std"], stdPoints > 0 {
            return stdPoints
        }
        
        return nil
    }
}