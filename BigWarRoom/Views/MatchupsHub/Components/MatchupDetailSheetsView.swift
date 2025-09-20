//
//  MatchupDetailSheetsView.swift
//  BigWarRoom
//
//  Sheet presentation component for matchup details
//

import SwiftUI

/// Component handling sheet presentations for matchup details
struct MatchupDetailSheetsView: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
        Group {
            if matchup.isChoppedLeague {
                ChoppedLeagueDetailSheet(matchup: matchup)
            } else {
                RegularMatchupDetailSheet(matchup: matchup)
            }
        }
    }
}

// MARK: - Supporting Components

/// Sheet for chopped league details
private struct ChoppedLeagueDetailSheet: View {
    let matchup: UnifiedMatchup
    @Environment(\.dismiss) private var dismiss // Add dismiss environment
    
    var body: some View {
        // 🔥 FIXED: The sheet content MUST be wrapped in a NavigationView to get a proper layout context.
        // This was the root cause of the inconsistent sizing from this specific entry point.
        NavigationView {
            if let choppedSummary = matchup.choppedSummary {
                ChoppedLeaderboardView(
                    choppedSummary: choppedSummary,
                    leagueName: matchup.league.league.name,
                    leagueID: matchup.league.league.leagueID
                )
                .navigationTitle(matchup.league.league.name)
                .navigationBarTitleDisplayMode(.inline)
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
}

/// Sheet for regular matchup details
private struct RegularMatchupDetailSheet: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
        if let fantasyMatchup = matchup.fantasyMatchup {
            let configuredViewModel = matchup.createConfiguredFantasyViewModel()
            FantasyMatchupDetailView(
                matchup: fantasyMatchup,
                fantasyViewModel: configuredViewModel,
                leagueName: matchup.league.league.name
            )
        }
    }
}