//
//  MatchupsHubLoadingStateView.swift
//  BigWarRoom
//
//  Loading state component for MatchupsHub
//

import SwiftUI

/// Loading state view for MatchupsHub
struct MatchupsHubLoadingStateView: View {
    let currentLeague: String
    let progress: Double
    let loadingStates: [String: LeagueLoadingState]
    
    var body: some View {
        VStack {
            Spacer()
            
            MatchupsHubLoadingIndicator(
                currentLeague: currentLeague,
                progress: progress,
                loadingStates: loadingStates
            )
            
            Spacer()
        }
    }
}