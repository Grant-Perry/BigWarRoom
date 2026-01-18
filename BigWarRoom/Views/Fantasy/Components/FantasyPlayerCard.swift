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
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    let matchup: FantasyMatchup?
    let teamIndex: Int?
    let isBench: Bool
    // 🔥 PURE DI: Accept AllLivePlayersViewModel as parameter
    let allLivePlayersViewModel: AllLivePlayersViewModel
    let nflWeekService: NFLWeekService
    
    @State private var viewModel: FantasyPlayerViewModel?
    @State private var watchService = PlayerWatchService.shared
    
    @State private var showingScoreBreakdown = false
    @State private var selectedPlayerForNavigation: SleeperPlayer? = nil // 🔥 NEW: Navigation trigger
    
    // 🔥 PURE DI: Add allLivePlayersViewModel parameter
    init(
        player: FantasyPlayer,
        fantasyViewModel: FantasyViewModel,
        matchup: FantasyMatchup?,
        teamIndex: Int?,
        isBench: Bool,
        allLivePlayersViewModel: AllLivePlayersViewModel,
        nflWeekService: NFLWeekService
    ) {
        self.player = player
        self.fantasyViewModel = fantasyViewModel
        self.matchup = matchup
        self.teamIndex = teamIndex
        self.isBench = isBench
        self.allLivePlayersViewModel = allLivePlayersViewModel
        self.nflWeekService = nflWeekService
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
                            showBorder: false,
                            isLive: vm.isPlayerLive(player),
                            isOnBye: player.isOnBye(gameDataService: vm.nflGameDataService)
                        )
                    )
                    
                    HStack {
                        Spacer()
                        VStack {
                            // 🔥 FIX: Normalize team code for DST players (same logic as AllLivePlayers)
                            let teamCode = player.team ?? ""
                            let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
                            
                            if let team = NFLTeam.team(for: normalizedTeamCode) {
                                teamAssets.logoOrFallback(for: team.id)
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
                .frame(width: 190, height: vm.cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            vm.isPlayerLive(player) ? 
                                LinearGradient(
                                    colors: [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                player.isOnBye(gameDataService: vm.nflGameDataService) ?
                                    LinearGradient(
                                        colors: [.gpPink, .gpPink.opacity(0.8), .gpRedPink.opacity(0.6), .gpPink.opacity(0.9), .gpPink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [vm.teamColor.opacity(0.6), Color.clear, vm.teamColor.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                            lineWidth: (vm.isPlayerLive(player) || player.isOnBye(gameDataService: vm.nflGameDataService)) ? 4 : 2
                        )
                        .opacity((vm.isPlayerLive(player) || player.isOnBye(gameDataService: vm.nflGameDataService)) ? 0.7 : 0.5)
                )
                .shadow(
                    color: vm.isPlayerLive(player) ? .gpGreen.opacity(0.5) : player.isOnBye(gameDataService: vm.nflGameDataService) ? .gpPink.opacity(0.5) : .clear,
                    radius: (vm.isPlayerLive(player) || player.isOnBye(gameDataService: vm.nflGameDataService)) ? 10 : 0
                )
                // 🔥 NEW: Navigation via state change
                .navigationDestination(item: $selectedPlayerForNavigation) { sleeperPlayer in
                    PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: sleeperPlayer.team ?? "")
                    )
                }
            } else {
                ProgressView()
                    .frame(height: 125)
            }
        }
        .onAppear {
            // 🔥 PURE DI: Create ViewModel with passed instance
            if viewModel == nil {
                viewModel = FantasyPlayerViewModel(
                    livePlayersViewModel: allLivePlayersViewModel,
                    playerDirectory: PlayerDirectoryStore.shared,
                    nflGameDataService: NFLGameDataService.shared,
                    nflWeekService: nflWeekService
                )
                viewModel?.configurePlayer(player)
            }
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
            isBench: isBench,
            onScoreTap: {
                showingScoreBreakdown = true
            },
            fantasyViewModel: fantasyViewModel,
            sleeperPlayer: vm.getSleeperPlayerData(for: player),
            onPlayerImageTap: {
                // 🔥 NEW: Trigger navigation via state
                if let sleeperPlayer = vm.getSleeperPlayerData(for: player) {
                    selectedPlayerForNavigation = sleeperPlayer
                }
            }
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
        FantasyPlayerCardWatchButton(
            isWatched: isPlayerWatched,
            onToggle: toggleWatchStatus
        )
        
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
        
        // 🔥 PURE DI: Already using vm.livePlayersViewModel (no .shared)
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: player,
            week: selectedWeek,
            localStatsProvider: nil,
            leagueContext: leagueContext,
            allLivePlayersViewModel: vm.livePlayersViewModel,
            weekSelectionManager: WeekSelectionManager.shared,
            idCanonicalizer: ESPNSleeperIDCanonicalizer.shared,
            playerDirectoryStore: PlayerDirectoryStore.shared,
            playerStatsCache: PlayerStatsCache.shared,
            scoringSettingsManager: ScoringSettingsManager.shared
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