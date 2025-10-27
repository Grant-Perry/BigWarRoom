//
//  RosterView.swift
//  BigWarRoom
//
//  Team-by-team roster view showing each manager's draft picks - Clean MVVM Coordinator
//
// MARK: -> Roster View (Coordinator)

import SwiftUI

struct RosterView: View {
    @Bindable var viewModel: DraftRoomViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rosterViewModel: RosterViewModel
    
    init(viewModel: DraftRoomViewModel) {
        self.viewModel = viewModel
        self._rosterViewModel = StateObject(wrappedValue: RosterViewModel(draftRoomViewModel: viewModel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Draft Header Info
                    if let selectedDraft = viewModel.selectedDraft {
                        RosterDraftHeaderCard(
                            league: selectedDraft,
                            totalPicks: viewModel.allDraftPicks.count
                        )
                    }
                    
                    // Team Rosters
                    if !viewModel.allDraftPicks.isEmpty {
                        RosterTeamRostersSection(
                            rosterViewModel: rosterViewModel,
                            draftRoomViewModel: viewModel
                        )
                    } else {
                        RosterEmptyStateView {
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Team Rosters")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Expand All Teams") {
                            rosterViewModel.expandAllTeams()
                        }
                        
                        Button("Collapse All Teams") {
                            rosterViewModel.collapseAllTeams()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        // 🔥 DEATH TO SHEETS: Remove PlayerStatsCardView sheet - using NavigationLink instead
        // BEFORE: .sheet(isPresented: $rosterViewModel.showingPlayerStats) {
        //     if let player = rosterViewModel.selectedPlayerForStats,
        //        let team = NFLTeam.team(for: player.team ?? "") {
        //         PlayerStatsCardView(player: player, team: team)
        //     }
        // }
    }
}