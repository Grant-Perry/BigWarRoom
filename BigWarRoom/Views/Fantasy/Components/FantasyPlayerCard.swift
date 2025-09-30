//
//  FantasyPlayerCard.swift
//  BigWarRoom
//
//  Clean, focused view for displaying fantasy player cards - CLEAN ARCHITECTURE
//

import SwiftUI

/// Clean fantasy player card view with business logic extracted to view model
struct FantasyPlayerCard: View {
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    let matchup: FantasyMatchup?
    let teamIndex: Int?
    let isBench: Bool
    
    @StateObject private var viewModel = FantasyPlayerViewModel()
    
    @State private var showingScoreBreakdown = false
    @State private var showingPlayerDetail = false // 🔥 FIX: Add dedicated player detail state
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                // Background jersey number
                buildBackgroundJerseyNumber()
                
                // Team gradient background
                buildTeamGradientBackground()
                
                // Team logo
                buildTeamLogo()
                
                // Main content stack
                buildMainContentStack()
                
                // Player name and position (right-justified) - UPDATED with score breakdown action
                buildPlayerNameAndPosition()
                
                // Game matchup (centered)
                buildGameMatchupSection()
                
                // Stats section with reserved space
                buildStatsSection()
            }
            .frame(height: viewModel.cardHeight)
            .background(buildCardBackground())
            .overlay(buildCardBorder())
            .clipShape(RoundedRectangle(cornerRadius: 15))
            // 🔥 FIX: Replace background NavigationLink with onTapGesture for player detail
            .onTapGesture {
                showingPlayerDetail = true
            }
            .onAppear {
                viewModel.configurePlayer(player)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Refresh game data when app becomes active
            }
        }
        // 🔥 FIX: Use sheet for player details to match score breakdown pattern
        .sheet(isPresented: $showingPlayerDetail) {
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
        .sheet(isPresented: $showingScoreBreakdown) {
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
    }
    
    // MARK: - Builder Functions (NO COMPUTED VIEW PROPERTIES)
    
    func buildBackgroundJerseyNumber() -> some View {
        FantasyPlayerCardBackgroundJerseyView(
            jerseyNumber: viewModel.nflPlayer?.jersey ?? player.jerseyNumber ?? "",
            teamColor: viewModel.teamColor
        )
    }
    
    func buildTeamGradientBackground() -> some View {
        FantasyPlayerCardTeamGradientView(teamColor: viewModel.teamColor)
    }
    
    func buildTeamLogo() -> some View {
        FantasyPlayerCardLogoView(
            player: player,
            teamColor: viewModel.teamColor,
            isPlayerLive: viewModel.isPlayerLive(player)
        )
    }
    
    func buildMainContentStack() -> some View {
        FantasyPlayerCardMainContentView(
            player: player,
            isPlayerLive: viewModel.isPlayerLive(player),
            glowIntensity: viewModel.glowIntensity,
            onScoreTap: {
                showingScoreBreakdown = true
            }
        )
    }
    
    func buildPlayerNameAndPosition() -> some View {
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
    }
    
    func buildGameMatchupSection() -> some View {
        FantasyPlayerCardMatchupView(player: player)
    }
    
    func buildStatsSection() -> some View {
        FantasyPlayerCardStatsView(
            player: player,
            statLine: viewModel.formatPlayerStatBreakdown(for: player),
            teamColor: viewModel.teamColor
        )
    }
    
    func buildCardBackground() -> some View {
        FantasyPlayerCardBackgroundStyleView(
            teamColor: viewModel.teamColor,
            shadowColor: viewModel.shadowColor(for: player),
            shadowRadius: viewModel.shadowRadius(for: player)
        )
    }
    
    func buildCardBorder() -> some View {
        FantasyPlayerCardBorderView(
            borderColors: viewModel.borderColors(for: player),
            borderWidth: viewModel.borderWidth(for: player),
            borderOpacity: viewModel.borderOpacity(for: player),
            shadowColor: viewModel.shadowColor(for: player),
            shadowRadius: viewModel.shadowRadius(for: player)
        )
    }
    
    // MARK: - ADD: Score Breakdown Helper Methods
    
    /// Creates score breakdown from current player stats
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        print("🐛 DEBUG: FantasyPlayerCard createScoreBreakdown called")
        
        guard let sleeperPlayer = viewModel.getSleeperPlayerData(for: player) else {
            print("🐛 DEBUG: No sleeperPlayer data")
            return nil
        }
        
        // Get stats from AllLivePlayersViewModel
        let livePlayersViewModel = AllLivePlayersViewModel.shared
        guard let stats = livePlayersViewModel.playerStats[sleeperPlayer.playerID],
              !stats.isEmpty else {
            print("🐛 DEBUG: No player stats found")
            return nil
        }
        
        print("🐛 DEBUG: Found \(stats.count) player stats")
        
        // 🔥 NEW: Use standardized ScoreBreakdownFactory interface
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        // Create league context if available
        var leagueContext: LeagueContext? = nil
        var leagueName: String? = nil // 🔥 NEW: Track league name
        
        if let selectedLeague = fantasyViewModel.selectedLeague {
            let leagueID = selectedLeague.league.id
            let source: LeagueSource = selectedLeague.source == .espn ? .espn : .sleeper
            leagueContext = LeagueContext(leagueID: leagueID, source: source)
            leagueName = selectedLeague.league.name // 🔥 NEW: Get league name
            print("🔥 DEBUG: Using unified scoring - League: \(selectedLeague.league.name), Source: \(source)")
        } else {
            print("⚠️ DEBUG: No selectedLeague available, using estimated scoring")
        }
        
        // Use new standardized interface - stats will be looked up automatically via StatsFacade
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: player,
            week: selectedWeek,
            localStatsProvider: nil, // Stats will be found via StatsFacade -> AllLivePlayersViewModel
            leagueContext: leagueContext
        )
        
        // 🔥 NEW: Add league name to breakdown
        let finalBreakdown = leagueName != nil ? breakdown.withLeagueName(leagueName!) : breakdown
        
        print("🔥 DEBUG: Created breakdown with hasRealScoringData: \(finalBreakdown.hasRealScoringData)")
        
        return finalBreakdown
    }
    
    /// Creates empty breakdown for players with no stats
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        return PlayerScoreBreakdown(
            player: player,
            week: selectedWeek,
            items: [],
            totalScore: player.currentPoints ?? 0.0,
            isChoppedLeague: false // Regular fantasy league
        )
    }
}