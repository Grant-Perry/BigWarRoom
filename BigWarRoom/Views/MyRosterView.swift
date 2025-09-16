//
//  MyRosterView.swift
//  BigWarRoom
//
//  A dedicated view to display the user's roster using enhanced player card styling.
//

import SwiftUI

struct MyRosterView: View {
    @ObservedObject var draftRoomViewModel: DraftRoomViewModel
    @StateObject private var myRosterViewModel: MyRosterViewModel
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
        self._myRosterViewModel = StateObject(wrappedValue: MyRosterViewModel(draftRoomViewModel: draftRoomViewModel))
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header with draft context
                RosterHeaderView(
                    title: myRosterViewModel.rosterTitle,
                    subtitle: myRosterViewModel.rosterSubtitle,
                    isLiveMode: myRosterViewModel.isLiveMode,
                    isMyTurn: myRosterViewModel.isMyTurn,
                    selectedDraft: myRosterViewModel.selectedDraft
                )
                
                // Roster stats summary
                RosterSummaryCardView(
                    filledSlots: myRosterViewModel.filledSlots,
                    benchCount: myRosterViewModel.benchCount,
                    totalPlayers: myRosterViewModel.totalPlayers,
                    pickDisplayText: myRosterViewModel.pickDisplayText
                )
                
                // Starting Lineup (Collapsible)
                CollapsibleRosterSectionView(
                    title: "Starting Lineup",
                    subtitle: "\(myRosterViewModel.filledSlots)/10 filled",
                    isExpanded: $myRosterViewModel.showStartingLineup
                ) {
                    VStack(spacing: 14) {
                        ForEach(myRosterViewModel.startingLineupSlots, id: \.label) { slot in
                            rosterSlotRow(label: slot.label, player: slot.player)
                        }
                    }
                }
                
                // Bench (Collapsible)
                CollapsibleRosterSectionView(
                    title: "Bench",
                    subtitle: "\(myRosterViewModel.benchCount) players",
                    isExpanded: $myRosterViewModel.showBench
                ) {
                    if myRosterViewModel.benchPlayers.isEmpty {
                        EmptyBenchView()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(myRosterViewModel.benchPlayers.enumerated()), id: \.offset) { _, player in
                                EnhancedPlayerCardView(
                                    player: player,
                                    sleeperPlayer: myRosterViewModel.findSleeperPlayer(for: player)
                                ) {
                                    myRosterViewModel.presentPlayerStats(for: player)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("My Roster")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $myRosterViewModel.showStats) {
            if let selectedPlayer = myRosterViewModel.selectedPlayer {
                PlayerStatsCardView(
                    player: selectedPlayer,
                    team: NFLTeam.team(for: selectedPlayer.team ?? "")
                )
            }
        }
    }
    
    // MARK: - Roster Slot Row
    
    private func rosterSlotRow(label: String, player: Player?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let player {
                EnhancedPlayerCardView(
                    player: player,
                    sleeperPlayer: myRosterViewModel.findSleeperPlayer(for: player)
                ) {
                    myRosterViewModel.presentPlayerStats(for: player)
                }
            } else {
                EmptyRosterSlotView(position: label)
            }
        }
    }
}