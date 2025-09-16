//
//  RosterEmptyStateView.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Empty state view for roster when no picks are available
struct RosterEmptyStateView: View {
    let onBackTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Team Rosters")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Connect to a draft to see team rosters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Back to Draft Board") {
                onBackTap()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
}