//
//  MatchupsHubContentView.swift
//  BigWarRoom
//
//  Main content scrollable view for MatchupsHub
//

import SwiftUI

/// Main scrollable content for MatchupsHub
struct MatchupsHubContentView: View {
    let heroHeaderView: AnyView
    let matchupsSectionView: AnyView
    @Binding var poweredByExpanded: Bool
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                heroHeaderView
                matchupsSectionView
                Color.clear.frame(height: 100) // Bottom padding for tab bar
            }
        }
        .onAppear {
            // Auto-collapse "Powered By" section after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    poweredByExpanded = false
                }
            }
        }
    }
}