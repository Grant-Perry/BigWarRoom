//
//  PlayerNotFoundView.swift
//  BigWarRoom
//
//  Fallback view when Sleeper player data is not available
//
// MARK: -> Player Not Found View

import SwiftUI

struct PlayerNotFoundView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(TeamAssetManager.self) private var teamAssets
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                
                // Player info we do have
                VStack(spacing: 8) {
                    Text(player.shortKey)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(player.position.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(positionColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if let team = NFLTeam.team(for: player.team) {
                        HStack(spacing: 8) {
                            teamAssets.logoOrFallback(for: team.id)
                                .frame(width: 24, height: 24)
                            Text(team.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Message
                VStack(spacing: 12) {
                    Text("Player Details Not Available")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("We couldn't find detailed stats for this player. This might be a newer player or the data hasn't been updated yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Basic info we can show
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Information")
                        .font(.headline)
                    
                    infoRow("Player ID", player.id)
                    infoRow("Position", player.position.rawValue)
                    infoRow("Team", player.team)
                    infoRow("Tier", "Tier \(player.tier)")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .navigationTitle("Player Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var positionColor: Color {
        switch player.position {
        case .qb: return .blue
        case .rb: return .green
        case .wr: return .purple
        case .te: return .orange
        case .k: return .yellow
        case .dst: return .red
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    PlayerNotFoundView(
        player: Player(
            id: "unknown-player",
            firstInitial: "J",
            lastName: "Unknown",
            position: .wr,
            team: "UNK",
            tier: 4
        )
    )
}