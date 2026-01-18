//
//  PlayerDetailsInfoView.swift
//  BigWarRoom
//
//  Player information section using DRY PlayerInfoItem component
//

import SwiftUI

/// Player details section using reusable components
struct PlayerDetailsInfoView: View {
    let player: SleeperPlayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let college = player.college {
                    PlayerInfoItem("College", college)
                }
                
                if let height = player.height, let weight = player.weight {
                    PlayerInfoItem("Size", "\(height.formattedHeight), \(weight) lbs")
                }
                
                if let yearsExp = player.yearsExp {
                    PlayerInfoItem("Experience", "\(yearsExp) years")
                }
                
                if let searchRank = player.searchRank {
                    PlayerInfoItem("Fantasy Rank", "#\(searchRank)")
                }
                
                if let depthChartPosition = player.depthChartPosition {
                    PlayerInfoItem("Depth Chart", "Position \(depthChartPosition)")
                }
                
                if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                    injuryStatusRow(injuryStatus)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func injuryStatusRow(_ status: String) -> some View {
        HStack {
            Text("Injury Status")
                .foregroundColor(.secondary)
            Spacer()
            Text(String(status.prefix(5)))
                .fontWeight(.semibold)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}