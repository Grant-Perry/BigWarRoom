//
//  WatchedPlayersSheet.swift
//  BigWarRoom
//
//  Sheet displaying all watched players with real-time deltas
//

import SwiftUI

/// Sheet for displaying and managing watched players
struct WatchedPlayersSheet: View {
    @ObservedObject var watchService: PlayerWatchService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // BG8 background
                Image("BG8")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea(.all)
                
                // Background overlay
                Color.black.opacity(0.3).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if watchService.watchedPlayers.isEmpty {
                        emptyStateView
                    } else {
                        // Watched players list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(watchService.sortedWatchedPlayers) { watchedPlayer in
                                    WatchedPlayerCard(watchedPlayer: watchedPlayer)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Watched Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !watchService.watchedPlayers.isEmpty {
                        Button("Clear All") {
                            watchService.clearAllWatchedPlayers()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Watched Players")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Red notification badge with count
                        if watchService.watchedPlayers.count > 0 {
                            Text("\(watchService.watchedPlayers.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(
                                    Circle()
                                        .fill(.red)
                                )
                                .scaleEffect(watchService.watchedPlayers.count > 99 ? 0.8 : 1.0) // Scale down for large numbers
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "eye.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Players Watched")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Tap the eye icon on opponent players to start monitoring their performance in real-time")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 8) {
                Text("👁️ Watch up to \(watchService.settings.maxWatchedPlayers) players")
                Text("📊 Track score deltas from watch start")
                Text("🔔 Get notified when they explode")
            }
            .font(.system(size: 14))
            .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Watched Player Card

struct WatchedPlayerCard: View {
    let watchedPlayer: WatchedPlayer
    @ObservedObject private var watchService = PlayerWatchService.shared
    @StateObject private var fantasyPlayerViewModel = FantasyPlayerViewModel()
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main card content
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 80) // Space for image
                
                // Player info section
                VStack(alignment: .leading, spacing: 6) {
                    // Name and team header
                    HStack {
                        Text(watchedPlayer.playerName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let team = watchedPlayer.team {
                            Text(team)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        // Unwatch button
                        Button(action: {
                            watchService.unwatchPlayer(watchedPlayer.playerID)
                        }) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Scores section
                    HStack(spacing: 16) {
                        // Initial score
                        VStack(alignment: .leading, spacing: 2) {
                            Text("START")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.gray)
                            
                            Text(String(format: "%.1f", watchedPlayer.initialScore))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        
                        // Current score
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CURRENT")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.gray)
                            
                            Text(String(format: "%.1f", watchedPlayer.currentScore))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(watchedPlayer.isLive ? .green : .white)
                        }
                        
                        Spacer()
                        
                        // Watch duration
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("WATCHING")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.gray)
                            
                            Text(watchedPlayer.watchDurationString)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Opponent references
                    if !watchedPlayer.opponentReferences.isEmpty {
                        HStack {
                            Text("vs")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                            
                            ForEach(watchedPlayer.opponentReferences.prefix(2)) { opponent in
                                Text(opponent.opponentName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            
                            if watchedPlayer.opponentReferences.count > 2 {
                                Text("+\(watchedPlayer.opponentReferences.count - 2) more")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Delta and threat section
                VStack(spacing: 8) {
                    // Threat level
                    VStack(spacing: 4) {
                        Text(watchedPlayer.currentThreatLevel.emoji)
                            .font(.system(size: 24))
                        
                        Text(watchedPlayer.currentThreatLevel.rawValue)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(watchedPlayer.currentThreatLevel.color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(watchedPlayer.currentThreatLevel.color.opacity(0.2))
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    // Delta score
                    VStack(spacing: 2) {
                        Text("DELTA")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.gray)
                        
                        Text(watchedPlayer.deltaDisplay)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(watchedPlayer.deltaColor)
                    }
                    
                    // Live indicator
                    if watchedPlayer.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(width: 80)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(watchedPlayer.currentThreatLevel.color.opacity(0.5), lineWidth: 1)
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                watchedPlayer.currentThreatLevel.color.opacity(0.1),
                                watchedPlayer.currentThreatLevel.color.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            
            // NOW overlay the team logo and player image on top (same pattern as All Live Players)
            HStack {
                ZStack {
                    // Large floating team logo behind player - EXACTLY like AllLivePlayersView
                    let teamCode = watchedPlayer.team ?? ""
                    // Use TeamCodeNormalizer for consistent team mapping
                    let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                    
                    if let team = NFLTeam.team(for: normalizedTeamCode) {
                        TeamAssetManager.shared.logoOrFallback(for: team.id)
                            .frame(width: 140, height: 140)
                            .opacity(0.35) // Increased opacity to make it more visible
                            .offset(x: 15, y: 0) // Adjusted positioning
                            .zIndex(0)
                    } else {
                        // Debug - let's see what's happening
                        let _ = print("🔍 WATCHED PLAYER DEBUG - No team logo for player: \(watchedPlayer.playerName), team: '\(teamCode)' (normalized: '\(normalizedTeamCode)')")
                        
                        // Fallback colored rectangle to show where logo should be
                        Rectangle()
                            .fill(positionColor.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .offset(x: 15, y: 0)
                            .zIndex(0)
                    }
                    
                    // Player image in front with NavigationLink
                    if let sleeperPlayer = getSleeperPlayerData() {
                        NavigationLink(destination: PlayerStatsCardView(
                            player: sleeperPlayer,
                            team: NFLTeam.team(for: watchedPlayer.team ?? "")
                        )) {
                            playerImageView
                        }
                        .buttonStyle(PlainButtonStyle())
                        .zIndex(1)
                        .offset(x: -40) // Move player left to show more of team logo
                    } else {
                        // Fallback - show image but not clickable if no SleeperPlayer data
                        playerImageView
                            .zIndex(1)
                            .offset(x: -40)
                    }
                }
                .frame(height: 90) // Increased height to accommodate larger logo
                .frame(maxWidth: 160) // Increased width to accommodate larger logo
                .offset(x: -5) // Adjust overall positioning
                
                Spacer()
            }
            
            // Position badge overlay
            VStack {
                HStack {
                    VStack {
                        Spacer()
                        
                        Text(watchedPlayer.position)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(positionColor)
                            )
                    }
                    .padding(.leading, 8)
                    .padding(.bottom, 8)
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .frame(height: 130) // Increased card height to accommodate larger team logo
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Clip the entire thing
    }
    
    // MARK: - Helper Views
    
    private var playerImageView: some View {
        AsyncImage(url: createHeadshotURL()) { phase in
            switch phase {
            case .empty:
                // Loading state with team gradient background
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
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                // Failed to load - show fallback with team colors
                Rectangle()
                    .fill(teamGradient)
                    .overlay(
                        Text(String(watchedPlayer.playerName.prefix(1).uppercased()))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
            @unknown default:
                Rectangle()
                    .fill(teamGradient)
                    .overlay(
                        Text(String(watchedPlayer.playerName.prefix(1).uppercased()))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 70, height: 90) // Slightly smaller than All Live Players to fit the watched player card
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helper Methods
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: watchedPlayer.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [positionColor], startPoint: .top, endPoint: .bottom)
    }
    
    private func getSleeperPlayerData() -> SleeperPlayer? {
        // Use PlayerMatchService to find the SleeperPlayer
        return PlayerMatchService.shared.matchPlayer(
            fullName: watchedPlayer.playerName,
            shortName: watchedPlayer.playerName, // We don't have shortName in WatchedPlayer, so use fullName
            team: watchedPlayer.team,
            position: watchedPlayer.position.uppercased()
        )
    }
    
    private func createHeadshotURL() -> URL? {
        // Try to get the URL from SleeperPlayer data if available
        if let sleeperPlayer = getSleeperPlayerData() {
            return sleeperPlayer.headshotURL
        }
        
        // Fallback to constructing URL from player name (less reliable)
        return nil
    }
    
    private var positionColor: Color {
        switch watchedPlayer.position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}

#Preview("Watched Players Sheet") {
    WatchedPlayersSheet(watchService: PlayerWatchService.shared)
        .preferredColorScheme(.dark)
}