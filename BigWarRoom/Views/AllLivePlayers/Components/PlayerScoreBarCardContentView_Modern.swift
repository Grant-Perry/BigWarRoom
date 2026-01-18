//
//  PlayerScoreBarCardContentView_Modern.swift
//  BigWarRoom
//
//  🎯 MODERN SPORTS APP DESIGN - Inspired by ESPN, Sleeper, Nike Run Club
//  Philosophy: Glanceable data, high contrast, horizontal layout
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI

struct PlayerScoreBarCardContentView_Modern: View {
    let playerEntry: AllLivePlayersViewModel.LivePlayerEntry
    let scoreBarWidth: Double
    let cardHeight: Double
    let formattedPlayerName: String
    let playerScoreColor: Color
    
    @Bindable var viewModel: AllLivePlayersViewModel
    let watchService: PlayerWatchService
    let playerDirectory: PlayerDirectoryStore
    
    @State private var showingScoreBreakdown = false
    @State private var isLoadingOverlayVisible = false
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
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
        // 🎯 ULTRA-MINIMAL: Score-first design with floating info
        ZStack(alignment: .leading) {
            // BACKGROUND: Subtle gradient with team color
            cardBackground
            
            HStack(spacing: 0) {
                // LEFT: Avatar only (50px)
                compactAvatarSection
                    .frame(width: 50)
                
                // CENTER: Stacked info (name on top, league/game below)
                VStack(alignment: .leading, spacing: 4) {
                    // Name + position inline
                    HStack(spacing: 6) {
                        Text(formattedPlayerName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // Position badge - inline with name
                        Text(playerEntry.position)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(colorService.positionColor(for: playerEntry.position))
                            )
                    }
                    
                    // League name - subtle
                    Text(playerEntry.leagueName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // RIGHT: Score + delta stacked (80px)
                compactScoreSection
                    .frame(width: 80)
            }
            
            // FLOATING: Game status badge - bottom left
            VStack {
                Spacer()
                HStack {
                    gameStatusBadge
                        .padding(.leading, 50)
                        .padding(.bottom, 4)
						.offset(x: 150, y: 10)
                    Spacer()
                }
            }
            
            // FLOATING: Matchup delta - top right corner
            if let matchupText = matchupDeltaText {
                VStack {
                    HStack {
                        Spacer()
                        matchupDeltaBadge(matchupText)
                            .padding(.trailing, 85)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
            }
            
            // FLOATING: Watch icon - top right
            VStack {
                HStack {
                    Spacer()
                    watchButton
                        .padding(.trailing, 4)
                        .padding(.top, 4)
						.offset(x: -5, y: 32)
                }
                Spacer()
            }
        }
        .frame(height: 65) // Even thinner
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to matchup
        }
        .overlay {
            if isLoadingOverlayVisible {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showingScoreBreakdown) {
            scoreBreakdownSheet
        }
    }
    
    // MARK: - COMPACT AVATAR (No position badge)
    
    private var compactAvatarSection: some View {
        PlayerScoreBarCardPlayerImageView(playerEntry: playerEntry)
            .scaleEffect(0.45)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(teamAccentColor, lineWidth: 2)
            )
            .shadow(color: teamAccentColor.opacity(0.3), radius: 3, x: 0, y: 0)
    }
    
    // MARK: - COMPACT SCORE (Just number + delta)
    
    private var compactScoreSection: some View {
        Button(action: {
            Task { await presentScoreBreakdown() }
        }) {
            VStack(spacing: 1) {
                // Big score
                Text(playerEntry.currentScoreString)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(playerScoreColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                
                // Delta below
                if let deltaText = scoreDeltaText {
                    HStack(spacing: 2) {
                        Image(systemName: deltaIcon)
                            .font(.system(size: 7, weight: .bold))
                        Text(deltaText)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(deltaColor)
                } else {
                    Text("PTS")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - FLOATING BADGES
    
    private var gameStatusBadge: some View {
        NavigationLink(destination: MatchupDetailSheetsView(matchup: playerEntry.matchup)) {
            HStack(spacing: 3) {
                Circle()
                    .fill(gameStatusColor)
                    .frame(width: 5, height: 5)
                
                MatchupTeamFinalView(player: playerEntry.player, scaleEffect: 0.7)
                
                if let injuryStatus = playerEntry.player.injuryStatus, !injuryStatus.isEmpty {
                    Text(colorService.injuryStatusText(for: injuryStatus))
                        .font(.system(size: 7, weight: .black))
                        .foregroundColor(colorService.injuryStatusTextColor(for: injuryStatus))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(colorService.injuryStatusColor(for: injuryStatus))
                        )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func matchupDeltaBadge(_ text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: matchupDeltaIcon)
                .font(.system(size: 7, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(matchupDeltaColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(matchupDeltaColor.opacity(0.2))
        )
    }
    
    private var watchButton: some View {
        Button(action: toggleWatch) {
            Image(systemName: isWatching ? "eye.fill" : "eye")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isWatching ? .gpOrange : .white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - OLD LEFT SECTION (UNUSED)
    
    private var leftPlayerSection: some View {
        ZStack {
            // Team color accent bar on left edge
            HStack {
                Rectangle()
                    .fill(teamAccentColor)
                    .frame(width: 4)
                Spacer()
            }
            
            VStack(spacing: 4) {
                // Small circular avatar (40x40)
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                    
                    PlayerScoreBarCardPlayerImageView(playerEntry: playerEntry)
                        .scaleEffect(0.45) // Shrink the image to 45% so faces aren't too zoomed
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(teamAccentColor, lineWidth: 2)
                )
                
                // Position badge - minimal
                Text(playerEntry.position)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(colorService.positionColor(for: playerEntry.position).opacity(0.3))
                    )
            }
        }
    }
    
    // MARK: - CENTER: Info Strip
    
    private var centerInfoSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            // TOP ROW: Player name + watch icon
            HStack(spacing: 6) {
                Text(formattedPlayerName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Watch icon - inline
                Button(action: toggleWatch) {
                    Image(systemName: isWatching ? "eye.fill" : "eye")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isWatching ? .gpOrange : .gray.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // MIDDLE ROW: League + Matchup delta
            HStack(spacing: 6) {
                // League name - truncated
                Text(playerEntry.leagueName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                // Matchup differential pill (if not chopped)
                if let matchupText = matchupDeltaText {
                    HStack(spacing: 2) {
                        Image(systemName: matchupDeltaIcon)
                            .font(.system(size: 8, weight: .bold))
                        Text(matchupText)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(matchupDeltaColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(matchupDeltaColor.opacity(0.15))
                    )
                }
            }
            
            // BOTTOM ROW: Game status - TAPPABLE to navigate to matchup
            NavigationLink(destination: MatchupDetailSheetsView(matchup: playerEntry.matchup)) {
                HStack(spacing: 4) {
                    // Live indicator dot
                    Circle()
                        .fill(gameStatusColor)
                        .frame(width: 6, height: 6)
                    
                    // Use MatchupTeamFinalView for real game status
                    MatchupTeamFinalView(player: playerEntry.player, scaleEffect: 0.8)
                    
                    // Injury badge (if any)
                    if let injuryStatus = playerEntry.player.injuryStatus, !injuryStatus.isEmpty {
                        Text(colorService.injuryStatusText(for: injuryStatus))
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(colorService.injuryStatusTextColor(for: injuryStatus))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(colorService.injuryStatusColor(for: injuryStatus))
                            )
                    }
                    
                    // Arrow indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var gameStatusColor: Color {
        if playerEntry.player.isLive(gameDataService: viewModel.nflGameDataService) {
            return .gpGreen
        }
        return .gray.opacity(0.5)
    }
    
    // MARK: - RIGHT: Score Section
    
    private var rightScoreSection: some View {
        Button(action: {
            Task { await presentScoreBreakdown() }
        }) {
            VStack(spacing: 2) {
                // HERO NUMBER: Score
                Text(playerEntry.currentScoreString)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(playerScoreColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // "pts" label
                Text("PTS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                
                // Delta with icon
                if let deltaText = scoreDeltaText {
                    HStack(spacing: 2) {
                        Image(systemName: deltaIcon)
                            .font(.system(size: 8, weight: .bold))
                        Text(deltaText)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(deltaColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(playerScoreColor.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var deltaIcon: String {
        guard let previous = playerEntry.previousScore else { return "minus" }
        let diff = playerEntry.currentScore - previous
        if diff > 0 { return "arrow.up" }
        if diff < 0 { return "arrow.down" }
        return "minus"
    }
    
    private var deltaColor: Color {
        guard let previous = playerEntry.previousScore else { return .gray }
        let diff = playerEntry.currentScore - previous
        return colorService.deltaColor(for: diff)
    }
    
    // MARK: - Background & Border
    
    private var cardBackground: some View {
        ZStack {
            // Base dark background
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle team color overlay on left
            HStack {
                LinearGradient(
                    colors: [
                        teamAccentColor.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                
                Spacer()
            }
        }
    }
    
    private var borderColor: Color {
        if playerEntry.player.isLive(gameDataService: viewModel.nflGameDataService) {
            return .gpGreen.opacity(0.6)
        }
        return Color.white.opacity(0.15)
    }
    
    private var teamAccentColor: Color {
        if let team = NFLTeam.team(for: playerEntry.player.team ?? "") {
            return team.primaryColor
        }
        return .gray
    }
    
    // MARK: - Matchup Delta
    
    private var matchupDeltaText: String? {
        guard let diff = playerEntry.matchup.scoreDifferential else { return nil }
        let formatted = String(format: diff > 0 ? "+%.1f" : "%.1f", diff)
        return formatted
    }
    
    private var matchupDeltaIcon: String {
        guard let diff = playerEntry.matchup.scoreDifferential else { return "equal.circle.fill" }
        return diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    private var matchupDeltaColor: Color {
        guard let diff = playerEntry.matchup.scoreDifferential else { return .secondary }
        return colorService.deltaColor(for: diff)
    }
    
    // MARK: - Score Delta
    
    private var scoreDeltaText: String? {
        guard let previous = playerEntry.previousScore else { return nil }
        let diff = playerEntry.currentScore - previous
        guard abs(diff) > 0.01 else { return nil }
        
        let formatted = String(format: diff > 0 ? "+%.1f" : "%.1f", diff)
        return formatted
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
                Text("Loading stats...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Score Breakdown Sheet
    
    private var scoreBreakdownSheet: some View {
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
    
    // MARK: - Helper Functions
    
    private func presentScoreBreakdown() async {
        await MainActor.run { isLoadingOverlayVisible = true }
        
        if !viewModel.statsLoaded {
            await viewModel.loadAllPlayers()
        }
        
        await MainActor.run {
            isLoadingOverlayVisible = false
            showingScoreBreakdown = true
        }
    }
    
    private var isWatching: Bool {
        watchService.isWatching(playerEntry.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(playerEntry.player.id)
        } else {
            let opponentRefs = createOpponentReferences()
            
            let opponentPlayer = OpponentPlayer(
                id: UUID().uuidString,
                player: playerEntry.player,
                isStarter: playerEntry.isStarter,
                currentScore: playerEntry.currentScore,
                projectedScore: playerEntry.projectedScore,
                threatLevel: .moderate,
                matchupAdvantage: .neutral,
                percentageOfOpponentTotal: 0.0
            )
            
            let success = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentRefs)
            if !success {
            }
        }
    }
    
    private func createOpponentReferences() -> [OpponentReference] {
        return [OpponentReference(
            id: "personal_roster_\(playerEntry.matchup.id)",
            opponentName: "Personal Roster",
            leagueName: playerEntry.leagueName,
            leagueSource: playerEntry.leagueSource.lowercased()
        )]
    }
}