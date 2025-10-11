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
    @Environment(\.editMode) private var editMode
    
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
                        // Native SwiftUI List with .onMove for smooth drag & drop
                        List {
                            ForEach(watchService.displayOrderWatchedPlayers, id: \.id) { watchedPlayer in
                                WatchedPlayerCard(watchedPlayer: watchedPlayer)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onMove(perform: moveWatchedPlayers)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.editMode, .constant(.active)) // Always enable drag handles
                        .padding(.bottom, 100)
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
                    Text("Watched Players")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .notificationBadge(count: watchService.watchedPlayers.count, xOffset: 20, yOffset: -8)
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
    
    // MARK: - Native SwiftUI Drag and Drop
    
    private func moveWatchedPlayers(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            watchService.moveWatchedPlayers(from: source, to: destination)
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
    
    // Computed properties to break up complex ViewBuilder
    private var sleeperPlayerData: SleeperPlayer? {
        PlayerMatchService.shared.matchPlayer(
            fullName: watchedPlayer.playerName,
            shortName: watchedPlayer.playerName,
            team: watchedPlayer.team,
            position: watchedPlayer.position.uppercased()
        )
    }
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: watchedPlayer.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [positionColor], startPoint: .top, endPoint: .bottom)
    }
    
    private var normalizedTeamCode: String {
        let teamCode = watchedPlayer.team ?? ""
        return TeamCodeNormalizer.normalize(teamCode) ?? teamCode
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
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Main card content
            mainCardContent
            
            // Player image overlay
            playerImageOverlay
            
            // Position badge overlay
            positionBadgeOverlay
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Component Views
    
    private var mainCardContent: some View {
        HStack(spacing: 0) {
            // Empty space for where image will be overlaid
            Rectangle()
                .fill(Color.clear)
                .frame(width: 80)
            
            // Player info section
            playerInfoSection
            
            Spacer()
            
            // Delta and threat section
            deltaAndThreatSection
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Name and team header
            HStack {
                Text(watchedPlayer.playerName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                
                Spacer()
                
                if let team = watchedPlayer.team {
                    Text(team)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
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
            scoresSection
            
            // Opponent references
            opponentReferencesSection
        }
        .padding(.leading, 12)
        .zIndex(10)
    }
    
    private var scoresSection: some View {
        HStack(spacing: 16) {
            // Initial score
            VStack(alignment: .leading, spacing: 2) {
                Text("START")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                
                Text(String(format: "%.1f", watchedPlayer.initialScore))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
            }
            
            // Current score
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                
                Text(String(format: "%.1f", watchedPlayer.currentScore))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(watchedPlayer.isLive ? .green : .white)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
            }
            
            Spacer()
            
            // Watch duration
            VStack(alignment: .trailing, spacing: 2) {
                Text("WATCHING")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                
                Text(watchedPlayer.watchDurationString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
            }
        }
    }
    
    private var opponentReferencesSection: some View {
        Group {
            if !watchedPlayer.opponentReferences.isEmpty {
                HStack {
                    Text("vs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    
                    ForEach(watchedPlayer.opponentReferences.prefix(2)) { opponent in
                        Text(opponent.opponentName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                            .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    }
                    
                    if watchedPlayer.opponentReferences.count > 2 {
                        Text("+\(watchedPlayer.opponentReferences.count - 2) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    }
                }
            }
        }
    }
    
    private var deltaAndThreatSection: some View {
        VStack(spacing: 8) {
            // Threat level
            VStack(spacing: 4) {
                Image(systemName: watchedPlayer.currentThreatLevel.sfSymbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(watchedPlayer.currentThreatLevel.color)
                
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
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(watchedPlayer.currentThreatLevel.color.opacity(0.5), lineWidth: 1)
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
    }
    
    private var playerImageOverlay: some View {
        HStack {
            ZStack {
                // Large floating team logo behind player
                teamLogoBackground
                
                // Player image in front
                playerImageWithNavigation
            }
            .frame(height: 90)
            .frame(maxWidth: 140)
            .offset(x: 0)
            
            Spacer()
        }
    }
    
    private var teamLogoBackground: some View {
        Group {
            if let team = NFLTeam.team(for: normalizedTeamCode) {
                TeamAssetManager.shared.logoOrFallback(for: team.id)
                    .frame(width: 100, height: 100)
                    .opacity(0.2)
                    .offset(x: 20, y: 0)
                    .zIndex(0)
            } else {
                Rectangle()
                    .fill(positionColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .offset(x: 20, y: 0)
                    .zIndex(0)
            }
        }
    }
    
    private var playerImageWithNavigation: some View {
        Group {
            if let sleeperPlayer = sleeperPlayerData {
                NavigationLink(destination: PlayerStatsCardView(
                    player: sleeperPlayer,
                    team: NFLTeam.team(for: watchedPlayer.team ?? "")
                )) {
                    playerImageView
                }
                .buttonStyle(PlainButtonStyle())
                .zIndex(2)
                .offset(x: -1)
            } else {
                playerImageView
                    .zIndex(2)
                    .offset(x: -1)
            }
        }
    }
    
    private var positionBadgeOverlay: some View {
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
    
    // MARK: - Helper Views
    
    private var playerImageView: some View {
        AsyncImage(url: createHeadshotURL()) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(teamGradient)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
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
        .frame(width: 70, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helper Methods
    
    private func createHeadshotURL() -> URL? {
        return sleeperPlayerData?.headshotURL
    }
}

#Preview("Watched Players Sheet") {
    WatchedPlayersSheet(watchService: PlayerWatchService.shared)
        .preferredColorScheme(.dark)
}