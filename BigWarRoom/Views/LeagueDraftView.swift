//
//  LeagueDraftView.swift
//  BigWarRoom
//
//  Complete league draft board showing all managers and their picks
//
// MARK: -> League Draft View

import SwiftUI

struct LeagueDraftView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @State private var showingRosterView = false
    @State private var selectedPlayerForStats: SleeperPlayer? // Add state for player stats
    @State private var showingPlayerStats = false // Add state for stats sheet
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Draft Header Info
                if let selectedDraft = viewModel.selectedDraft {
                    draftHeaderCard(selectedDraft)
                }
                
                // View Toggle Section
                viewToggleSection
                
                // Draft Board by Rounds
                if !viewModel.allDraftPicks.isEmpty {
                    draftBoardSection
                } else {
                    emptyDraftState
                }
            }
            .padding()
        }
        .navigationTitle("Draft Board")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingRosterView) {
            RosterView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPlayerStats) {
            if let player = selectedPlayerForStats,
               let team = NFLTeam.team(for: player.team ?? "") {
                PlayerStatsCardView(player: player, team: team)
            }
        }
    }
    
    // MARK: -> View Toggle Section
    
    private var viewToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("View Options")
                .font(.headline)
            
            HStack(spacing: 12) {
                // Round View Button (current view)
                Button {
                    // Already on round view - do nothing
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .font(.system(size: 12))
                        Text("Rounds")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Team View Button
                Button {
                    showingRosterView = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3")
                            .font(.system(size: 12))
                        Text("Teams")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Info indicator
                if !viewModel.allDraftPicks.isEmpty {
                    Text("\(viewModel.allDraftPicks.count) picks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Draft Header
    
    private func draftHeaderCard(_ league: SleeperLeague) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(league.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Text(league.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(league.status == .complete ? .green : .blue)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(league.totalRosters) teams")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(league.season)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.allDraftPicks.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("picks made")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Draft progress bar
            if let expectedPicks = expectedTotalPicks {
                ProgressView(value: min(max(Double(viewModel.allDraftPicks.count), 0), Double(expectedPicks)), total: Double(expectedPicks))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
                
                Text("\(viewModel.allDraftPicks.count) of \(expectedPicks) picks completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Draft Board
    
    private var draftBoardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Draft Board - By Round")
                .font(.title2)
                .fontWeight(.bold)
            
            // Group picks by round
            let picksByRound = Dictionary(grouping: viewModel.allDraftPicks) { $0.round }
            let sortedRounds = picksByRound.keys.sorted()
            
            LazyVStack(spacing: 20) {
                ForEach(sortedRounds, id: \.self) { round in
                    roundSection(round: round, picks: picksByRound[round] ?? [])
                }
            }
        }
    }
    
    private func roundSection(round: Int, picks: [EnhancedPick]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round header
            HStack {
                Text("Round \(round)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(picks.count) picks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Picks grid for this round (2 columns for larger cards)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(picks.sorted { $0.pickNumber < $1.pickNumber }) { pick in
                    LeagueDraftPickCard(
                        pick: pick, 
                        myRosterID: viewModel.myRosterID, 
                        viewModel: viewModel,
                        onPlayerTap: { sleeperPlayer in
                            // Handle player stats tap
                            selectedPlayerForStats = sleeperPlayer
                            showingPlayerStats = true
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Empty State
    
    private var emptyDraftState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Draft Connected")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Connect to a live draft to see the draft board")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Go to War Room") {
                // This will be handled by parent TabView
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: -> Helpers
    
    private var expectedTotalPicks: Int? {
        guard let league = viewModel.selectedDraft else { return nil }
        // Estimate 15 rounds * number of teams (common draft format)
        return league.totalRosters * 15
    }
}

// MARK: -> League Draft Pick Card

struct LeagueDraftPickCard: View {
    let pick: EnhancedPick
    let myRosterID: Int?
    @ObservedObject var viewModel: DraftRoomViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    
    // Computed property to check if this is my pick
    private var isMyPick: Bool {
        guard let myRosterID = myRosterID else { return false }
        
        // For ESPN leagues using positional logic, ONLY use positional matching
        // Check if we're using positional logic (no roster info correlation)
        if pick.rosterInfo == nil || viewModel.selectedLeagueWrapper?.source == .espn {
            // Pure positional logic match (for ESPN leagues using positional logic)
            let teamCount = viewModel.currentDraftTeamCount // Use real team count from viewModel
            let draftSlot = myRosterID // For positional logic, myRosterID represents draft slot
            
            // Calculate if this pick number belongs to our draft position
            let round = ((pick.pickNumber - 1) / teamCount) + 1
            
            if round % 2 == 1 {
                // Odd rounds: normal order
                let expectedSlot = ((pick.pickNumber - 1) % teamCount) + 1
                return expectedSlot == draftSlot
            } else {
                // Even rounds: snake order
                let expectedSlot = teamCount - ((pick.pickNumber - 1) % teamCount)
                return expectedSlot == draftSlot
            }
        }
        
        // Strategy 1: Direct roster ID match (for Sleeper leagues with real roster correlation)
        if let rosterInfo = pick.rosterInfo {
            return rosterInfo.rosterID == myRosterID
        }
        
        return false
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Top row: Player name taking full width
            HStack {
                Text(pick.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
			   if let positionRank = pick.player.positionalRank {
				  Text(positionRank)
					 .font(.system(size: 12, weight: .bold))
					 .foregroundColor(.white)
					 .padding(.horizontal, 10)
					 .padding(.vertical, 5)
					 .background(
						Capsule()
						   .fill(positionColor(pick.position))
					 )
			   } else {
				  Text(pick.position)
					 .font(.system(size: 12, weight: .bold))
					 .foregroundColor(.white)
					 .padding(.horizontal, 10)
					 .padding(.vertical, 5)
					 .background(
						Capsule()
						   .fill(positionColor(pick.position))
					 )
			   }
            }
            
            // Second row: Player image first, then team logo, position, and pick number
            HStack(spacing: 8) {
                // Player image first (larger)
                ZStack {
                    Circle()
                        .fill(positionColor(pick.position).opacity(0.3))
                        .frame(width: 58, height: 58)
                        .blur(radius: 1)
                    
                    playerImageForPick()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(positionColor(pick.position).opacity(0.6), lineWidth: 1.5)
                        )
                }
                
                // Team logo (larger)
                TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                    .frame(width: 28, height: 28)
                
                // Position badge (larger)

                
                Spacer()
                
                // Pick number (larger)
                Text("\(pick.pickNumber)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                    )
            }
            
            // Third row: Fantasy rank (left) + Manager name (right)
            HStack {
                // Fantasy rank (if available)
                if let realPlayer = findRealSleeperPlayer(),
                   let searchRank = realPlayer.searchRank {
                    Text("FR: \(searchRank)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gpYellow)
                } else if let searchRank = pick.player.searchRank {
                    Text("FR: \(searchRank)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gpYellow)
                } else {
                    Text("")
                }
                
                Spacer()
                
                // Manager name (right justified, larger font)
                Text(viewModel.teamDisplayName(for: pick.draftSlot))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: isMyPick ? Color.gpGreen.opacity(0.4) : Color.black.opacity(0.7), location: 0.0),
                    .init(color: positionColor(pick.position).opacity(0.2), location: 0.5),
                    .init(color: isMyPick ? Color.gpGreen.opacity(0.2) : Color.black.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isMyPick ? Color.gpGreen.opacity(0.8) : positionColor(pick.position).opacity(0.4), lineWidth: isMyPick ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
        .onTapGesture {
            if let realSleeperPlayer = findRealSleeperPlayer() {
                onPlayerTap(realSleeperPlayer)
            }
        }
    }
    
    // MARK: -> Enhanced Player Image with Real Sleeper Lookup
    
    @ViewBuilder
    private func playerImageForPick() -> some View {
        if let realSleeperPlayer = findRealSleeperPlayer() {
            PlayerImageView(
                player: realSleeperPlayer,
                size: 36,
                team: pick.team
            )
        } else {
            PlayerImageView(
                player: pick.player,
                size: 36,
                team: pick.team
            )
        }
    }
    
    // MARK: -> Enhanced Sleeper Player Lookup
    
    private func findRealSleeperPlayer() -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Strategy 1: Direct ID match (if it's already a real Sleeper player)
        if let directMatch = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            return directMatch
        }
        
        // For ESPN/fake players, try to match by name and team
        if let firstName = pick.player.firstName,
           let lastName = pick.player.lastName,
           let team = pick.player.team,
           let position = pick.player.position {
            
            // Strategy 2: Exact name, team, and position match
            let exactMatch = allSleeperPlayers.first { sleeperPlayer in
                let firstNameMatches = sleeperPlayer.firstName?.lowercased() == firstName.lowercased()
                let lastNameMatches = sleeperPlayer.lastName?.lowercased() == lastName.lowercased()
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                let positionMatches = sleeperPlayer.position?.uppercased() == position.uppercased()
                
                return firstNameMatches && lastNameMatches && teamMatches && positionMatches
            }
            
            if let exactMatch = exactMatch {
                return exactMatch
            }
            
            // Strategy 3: Fuzzy name match with team (handles name variations)
            let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperFirst = sleeperPlayer.firstName,
                      let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == firstName.prefix(1).uppercased()
                let lastNameContains = sleeperLast.lowercased().contains(lastName.lowercased()) || 
                                       lastName.lowercased().contains(sleeperLast.lowercased())
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                
                return firstInitialMatches && lastNameContains && teamMatches
            }
            
            if let fuzzyMatch = fuzzyMatch {
                return fuzzyMatch
            }
            
            // Strategy 4: Team + position match for common names
            let teamPositionMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let lastNameMatches = sleeperLast.lowercased() == lastName.lowercased()
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                let positionMatches = sleeperPlayer.position?.uppercased() == position.uppercased()
                
                return lastNameMatches && teamMatches && positionMatches
            }
            
            return teamPositionMatch
        }
        
        return nil
    }
    
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return Color(red: 0.6, green: 0.3, blue: 0.9) // Purple
        case "RB": return Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        case "WR": return Color(red: 0.3, green: 0.6, blue: 1.0) // Blue
        case "TE": return Color(red: 1.0, green: 0.6, blue: 0.2) // Orange
        case "K": return Color(red: 0.7, green: 0.7, blue: 0.7) // Gray
        case "DEF", "DST": return Color(red: 0.9, green: 0.3, blue: 0.3) // Red
        default: return Color(red: 0.6, green: 0.6, blue: 0.6) // Default Gray
        }
    }
}
