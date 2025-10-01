//
//  FantasySingleLeagueContentView.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Single league content view that displays the main fantasy content
struct FantasySingleLeagueContentView: View {
    let draftRoomViewModel: DraftRoomViewModel
    let weekManager: WeekSelectionManager
    let fantasyViewModel: FantasyViewModel
    let fantasyMatchupListViewModel: FantasyMatchupListViewModel
    @Binding var forceChoppedMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status header
            FantasyConnectionStatusHeader(
                draftRoomViewModel: draftRoomViewModel,
                fantasyViewModel: fantasyViewModel
            )
            
            // Main content
            if fantasyViewModel.isLoading || fantasyMatchupListViewModel.shouldShowLoadingState() {
                FantasyLoadingView()
            } else if fantasyMatchupListViewModel.isChoppedLeague() || forceChoppedMode {
                FantasyChoppedLeaderboardContainer(
                    draftRoomViewModel: draftRoomViewModel,
                    weekManager: weekManager,
                    fantasyViewModel: fantasyViewModel,
                    fantasyMatchupListViewModel: fantasyMatchupListViewModel
                )
            } else if fantasyViewModel.matchups.isEmpty && fantasyViewModel.hasActiveRosters {
                FantasyChoppedLeaderboardContainer(
                    draftRoomViewModel: draftRoomViewModel,
                    weekManager: weekManager,
                    fantasyViewModel: fantasyViewModel,
                    fantasyMatchupListViewModel: fantasyMatchupListViewModel
                )
            } else if fantasyViewModel.matchups.isEmpty && !fantasyViewModel.hasActiveRosters {
                FantasyEmptyStateView()
            } else {
                FantasyMatchupsList(fantasyViewModel: fantasyViewModel)
            }
        }
    }
}