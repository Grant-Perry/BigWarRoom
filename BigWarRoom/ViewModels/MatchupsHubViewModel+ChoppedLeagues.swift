//
//  MatchupsHubViewModel+ChoppedLeagues.swift
//  BigWarRoom
//
//  Chopped league specific logic for MatchupsHubViewModel
//  Phase 2: Delegates to ChoppedLeagueService (DRY principle)
//

import Foundation

// MARK: - Chopped League Operations
extension MatchupsHubViewModel {
    
    /// Handle chopped league processing - delegates to ChoppedLeagueService
    internal func handleChoppedLeague(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        // Delegate to service
        let unifiedMatchup = await choppedLeagueService.createChoppedMatchup(
            league: league,
            myTeamID: myTeamID,
            currentWeek: getCurrentWeek()
        )
        
        // Update loading state
        if unifiedMatchup != nil {
            await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
        } else {
            await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
        }
        
        return unifiedMatchup
    }
}