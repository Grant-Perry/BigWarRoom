//
//  PlayerSearchView.swift
//  BigWarRoom
//
//  Player search interface that allows searching NFL players and viewing detailed stats
//

import SwiftUI

/// **PLAYER SEARCH VIEW**
/// 
/// Allows users to search for NFL players by name and navigate to detailed player stats
/// Uses PlayerDirectoryStore for fast in-memory searching across all NFL players
struct PlayerSearchView: View {
    
    // MARK: - State Properties
    @State private var searchText = ""
    @State private var playerDirectory = PlayerDirectoryStore.shared
    // 🔥 PHASE 3 DI: Use @Environment for ViewModels
    @Environment(MatchupsHubViewModel.self) private var matchupsViewModel
    @State private var selectedScope: SearchScope = .all
    @Environment(\.presentationMode) var presentationMode
    
    enum SearchScope {
        case all, rostered
    }
    
    // MARK: - Computed Properties
    /// All Sleeper IDs of players on my rosters across leagues
    private var myRosterSleeperIDs: Set<String> {
        var ids = Set<String>()
        for matchup in matchupsViewModel.myMatchups {
            if let myTeam = matchup.myTeam {
                for p in myTeam.roster {
                    if let id = p.sleeperID {
                        ids.insert(id)
                    }
                }
            }
        }
        return ids
    }
    
    /// Filtered players based on search text
    private var filteredPlayers: [SleeperPlayer] {
        guard !searchText.isEmpty else {
            return []
        }
        
        let searchTerms = searchText.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
        
        let base = Array(playerDirectory.players.values)
            .filter { player in
                let fullName = player.fullName.lowercased()
                let shortName = player.shortName.lowercased()
                let firstName = player.firstName?.lowercased() ?? ""
                let lastName = player.lastName?.lowercased() ?? ""
                
                return searchTerms.allSatisfy { term in
                    fullName.contains(term) || 
                    shortName.contains(term) || 
                    firstName.contains(term) || 
                    lastName.contains(term)
                }
            }
            .filter { player in
                player.position != nil &&
                !player.fullName.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .sorted { player1, player2 in
                let rank1 = player1.searchRank ?? 999
                let rank2 = player2.searchRank ?? 999
                return rank1 < rank2
            }
        
        // Apply scope
        let scoped: [SleeperPlayer]
        switch selectedScope {
        case .all:
            scoped = base
        case .rostered:
            scoped = base.filter { myRosterSleeperIDs.contains($0.playerID) }
        }
        
        return Array(scoped.prefix(50))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // CUSTOM HEADER WITH BACK BUTTON, TITLE AND SEARCH
            VStack(spacing: 16) {
                // Back button and title section
                HStack {
                    // Back button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Player Search")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to center the title
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .opacity(0) // Invisible but takes up space
                }
                
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("Search players by name...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Scope toggle row
                HStack(spacing: 10) {
                    // All
                    scopeChip(
                        title: "All",
                        isSelected: selectedScope == .all,
                        selectedColor: .gpGreen
                    ) { selectedScope = .all }
                    
                    // Rostered
                    scopeChip(
                        title: "Rostered",
                        isSelected: selectedScope == .rostered,
                        selectedColor: .gpBlue
                    ) { selectedScope = .rostered }
                    
                    Spacer()
                    
                    // Players count
                    Text("Players \(filteredPlayers.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
//            .background(Color.red) // DEBUG: Red background to see the bounds
            
            // Content
            if searchText.isEmpty {
                // Empty state - show instructions
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("Search for NFL Players")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Enter a player name to view detailed stats, live game data, roster information, and more")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
            } else if filteredPlayers.isEmpty {
                // No results state
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Players Found")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Try adjusting your search or check spelling")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
            } else {
                // Results list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Results header
                        HStack {
                            Text("\(filteredPlayers.count) player\(filteredPlayers.count == 1 ? "" : "s") found")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        
                        // Player results
                        ForEach(filteredPlayers, id: \.playerID) { player in
                            NavigationLink(destination: PlayerStatsCardView(
                                player: player,
                                team: NFLTeam.team(for: player.team ?? "")
                            )) {
                                PlayerSearchResultCard(player: player)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Extra space for tab bar
                }
            }
        }
        .background(
            Image("BG5")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea(.all)
        )
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            // Ensure the directory is up-to-date so rookies/new players (e.g., Jayden Daniels) are included
            if playerDirectory.needsRefresh {
                await playerDirectory.refreshPlayers()
            }
            // Load leagues so "Rostered" scope works
            await matchupsViewModel.loadAllMatchups()
        }
    }
    
    private func scopeChip(title: String, isSelected: Bool, selectedColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedColor.opacity(0.35) : Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? selectedColor.opacity(0.8) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Player Search Result Card

/// Individual player result card for search results
struct PlayerSearchResultCard: View {
    let player: SleeperPlayer
    
    private var team: NFLTeam? {
        NFLTeam.team(for: player.team ?? "")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Player Image
            playerImageView
            
            // Player Info
            playerInfoSection
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - Private Views
    
    private var playerImageView: some View {
        AsyncImage(url: player.headshotURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            playerImagePlaceholder
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(team?.primaryColor ?? .white, lineWidth: 2)
        )
    }
    
    private var playerImagePlaceholder: some View {
        ZStack {
            team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
            
            Text(player.shortName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var playerInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name
            Text(player.fullName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Position and Team row
            playerDetailsRow
        }
    }
    
    private var playerDetailsRow: some View {
        HStack(spacing: 8) {
            // Position badge
            if let position = player.position {
                Text(position)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(team?.primaryColor ?? .gray)
                    )
            }
            
            // Team
            if let teamName = team?.id {
                Text(teamName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Search Rank (if available)
            if let rank = player.searchRank {
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke((team?.primaryColor ?? Color.white).opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview("Player Search - Empty State") {
    NavigationView {
        PlayerSearchView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Player Search - With Results") {
    NavigationView {
        PlayerSearchView()
    }
    .preferredColorScheme(.dark)
    .onAppear {
        // This would be handled by search in real app
    }
}