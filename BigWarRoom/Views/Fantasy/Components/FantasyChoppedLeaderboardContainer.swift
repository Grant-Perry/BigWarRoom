//
//  FantasyChoppedLeaderboardContainer.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Container view that determines which chopped leaderboard to display
struct FantasyChoppedLeaderboardContainer: View {
    let draftRoomViewModel: DraftRoomViewModel
    let weekManager: WeekSelectionManager
    let fantasyViewModel: FantasyViewModel
    let fantasyMatchupListViewModel: FantasyMatchupListViewModel
    
    var body: some View {
        // Use async loading for real Chopped data
        if let leagueWrapper = draftRoomViewModel.selectedLeagueWrapper,
           leagueWrapper.source == .sleeper {
            AsyncChoppedLeaderboardView(
                leagueWrapper: leagueWrapper,
                week: weekManager.selectedWeek,
                fantasyViewModel: fantasyViewModel
            )
        } else {
            // Fallback to mock data for non-Sleeper leagues
            // Chopped League Content
            if let choppedSummary = fantasyMatchupListViewModel.createChoppedSummaryFromMatchups() {
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: fantasyViewModel.selectedLeague?.league.name ?? "Chopped League",
                    leagueID: fantasyViewModel.selectedLeague?.league.leagueID ?? ""
                )
            } else {
                // Empty state when no teams are available
                ContentUnavailableView(
                    "No Teams Available",
                    systemImage: "person.3.slash",
                    description: Text("Unable to load Chopped league data")
                )
            }
        }
    }
}