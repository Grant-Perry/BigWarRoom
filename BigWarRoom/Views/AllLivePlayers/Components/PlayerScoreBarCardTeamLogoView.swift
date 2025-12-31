//
//  PlayerScoreBarCardTeamLogoView.swift
//  BigWarRoom
//
//  Team logo component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardTeamLogoView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(PlayerDirectoryStore.self) private var playerDirectory
    
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    var body: some View {
        ZStack {
            // Main team logo or fallback circle
            Group {
                if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                    teamAssets.logoOrFallback(for: team.id)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .fill(leagueSourceColor)
                        .frame(width: 6, height: 6)
                }
            }
            
            // 🔥 NEW: Injury Status Badge - EXACT COPY from PlayerScoreBarCardPlayerImageView
            if let injuryStatus = getSleeperPlayerData()?.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .scaleEffect(0.7)
                            .offset(x: -2, y: -2)
                    }
                }
            }
        }
    }
    
    // 🔥 NEW: Get Sleeper player data - EXACT COPY from PlayerScoreBarCardPlayerImageView
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName.lowercased()
        let shortName = playerEntry.player.shortName.lowercased()
        let team = playerEntry.player.team?.lowercased()
        
        // 🔥 DEBUG: Log for Lamar Jackson
        if playerName.contains("lamar jackson") {
        }
        
        let result = playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
        
        // 🔍 DEBUG: Log result for Lamar Jackson
        if playerName.contains("lamar jackson") {
        }
        
        return result
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