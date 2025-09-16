//
//  AllLivePlayersEmptyStateView.swift
//  BigWarRoom
//
//  Empty state view for All Live Players (handles both no leagues and no players scenarios)
//

import SwiftUI

/// Empty state handling both no leagues connected and no players for position
struct AllLivePlayersEmptyStateView: View {
    @ObservedObject var viewModel: AllLivePlayersViewModel
    let onAnimationReset: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            if viewModel.hasNoLeagues {
                buildNoLeaguesView()
            } else {
                buildNoPlayersView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Builder Functions
    
    func buildNoLeaguesView() -> some View {
        AllLivePlayersNoLeaguesView(viewModel: viewModel)
    }
    
    func buildNoPlayersView() -> some View {
        AllLivePlayersNoPlayersView(
            viewModel: viewModel,
            onAnimationReset: onAnimationReset
        )
    }
}

#Preview {
    AllLivePlayersEmptyStateView(
        viewModel: AllLivePlayersViewModel.shared,
        onAnimationReset: {}
    )
}