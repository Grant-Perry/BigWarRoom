//
//  ChoppedLeaderboardView.swift
//  BigWarRoom
//
//  🔥💀 CHOPPED LEAGUE BATTLE ROYALE 💀🔥
//  The most INSANE elimination fantasy football experience
//
// MARK: -> CHOPPED APOCALYPSE LEADERBOARD (MVVM Coordinator)

import SwiftUI

/// **ChoppedLeaderboardView**
/// 
/// Main coordinator view for the Chopped elimination leaderboard. Clean MVVM architecture with:
/// - Pure coordinator pattern
/// - All view components extracted to external files
/// - No computed properties that build views
/// - DRY principles throughout
struct ChoppedLeaderboardView: View {
    @StateObject private var viewModel: ChoppedLeaderboardViewModel
    let leagueID: String
    
    // MARK: - Configuration
    private let zoneOpacity: Double = 0.3 // Single source of truth for all zone background opacity
    
    // MARK: - Navigation State
    @State private var showingMyRoster = false
    
    // MARK: - Initialization
    init(choppedSummary: ChoppedWeekSummary, leagueName: String, leagueID: String) {
        self._viewModel = StateObject(wrappedValue: ChoppedLeaderboardViewModel(
            choppedSummary: choppedSummary,
            leagueName: leagueName
        ))
        self.leagueID = leagueID
    }
    
    var body: some View {
        ZStack {
            // APOCALYPTIC BACKGROUND
            ChoppedApocalypticBackground(
                shouldShowDangerBackground: viewModel.shouldShowDangerBackground,
                dangerPulse: viewModel.dangerPulse
            )
            
            ScrollView {
                Group {
                    VStack(spacing: 24) {
                        // BATTLE ROYALE HEADER
                        ChoppedBattleRoyaleHeader(
                            choppedLeaderboardViewModel: viewModel,
                            pulseAnimation: viewModel.pulseAnimation
                        )
                        
                        // SURVIVAL STATS (only if week started)
                        if viewModel.shouldShowSurvivalStats {
                            ChoppedSurvivalStats(
                                choppedLeaderboardViewModel: viewModel,
                                pulseAnimation: viewModel.pulseAnimation,
                                showingMyRoster: $showingMyRoster
                            )
                        } else {
                            ChoppedPreGameMessage()
                        }
                        
                        // CHAMPION THRONE (only if week started)
                        if viewModel.hasChampion, let champion = viewModel.choppedSummary.champion {
                            ChoppedChampionSection(
                                champion: champion,
                                weekDisplay: viewModel.weekDisplay,
                                leagueID: leagueID,
                                week: viewModel.choppedSummary.week
                            )
                        }
                        
                        // If week hasn't started, show all teams in neutral waiting state
                        if !viewModel.hasWeekStarted {
                            ChoppedWaitingTeamsSection(
                                choppedLeaderboardViewModel: viewModel,
                                leagueID: leagueID,
                                week: viewModel.choppedSummary.week
                            )
                        } else {
                            // Normal ranked sections when week has started
                            
                            // SAFE ZONE
                            if viewModel.hasSafeTeams {
                                ChoppedSurvivalSection(
                                    title: "🛡️ SAFE ZONE",
                                    subtitle: "Living to fight another week",
                                    teams: viewModel.choppedSummary.safeTeams,
                                    sectionColor: .green,
                                    leagueID: leagueID,
                                    week: viewModel.choppedSummary.week,
                                    zoneOpacity: zoneOpacity
                                )
                            }
                            
                            // WARNING ZONE
                            if viewModel.hasWarningTeams {
                                ChoppedSurvivalSection(
                                    title: "⚡ WARNING ZONE",
                                    subtitle: "Treading dangerous waters",
                                    teams: viewModel.choppedSummary.warningTeams,
                                    sectionColor: .blue,
                                    leagueID: leagueID,
                                    week: viewModel.choppedSummary.week,
                                    zoneOpacity: zoneOpacity
                                )
                            }
                            
                            // DANGER ZONE - PULSING RED
                            if viewModel.hasDangerZoneTeams {
                                ChoppedDangerZoneSection(
                                    choppedLeaderboardViewModel: viewModel,
                                    dangerPulse: viewModel.dangerPulse,
                                    leagueID: leagueID,
                                    week: viewModel.choppedSummary.week,
                                    zoneOpacity: zoneOpacity
                                )
                            }
                            
                            // CRITICAL ZONE - DEATH ROW
                            if viewModel.hasCriticalTeams {
                                ChoppedCriticalZoneSection(
                                    choppedLeaderboardViewModel: viewModel,
                                    pulseAnimation: viewModel.pulseAnimation,
                                    leagueID: leagueID,
                                    week: viewModel.choppedSummary.week,
                                    zoneOpacity: zoneOpacity
                                )
                            }
                        }
                        
                        // HALL OF THE DEAD (always show if there's history)
                        if viewModel.hasEliminationHistory {
                            ChoppedEliminatedHistorySection(
                                choppedLeaderboardViewModel: viewModel
                            )
                        }
                    }
                }
                .padding(.horizontal, 24) // Group padding for all content
                .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.startAnimations()
        }
        .sheet(isPresented: $viewModel.showEliminationCeremony) {
            EliminationCeremonyView(
                eliminatedTeam: viewModel.choppedSummary.eliminatedTeam,
                week: viewModel.choppedSummary.week
            )
        }
        .sheet(isPresented: $showingMyRoster) {
            // Your roster sheet
            if let myTeam = viewModel.myTeamRanking {
                ChoppedTeamRosterView(
                    teamRanking: myTeam,
                    leagueID: leagueID,
                    week: viewModel.choppedSummary.week
                )
            }
        }
    }
}