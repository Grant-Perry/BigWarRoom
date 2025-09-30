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
        // 🔥 FIX: Remove NavigationView wrapper since FantasyMatchupDetailView has its own navigation
        Group {
            if matchup.isChoppedLeague {
                // Show Chopped league detail with NavigationView for proper navigation
                NavigationView {
                    ChoppedLeaderboardView(
                        choppedSummary: matchup.choppedSummary!,
                        leagueName: matchup.league.league.name,
                        leagueID: matchup.league.league.leagueID
                    )
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
            } else {
                // 🔥 FIX: Show fantasy matchup WITHOUT NavigationView wrapper
                // FantasyMatchupDetailView handles its own navigation with custom header
                FantasyMatchupDetailView(
                    matchup: matchup.fantasyMatchup!,
                    fantasyViewModel: matchup.createConfiguredFantasyViewModel(),
                    leagueName: matchup.league.league.name
                )
            }
        }
    }
}

#Preview {
    // Preview requires a mock UnifiedMatchup - would need proper setup
    Text("MatchupDetailSheet Preview")
}