//
//  FantasyPlayerCard.swift
//  BigWarRoom
//
//  🔥 PHASE 2 SIMPLIFIED MIGRATION: Reduced complexity while eliminating duplication
//

import SwiftUI

/// **Fantasy Player Card - SIMPLIFIED MIGRATION**
/// 
/// **Strategy:** Keep the familiar interface but eliminate the massive duplicate logic
/// **Before:** 300+ lines of mostly duplicate rendering code
/// **After:** Use existing UnifiedPlayerCardBackground + clean logic
struct FantasyPlayerCard: View {
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    let matchup: FantasyMatchup?
    let teamIndex: Int?
    let isBench: Bool
    
    @StateObject private var viewModel = FantasyPlayerViewModel()
    @StateObject private var watchService = PlayerWatchService.shared
    
    @State private var showingScoreBreakdown = false
    @State private var showingPlayerDetail = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                // 🔥 UNIFIED: Use existing UnifiedPlayerCardBackground with live status
                UnifiedPlayerCardBackground(
                    configuration: .fantasy(
                        team: NFLTeam.team(for: player.team ?? ""),
                        jerseyNumber: player.jerseyNumber,
                        cornerRadius: 15,
                        showBorder: true,
                        isLive: viewModel.isPlayerLive(player)
                    )
                )
                
                // 🔥 FIX: Team logo overlay behind player content (like WatchedPlayersSheet)
                HStack {
                    Spacer()
                    VStack {
                        if let team = NFLTeam.team(for: player.team ?? "") {
                            TeamAssetManager.shared.logoOrFallback(for: team.id)
                                .frame(width: 90, height: 90)
                                .opacity(viewModel.isPlayerLive(player) ? 0.4 : 0.25)
                                .offset(x: 10, y: 10)
                                .zIndex(0)
                        }
                        Spacer()
                    }
                }
                .padding(.top, 20)
                .padding(.trailing, 15)
                
                // 🔥 SIMPLIFIED: Reuse existing content components but cleaned up
                buildMainContent()
            }
            .frame(height: viewModel.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .onTapGesture {
                showingPlayerDetail = true
            }
            .onAppear {
                viewModel.configurePlayer(player)
            }
        }
        .sheet(isPresented: $showingPlayerDetail) {
            buildPlayerDetailSheet()
        }
        .sheet(isPresented: $showingScoreBreakdown) {
            buildScoreBreakdownSheet()
        }
    }
    
    // MARK: - Simplified Content Builder
    
    @ViewBuilder
    private func buildMainContent() -> some View {
        // Main content stack - reuse existing FantasyPlayerCardMainContentView
        FantasyPlayerCardMainContentView(
            player: player,
            isPlayerLive: viewModel.isPlayerLive(player),
            glowIntensity: viewModel.glowIntensity,
            onScoreTap: {
                showingScoreBreakdown = true
            },
            fantasyViewModel: fantasyViewModel
        )
        
        // Player name and position - reuse existing component
        FantasyPlayerCardNamePositionView(
            player: player,
            positionalRanking: viewModel.getPositionalRanking(
                for: player, 
                in: matchup, 
                teamIndex: teamIndex, 
                isBench: isBench, 
                fantasyViewModel: fantasyViewModel
            ),
            teamColor: viewModel.teamColor
        )
        
        // Watch toggle button
        buildWatchToggle()
        
        // Game matchup section
        FantasyPlayerCardMatchupView(player: player)
        
        // Stats section  
        FantasyPlayerCardStatsView(
            player: player,
            statLine: viewModel.formatPlayerStatBreakdown(for: player),
            teamColor: viewModel.teamColor
        )
    }
    
    @ViewBuilder
    private func buildWatchToggle() -> some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: toggleWatchStatus) {
                    Image(systemName: isPlayerWatched ? "eye.fill" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPlayerWatched ? .gpYellow : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func buildPlayerDetailSheet() -> some View {
        NavigationView {
            if let sleeperPlayer = viewModel.getSleeperPlayerData(for: player) {
                PlayerStatsCardView(
                    player: sleeperPlayer,
                    team: NFLTeam.team(for: player.team ?? "")
                )
            } else {
                PlayerDetailFallbackView(player: player)
            }
        }
    }
    
    @ViewBuilder 
    private func buildScoreBreakdownSheet() -> some View {
        if let breakdown = createScoreBreakdown() {
            ScoreBreakdownView(breakdown: breakdown)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        } else {
            ScoreBreakdownView(breakdown: createEmptyBreakdown())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Watch Status Methods
    
    private var isPlayerWatched: Bool {
        return watchService.isWatching(player.id)
    }
    
    private func toggleWatchStatus() {
        if isPlayerWatched {
            watchService.unwatchPlayer(player.id)
        } else {
            if let opponentPlayer = createOpponentPlayer() {
                let opponentReferences = createOpponentReferences()
                let _ = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentReferences)
            }
        }
    }
    
    private func createOpponentPlayer() -> OpponentPlayer? {
        return OpponentPlayer(
            id: UUID().uuidString,
            player: player,
            isStarter: player.isStarter,
            currentScore: player.currentPoints ?? 0.0,
            projectedScore: player.projectedPoints ?? 0.0,
            threatLevel: .moderate,
            matchupAdvantage: .neutral,
            percentageOfOpponentTotal: 0.0
        )
    }
    
    private func createOpponentReferences() -> [OpponentReference] {
        guard let matchup = matchup else { return [] }
        
        let isOnHomeTeam = matchup.homeTeam.roster.contains { $0.id == player.id }
        let opponentTeam = isOnHomeTeam ? matchup.awayTeam : matchup.homeTeam
        
        return [
            OpponentReference(
                id: opponentTeam.id,
                opponentName: opponentTeam.ownerName,
                leagueName: fantasyViewModel.selectedLeague?.league.name ?? "Unknown League",
                leagueSource: fantasyViewModel.selectedLeague?.source.rawValue ?? "sleeper"
            )
        ]
    }
    
    // MARK: - Score Breakdown Methods
    
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        guard let sleeperPlayer = viewModel.getSleeperPlayerData(for: player) else {
            return nil
        }
        
        let livePlayersViewModel = AllLivePlayersViewModel.shared
        guard let stats = livePlayersViewModel.playerStats[sleeperPlayer.playerID],
              !stats.isEmpty else {
            return nil
        }
        
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        var leagueContext: LeagueContext? = nil
        var leagueName: String? = nil
        
        if let selectedLeague = fantasyViewModel.selectedLeague {
            let leagueID = selectedLeague.league.id
            let source: LeagueSource = selectedLeague.source == .espn ? .espn : .sleeper
            leagueContext = LeagueContext(leagueID: leagueID, source: source)
            leagueName = selectedLeague.league.name
        }
        
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: player,
            week: selectedWeek,
            localStatsProvider: nil,
            leagueContext: leagueContext
        )
        
        return leagueName != nil ? breakdown.withLeagueName(leagueName!) : breakdown
    }
    
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        return PlayerScoreBreakdown(
            player: player,
            week: selectedWeek,
            items: [],
            totalScore: player.currentPoints ?? 0.0,
            isChoppedLeague: false
        )
    }
}