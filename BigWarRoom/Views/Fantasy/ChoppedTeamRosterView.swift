//
//  ChoppedTeamRosterView.swift
//  BigWarRoom
//
//  💀🏈 CHOPPED TEAM ROSTER VIEW 🏈💀
//  View a team's active roster in a Chopped league
//
//  REFACTORED: Now follows proper MVVM architecture
//

import SwiftUI

/// **ChoppedTeamRosterView**
/// 
/// Shows a team's active roster in Chopped leagues with:
/// - Starting lineup (the scoring players)
/// - Bench players (non-scoring)
/// - Same player card styling as Active Roster
/// - Real fantasy points and projections
/// - Collapsible sections
/// 
/// **REFACTORED**: Now follows proper MVVM with business logic in ViewModels
struct ChoppedTeamRosterView: View {
    let teamRanking: FantasyTeamRanking
    let leagueID: String
    let week: Int
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChoppedTeamRosterViewModel
    
    // NFL Game Data Integration
    @StateObject private var nflGameService = NFLGameDataService.shared
    
    // UI State
    @State private var showStartingLineup = true
    @State private var showBench = true
    @State private var sortingMethod: MatchupSortingMethod = .position
    @State private var sortHighToLow = false
    
    // Player stats sheet
    @State private var selectedPlayer: SleeperPlayer?
    @State private var showStats = false
    
    // MARK: - Initialization
    
    init(teamRanking: FantasyTeamRanking, leagueID: String, week: Int) {
        self.teamRanking = teamRanking
        self.leagueID = leagueID
        self.week = week
        self._viewModel = StateObject(wrappedValue: ChoppedTeamRosterViewModel(
            teamRanking: teamRanking,
            leagueID: leagueID,
            week: week
        ))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ChoppedRosterLoadingView(ownerName: teamRanking.team.ownerName)
                } else if let roster = viewModel.rosterData {
                    ChoppedRosterContentView(
                        roster: roster,
                        teamRanking: teamRanking,
                        week: week,
                        parentViewModel: viewModel,
                        onPlayerTap: handlePlayerTap,
                        sortingMethod: $sortingMethod,
                        sortHighToLow: $sortHighToLow,
                        showStartingLineup: $showStartingLineup,
                        showBench: $showBench
                    )
                } else {
                    ChoppedRosterErrorView(
                        errorMessage: viewModel.errorMessage,
                        onRetry: {
                            Task {
                                await viewModel.loadTeamRoster()
                            }
                        }
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadTeamRoster()
        }
        .sheet(isPresented: $showStats) {
            if let player = selectedPlayer {
                PlayerStatsCardView(
                    player: player,
                    team: NFLTeam.team(for: player.team ?? "")
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handlePlayerTap(_ player: SleeperPlayer) {
        selectedPlayer = player
        showStats = true
    }
}

#Preview {
    // Cannot preview without proper models setup
    Text("ChoppedTeamRosterView Preview")
        .foregroundColor(.white)
        .background(Color.black)
}
 
