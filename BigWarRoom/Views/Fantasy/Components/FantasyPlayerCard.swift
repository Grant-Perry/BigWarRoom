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
    
    @State private var viewModel: FantasyPlayerViewModel?
    @State private var watchService = PlayerWatchService.shared
    
    @State private var showingScoreBreakdown = false
    @State private var showingPlayerDetail = false
    
    // 🔥 SIMPLIFIED: Just take the essentials, create ViewModel in onAppear
    init(
        player: FantasyPlayer,
        fantasyViewModel: FantasyViewModel,
        matchup: FantasyMatchup?,
        teamIndex: Int?,
        isBench: Bool
    ) {
        self.player = player
        self.fantasyViewModel = fantasyViewModel
        self.matchup = matchup
        self.teamIndex = teamIndex
        self.isBench = isBench
    }

    var body: some View {
        VStack {
            if let vm = viewModel {
                ZStack(alignment: .topLeading) {
                    UnifiedPlayerCardBackground(
                        configuration: .fantasy(
                            team: NFLTeam.team(for: player.team ?? ""),
                            jerseyNumber: player.jerseyNumber,
                            cornerRadius: 15,
                            showBorder: true,
                            isLive: vm.isPlayerLive(player)
                        )
                    )
                    
                    HStack {
                        Spacer()
                        VStack {
                            if let team = NFLTeam.team(for: player.team ?? "") {
                                TeamAssetManager.shared.logoOrFallback(for: team.id)
                                    .frame(width: 90, height: 90)
                                    .opacity(vm.isPlayerLive(player) ? 0.4 : 0.25)
                                    .offset(x: 10, y: 10)
                                    .zIndex(0)
                            }
                            Spacer()
                        }
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 15)
                    
                    buildMainContent(vm: vm)
                }
                .frame(height: vm.cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .onTapGesture {
                    showingPlayerDetail = true
                }
            } else {
                ProgressView()
                    .frame(height: 125)
            }
        }
        .onAppear {
            // 🔥 CREATE ViewModel with .shared dependencies
            if viewModel == nil {
                viewModel = FantasyPlayerViewModel(
                    livePlayersViewModel: AllLivePlayersViewModel.shared,
                    playerDirectory: PlayerDirectoryStore.shared,
                    nflGameDataService: NFLGameDataService.shared,
                    nflWeekService: NFLWeekService.shared
                )
                viewModel?.configurePlayer(player)
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
    private func buildMainContent(vm: FantasyPlayerViewModel) -> some View {
        // Main content stack - reuse existing FantasyPlayerCardMainContentView
        FantasyPlayerCardMainContentView(
            player: player,
            isPlayerLive: vm.isPlayerLive(player),
            glowIntensity: vm.glowIntensity,
            onScoreTap: {
                showingScoreBreakdown = true
            },
            fantasyViewModel: fantasyViewModel
        )
        
        // Player name and position - reuse existing component
        FantasyPlayerCardNamePositionView(
            player: player,
            positionalRanking: vm.getPositionalRanking(
                for: player, 
                in: matchup, 
                teamIndex: teamIndex, 
                isBench: isBench, 
                fantasyViewModel: fantasyViewModel
            ),
            teamColor: vm.teamColor
        )
        
        // Watch toggle button
        buildWatchToggle()
        
        // Game matchup section
        FantasyPlayerCardMatchupView(player: player)
        
        // Stats section  
        FantasyPlayerCardStatsView(
            player: player,
            statLine: vm.formatPlayerStatBreakdown(for: player),
            teamColor: vm.teamColor
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
            if let sleeperPlayer = viewModel?.getSleeperPlayerData(for: player) {
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
        guard let vm = viewModel,
              let sleeperPlayer = vm.getSleeperPlayerData(for: player) else {
            return nil
        }
        
        guard let stats = vm.livePlayersViewModel.playerStats[sleeperPlayer.playerID],
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
        
        // 🔥 FIX: Pass AllLivePlayersViewModel to ScoreBreakdownFactory
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: player,
            week: selectedWeek,
            localStatsProvider: nil,
            leagueContext: leagueContext,
            allLivePlayersViewModel: vm.livePlayersViewModel
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