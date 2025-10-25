//
//  AIPickSuggestionsView.swift
//  BigWarRoom
//
//  Dedicated AI-powered player suggestions view - CLEAN ARCHITECTURE
//
// MARK: -> AI Pick Suggestions View

import SwiftUI

struct AIPickSuggestionsView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // AI Header Section
                    buildHeaderSection()
                    
                    // Position Filter & Sort Method
                    buildFiltersSection()
                    
                    // Main Suggestions Content
                    buildSuggestionsContent()
                }
                .padding()
            }
            .navigationTitle("AI Picks")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Builder Functions (NO COMPUTED VIEW PROPERTIES)
    
    func buildHeaderSection() -> some View {
        AIPickSuggestionsHeaderView(viewModel: viewModel)
    }
    
    func buildFiltersSection() -> some View {
        AIPickSuggestionsFiltersView(viewModel: viewModel)
    }
    
    func buildSuggestionsContent() -> some View {
        AIPickSuggestionsContentView(
            viewModel: viewModel,
            onPlayerTap: nil,
            onLockPick: lockPlayerAsPick,
            onAddToFeed: addPlayerToFeed
        )
    }
    
    // MARK: - Event Handlers
    
    private func addPlayerToFeed(_ suggestion: Suggestion) {
        let currentFeed = viewModel.picksFeed.isEmpty ? "" : viewModel.picksFeed + ", "
        viewModel.picksFeed = currentFeed + suggestion.player.shortKey
        viewModel.addFeedPick()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func lockPlayerAsPick(_ suggestion: Suggestion) {
        viewModel.myPickInput = suggestion.player.shortKey
        Task {
            await viewModel.lockMyPick()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    // MARK: - Helper Methods
    
    private func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        if let directMatch = PlayerDirectoryStore.shared.players[player.id] {
            return directMatch
        }
        
        let nameMatch = allSleeperPlayers.first { sleeperPlayer in
            let nameMatches = sleeperPlayer.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sleeperPlayer.position?.uppercased() == player.position.rawValue
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return nameMatches && positionMatches && teamMatches
        }
        
        if let nameMatch = nameMatch {
            return nameMatch
        }
        
        let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
            guard let sleeperFirst = sleeperPlayer.firstName,
                  let sleeperLast = sleeperPlayer.lastName else { return false }
            
            let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = sleeperLast.lowercased().contains(player.lastName.lowercased()) || 
                                   player.lastName.lowercased().contains(sleeperLast.lowercased())
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return firstInitialMatches && lastNameMatches && teamMatches
        }
        
        return fuzzyMatch
    }
}

// MARK: -> Extension for SortMethod descriptions

extension SortMethod {
    var description: String {
        switch self {
        case .wizard:
            return "Strategic AI recommendations"
        case .rankings:
            return "Pure fantasy rankings"
        case .all:
            return "Complete player database"
        }
    }
}

#Preview {
    NavigationView {
        AIPickSuggestionsView(viewModel: DraftRoomViewModel())
    }
}