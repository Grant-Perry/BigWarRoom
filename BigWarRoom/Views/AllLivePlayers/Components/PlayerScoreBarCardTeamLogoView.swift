//
//  PlayerScoreBarCardTeamLogoView.swift
//  BigWarRoom
//
//  Team logo component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardTeamLogoView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    // 🔥 NEW: State for accessing player directory for injury data
    @State private var playerDirectory = PlayerDirectoryStore.shared
    
    var body: some View {
        ZStack {
            // Main team logo or fallback circle
            Group {
                if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
                    TeamAssetManager.shared.logoOrFallback(for: team.id)
                        .frame(width: 20, height: 20) // Smaller logo (was 24x24)
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
                            .scaleEffect(0.7) // Scale for smaller team logo
                            .offset(x: -2, y: -2) // Adjusted positioning for small logo
                    }
                }
            }
            
            // 🔥 DEBUG: Force show badge for Lamar Jackson to test visibility
            if playerEntry.player.fullName.contains("Lamar Jackson") {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: "Questionable")
                            .scaleEffect(0.7)
                            .offset(x: -2, y: -2)
                            .border(Color.red, width: 2) // Debug border to see positioning
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
            print("🔍 DEBUG TEAM LOGO: Searching for Lamar Jackson injury data")
            print("   Player Name: \(playerName)")
            print("   Short Name: \(shortName)")
            print("   Team: \(team ?? "nil")")
            print("   SleeperID: \(playerEntry.player.sleeperID ?? "nil")")
            print("   ESPNID: \(playerEntry.player.espnID ?? "nil")")
        }
        
        let result = playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
        
        // 🔍 DEBUG: Log result for Lamar Jackson
        if playerName.contains("lamar jackson") {
            print("   Found SleeperPlayer: \(result != nil)")
            print("   Injury Status: \(result?.injuryStatus ?? "nil")")
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