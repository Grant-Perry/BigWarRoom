//
//  FantasyEmptyStateView.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Empty state view when no matchups are available
struct FantasyEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No matchups available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("This week may not have started yet or league data is unavailable")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}