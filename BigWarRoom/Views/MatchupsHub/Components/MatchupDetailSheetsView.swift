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
    let allLeagueMatchups: [UnifiedMatchup]? // 🔥 NEW: Pass all matchups from same league
    
    // Default initializer for backward compatibility
    init(matchup: UnifiedMatchup) {
        self.matchup = matchup
        self.allLeagueMatchups = nil
    }
    
    // New initializer with all league matchups for horizontal scrolling
    init(matchup: UnifiedMatchup, allLeagueMatchups: [UnifiedMatchup]) {
        self.matchup = matchup
        self.allLeagueMatchups = allLeagueMatchups
    }
    
    var body: some View {
        Group {
            if matchup.isChoppedLeague {
                ChoppedLeagueDetailSheet(matchup: matchup)
            } else {
                RegularMatchupDetailSheet(matchup: matchup, allLeagueMatchups: allLeagueMatchups)
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
    let allLeagueMatchups: [UnifiedMatchup]?
    
    var body: some View {
        if let fantasyMatchup = matchup.fantasyMatchup {
            let configuredViewModel = matchup.createConfiguredFantasyViewModel()
            
            // 🔥 SIMPLIFIED: Just pass the single matchup, let LeagueMatchupsTabView fetch the rest
            LeagueMatchupsTabView(
                allMatchups: [fantasyMatchup],  // Start with single matchup
                startingMatchup: fantasyMatchup,
                leagueName: matchup.league.league.name,
                fantasyViewModel: configuredViewModel
            )
        }
    }
}