//
//  PlayerScoreBarCardPlayerImageView.swift
//  BigWarRoom
//
//  Player image component for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

// 🔥 NAVIGATION VALUE: Used for type-safe navigation from lazy containers
struct PlayerNavigationValue: Hashable {
    let sleeperPlayer: SleeperPlayer?
    let playerFullName: String
    let teamAbbrev: String?
    
    init(sleeperPlayer: SleeperPlayer?, playerName: String, team: String?) {
        self.sleeperPlayer = sleeperPlayer
        self.playerFullName = playerName
        self.teamAbbrev = team
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(playerFullName)
        hasher.combine(teamAbbrev)
    }
    
    static func == (lhs: PlayerNavigationValue, rhs: PlayerNavigationValue) -> Bool {
        lhs.playerFullName == rhs.playerFullName && lhs.teamAbbrev == rhs.teamAbbrev
    }
}

struct PlayerScoreBarCardPlayerImageView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    // 🔥 PHASE 3 DI: PlayerDirectory removed - not used in this view
    
    var body: some View {
        // 🔥 FIX: Use NavigationLink(value:) instead of navigationDestination inside lazy container
        NavigationLink(value: PlayerNavigationValue(
            sleeperPlayer: getSleeperPlayerData(),
            playerName: playerEntry.player.fullName,
            team: playerEntry.player.team
        )) {
            playerImageContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Extracted image content to separate computed property
    private var playerImageContent: some View {
        // 🔥 DEBUG: Log D/ST detection OUTSIDE the view builder
        let _ = logDSTPlayerInfo()
        
        return ZStack {
            // Main player image or team logo
            if isDefenseOrSpecialTeams {
                // Use EXACT same logic as the background logo in PlayerScoreBarCardContentView
                let teamCode = playerEntry.player.team ?? ""
                let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                
                if let team = NFLTeam.team(for: normalizedTeamCode) {
                    TeamAssetManager.shared.logoOrFallback(for: team.id)
                        .frame(width: 140, height: 140)
                } else {
                    // Fallback
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("DEF")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            } else {
                // Regular player - show headshot
                AsyncImage(url: playerEntry.player.headshotURL) { phase in
                    switch phase {
                    case .empty:
                        // Loading state
                        Rectangle()
                            .fill(teamGradient)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    case .success(let image):
                        // Successfully loaded image
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure(_):
                        // Failed to load - try alternative URL or show fallback
                        AsyncImage(url: alternativeImageURL) { altPhase in
                            switch altPhase {
                            case .success(let altImage):
                                altImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            default:
                                Rectangle()
                                    .fill(teamGradient)
                                    .overlay(
                                        Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    @unknown default:
                        Rectangle()
                            .fill(teamGradient)
                            .overlay(
                                Text(playerEntry.player.firstName?.prefix(1).uppercased() ?? "?")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 150, height: 180)
            }
            
            // 🔥 NEW: Injury Status Badge (positioned at bottom-right of image)
            if let injuryStatus = getSleeperPlayerData()?.injuryStatus, !injuryStatus.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .offset(x: -8, y: -8) // Position as subscript to image
                    }
                }
            }
            
            // 🔥 DEBUG: Force show badge in simple position for Lamar Jackson
            if playerEntry.player.fullName.contains("Lamar Jackson") {
                VStack {
                    HStack {
                        Spacer()
                        InjuryStatusBadgeView(injuryStatus: "Q")
                            .background(Color.red.opacity(0.5))
                            .scaleEffect(1.5)
                    }
                    Spacer()
                }
            }
        }
    }
    
    // --- Insert the logger function here ---
    private func logDSTPlayerInfo() {
        if isDefenseOrSpecialTeams {
            let teamCode = playerEntry.player.team ?? ""
            let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
            DebugPrint(mode: .matchupLoading, "🏈 D/ST PLAYER: \(playerEntry.player.fullName)")
            DebugPrint(mode: .matchupLoading, "   Raw team code: \(teamCode)")
            DebugPrint(mode: .matchupLoading, "   Normalized code: \(normalizedTeamCode)")
            DebugPrint(mode: .matchupLoading, "   Position: \(playerEntry.position)")
            if let team = NFLTeam.team(for: normalizedTeamCode) {
                DebugPrint(mode: .matchupLoading, "   ✅ Found team: \(team.fullName)")
            } else {
                DebugPrint(mode: .matchupLoading, "   ❌ NO TEAM FOUND - showing fallback")
            }
        }
    }
    
    // 🔥 UPDATED: Helper to identify defense/special teams players - check all variations
    private var isDefenseOrSpecialTeams: Bool {
        let position = playerEntry.position.uppercased()
        let isDST = position.contains("DEF") || position.contains("DST") || position.contains("D/ST")
        
        DebugPrint(mode: .matchupLoading, limit: 3, "🔍 Position check for \(playerEntry.player.fullName): '\(position)' -> isDST: \(isDST)")
        
        return isDST
    }
    
    // 🔥 FIXED: Get Sleeper player data using SAME logic as Content View
    private func getSleeperPlayerData() -> SleeperPlayer? {
        // 🔥 FIX: Try SleeperID first (most reliable) - SAME AS CONTENT VIEW
        if let sleeperID = playerEntry.player.sleeperID,
           let sleeperPlayer = PlayerDirectoryStore.shared.players[sleeperID] {
            return sleeperPlayer
        }
        
        // Try ESPN ID mapping to Sleeper
        if let espnID = playerEntry.player.espnID,
           let sleeperPlayer = PlayerDirectoryStore.shared.playerByESPNID(espnID) {
            return sleeperPlayer
        }
        
        // Fallback to name-based lookup
        let playerName = playerEntry.player.fullName.lowercased()
        let shortName = playerEntry.player.shortName.lowercased()
        let team = playerEntry.player.team?.lowercased()
        
        return PlayerDirectoryStore.shared.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
    }
    
    // MARK: - Computed Properties (Data Only)
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    /// Alternative image URL for retry logic
    private var alternativeImageURL: URL? {
        // Try ESPN headshot as fallback
        if let espnURL = playerEntry.player.espnHeadshotURL {
            return espnURL
        }
        
        // For defense/special teams, try a different approach
        if playerEntry.position == "DEF" || playerEntry.position == "DST" {
            if let team = playerEntry.player.team {
                // Try ESPN team logo as player image for defenses
                return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
            }
        }
        
        return nil
    }
}