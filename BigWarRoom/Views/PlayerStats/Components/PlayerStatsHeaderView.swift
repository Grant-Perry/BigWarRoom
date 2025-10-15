//
//  PlayerStatsHeaderView.swift
//  BigWarRoom
//
//  Header view for PlayerStatsCardView with player image and basic info
//

import SwiftUI

/// Header section with player image, name, position, and basic info
struct PlayerStatsHeaderView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    @StateObject private var livePlayersViewModel = AllLivePlayersViewModel.shared
    @StateObject private var playerNewsViewModel = PlayerNewsViewModel()
    
    // 🗞️ NEWS: Player news sheet state
    @State private var showingPlayerNews = false
    
    // 🔥 NEW: Computed ESPN ID that tries multiple methods to find ESPN ID
    private var resolvedESPNID: String? {
        print("🔍 DEBUG: Starting ESPN ID resolution for \(player.fullName)")
        
        // Method 1: Try the direct ESPN ID from Sleeper
        if let espnID = player.espnID {
            print("🔍 DEBUG: Found direct ESPN ID: \(espnID)")
            return espnID
        }
        
        // Method 2: Try PlayerMatchService to find another Sleeper player with ESPN ID
        print("🔍 DEBUG: No direct ESPN ID, trying PlayerMatchService...")
        let matchService = PlayerMatchService.shared
        let matchResult = matchService.matchPlayerWithConfidence(
            fullName: player.fullName,
            shortName: player.shortName,
            team: player.team,
            position: player.position ?? ""
        )
        
        if let matchedPlayer = matchResult.player, let espnID = matchedPlayer.espnID {
            print("🎯 SUCCESS: Resolved ESPN ID via PlayerMatchService: \(espnID)")
            return espnID
        }
        
        // Method 3: Try fallback mapping service for high-profile players
        print("🔍 DEBUG: No ESPN ID via PlayerMatchService, trying fallback mapping...")
        let fallbackService = ESPNIDMappingService.shared
        if let fallbackESPNID = fallbackService.getFallbackESPNID(
            fullName: player.fullName,
            team: player.team,
            position: player.position
        ) {
            print("🎯 SUCCESS: Resolved ESPN ID via fallback mapping: \(fallbackESPNID)")
            return fallbackESPNID
        }
        
        print("🔍 DEBUG: Final result - NO ESPN ID found for \(player.fullName) via any method")
        return nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // TAPPABLE PLAYER IMAGE FOR NEWS with NOTIFICATION BADGE
            Button(action: {
                print("🗞️ BUTTON TAPPED: \(player.fullName)")
                print("🗞️ Direct ESPN ID from Sleeper: \(player.espnID ?? "NONE")")
                print("🗞️ Resolved ESPN ID: \(resolvedESPNID ?? "NONE")")
                print("🗞️ Current news count: \(playerNewsViewModel.newsItems.count)")
                showingPlayerNews = true
            }) {
                PlayerImageView(
                    player: player,
                    size: 120,
                    team: team
                )
            }
            .buttonStyle(.plain)
            .notificationBadge(
                count: resolvedESPNID != nil ? playerNewsViewModel.newsItems.count : 0,
                xOffset: 8,
                yOffset: -8,
                badgeColor: .gpRedPink
            )
            .scaleEffect(
                resolvedESPNID != nil && playerNewsViewModel.newsItems.count > 0 ? 1.25 : 1.0,
                anchor: .topTrailing
            )
            
            // Original player info
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    // Position badge
                    positionBadge
                    
                    // Team info with PPR
                    if let team = team {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                teamAssets.logoOrFallback(for: team.id)
                                    .frame(width: 24, height: 24)
                                
                                Text(team.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let pprPoints = getPPRPoints() {
                                Text("PPR: \(String(format: "%.1f", pprPoints))")
                                    .font(.callout)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Jersey number
                    if let number = player.number {
                        Text("\(number)")
                            .font(.bebas(size: 44))
                            .fontWeight(.black)
                            .foregroundColor(team?.primaryColor ?? .primary)
                            .shadow(color: team?.secondaryColor ?? .black, radius: 0, x: 2, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(team?.backgroundColor ?? Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(team?.borderColor ?? Color(.systemGray4), lineWidth: 2)
                                    )
                            )
                    }
                }
            }
            
            // Additional info
            HStack(spacing: 20) {
                if let age = player.age {
                    PlayerInfoItem("Age", "\(age)", style: .compact)
                }
                if let yearsExp = player.yearsExp {
                    PlayerInfoItem("Exp", "Y\(yearsExp)", style: .compact)
                }
                if let height = player.height {
                    PlayerInfoItem("Height", height.formattedHeight, style: .compact)
                }
                if let weight = player.weight {
                    PlayerInfoItem("Weight", "\(weight) lbs", style: .compact)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(teamBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            print("🔍 DEBUG: PlayerStatsHeaderView.onAppear for \(player.fullName)")
            
            // Load news when view appears if player has ESPN ID (resolved)
            if let espnID = resolvedESPNID, let espnIDInt = Int(espnID) {
                print("🔍 DEBUG: Loading news with ESPN ID: \(espnIDInt)")
                playerNewsViewModel.loadPlayerNews(espnId: espnIDInt)
            } else {
                print("🔍 DEBUG: No ESPN ID resolved, skipping news load")
            }
        }
        .sheet(isPresented: $showingPlayerNews) {
            if let espnID = resolvedESPNID, let espnIDInt = Int(espnID) {
                // Use the actual PlayerNewsView with real ESPN data
                PlayerNewsView(player: PlayerData(
                    id: player.playerID,
                    fullName: player.fullName,
                    position: player.position ?? "UNK",
                    team: player.team ?? "UNK",
                    photoUrl: player.headshotURL?.absoluteString,
                    espnId: espnIDInt
                ))
            } else {
                // Fallback for players without ESPN ID
                testNewsSheet
            }
        }
    }
    
    // TEST SHEET for players without ESPN ID
    private var testNewsSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🗞️ NO NEWS AVAILABLE")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Player: \(player.fullName)")
                    .font(.title2)
                
                Text("❌ No ESPN ID in Sleeper data")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Text("This player doesn't have ESPN news integration available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Player News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPlayerNews = false
                    }
                }
            }
        }
    }
    
    private func getPPRPoints() -> Double? {
        guard let playerStats = livePlayersViewModel.playerStats[player.playerID] else {
            return nil
        }
        
        if let pprPoints = playerStats["pts_ppr"], pprPoints > 0 {
            return pprPoints
        } else if let halfPprPoints = playerStats["pts_half_ppr"], halfPprPoints > 0 {
            return halfPprPoints
        } else if let stdPoints = playerStats["pts_std"], stdPoints > 0 {
            return stdPoints
        }
        
        return nil
    }
    
    private var positionBadge: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var positionColor: Color {
        guard let position = player.position else { return .gray }
        
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
    
    private var teamBackgroundView: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 16)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            }
        }
    }
}

#Preview {
    let mockPlayerData = """
    {
        "player_id": "123",
        "first_name": "Jared",
        "last_name": "Goff",
        "position": "QB",
        "team": "DET",
        "espn_id": "3046779",
        "number": 16,
        "age": 30,
        "height": "76",
        "weight": 217,
        "years_exp": 9,
        "college": "California"
    }
    """.data(using: .utf8)!
    
    let mockPlayer = try! JSONDecoder().decode(SleeperPlayer.self, from: mockPlayerData)
    
    return PlayerStatsHeaderView(player: mockPlayer, team: nil)
}