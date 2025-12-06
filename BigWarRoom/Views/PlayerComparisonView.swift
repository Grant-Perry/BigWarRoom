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
    @State private var isPlayerSelectionCollapsed = false
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Image("BG5")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Player Selection Panel (Collapsible - contains both players)
                    VStack(spacing: 0) {
                        // Collapsible header
                        if viewModel.recommendation != nil {
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isPlayerSelectionCollapsed.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Player Selection")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: isPlayerSelectionCollapsed ? "chevron.down" : "chevron.up")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Player selection content
                        if !isPlayerSelectionCollapsed {
                            VStack(spacing: 24) {
                                // Player 1
                                playerSelectionSection(
                                    player: viewModel.player1,
                                    searchText: $searchText1,
                                    placeholder: "Search Player 1...",
                                    showSearch: $showPlayer1Search,
                                    onSelect: { viewModel.selectPlayer1($0) },
                                    onClear: { viewModel.clearPlayer1() },
                                    playerNumber: 1
                                )
                                
                                // Player 2
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
                                
                                // Comparison Button (Smaller, Sexier)
                                if viewModel.player1 != nil && viewModel.player2 != nil {
                                    Button(action: {
                                        // Collapse the panel
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            isPlayerSelectionCollapsed = true
                                        }
                                        
                                        // Perform comparison
                                        Task {
                                            await viewModel.performComparison()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.left.arrow.right")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text("Compare Players")
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
											 colors: [
												Color.gpBlueLight,
												Color.gpLtBlue.opacity(0.8)
											 ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 4)
                                    }
                                    .disabled(viewModel.isLoading)
                                    .scaleEffect(viewModel.isLoading ? 0.95 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
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
                    // Reset UI state to show player selection
                    isPlayerSelectionCollapsed = false
                    showPlayer1Search = false
                    showPlayer2Search = false
                }
                .foregroundColor(.white)
            }
        }
        .onAppear {
            // Restore last comparison so a relaunched app brings the user back where they left off
            viewModel.restoreLastComparison()
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
                                        searchResultCard(player: p)
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
    
    private func searchResultCard(player: SleeperPlayer) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Player image with team background (LEFT side)
                ZStack(alignment: .leading) {
                    // Team logo background
                    if let team = player.team {
                        let normalizedTeamCode = TeamCodeNormalizer.normalize(team) ?? team
                        if let nflTeam = NFLTeam.team(for: normalizedTeamCode) {
                            TeamAssetManager.shared.logoOrFallback(for: nflTeam.id)
                                .frame(width: 70, height: 70)
                                .opacity(0.2)
                        }
                    }
                    
                    // Player image
                    AsyncImage(url: player.headshotURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .offset(x: -15)
                }
                .frame(width: 70, height: 70)
                
                // Player info on RIGHT
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.fullName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        if let position = player.position {
                            Text(position)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        if let team = player.team {
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
            
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
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
				  .fill(Color.blue.gradient)
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
            
            // Percentage Thermometer - shows weighted score distribution
            percentageThermometer(recommendation: recommendation)
            
            // Key Factors Analysis
            KeyFactorsView(player1: recommendation.winner, player2: recommendation.loser)
            
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
                ZStack {
                    // Team logo background (like Live Players)
                    if let team = player.sleeperPlayer.team {
                        let normalizedTeamCode = TeamCodeNormalizer.normalize(team) ?? team
                        if let nflTeam = NFLTeam.team(for: normalizedTeamCode) {
                            TeamAssetManager.shared.logoOrFallback(for: nflTeam.id)
                                .frame(width: 120, height: 120)
                                .opacity(0.25)
                                .zIndex(0)
                        }
                    }
                    
                    // Player image on top
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
                    .zIndex(1)
                    
                    // Injury Status Badge
                    if let injuryStatus = player.sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                InjuryStatusBadgeView(injuryStatus: injuryStatus)
                                    .scaleEffect(0.9)
                                    .offset(x: -6, y: -6)
                            }
                        }
                        .zIndex(2)
                    }
                }
                .frame(width: 120, height: 120) // Container size for logo
            }
            
            // Player Name
            Text(player.fullName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Position Badge & Team Name (e.g., "QB1 Bills")
            HStack(spacing: 4) {
                // Position badge with roster position
                Text(getPositionWithRosterNumber(for: player))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(getPositionColor(for: player.position))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Team abbreviated name
                if let teamName = getTeamAbbreviatedName(for: player) {
                    Text(teamName)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Grade
            Text(grade.rawValue)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(gradeColor(grade))
            
            // Projected Points & OPRK (Two columns)
            HStack(spacing: 8) {
                // Column 1: Projected
                if let projected = player.projectedPoints {
                    VStack(spacing: 4) {
                        Text("Projected")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text(projected.fantasyPointsString)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Column 2: OPRK
                if let team = player.sleeperPlayer.team,
                   let matchupInfo = player.matchupInfo,
                   let opponent = matchupInfo.opponent {
                    let position = player.position
                    let _ = DebugPrint(mode: .oprk, "PlayerComparisonView: \(player.fullName) (\(position)) on \(team) playing vs \(opponent)")
                    let oprk = OPRKService.shared.getOPRK(forTeam: opponent, position: position)
                    let advantage = OPRKService.shared.getMatchupAdvantage(forOpponent: opponent, position: position)
                    
                    VStack(spacing: 4) {
                        VStack(spacing: 0) {
                            Text("vs \(opponent)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            Text("OPRK")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        if let rank = oprk {
                            HStack(spacing: 2) {
                                // OPRK emoji indicator (40% smaller, shown first)
                                Text(self.getOPRKEmoji(advantage))
                                    .font(.system(size: 7.2))  // 40% smaller than 12
                                Text("\(rank)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("--")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            
            // Recent Form (Single column)
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
    
    private func percentageThermometer(recommendation: ComparisonRecommendation) -> some View {
        let totalScore = recommendation.winnerScore + recommendation.loserScore
        let winnerPercentage = totalScore > 0 ? (recommendation.winnerScore / totalScore) * 100 : 0
        let loserPercentage = 100 - winnerPercentage
        
        return VStack(alignment: .center, spacing: 8) {
            // Labels
            HStack(spacing: 16) {
                Text(recommendation.winner.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text(recommendation.loser.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            // Thermometer Bar
            HStack(spacing: 0) {
                // Winner side (green)
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(maxWidth: .infinity)
                
                // Loser side (red)
                Rectangle()
                    .fill(Color.red.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 12)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            // Percentage Labels
            HStack(spacing: 16) {
                Text(String(format: "%.0f%%", winnerPercentage))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(String(format: "%.0f%%", loserPercentage))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func reasoningSection(reasoning: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why?")
                .font(.system(size: 18, weight: .bold))
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
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
    
    private func getPositionWithRosterNumber(for player: ComparisonPlayer) -> String {
        // Build position string with roster number (e.g., "QB1", "WR2")
        let position = player.position
        
        // Add roster position number if available
        if let depthPosition = player.depthChartPosition {
            return "\(position)\(depthPosition)"
        }
        
        // No roster position, just return position
        return position
    }
    
    private func getTeamAbbreviatedName(for player: ComparisonPlayer) -> String? {
        // Return abbreviated team name (e.g., "Bills", "Dolphins")
        guard let teamCode = player.team else { return nil }
        
        let normalizedTeamCode = TeamCodeNormalizer.normalize(teamCode) ?? teamCode
        if let nflTeam = NFLTeam.team(for: normalizedTeamCode) {
            return nflTeam.name  // Just the team name (e.g., "Bills", not "Buffalo Bills")
        }
        
        // Fallback: return the team code if team not found
        return teamCode
    }
    
    private func getPositionColor(for position: String) -> Color {
        // Return position-specific color (matching Live Players)
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF", "DST", "D/ST": return .red
        default: return .gray
        }
    }
    
    private func getOPRKEmoji(_ advantage: MatchupAdvantage) -> String {
        switch advantage {
        case .elite:      return "🟢"  // Easiest matchup
        case .favorable:  return "🟡"  // Good matchup
        case .neutral:    return "⚪"  // Average
        case .difficult:  return "🔴"  // Tough matchup
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

// MARK: - Key Factors View Component

struct KeyFactorsView: View {
    let player1: ComparisonPlayer
    let player2: ComparisonPlayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 Key Factors")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                // Depth Chart Comparison
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Depth")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            if player1.depthChartTier == "Starter" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if player1.depthChartTier == "Backup" {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.yellow)
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            Text(player1.depthChartTier)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Depth")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text(player2.depthChartTier)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            if player2.depthChartTier == "Starter" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if player2.depthChartTier == "Backup" {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.yellow)
                            } else {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                
                // TD Potential
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TD Potential")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            let emoji1 = player1.tdScoringTier == "High TD Potential" ? "🔥" : "⚡"
                            Text(emoji1)
                            Text(player1.tdScoringTier)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("TD Potential")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text(player2.tdScoringTier)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            let emoji2 = player2.tdScoringTier == "High TD Potential" ? "🔥" : "⚡"
                            Text(emoji2)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                
                // Health Status
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            let healthEmoji1 = getHealthEmoji(player1.injurySeverity)
                            Text(healthEmoji1)
                            Text(player1.injurySeverity)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(getHealthColor(player1.injurySeverity))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Health")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text(player2.injurySeverity)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(getHealthColor(player2.injurySeverity))
                            let healthEmoji2 = getHealthEmoji(player2.injurySeverity)
                            Text(healthEmoji2)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                
                // Trend
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trend")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(player1.efficiencyTrend)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Trend")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(player2.efficiencyTrend)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                
                // QB Quality (for WR/TE/RB)
                if ["WR", "TE", "RB"].contains(player1.position.uppercased()) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("QB Quality")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            HStack(spacing: 4) {
                                let qbEmoji1 = getQBEmoji(player1.qbQualityTier)
                                Text(qbEmoji1)
                                Text(player1.qbQualityTier ?? "Unknown")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("QB Quality")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            HStack(spacing: 4) {
                                Text(player2.qbQualityTier ?? "Unknown")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                let qbEmoji2 = getQBEmoji(player2.qbQualityTier)
                                Text(qbEmoji2)
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    private func getHealthEmoji(_ severity: String) -> String {
        switch severity {
        case "Healthy": return "✅"
        case "Minor Risk": return "⚠️"
        case "Moderate Risk": return "🔴"
        case "High Risk": return "❌"
        case "Low Risk": return "✅"
        default: return "❓"
        }
    }
    
    private func getHealthColor(_ severity: String) -> Color {
        switch severity {
        case "Healthy": return .green
        case "Minor Risk": return .yellow
        case "Moderate Risk": return .orange
        case "High Risk": return .red
        case "Low Risk": return .green
        default: return .white
        }
    }
    
    private func getQBEmoji(_ tier: String?) -> String {
        guard let tier = tier else { return "❓" }
        switch tier {
        case "Elite": return "⭐"
        case "Solid": return "👍"
        case "Good": return "✅"
        case "Adequate": return "👌"
        case "Weak": return "📉"
        default: return "❓"
        }
    }
}

