//
//  MatchupsHubView+Helpers.swift
//  BigWarRoom
//
//  Clean delegation helpers for MatchupsHubView - minimal computed properties only
//

import SwiftUI

// MARK: - Clean Delegating Helpers
extension MatchupsHubView {
    
    // MARK: - Simple Computed Properties (Delegate to ViewModel)
    
    var liveMatchupsCount: Int {
        matchupsHubViewModel.liveMatchupsCount(from: sortedMatchups)
    }
    
    var currentNFLWeek: Int {
        weekManager.selectedWeek
    }
    
    var connectedLeaguesCount: Int {
        matchupsHubViewModel.connectedLeaguesCount
    }
}