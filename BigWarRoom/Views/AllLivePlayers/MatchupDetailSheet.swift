//
//  MatchupDetailSheet.swift
//  BigWarRoom
//
//  Detail sheet for displaying matchup information
//

import SwiftUI

/// Detail sheet for displaying matchup information (Chopped or Fantasy)
struct MatchupDetailSheet: View {
    let matchup: UnifiedMatchup
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if matchup.isChoppedLeague {
                    // Show Chopped league detail
                    ChoppedLeaderboardView(
                        choppedSummary: matchup.choppedSummary!,
                        leagueName: matchup.league.league.name,
                        leagueID: matchup.league.league.leagueID
                    )
                } else {
                    // Show regular fantasy matchup detail
                    FantasyMatchupDetailView(
                        matchup: matchup.fantasyMatchup!,
                        fantasyViewModel: matchup.createConfiguredFantasyViewModel(),
                        leagueName: matchup.league.league.name
                    )
                }
            }
            .navigationTitle(matchup.league.league.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Preview requires a mock UnifiedMatchup - would need proper setup
    Text("MatchupDetailSheet Preview")
}