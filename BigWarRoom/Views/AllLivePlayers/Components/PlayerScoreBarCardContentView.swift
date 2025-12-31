//
//  PlayerScoreBarCardContentView.swift
//  BigWarRoom
//
//  Main content view for PlayerScoreBarCardView - CLEAN ARCHITECTURE
//

import SwiftUI

struct PlayerScoreBarCardContentView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    let cardHeight: Double
    let formattedPlayerName: String
    let playerScoreColor: Color
    
    @Bindable var viewModel: AllLivePlayersViewModel
    // 🔥 PHASE 3 DI: Accept services as parameters
    let watchService: PlayerWatchService
    let playerDirectory: PlayerDirectoryStore
    
    @State private var showingScoreBreakdown = false
    @State private var isLoadingOverlayVisible = false
    
    // 🔥 SSOT: Projected scores for win probability thermometer (matches Matchups Hub)
    @State private var myProjected: Double = 0.0
    @State private var opponentProjected: Double = 0.0
    @State private var projectionsLoaded = false
    
    // 🔥 PHASE 3 DI: Initializer accepts all dependencies
    init(
        playerEntry: AllLivePlayersViewModel.LivePlayerEntry,
        scoreBarWidth: Double,
        cardHeight: Double,
        formattedPlayerName: String,
        playerScoreColor: Color,
        viewModel: AllLivePlayersViewModel,
        watchService: PlayerWatchService,
        playerDirectory: PlayerDirectoryStore
    ) {
        self.playerEntry = playerEntry
        self.scoreBarWidth = scoreBarWidth
        self.cardHeight = cardHeight
        self.formattedPlayerName = formattedPlayerName
        self.playerScoreColor = playerScoreColor
        self.viewModel = viewModel
        self.watchService = watchService
        self.playerDirectory = playerDirectory
    }

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
                
                // Points section - right side, vertically centered
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer()
                    
                    // Points delta + Points box + Position badge
                    HStack(spacing: 4) {
                        Spacer()
                        
                        // Per-player score delta (in pill)
                        if abs(playerEntry.accumulatedDelta) > 0.01 {
                            let deltaValue = playerEntry.accumulatedDelta
                            Text(String(format: "%+.2f", deltaValue))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(deltaValue >= 0 ? .gpGreen : .gpRedPink)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill((deltaValue >= 0 ? Color.gpGreen : Color.gpRedPink).opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke((deltaValue >= 0 ? Color.gpGreen : Color.gpRedPink).opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                        
                        // Points box
                        Button(action: {
                            Task { await presentScoreBreakdown() }
                        }) {
                            HStack(spacing: 4) {
                                Text(playerEntry.currentScoreString)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(playerScoreColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)

                                Text("pts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.3)
                            }
                            .fixedSize(horizontal: true, vertical: false)
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
                    }
                    
                    // 🔥 SSOT: Win probability thermometer using matchup's calculated win probability
                    if let winProb = playerEntry.matchup.myWinProbability,
                       let myTeam = playerEntry.matchup.myTeam,
                       let oppTeam = playerEntry.matchup.opponentTeam {
                        let isWinning = (myTeam.currentScore ?? 0) >= (oppTeam.currentScore ?? 0)
                        CompactWinThermometer(
                            winProbability: winProb,
                            isWinning: isWinning
                        )
                        .frame(width: 100)
                    }
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                
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
            
            // NOW overlay the player image on top - unconstrained!
            HStack {
                ZStack {
                    // 🔥 FIXED: Large floating team logo behind player
                    let teamCode = playerEntry.player.team ?? ""
                    let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                    
                    if let team = NFLTeam.team(for: normalizedTeamCode) {
                        // Team logo
                        teamAssets.logoOrFallback(for: team.id)
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
                    if let injuryStatus = playerEntry.player.injuryStatus, !injuryStatus.isEmpty {
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
        // Watch button overlay (bottom left corner)
        .overlay(alignment: .bottomLeading) {
            Button(action: toggleWatch) {
                Image(systemName: isWatching ? "eye.fill" : "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isWatching ? .gpOrange : .white.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isWatching ? Color.gpOrange.opacity(0.3) : Color.black.opacity(0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 8)
            .padding(.bottom, 8)
        }
        // LARGE player name + position overlay at TOP
        .overlay(alignment: .top) {
            HStack(spacing: 6) {
                Spacer()
                Text(formattedPlayerName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                // Small position badge next to name
                Text(playerEntry.position)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(positionColor)
                    )
            }
            .padding(.top, 6)
            .padding(.trailing, 10)
            .padding(.leading, 140) // Start after matchup section
        }
        // League banner overlay at BOTTOM
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 6) {
                // League banner with max width to leave room for delta
                PlayerScoreBarCardLeagueBannerView(playerEntry: playerEntry)
                    .frame(maxWidth: 160) // Cap width so delta always fits
                
                // League delta ALWAYS shows
                if let matchupText = matchupDeltaText {
                    Text(matchupText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(matchupDeltaColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.trailing, 10)
            .padding(.bottom, 6)
        }
        
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
            
            // 🔥 FIX: Pass all required services to ScoreBreakdownFactory
            let breakdown = ScoreBreakdownFactory.createBreakdown(
                for: playerEntry.player,
                week: viewModel.weekSelectionManager.selectedWeek,
                leagueContext: leagueContext,
                allLivePlayersViewModel: viewModel,
                weekSelectionManager: viewModel.weekSelectionManager,
                idCanonicalizer: ESPNSleeperIDCanonicalizer.shared,
                playerDirectoryStore: viewModel.playerDirectory,
                playerStatsCache: PlayerStatsCache.shared,
                scoringSettingsManager: ScoringSettingsManager.shared
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
        // 🔥 PHASE 3 DI: Use injected viewModel instead of .shared
        if !viewModel.statsLoaded {
            await viewModel.loadAllPlayers()
        }
        
        // Hide overlay and present the breakdown sheet
        await MainActor.run {
            isLoadingOverlayVisible = false
            showingScoreBreakdown = true
        }
    }
    
    // MARK: - Per-player and matchup deltas
    
    /// Delta between current score and previousScore (last update), no +/- sign (color indicates direction)
    private var scoreDeltaText: String? {
        guard let previous = playerEntry.previousScore else { return nil }
        let diff = playerEntry.currentScore - previous
        // Ignore tiny noise
        guard abs(diff) > 0.01 else { return nil }
        
        // No +/- sign - color indicates positive/negative
        return String(format: "%.2f", abs(diff))
    }
    
    /// Raw delta value for color logic
    private var scoreDeltaValue: Double? {
        guard let previous = playerEntry.previousScore else { return nil }
        let diff = playerEntry.currentScore - previous
        guard abs(diff) > 0.01 else { return nil }
        return diff
    }
    
    /// My team vs opponent score differential, OR delta from cutoff for Chopped leagues
    private var matchupDeltaText: String? {
        // Regular matchup - show score differential
        if let diff = playerEntry.matchup.scoreDifferential {
            return String(format: "%.1f", abs(diff))
        }
        
        // Chopped league - show delta from cutoff line
        if playerEntry.matchup.isChoppedLeague,
           let ranking = playerEntry.matchup.myTeamRanking,
           let choppedSummary = playerEntry.matchup.choppedSummary {
            let myScore = ranking.team.currentScore ?? 0
            let cutoff = choppedSummary.cutoffScore
            let delta = myScore - cutoff
            return String(format: "%.1f", abs(delta))
        }
        
        return nil
    }
    
    private var matchupDeltaColor: Color {
        // Regular matchup
        if let diff = playerEntry.matchup.scoreDifferential {
            return diff >= 0 ? .gpGreen : .gpRedPink
        }
        
        // Chopped league - green if above cutoff, red if below
        if playerEntry.matchup.isChoppedLeague,
           let ranking = playerEntry.matchup.myTeamRanking,
           let choppedSummary = playerEntry.matchup.choppedSummary {
            let myScore = ranking.team.currentScore ?? 0
            let cutoff = choppedSummary.cutoffScore
            return myScore >= cutoff ? .gpGreen : .gpRedPink
        }
        
        return .secondary
    }
    
    private var positionColor: Color {
        switch playerEntry.position.uppercased() {
        case "QB": return .red
        case "RB": return .blue
        case "WR": return .green
        case "TE": return .orange
        case "K": return .yellow
        case "D/ST", "DEF": return .purple
        default: return .gray
        }
    }
    
    // 🔥 NEW: Get Sleeper player data for injury status - REMOVED DEBUG
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = playerEntry.player.fullName.lowercased()
        let shortName = playerEntry.player.shortName.lowercased()
        let team = playerEntry.player.team?.lowercased()
        
        // 🔥 PHASE 3 DI: Use injected playerDirectory
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
    // MARK: - 🔥 NEW: Jersey Number Helper Methods
    
    /// Get jersey number for the player - now uses model property directly
    private func getJerseyNumber() -> String? {
        // 🔥 MODEL-BASED: Jersey number already on the model! ✅
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
    @Environment(TeamAssetManager.self) private var teamAssets
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    
    // 🔥 PHASE 3 DI: viewModel should be passed in, not using .shared
    @State private var viewModel: AllLivePlayersViewModel
    @State private var isReady = false
    
    // 🔥 PHASE 3 DI: Add initializer
    init(playerEntry: AllLivePlayersViewModel.LivePlayerEntry, viewModel: AllLivePlayersViewModel) {
        self.playerEntry = playerEntry
        self._viewModel = State(initialValue: viewModel)
    }

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
        
        // 🔥 FIX: Pass all required services to ScoreBreakdownFactory
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: playerEntry.player,
            week: viewModel.weekSelectionManager.selectedWeek,
            leagueContext: leagueContext,
            allLivePlayersViewModel: viewModel,
            weekSelectionManager: viewModel.weekSelectionManager,
            idCanonicalizer: ESPNSleeperIDCanonicalizer.shared,
            playerDirectoryStore: viewModel.playerDirectory,
            playerStatsCache: PlayerStatsCache.shared,
            scoringSettingsManager: ScoringSettingsManager.shared
        ).withLeagueName(playerEntry.leagueName)
        
        return ScoreBreakdownView(breakdown: breakdown)
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
    }
}

// MARK: - Compact Win Thermometer

/// Compact win probability thermometer for Live Players cards
/// Pure view component - receives calculated probability from parent
struct CompactWinThermometer: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    let winProbability: Double
    let isWinning: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            // Win percentage text
            Text("\(Int(winProbability * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
            
            // Thermometer bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    // Fill bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isWinning ? Color.gpGreen : Color.gpRedPink)
                        .frame(width: geometry.size.width * CGFloat(winProbability), height: 4)
                        .animation(.easeInOut(duration: 0.5), value: winProbability)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - WCAG Color Contrast Extension