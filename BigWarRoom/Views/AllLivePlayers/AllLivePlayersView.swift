//
//  AllLivePlayersView.swift
//  BigWarRoom
//
//  Displays all active players across all leagues with score bars and animations
//

import SwiftUI

struct AllLivePlayersView: View {
    @StateObject private var viewModel = AllLivePlayersViewModel()
    @State private var animatedPlayers: [String] = []
    @State private var selectedMatchup: UnifiedMatchup?
    @State private var showingMatchupDetail = false
    @State private var sortHighToLow = true // Track sort direction
    
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
            await viewModel.loadAllPlayers()
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
            // Top row: Position filter and Sort toggle
            HStack(spacing: 16) {
                // Position filter (tight spacing) - Make it clickable!
                HStack(spacing: 4) {
                    Text("Position:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
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
                        HStack(spacing: 6) {
                            Text(viewModel.selectedPosition.displayName)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gpGreen.opacity(0.1))
                        .foregroundColor(.gpGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                
                Spacer()
                
                // Sort toggle (like Mission Control)
                HStack(spacing: 4) {
                    Text("Sorted:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sortHighToLow.toggle()
                            applySorting()
                            animatedPlayers.removeAll() // Reset animations
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(sortHighToLow ? "Highest" : "Lowest")
                                .fontWeight(.semibold)
                            
                            Image(systemName: sortHighToLow ? "arrow.down" : "arrow.up")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            
            // Stats Summary
            if !viewModel.filteredPlayers.isEmpty {
                statsSummaryView
            }
        }
        .padding(.horizontal)
        .padding(.top, 8) // Minimal top padding
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
                        }
                    )
                    .onAppear {
                        // Staggered animation timing
                        if !animatedPlayers.contains(playerEntry.id) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    animatedPlayers.append(playerEntry.id)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // Helper function to apply sorting
    private func applySorting() {
        viewModel.setSortDirection(highToLow: sortHighToLow)
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

// MARK: - Preview

#Preview {
    AllLivePlayersView()
}