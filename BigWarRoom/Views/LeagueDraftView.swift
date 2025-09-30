//
//  LeagueDraftView.swift
//  BigWarRoom
//
//  Complete league draft board showing all managers and their picks
//
// MARK: -> League Draft View

import SwiftUI

struct LeagueDraftView: View {
    @ObservedObject var draftRoomViewModel: DraftRoomViewModel
    @StateObject private var leagueDraftViewModel: LeagueDraftViewModel
    
    init(viewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = viewModel
        self._leagueDraftViewModel = StateObject(wrappedValue: LeagueDraftViewModel(draftRoomViewModel: viewModel))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Draft Header Info
                if let selectedDraft = leagueDraftViewModel.selectedDraft {
                    DraftHeaderCardView(
                        league: selectedDraft,
                        totalPicksCount: leagueDraftViewModel.totalPicksCount,
                        expectedTotalPicks: leagueDraftViewModel.expectedTotalPicks,
                        draftProgressPercentage: leagueDraftViewModel.draftProgressPercentage
                    )
                }
                
                // View Toggle Section
                ViewToggleSectionView(
                    totalPicksCount: leagueDraftViewModel.totalPicksCount,
                    onTeamsViewTapped: {
                        leagueDraftViewModel.showRosterView()
                    }
                )
                
                // Draft Board by Rounds
                if !leagueDraftViewModel.allDraftPicks.isEmpty {
                    draftBoardSection
                } else {
                    EmptyDraftStateView()
                }
            }
            .padding()
        }
        .navigationTitle("Draft Board")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $leagueDraftViewModel.showingRosterView) {
            RosterView(viewModel: draftRoomViewModel)
        }
        // 🔥 DEATH TO SHEETS: Remove PlayerStatsCardView sheet - using NavigationLink instead
        // BEFORE: .sheet(isPresented: $leagueDraftViewModel.showingPlayerStats) {
        //     if let player = leagueDraftViewModel.selectedPlayerForStats,
        //        let team = NFLTeam.team(for: player.team ?? "") {
        //         PlayerStatsCardView(player: player, team: team)
        //     }
        // }
    }
    
    // MARK: - Draft Board Section
    
    private var draftBoardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Draft Board - By Round")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 20) {
                ForEach(leagueDraftViewModel.sortedRounds, id: \.self) { round in
                    DraftRoundSectionView(
                        round: round,
                        picks: leagueDraftViewModel.sortedPicks(for: round),
                        viewModel: leagueDraftViewModel
                    )
                }
            }
        }
    }
}