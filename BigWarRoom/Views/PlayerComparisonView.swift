//
//  PlayerComparisonView.swift
//  BigWarRoom
//
//  Player comparison view - Start/Sit decision tool (MVP)
//

import SwiftUI

struct PlayerComparisonView: View {
    @State private var viewModel = PlayerComparisonViewModel()
    @State private var showPlayer1Search = false
    @State private var showPlayer2Search = false
    @State private var searchText1 = ""
    @State private var searchText2 = ""
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Image("BG1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Player 1 Selection
                    playerSelectionSection(
                        player: viewModel.player1,
                        searchText: $searchText1,
                        placeholder: "Search Player 1...",
                        showSearch: $showPlayer1Search,
                        onSelect: { viewModel.selectPlayer1($0) },
                        onClear: { viewModel.clearPlayer1() },
                        playerNumber: 1
                    )
                    
                    // Player 2 Selection
                    if viewModel.player1 != nil {
                        playerSelectionSection(
                            player: viewModel.player2,
                            searchText: $searchText2,
                            placeholder: "Search Player 2...",
                            showSearch: $showPlayer2Search,
                            onSelect: { viewModel.selectPlayer2($0) },
                            onClear: { viewModel.clearPlayer2() },
                            playerNumber: 2
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Comparison Button
                    if viewModel.player1 != nil && viewModel.player2 != nil {
                        Button(action: {
                            Task {
                                await viewModel.performComparison()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("Compare Players")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                        }
                        .disabled(viewModel.isLoading)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .scaleEffect(viewModel.isLoading ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                    }
                    
                    // Comparison Results
                    if let recommendation = viewModel.recommendation {
                        comparisonResultsSection(recommendation: recommendation)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Loading State
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    // Error State
                    if let error = viewModel.errorMessage {
                        errorCard(message: error)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
				.padding()
                .padding(.horizontal, 45)
                .padding(.vertical, 20)
                .animation(.easeInOut(duration: 0.4), value: viewModel.player1)
                .animation(.easeInOut(duration: 0.4), value: viewModel.player2)
                .animation(.easeInOut(duration: 0.5), value: viewModel.recommendation)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Start/Sit Comparison")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    viewModel.clearBoth()
                    searchText1 = ""
                    searchText2 = ""
                }
                .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Compare Players")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Get start/sit recommendations based on projected points, recent form, and matchup analysis")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Player Selection Section
    
    private func playerSelectionSection(
        player: SleeperPlayer?,
        searchText: Binding<String>,
        placeholder: String,
        showSearch: Binding<Bool>,
        onSelect: @escaping (SleeperPlayer) -> Void,
        onClear: @escaping () -> Void,
        playerNumber: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Player \(playerNumber)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let player = player, !showSearch.wrappedValue {
                NavigationLink(destination: PlayerStatsCardView(player: player, team: nil)) {
                    selectedPlayerCardContent(player: player, onClear: {
                        onClear()
                        showSearch.wrappedValue = true
                    })
                }
            } else {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    TextField(placeholder, text: searchText)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                // Search results dropdown
                if !searchText.wrappedValue.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            let filteredPlayers = getFilteredPlayers(for: searchText.wrappedValue)
                            if filteredPlayers.isEmpty {
                                Text("No players found")
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding()
                            } else {
                                ForEach(filteredPlayers.prefix(15), id: \.playerID) { p in
                                    Button(action: {
                                        onSelect(p)
                                        searchText.wrappedValue = ""
                                        showSearch.wrappedValue = false
                                    }) {
                                        HStack(spacing: 12) {
                                            AsyncImage(url: p.headshotURL) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                            }
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(p.fullName)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 6) {
                                                    if let position = p.position {
                                                        Text(position)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                    if let team = p.team {
                                                        Text("•")
                                                            .foregroundColor(.white.opacity(0.5))
                                                        Text(team)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.white.opacity(0.7))
                                                    }
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                    )
                }
            }
        }
    }
    
    private func getFilteredPlayers(for searchTerm: String) -> [SleeperPlayer] {
        let store = PlayerDirectoryStore.shared
        guard !searchTerm.isEmpty else { return [] }
        
        let searchTerms = searchTerm.lowercased().split(separator: " ").map(String.init)
        
        var results: [SleeperPlayer] = []
        
        for player in store.players.values {
            // Skip players without position
            guard player.position != nil else { continue }
            
            // Check if all search terms match
            let fullName = player.fullName.lowercased()
            let matches = searchTerms.allSatisfy { fullName.contains($0) }
            
            if matches {
                results.append(player)
            }
        }
        
        // Sort by search rank
        results.sort { ($0.searchRank ?? 999) < ($1.searchRank ?? 999) }
        
        return results
    }
    
    private func selectedPlayerCardContent(player: SleeperPlayer, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            // Player Image
            AsyncImage(url: player.headshotURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            // Player Info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.fullName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    if let position = player.position {
                        Text(position)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    if let team = player.team {
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(team)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Clear Button - with extra padding from edge
            Button(action: {
                onClear()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 24))
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Compare Button
    
    private var compareButton: some View {
        Button(action: {
            Task {
                await viewModel.performComparison()
            }
        }) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                Text("Compare Players")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Comparison Results
    
    private func comparisonResultsSection(recommendation: ComparisonRecommendation) -> some View {
        VStack(spacing: 20) {
            // Recommendation Header
            recommendationHeader(recommendation: recommendation)
            
            // Side-by-side Player Comparison
            HStack(spacing: 12) {
                playerComparisonCard(
                    player: recommendation.winner,
                    grade: recommendation.winnerGrade,
                    isWinner: true
                )
                
                playerComparisonCard(
                    player: recommendation.loser,
                    grade: recommendation.loserGrade,
                    isWinner: false
                )
            }
            .padding(.horizontal, 4)
            
            // Reasoning
            reasoningSection(reasoning: recommendation.reasoning)
            
            // Confidence Level
            confidenceBadge(confidence: recommendation.confidence)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func recommendationHeader(recommendation: ComparisonRecommendation) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("START")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(recommendation.winner.fullName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            if recommendation.scoreDifference > 0 {
                Text("+\(recommendation.scoreDifference.fantasyPointsString) pt advantage")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func playerComparisonCard(
        player: ComparisonPlayer,
        grade: ComparisonRecommendation.LetterGrade,
        isWinner: Bool
    ) -> some View {
        VStack(spacing: 12) {
            // Player Image - Clickable to view stats
            NavigationLink(destination: PlayerStatsCardView(player: player.sleeperPlayer, team: nil)) {
                AsyncImage(url: player.sleeperPlayer.headshotURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isWinner ? Color.green : Color.red, lineWidth: 3)
                )
            }
            
            // Player Name
            Text(player.fullName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Grade
            Text(grade.rawValue)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(gradeColor(grade))
            
            // Projected Points
            if let projected = player.projectedPoints {
                VStack(spacing: 4) {
                    Text("Projected")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Text(projected.fantasyPointsString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // Recent Form
            if let form = player.recentForm {
                VStack(spacing: 4) {
                    Text("Avg (3 games)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Text(form.averagePoints.fantasyPointsString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isWinner ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        )
    }
    
    private func reasoningSection(reasoning: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            ForEach(Array(reasoning.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(reason)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    private func confidenceBadge(confidence: ComparisonRecommendation.ConfidenceLevel) -> some View {
        HStack {
            Image(systemName: confidence == .high ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
            Text(confidence.description)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(confidenceColor(confidence).opacity(0.3))
        )
        .foregroundColor(confidenceColor(confidence))
    }
    
    private func gradeColor(_ grade: ComparisonRecommendation.LetterGrade) -> Color {
        switch grade {
        case .aPlus, .a, .aMinus: return .green
        case .bPlus, .b, .bMinus: return .blue
        case .cPlus, .c, .cMinus: return .yellow
        case .d: return .orange
        case .f: return .red
        }
    }
    
    private func confidenceColor(_ confidence: ComparisonRecommendation.ConfidenceLevel) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }
    
    private func errorCard(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.2))
        )
    }
}

