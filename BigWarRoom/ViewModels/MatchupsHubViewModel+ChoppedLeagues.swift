//
//  MatchupsHubViewModel+ChoppedLeagues.swift
//  BigWarRoom
//
//  Chopped league specific logic for MatchupsHubViewModel
//

import Foundation

// MARK: - Chopped League Operations
extension MatchupsHubViewModel {
    
    /// Handle chopped league processing (🔥 NOW USING SERVICE)
    internal func handleChoppedLeague(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        // Use ChoppedLeagueService to create summary
        guard let choppedSummary = await choppedLeagueService.createSleeperChoppedSummary(
            league: league,
            myTeamID: myTeamID,
            week: getCurrentWeek()
        ) else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
        
        // Find my team in the leaderboard
        guard let myTeamRanking = await choppedLeagueService.findMyTeamInChoppedLeaderboard(
            choppedSummary,
            leagueID: league.league.leagueID,
            sleeperCredentials: sleeperCredentials
        ) else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
            return nil
        }
        
        DebugPrint(
            mode: .matchupLoading,
            limit: 20,
            "🪓 CHOPPED STATUS: \(league.league.name) rosterID=\(String(describing: myTeamRanking.team.rosterID)) rank=\(myTeamRanking.rank) status=\(myTeamRanking.eliminationStatus.rawValue) isEliminated=\(myTeamRanking.isEliminated) showElimToggle=\(UserDefaults.standard.showEliminatedChoppedLeagues)"
        )
        
        // If the user disabled eliminated chopped leagues, skip loading them
        if !UserDefaults.standard.showEliminatedChoppedLeagues, myTeamRanking.isEliminated {
            DebugPrint(mode: .matchupLoading, limit: 20, "🪓 FILTER OUT: \(league.league.name) (chopped eliminated, toggle OFF)")
            await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
            return nil
        }
        
        let unifiedMatchup = UnifiedMatchup(
            id: "\(league.id)_chopped",
            league: league,
            fantasyMatchup: nil,
            choppedSummary: choppedSummary,
            lastUpdated: Date(),
            myTeamRanking: myTeamRanking,
            myIdentifiedTeamID: myTeamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: nil,
            gameDataService: NFLGameDataService.shared
        )
        
        await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
        return unifiedMatchup
    }
}