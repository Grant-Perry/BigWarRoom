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
    
    @Environment(FantasyViewModel.self) private var fantasyViewModel
    @Environment(AllLivePlayersViewModel.self) private var allLivePlayersViewModel
    
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
                RegularMatchupDetailSheet(
                    matchup: matchup, 
                    allLeagueMatchups: allLeagueMatchups,
                    fantasyViewModel: fantasyViewModel,
                    allLivePlayersViewModel: allLivePlayersViewModel
                )
            }
        }
    }
}

// MARK: - Supporting Components

/// Sheet for chopped league details
private struct ChoppedLeagueDetailSheet: View {
    let matchup: UnifiedMatchup
    
    var body: some View {
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
    let fantasyViewModel: FantasyViewModel
    let allLivePlayersViewModel: AllLivePlayersViewModel
    
    var body: some View {
        // 🔥 FIXED: Extract all FantasyMatchups from allLeagueMatchups
        let allFantasyMatchups: [FantasyMatchup] = {
            if let leagueMatchups = allLeagueMatchups {
                return leagueMatchups.compactMap { $0.fantasyMatchup }
            } else if let fantasyMatchup = matchup.fantasyMatchup {
                return [fantasyMatchup]
            } else {
                return []
            }
        }()
        
        return Group {
            if let fantasyMatchup = matchup.fantasyMatchup {
                LeagueMatchupsTabView(
                    allMatchups: allFantasyMatchups,
                    startingMatchup: fantasyMatchup,
                    leagueName: matchup.league.league.name,
                    league: matchup.league,  // 🔥 NEW: Pass the LeagueWrapper
                    fantasyViewModel: fantasyViewModel,
                    allLivePlayersViewModel: allLivePlayersViewModel
                )
            } else {
                matchupErrorView
            }
        }
    }
    
    private var matchupErrorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Matchup Not Available")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("This \(matchup.league.source.rawValue.uppercased()) league matchup could not be loaded.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("League: \(matchup.league.league.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 4) {
                Text("Possible causes:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("• Week has no active matchups")
                    Text("• Your team couldn't be identified")
                    Text("• League is not properly configured")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Button("Go Back") {
                // Navigation back will be handled automatically
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            print("🚨 DEBUG: RegularMatchupDetailSheet - fantasyMatchup is nil!")
            print("🚨 DEBUG: League: \(matchup.league.league.name) (\(matchup.league.source.rawValue))")
            print("🚨 DEBUG: League ID: \(matchup.league.league.leagueID)")
            print("🚨 DEBUG: Matchup ID: \(matchup.id)")
            print("🚨 DEBUG: Is Chopped: \(matchup.isChoppedLeague)")
            print("🚨 DEBUG: My Team ID: \(matchup.myIdentifiedTeamID ?? "nil")")
        }
    }
}