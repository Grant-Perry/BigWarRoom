//
//  PlayerDetailFallbackView.swift
//  BigWarRoom
//
//  Fallback view for player details when full stats are unavailable
//

import SwiftUI

/// Fallback view displayed when detailed player stats are unavailable
struct PlayerDetailFallbackView: View {
    let player: FantasyPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Player Avatar
            AsyncImage(url: player.headshotURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.gray)
                    .overlay(
                        Text(player.shortName.prefix(2))
                            .font(.title)
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            
            // Player Information
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    Text(player.position)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(positionColor(player.position))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if let team = player.team {
                        Text(team)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let jersey = player.jerseyNumber {
                        Text("#\(jersey)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stats Section
            VStack(spacing: 12) {
                HStack {
                    Text("Current Points")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(player.currentPointsString)
                        .fontWeight(.bold)
                        .foregroundColor(.gpGreen)
                }
                
                if let projected = player.projectedPoints {
                    HStack {
                        Text("Projected Points")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", projected))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Text("Detailed stats unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle(player.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func positionColor(_ position: String) -> Color {
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
}