//
//  DepthChartPlayerRowInfoSectionView.swift
//  BigWarRoom
//
//  Player info section component for DepthChartPlayerRowView - CLEAN ARCHITECTURE
//

import SwiftUI

struct DepthChartPlayerRowInfoSectionView: View {
    let depthPlayer: DepthChartPlayer
    
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
}