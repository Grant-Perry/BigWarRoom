//
//  AllLivePlayersView.swift
//  BigWarRoom
//
//  Displays all active players across all leagues with score bars and animations
//

import SwiftUI

struct AllLivePlayersView: View {
    // 🔥 FIXED: Use shared instance instead of creating new one
    @ObservedObject private var viewModel = AllLivePlayersViewModel.shared
    @State private var animatedPlayers: [String] = []
    @State private var selectedMatchup: UnifiedMatchup?
    @State private var showingMatchupDetail = false
    @State private var sortHighToLow = true // Track sort direction
    
    // 🔥 NEW: Task management for better performance
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with position filter and sorting
                headerView
                
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredPlayers.isEmpty {
                    emptyStateView
                } else {
                    playersListView
                }
            }
            .navigationTitle("All Live Players")
            .navigationBarTitleDisplayMode(.inline) // Changed from .large to .inline to save space
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            // Cancel any existing task before starting new one
            loadTask?.cancel()
            loadTask = Task {
                await viewModel.loadAllPlayers()
            }
        }
        .onDisappear {
            // Cancel tasks when view disappears to prevent background work
            loadTask?.cancel()
        }
        .sheet(isPresented: $showingMatchupDetail) {
            if let matchup = selectedMatchup {
                MatchupDetailSheet(matchup: matchup)
            }
        }
    }
    
    // MARK: - Header View (Compact and efficient)
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Manager info as full width header
            if let firstManager = getFirstAvailableManager() {
                fullWidthManagerHeader(firstManager)
            }
            
            // Controls row with All selector, Sort controls
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.setPositionFilter(position)
                                    animatedPlayers.removeAll()
                                }
                            }) {
                                HStack {
                                    Text(position.displayName)
                                    if viewModel.selectedPosition == position {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.selectedPosition.displayName)
                                .fontWeight(.semibold)
                                .font(.subheadline)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gpGreen.opacity(0.1))
                        .foregroundColor(.gpGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                HStack(spacing: 2) {
                    Text("Sort:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(AllLivePlayersViewModel.SortingMethod.allCases) { method in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.setSortingMethod(method)
                                    animatedPlayers.removeAll()
                                }
                            }) {
                                HStack {
                                    Text(method.displayName)
                                    if viewModel.sortingMethod == method {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.sortingMethod.displayName)
                                .fontWeight(.semibold)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 60)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                // Sort direction toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortHighToLow.toggle()
                        applySorting()
                        animatedPlayers.removeAll()
                    }
                }) {
                    Text(sortDirectionText)
                        .fontWeight(.semibold)
                        .font(.subheadline)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 65)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Spacer()
            }
            
            // Stats Summary
            if !viewModel.filteredPlayers.isEmpty {
                statsSummaryView
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGray6).opacity(0.3))
    }
    
    private var statsSummaryView: some View {
        HStack(spacing: 20) {
            StatBlock(
                title: "Players",
                value: "\(viewModel.filteredPlayers.count)",
                color: .gpGreen
            )
            
            StatBlock(
                title: "Top Score",
                value: String(format: "%.1f", viewModel.positionTopScore > 0 ? viewModel.positionTopScore : viewModel.topScore),
                color: .blue
            )
            
            Menu {
                ForEach(AllLivePlayersViewModel.PlayerPosition.allCases) { position in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.setPositionFilter(position)
                            animatedPlayers.removeAll() // Reset animations
                        }
                    }) {
                        HStack {
                            Text(position.displayName)
                            if viewModel.selectedPosition == position {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                StatBlock(
                    title: "Position",
                    value: viewModel.selectedPosition.displayName,
                    color: .orange
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            FantasyLoadingIndicator()
                .scaleEffect(1.2)
            
            Text("Loading players from all leagues...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Active Players")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No players found for the selected position. Try selecting a different position or check your league connections.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Players List View
    
    // 🔥 IMPROVED: Optimized players list view with better scroll performance
    private var playersListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) { // Reduced from 12 to 8 for tighter spacing
                ForEach(Array(viewModel.filteredPlayers.enumerated()), id: \.element.id) { index, playerEntry in
                    PlayerScoreBarCardView(
                        playerEntry: playerEntry,
                        animateIn: !animatedPlayers.contains(playerEntry.id),
                        onTap: {
                            // Open matchup detail
                            selectedMatchup = playerEntry.matchup
                            showingMatchupDetail = true
                        },
                        viewModel: viewModel
                    )
                    .onAppear {
                        // Optimized staggered animation with shorter delays
                        if !animatedPlayers.contains(playerEntry.id) {
                            let delay = min(Double(index) * 0.05, 1.0) // Cap max delay at 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                // Check if view is still alive before animating
                                guard !Task.isCancelled else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    animatedPlayers.append(playerEntry.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .clipped() // Prevent scroll view overflow during fast scrolling
    }

    // Helper function to apply sorting (optimized)
    private func applySorting() {
        withAnimation(.easeInOut(duration: 0.2)) { // Shorter animation
            viewModel.setSortDirection(highToLow: sortHighToLow)
        }
    }
    
    // Dynamic text for sort direction based on sorting method
    private var sortDirectionText: String {
        switch viewModel.sortingMethod {
        case .score:
            return sortHighToLow ? "Highest" : "Lowest"
        case .name:
            return sortHighToLow ? "A to Z" : "Z to A"
        case .team:
            return sortHighToLow ? "A to Z" : "Z to A"
        }
    }
    
    // MARK: - Full Width Manager Header
    
    private func fullWidthManagerHeader(_ manager: ManagerInfo) -> some View {
        HStack(spacing: 12) {
            // Manager avatar
            Group {
                if let avatarURL = manager.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(manager.initials)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(manager.initials)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            // Manager name and score
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(String(format: "%.1f", manager.score))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(manager.scoreColor)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }

    // MARK: - Manager Info View
    
    private func managerInfoView(_ manager: ManagerInfo) -> some View {
        HStack(spacing: 8) {
            // Manager avatar
            Group {
                if let avatarURL = manager.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(manager.initials)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(manager.initials)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            
            // Manager name and score
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(String(format: "%.1f", manager.score))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(manager.scoreColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    // MARK: - Helper Methods
    
    private func getFirstAvailableManager() -> ManagerInfo? {
        // Get the first available manager from the loaded matchups
        for matchup in viewModel.matchupsHubViewModel.myMatchups {
            if let myTeam = matchup.myTeam {
                let isWinning = determineIfWinning(matchup: matchup, team: myTeam)
                return ManagerInfo(
                    name: myTeam.ownerName,
                    score: myTeam.currentScore ?? 0.0,
                    avatarURL: myTeam.avatarURL,
                    scoreColor: isWinning ? .green : .red,
                    initials: String(myTeam.ownerName.prefix(2)).uppercased()
                )
            }
        }
        return nil
    }
    
    private func determineIfWinning(matchup: UnifiedMatchup, team: FantasyTeam) -> Bool {
        // For chopped leagues, use ranking logic
        if matchup.isChoppedLeague {
            return true // Default to green for chopped leagues since there's no direct opponent
        }
        
        // For regular matchups, compare against opponent
        guard let opponent = matchup.opponentTeam else { return true }
        return (team.currentScore ?? 0.0) > (opponent.currentScore ?? 0.0)
    }
}

// MARK: - Matchup Detail Sheet

struct MatchupDetailSheet: View {
    let matchup: UnifiedMatchup
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if matchup.isChoppedLeague {
                    // Show Chopped league detail
                    ChoppedLeaderboardView(
                        choppedSummary: matchup.choppedSummary!,
                        leagueName: matchup.league.league.name,
                        leagueID: matchup.league.league.leagueID
                    )
                } else {
                    // Show regular fantasy matchup detail
                    FantasyMatchupDetailView(
                        matchup: matchup.fantasyMatchup!,
                        fantasyViewModel: matchup.createConfiguredFantasyViewModel(),
                        leagueName: matchup.league.league.name
                    )
                }
            }
            .navigationTitle(matchup.league.league.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Stat Block Component

struct StatBlock: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Models

struct ManagerInfo {
    let name: String
    let score: Double
    let avatarURL: URL?
    let scoreColor: Color
    let initials: String
}

// MARK: - Preview

#Preview {
    AllLivePlayersView()
}