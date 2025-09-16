//
//  MatchupsHubLoadingProgressSectionView.swift
//  BigWarRoom
//
//  League progress section component for MatchupsHubLoadingIndicator
//

import SwiftUI

/// League progress section with current loading message and states
struct MatchupsHubLoadingProgressSectionView: View {
    let currentLeague: String
    let loadingStates: [String: LeagueLoadingState]
    
    var body: some View {
        VStack(spacing: 16) {
            // Current loading message
            VStack(spacing: 8) {
                Text("MISSION CONTROL")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(currentLeague)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: currentLeague)
            }
            
            // League loading states
            if !loadingStates.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(Array(loadingStates.keys.sorted()), id: \.self) { leagueID in
                        if let state = loadingStates[leagueID] {
                            LeagueLoadingRow(state: state)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}