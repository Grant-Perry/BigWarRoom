//
//  ChoppedRosterContentView.swift
//  BigWarRoom
//
//  🏈 CHOPPED ROSTER CONTENT VIEW 🏈
//  Main content view for roster display
//

import SwiftUI

/// **ChoppedRosterContentView**
/// 
/// Main content container for the roster display
struct ChoppedRosterContentView: View {
    let roster: ChoppedTeamRoster
    let teamRanking: FantasyTeamRanking
    let week: Int
    let parentViewModel: ChoppedTeamRosterViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    
    @Binding var sortingMethod: MatchupSortingMethod
    @Binding var sortHighToLow: Bool
    @Binding var showStartingLineup: Bool
    @Binding var showBench: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Team header with score
                ChoppedTeamHeaderCard(
                    teamRanking: teamRanking,
                    week: week,
                    roster: roster
                )
                .padding(.horizontal, 16) // 🔥 ADDED: Horizontal padding for header
                
                // Sorting controls
                PlayerSortingControlsView(
                    sortingMethod: $sortingMethod, 
                    sortHighToLow: $sortHighToLow
                )
                .padding(.horizontal, 16) // 🔥 ADDED: Horizontal padding for controls

                // Starting Lineup Section
                if !roster.starters.isEmpty {
                    ChoppedStartingLineupSection(
                        starters: parentViewModel.sortPlayers(roster.starters, by: sortingMethod, highToLow: sortHighToLow),
                        parentViewModel: parentViewModel,
                        onPlayerTap: onPlayerTap,
                        showStartingLineup: $showStartingLineup
                    )
                    .padding(.horizontal, 16) // 🔥 ADDED: Horizontal padding for starting lineup
                }
                
                // Bench Section
                if !roster.bench.isEmpty {
                    ChoppedBenchSection(
                        bench: parentViewModel.sortPlayers(roster.bench, by: sortingMethod, highToLow: sortHighToLow),
                        parentViewModel: parentViewModel,
                        onPlayerTap: onPlayerTap,
                        showBench: $showBench
                    )
                    .padding(.horizontal, 16) // 🔥 ADDED: Horizontal padding for bench
                }
            }
            .padding(.vertical, 8) // 🔥 ADDED: Vertical padding for top/bottom spacing
        }
        .task {
            // Load NFL game data for real game times
            await parentViewModel.loadNFLGameData()
        }
    }
}