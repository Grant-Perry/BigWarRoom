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
                        // Sort control section (matching All Live Players style)
                        sortControlsSection
                        
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
                    }
                }
            }
            .navigationTitle("Watched Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        if !watchService.watchedPlayers.isEmpty {
                            // 🔄 NEW: Reset All Deltas Button
                            Button("Reset Δ") {
                                watchService.resetAllDeltas()
                            }
                            .foregroundColor(.orange)
                            
                            // Clear All Button (existing)
                            Button("Clear All") {
                                watchService.clearAllWatchedPlayers()
                            }
                            .foregroundColor(.red)
                        }
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
    
    // MARK: - Sort Controls Section
    
    private var sortControlsSection: some View {
        HStack {
            Spacer()
            
            // Sort Method Toggle - Make it clickable when STATIC
            Button(action: {
                if watchService.isManuallyOrdered {
                    // If currently manual, reset to automatic with current sort method
                    watchService.resetToAutomaticSorting()
                } else {
                    // If automatic, cycle through sort methods or show menu
                    cycleToNextSortMethod()
                }
            }) {
                VStack(spacing: 2) {
                    Text(watchService.isManuallyOrdered ? "STATIC" : watchService.sortMethod.displayName.uppercased())
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(watchService.isManuallyOrdered ? .gpOrange : .gpGreen)
                    
                    Text("Sort Order")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Sort Direction with Up/Down Chevron - Always show
            Button(action: {
                if watchService.isManuallyOrdered {
                    // Reset to automatic when clicked in manual mode
                    watchService.resetToAutomaticSorting()
                } else {
                    // Toggle direction in automatic mode
                    watchService.toggleSortDirection()
                }
            }) {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        // 🔥 NEW: Always show up/down chevron
                        Image(systemName: watchService.sortHighToLow ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(watchService.isManuallyOrdered ? .gpOrange : .purple)
                        
                        Text(directionText)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(watchService.isManuallyOrdered ? .gpOrange : .purple)
                    }
                    
                    Text("Direction")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Drag Hint
            VStack(spacing: 2) {
                Text("DRAG")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.gpBlue)
                
                Text("To Reorder")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.1))
    }
    
    // 🔥 NEW: Cycle through sort methods
    private func cycleToNextSortMethod() {
        let allMethods = WatchSortMethod.allCases
        let currentIndex = allMethods.firstIndex(of: watchService.sortMethod) ?? 0
        let nextIndex = (currentIndex + 1) % allMethods.count
        watchService.setSortMethod(allMethods[nextIndex])
    }
    
    // 🔥 NEW: Dynamic direction text based on sort method
    private var directionText: String {
        if watchService.isManuallyOrdered {
            return "CUSTOM"
        }
        
        switch watchService.sortMethod {
        case .delta, .threat, .current:
            return watchService.sortHighToLow ? "HIGH→LOW" : "LOW→HIGH"
        case .name, .position:
            return watchService.sortHighToLow ? "Z→A" : "A→Z"
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
    
    // 🔥 NEW: State for player stats sheet
    @State private var showingPlayerStats = false
    
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
        VStack(spacing: 0) {
            // Header row with player name and controls
            HStack {
                // Player name and team
                HStack(spacing: 8) {
                    Text(watchedPlayer.playerName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                    
                    if let team = watchedPlayer.team {
                        Text(team)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                    }
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 8) {
                    // Reset delta button
                    Button(action: {
                        watchService.resetPlayerDelta(watchedPlayer.playerID)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Main content row
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 80)
                
                // Player info section (no longer has name)
                playerInfoSection
                
                Spacer()
                
                // Delta and threat section
                deltaAndThreatSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(cardBackground)
    }
    
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // EMPTY - player name moved to header
            
            // Scores section (now takes up more space)
            scoresSection
            
            // Opponent references
            opponentReferencesSection
        }
        .padding(.leading, 12)
        .zIndex(10)
    }
    
    private var scoresSection: some View {
        HStack(spacing: 8) { // 🔥 REDUCED spacing from 16 to 8 to make more room
            // Initial score
            VStack(alignment: .leading, spacing: 2) {
                Text("START")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(String(format: "%.1f", watchedPlayer.initialScore))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 45) // 🔥 FIXED width for START column
            
            // Current score - EXPANDED
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(String(format: "%.1f", watchedPlayer.currentScore))
                    .font(.system(size: 20, weight: .bold, design: .rounded)) // Large size maintained
                    .foregroundColor(watchedPlayer.deltaScore >= 0 ? .gpRedPink : .gpGreen) // 🔥 WIN/LOSE COLORS: Red when opponent scoring (bad), Green when struggling (good)
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // 🔥 INCREASED from 0.7 to 0.8 for better readability
            }
            .frame(minWidth: 65) // 🔥 INCREASED minimum width for CURRENT column
            
            Spacer()
            
            // 🔥 NEW: Delta score on same line as CURRENT
            VStack(alignment: .trailing, spacing: 2) {
                Text("DELTA")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(watchedPlayer.deltaDisplay)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(
                        watchedPlayer.deltaScore == 0 ? .secondary : 
                        (watchedPlayer.deltaScore > 0 ? .gpGreen : .gpRedPink)
                    ) // 🔥 FIXED: Gray when exactly 0, Green when positive, Red when negative
                    .lineLimit(1)
                    .minimumScaleFactor(1.0)
            }
            .frame(width: 50) // 🔥 FIXED width for DELTA column
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
            
            // Watch duration
            VStack(spacing: 2) {
                Text(watchedPlayer.watchDurationString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        Button(action: {
            // 🔥 FIXED: Use sheet instead of NavigationLink
            showingPlayerStats = true
        }) {
            playerImageView
        }
        .buttonStyle(PlainButtonStyle())
        .zIndex(2)
        .offset(x: -1)
        .sheet(isPresented: $showingPlayerStats) {
            NavigationView {
                if let sleeperPlayer = sleeperPlayerData {
                    PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: watchedPlayer.team ?? "")
                    )
                } else {
                    // 🔥 SIMPLIFIED FALLBACK: Show error message instead of trying to create SleeperPlayer
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Player Not Found")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Unable to load detailed stats for \(watchedPlayer.playerName)")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Dismiss") {
                            showingPlayerStats = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .navigationTitle("Player Stats")
                    .navigationBarTitleDisplayMode(.inline)
                }
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