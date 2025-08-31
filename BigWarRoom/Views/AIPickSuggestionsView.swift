//
//  AIPickSuggestionsView.swift
//  BigWarRoom
//
//  Dedicated AI-powered player suggestions view
//
// MARK: -> AI Pick Suggestions View

import SwiftUI

struct AIPickSuggestionsView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @State private var selectedPlayerForStats: Player?
    @State private var showingPlayerStats = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // AI Header Section
                    aiHeaderSection
                    
                    // Position Filter & Sort Method
                    filtersSection
                    
                    // Main Suggestions Content
                    suggestionsContent
                }
                .padding()
            }
            .navigationTitle("AI Picks")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingPlayerStats) {
            if let player = selectedPlayerForStats,
               let sleeperPlayer = findSleeperPlayer(for: player) {
                PlayerStatsCardView(player: sleeperPlayer, team: NFLTeam.team(for: player.team))
            }
        }
    }
    
    // MARK: -> AI Header Section
    
    private var aiHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        Text("AI Strategy Engine")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Smart pick recommendations based on your draft context")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if viewModel.isLiveMode {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Text("\(viewModel.suggestions.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        
                        Text("suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Draft context info (if connected)
            if let selectedDraft = viewModel.selectedDraft {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Draft Context")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedDraft.name)
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    if let myRosterID = viewModel.myRosterID {
                        HStack(spacing: 4) {
                            Text("Pick")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(myRosterID)")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    if viewModel.isMyTurn {
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text("YOUR TURN")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: -> Filters Section
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sort Method Toggle
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Strategy Mode")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(SortMethod.allCases) { method in
                        Button {
                            viewModel.updateSortMethod(method)
                        } label: {
                            VStack(spacing: 4) {
                                Text(method.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text(method.description)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                viewModel.selectedSortMethod == method 
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(.systemGray5)], startPoint: .top, endPoint: .bottom)
                            )
                            .foregroundColor(
                                viewModel.selectedSortMethod == method 
                                ? .white 
                                : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            
            // Position Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Position Filter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PositionFilter.allCases) { filter in
                            Button {
                                viewModel.updatePositionFilter(filter)
                            } label: {
                                Text(filter.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        viewModel.selectedPositionFilter == filter 
                                        ? Color.blue 
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        viewModel.selectedPositionFilter == filter 
                                        ? .white 
                                        : .primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Suggestions Content
    
    private var suggestionsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Smart Recommendations")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.suggestions.isEmpty {
                    Text("\(viewModel.suggestions.count) players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.suggestions.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                    
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("AI is analyzing the best picks for you...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Choose display method based on sort method
                if viewModel.selectedSortMethod == .all {
                    // LazyVStack for "All" - can handle thousands of players
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.suggestions) { suggestion in
                            enhancedSuggestionCardForAll(suggestion)
                        }
                    }
                } else {
                    // List with swipe actions for Wizard and Rankings
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.suggestions) { suggestion in
                            enhancedSuggestionCard(suggestion)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: -> Enhanced Suggestion Cards
    
    private func enhancedSuggestionCard(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 12) {
            // Player headshot - improved lookup logic
            playerImageForSuggestion(suggestion.player)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Custom player name and position display
                    playerNameAndPositionView(for: suggestion)
                    
                    // Tier badge (T1 = Elite, T2 = Very Good, etc.)
                    tierBadge(suggestion.player.tier)
                    
                    Spacer()
                    
                    // Team logo (much larger size)
                    TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                        .frame(width: 42, height: 42)
                }
                
                // Player details: fantasy rank, jersey, years, injury status all on one line
                playerDetailsRow(for: suggestion.player)
            }
        }
        .padding(12)
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Tap to show player stats
            showPlayerStats(for: suggestion.player)
        }
        .contextMenu {
            Button("Lock as My Pick") {
                lockPlayerAsPick(suggestion)
            }
            
            Button("Add to Feed") {
                addPlayerToFeed(suggestion)
            }
            
            Button("View Stats") {
                showPlayerStats(for: suggestion.player)
            }
        }
    }
    
    // MARK: -> Enhanced Suggestion Card for "All" view
    
    private func enhancedSuggestionCardForAll(_ suggestion: Suggestion) -> some View {
        HStack(spacing: 16) {  
            // Player headshot with position number badge overlay
            ZStack(alignment: .topTrailing) {
                playerImageForSuggestion(suggestion.player)
                
                // Sequential position number in blue gradient circle
                if let index = viewModel.suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            // Player info - expanded to fill more space
            VStack(alignment: .leading, spacing: 6) {  
                HStack(spacing: 8) {
                    playerNameAndPositionView(for: suggestion)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        tierBadge(suggestion.player.tier)
                        
                        TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                            .frame(width: 42, height: 42)
                    }
                }
                
                playerDetailsRowForAll(for: suggestion.player)
            }
        }
        .padding(.horizontal, 16)  
        .padding(.vertical, 14)    
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            showPlayerStats(for: suggestion.player)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            lockPlayerAsPick(suggestion)
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        .contextMenu {
            Button("Lock as My Pick") {
                lockPlayerAsPick(suggestion)
            }
            
            Button("Add to Feed") {
                addPlayerToFeed(suggestion)
            }
            
            Button("View Stats") {
                showPlayerStats(for: suggestion.player)
            }
        }
    }
    
    // MARK: -> Helper Methods (Copied from DraftRoomView)
    
    @ViewBuilder
    private func playerImageForSuggestion(_ player: Player) -> some View {
        if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: player.team)
            )
        } else {
            Circle()
                .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(player.firstInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                )
                .frame(width: 60, height: 60)
        }
    }
    
    private func findSleeperPlayerForSuggestion(_ player: Player) -> SleeperPlayer? {
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
    
    private func showPlayerStats(for player: Player) {
        selectedPlayerForStats = player
        DispatchQueue.main.async {
            showingPlayerStats = true
        }
    }
    
    private func addPlayerToFeed(_ suggestion: Suggestion) {
        let currentFeed = viewModel.picksFeed.isEmpty ? "" : viewModel.picksFeed + ", "
        viewModel.picksFeed = currentFeed + suggestion.player.shortKey
        viewModel.addFeedPick()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func lockPlayerAsPick(_ suggestion: Suggestion) {
        viewModel.myPickInput = suggestion.player.shortKey
        viewModel.lockMyPick()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func playerDetailsRow(for player: Player) -> some View {
        HStack(spacing: 8) {
            if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func playerDetailsRowForAll(for player: Player) -> some View {
        HStack(spacing: 8) {
            if let sleeperPlayer = findSleeperPlayerForSuggestion(player) {
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let number = sleeperPlayer.number {
                    Text("#: \(number)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func playerNameAndPositionView(for suggestion: Suggestion) -> some View {
        HStack(spacing: 6) {
            Text("\(suggestion.player.firstInitial) \(suggestion.player.lastName)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let sleeperPlayer = findSleeperPlayerForSuggestion(suggestion.player),
               let positionRank = sleeperPlayer.positionalRank {
                Text("- \(positionRank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } else {
                Text("- \(suggestion.player.position.rawValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tierBadge(_ tier: Int) -> some View {
        Text("T\(tier)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(tierColor(tier))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }

    private func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        return findSleeperPlayerForSuggestion(player)
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
    AIPickSuggestionsView(viewModel: DraftRoomViewModel())
}
