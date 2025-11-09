//
//  PlayerScoreBarCardContentView.swift
//  BigWarRoom
//
//  Main content view for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardContentView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    let cardHeight: Double
    let formattedPlayerName: String
    let playerScoreColor: Color
    
    @Bindable var viewModel: AllLivePlayersViewModel
    @State private var watchService = PlayerWatchService.shared
    @State private var playerDirectory = PlayerDirectoryStore.shared // 🔥 PHASE 2.5: Use @State for @Observable
    
    @State private var showingScoreBreakdown = false
    @State private var isLoadingOverlayVisible = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 🔥 NEW: Jersey number as bottom layer - before any other content
            HStack {
                Spacer()
                if let jerseyNumber = getJerseyNumber() {
                    JerseyNumberView(
                        jerseyNumber: jerseyNumber,
                        teamColor: getContrastingJerseyColor(for: playerEntry.player.team ?? "")
                    )
                    .offset(x: -60, y: 15) // Position it in the right area
                }
                Spacer()
            }
            
            // Build the card content first (without image)
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 65) // Space for image
                
                // Center matchup section
                VStack {
                    Spacer()
                    NavigationLink(destination: MatchupDetailSheetsView(matchup: playerEntry.matchup)) {
                        MatchupTeamFinalView(player: playerEntry.player)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .offset(x: 37)
                .scaleEffect(1.1)
                
                // Player info - moved to right side with swapped league banner and player name
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Spacer()
                        
                        // Player name moved to top (no position badge here)
                        Text(formattedPlayerName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    HStack(spacing: 6) {
                        Spacer()
                        
                        // League banner and position badge on same line (swapped order)
                        PlayerScoreBarCardLeagueBannerView(playerEntry: playerEntry)
                        PlayerScoreBarCardPositionBadgeView(playerEntry: playerEntry)
                    }
                    
                    Spacer() // Push score to bottom of this section
                    
                    // Score info and watch button row
                    HStack(spacing: 8) {
                        // Watch toggle button
                        Button(action: toggleWatch) {
                            Image(systemName: isWatching ? "eye.fill" : "eye")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isWatching ? .gpOrange : .gray)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(isWatching ? Color.gpOrange.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -20) // Smaller offset to align with points without disappearing
                        
                        // 🔥 NEW: Load Matchup button
                        NavigationLink(destination: MatchupDetailSheetsView(matchup: playerEntry.matchup)) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -20)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            // 🔥 FIXED: Make score clickable with background like before
                            Button(action: {
                                Task { await presentScoreBreakdown() }
                            }) {
                                HStack(spacing: 8) {
                                    Text(playerEntry.currentScoreString)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundColor(playerScoreColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    
                                    Text("pts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(playerScoreColor.opacity(0.4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(playerScoreColor.opacity(0.6), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(y: -20)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                PlayerScoreBarCardBackgroundView(
                    playerEntry: playerEntry,
                    scoreBarWidth: scoreBarWidth
                )
            )
            
            // 🔥 SIMPLIFIED: Basic stats section - only show if player has points
            if playerEntry.currentScore > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Text(simpleStatsDisplay)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            
            // NOW overlay the player image on top - unconstrained!
            HStack {
                ZStack {
                    // 🔥 FIXED: Large floating team logo behind player
                    let teamCode = playerEntry.player.team ?? ""
                    let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                    
                    if let team = NFLTeam.team(for: normalizedTeamCode) {
                        // Team logo
                        TeamAssetManager.shared.logoOrFallback(for: team.id)
                            .frame(width: 140, height: 140)
                            .opacity(0.25)
                            .offset(x: 20, y: 15)
                            .zIndex(0)
                    }
                    
                    // Player image in front - FIXED HEIGHT
                    PlayerScoreBarCardPlayerImageView(playerEntry: playerEntry)
                        .zIndex(1)
                        .offset(x: -35) // 🔥 NEW: Move player left to clip off shoulder
                    
                    // 🔥 INJURY BADGE: RIGHT SHOULDER of player - positioned relative to player image
                    if let injuryStatus = getSleeperPlayerData()?.injuryStatus, !injuryStatus.isEmpty {
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .scaleEffect(0.8)
                            .offset(x: 25, y: 5) // RIGHT SHOULDER: Same position as test badge
                            .zIndex(15) // Higher than player image zIndex
                    }
                }
                .frame(height: 80) // Constrain height
                .frame(maxWidth: 180) // 🔥 INCREASED: Wider to accommodate offset logo (was 120)
                .offset(x: -10)
                Spacer()
            }
        }
        .frame(height: cardHeight) // Apply the card height constraint
        .clipShape(RoundedRectangle(cornerRadius: 12)) // Restore clipping
        
        // Inline loading overlay (not a sheet)
        .overlay {
            if isLoadingOverlayVisible {
                ZStack {
                    // MARK: Transparancy for point proof overlay
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading stats...")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        
        // Final sheet only for the breakdown once stats are ready
        .sheet(isPresented: $showingScoreBreakdown) {
            let leagueContext = LeagueContext(
                leagueID: playerEntry.matchup.league.league.leagueID,
                source: playerEntry.matchup.league.source,
                isChopped: playerEntry.matchup.isChoppedLeague
            )
            
            let breakdown = ScoreBreakdownFactory.createBreakdown(
                for: playerEntry.player,
                week: WeekSelectionManager.shared.selectedWeek,
                leagueContext: leagueContext
            ).withLeagueName(playerEntry.leagueName)
            
            ScoreBreakdownView(breakdown: breakdown)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
    }
    
    // MARK: - Loading + Sheet Orchestration
    private func presentScoreBreakdown() async {
        // Show inline overlay
        await MainActor.run { isLoadingOverlayVisible = true }
        
        // Ensure stats are available on-demand
        if !AllLivePlayersViewModel.shared.statsLoaded {
            // IMPORTANT: Load using the singleton since ScoreBreakdown/StatsFacade reads from the shared store
            await AllLivePlayersViewModel.shared.loadAllPlayers()
        }
        
        // Hide overlay and present the breakdown sheet
        await MainActor.run {
            isLoadingOverlayVisible = false
            showingScoreBreakdown = true
        }
    }
    
    // 🔥 NEW: Get Sleeper player data for injury status - REMOVED DEBUG
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName.lowercased()
        let shortName = playerEntry.player.shortName.lowercased()
        let team = playerEntry.player.team?.lowercased()
        
        let result = playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
        
        return result
    }
    
    // MARK: - Watch Functionality
    
    private var isWatching: Bool {
        watchService.isWatching(playerEntry.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(playerEntry.player.id)
        } else {
            // Create opponent references from the matchup context
            let opponentRefs = createOpponentReferences()
            
            // Convert LivePlayerEntry to OpponentPlayer for watching
            let opponentPlayer = OpponentPlayer(
                id: UUID().uuidString,
                player: playerEntry.player,
                isStarter: playerEntry.isStarter,
                currentScore: playerEntry.currentScore,
                projectedScore: playerEntry.projectedScore,
                threatLevel: .moderate, // Default threat level for personal players
                matchupAdvantage: .neutral, // Neutral advantage for personal players
                percentageOfOpponentTotal: 0.0 // Not applicable for personal players
            )
            
            let success = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentRefs)
            if !success {
                // TODO: Show alert about watch limit or other issues
                print("Failed to watch player - possibly at limit")
            }
        }
    }
    
    private func createOpponentReferences() -> [OpponentReference] {
        // For All Live Players, we're watching our own players, so create a reference
        // indicating this is for personal roster tracking
        return [OpponentReference(
            id: "personal_roster_\(playerEntry.matchup.id)",
            opponentName: "Personal Roster",
            leagueName: playerEntry.leagueName,
            leagueSource: playerEntry.leagueSource.lowercased()
        )]
    }
    
    // MARK: - 🔥 SIMPLIFIED: Basic stats display like NonMicroCardView approach
    
    /// Simple stats display - just show basic info from the playerEntry itself
    private var simpleStatsDisplay: String {
        // 🔥 SIMPLE: Just show position and score info, no complex stat matching
        let position = playerEntry.position
        let score = playerEntry.currentScore
        
        if score > 0 {
            return "\(position) • \(String(format: "%.1f", score)) pts"
        } else {
            return "\(position) • No stats yet"
        }
    }
    
    // MARK: - 🔥 NEW: Jersey Number Helper Methods
    
    /// Get jersey number for the player from SleeperPlayer data
    private func getJerseyNumber() -> String? {
        // Try to find SleeperPlayer by ID first (most reliable)
        if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerEntry.player.id) {
            return sleeperPlayer.number?.description
        }
        
        // Fallback to existing jerseyNumber property
        return playerEntry.player.jerseyNumber
    }
    
    /// Get team color for jersey number display
    private func getTeamColor(for teamCode: String) -> Color {
        if let team = NFLTeam.team(for: teamCode) {
            return team.primaryColor
        }
        return .white // Default fallback
    }
    
    /// Get contrasting color for jersey number display using WCAG luminance calculation
    private func getContrastingJerseyColor(for teamCode: String) -> Color {
        // 🔥 WCAG-COMPLIANT: Use luminance-based contrast calculation
        guard let team = NFLTeam.team(for: teamCode) else {
            return .white
        }
        
        return team.primaryColor.adaptedTextColor()
    }
    
    /// WCAG-compliant luminance calculation for contrast
    private func calculateLuminance(_ color: Color) -> Double {
        // Convert SwiftUI Color to UIColor to get RGB components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Apply gamma correction according to WCAG formula
        func adjustColorComponent(_ component: CGFloat) -> CGFloat {
            return component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        
        let adjustedRed = adjustColorComponent(red)
        let adjustedGreen = adjustColorComponent(green)
        let adjustedBlue = adjustColorComponent(blue)
        
        // WCAG luminance formula
        return 0.2126 * Double(adjustedRed) + 0.7152 * Double(adjustedGreen) + 0.0722 * Double(adjustedBlue)
    }
}

// MARK: - Score Breakdown Loader

/// On-demand stats loader - only loads stats when user clicks points box
struct ScoreBreakdownLoaderView: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    @State private var viewModel = AllLivePlayersViewModel.shared
    @State private var isReady = false
    
    var body: some View {
        ZStack {
            if isReady {
                breakdownView
            } else {
                // Simple transparent overlay with loading indicator
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading stats...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .task {
                    // Check if stats are already loaded
                    if viewModel.statsLoaded {
                        isReady = true
                    } else {
                        // Load stats on-demand
                        await viewModel.loadAllPlayers()
                        isReady = true
                    }
                }
            }
        }
    }
    
    private var breakdownView: some View {
        let leagueContext = LeagueContext(
            leagueID: playerEntry.matchup.league.league.leagueID,
            source: playerEntry.matchup.league.source,
            isChopped: playerEntry.matchup.isChoppedLeague
        )
        
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: playerEntry.player,
            week: WeekSelectionManager.shared.selectedWeek,
            leagueContext: leagueContext
        ).withLeagueName(playerEntry.leagueName)
        
        return ScoreBreakdownView(breakdown: breakdown)
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
    }
}

// MARK: - WCAG Color Contrast Extension
