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
    // 🏈 NAVIGATION FREEDOM: Remove dismiss - not needed for NavigationLink
    // @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove NavigationView wrapper - parent handles navigation
        // BEFORE: NavigationView wrapper with Done button for sheet
        // AFTER: Direct content view for NavigationLink navigation
        if let choppedSummary = matchup.choppedSummary {
            ChoppedLeaderboardView(
                choppedSummary: choppedSummary,
                leagueName: matchup.league.league.name,
                leagueID: matchup.league.league.leagueID
            )
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