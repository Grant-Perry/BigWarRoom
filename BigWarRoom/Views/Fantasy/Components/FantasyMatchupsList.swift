//
//  FantasyMatchupsList.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Scrollable list of fantasy matchups and bye week teams
struct FantasyMatchupsList: View {
    let fantasyViewModel: FantasyViewModel
    // 🔥 PURE DI: Accept AllLivePlayersViewModel as parameter
    let allLivePlayersViewModel: AllLivePlayersViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Regular matchups
                ForEach(fantasyViewModel.matchups) { matchup in
                    NavigationLink(destination: FantasyMatchupDetailView(
                        matchup: matchup,
                        fantasyViewModel: fantasyViewModel,
                        leagueName: fantasyViewModel.selectedLeague?.league.name ?? "League",
                        livePlayersViewModel: allLivePlayersViewModel
                    )) {
                        FantasyMatchupCard(matchup: matchup)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Bye week teams section
                if !fantasyViewModel.byeWeekTeams.isEmpty {
                    ByeWeekSection(
                        teams: fantasyViewModel.byeWeekTeams,
                        week: fantasyViewModel.selectedWeek
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

/// Bye week teams section
struct ByeWeekSection: View {
    let teams: [FantasyTeam]
    let week: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "bed.double")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
                Text("Bye Week")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("\(teams.count) team\(teams.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            // Bye week teams
            ForEach(teams, id: \.id) { team in
                ByeWeekCard(team: team, week: week)
            }
        }
    }
}