//
//  PlayerScoreBarCardTeamLogoView.swift
//  BigWarRoom
//
//  Team logo component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardTeamLogoView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    var body: some View {
        Group {
            if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                TeamAssetManager.shared.logoOrFallback(for: team.id)
                    .frame(width: 20, height: 20) // Smaller logo (was 24x24)
            } else {
                // 🔥 DEBUG: Print when small logo fails too
                let _ = print("🔍 DEBUG - No small team logo for: \(playerEntry.player.shortName), team: '\(playerEntry.player.team ?? "nil")'")
                Circle()
                    .fill(leagueSourceColor)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var leagueSourceColor: Color {
        switch playerEntry.leagueSource {
        case "Sleeper": return .blue
        case "ESPN": return .red
        default: return .gray
        }
    }
}