//
//  DraftRoundSectionView.swift
//  BigWarRoom
//
//  Component for displaying a single draft round with picks grid
//

import SwiftUI

/// Component for displaying draft picks organized by round
struct DraftRoundSectionView: View {
    let round: Int
    let picks: [EnhancedPick]
    let viewModel: LeagueDraftViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round header
            RoundHeaderView(round: round, picksCount: picks.count)
            
            // Picks grid for this round (2 columns for larger cards)
            RoundPicksGrid(picks: picks, viewModel: viewModel)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Supporting Components

/// Header component for round display
private struct RoundHeaderView: View {
    let round: Int
    let picksCount: Int
    
    var body: some View {
        HStack {
            Text("Round \(round)")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("\(picksCount) picks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Grid component for displaying round picks
private struct RoundPicksGrid: View {
    let picks: [EnhancedPick]
    let viewModel: LeagueDraftViewModel
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(picks.sorted { $0.pickNumber < $1.pickNumber }) { pick in
                LeagueDraftPickCardView(pick: pick, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 8)
    }
}