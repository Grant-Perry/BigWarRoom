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
    let myRosterID: Int? // To identify my picks
    @ObservedObject var viewModel: DraftRoomViewModel // Add viewModel to access team count
    let onPlayerTap: (SleeperPlayer) -> Void // Add callback for player stats
    
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
        VStack(alignment: .leading, spacing: 12) {
            // Header: Pick number (blue circle) and badges
            HStack(spacing: 12) {
                // Pick number in blue circle
                Text("\(pick.pickNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.blue))
                
                Spacer()
                
                // Show positional rank badge (RB1, WR2, etc.) with position colors if available,
                // otherwise show basic position badge as fallback
                if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(positionColor(pick.position))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    // Fallback to basic position badge if no positional rank
                    Text(pick.position)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(positionColor(pick.position))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Player section: image + name + details
            HStack(spacing: 14) {
                // Player image - use enhanced lookup method to get real Sleeper player
                playerImageForPick(pick.player)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Player name
                    Text(pick.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    // Enhanced stats using real Sleeper player data
                    enhancedPlayerDetailsRow()
                    
                    // Team info with logo
                    HStack(spacing: 8) {
                        TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                            .frame(width: 22, height: 22)
                        
                        Text(pick.teamCode)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isMyPick ?
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gpGreen.opacity(0.3),
                            Color.gpGreen.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.15),
                            Color.blue.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isMyPick ? Color.gpGreen : Color.blue.opacity(0.2), 
                            lineWidth: isMyPick ? 2.5 : 1
                        )
                )
        )
        .frame(width: 175, height: 130)
        .onTapGesture {
            // Handle tap to show player stats - same as Top 25
            if let realSleeperPlayer = findRealSleeperPlayer(for: pick.player) {
                onPlayerTap(realSleeperPlayer)
            }
        }
    }
    
    // MARK: -> Enhanced Player Details Row (Same as DraftRoomView)
    
    @ViewBuilder
    private func enhancedPlayerDetailsRow() -> some View {
        HStack(spacing: 8) {
            // Try to get real Sleeper player data for detailed info
            if let realSleeperPlayer = findRealSleeperPlayer(for: pick.player) {
                // Fantasy Rank
                if let searchRank = realSleeperPlayer.searchRank {
                    Text("FR: \(searchRank)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                // Positional rank (RB1, WR2, etc.)
                if let positionRank = realSleeperPlayer.positionalRank {
                    Text("(\(positionRank))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.cyan)
                }
                
                // Years of experience
                if let yearsExp = realSleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Injury status (red text if present)
                if let injuryStatus = realSleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(3)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                // Fallback when no Sleeper data - use original pick data
                if let searchRank = pick.player.searchRank {
                    Text("FR: \(searchRank)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                if let positionRank = pick.player.positionalRank {
                    Text("(\(positionRank))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.cyan)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: -> Player Image Helper (Enhanced Version)
    
    @ViewBuilder
    private func playerImageForPick(_ player: SleeperPlayer) -> some View {
        // Try to find the real Sleeper player using enhanced lookup
        if let realSleeperPlayer = findRealSleeperPlayer(for: player) {
            PlayerImageView(
                player: realSleeperPlayer,
                size: 60,
                team: pick.team
            )
        } else {
            // Fallback: Use the pick's player directly if it has valid data
            if let _ = player.firstName, let _ = player.lastName {
                PlayerImageView(
                    player: player,
                    size: 60,
                    team: pick.team
                )
            } else {
                // Final fallback with team colors
                Circle()
                    .fill(pick.team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        Text(getPlayerInitial(player))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(pick.team?.accentColor ?? .white)
                    )
                    .frame(width: 60, height: 60)
            }
        }
    }
    
    // MARK: -> Enhanced Sleeper Player Lookup (Same logic as DraftRoomView)
    
    private func findRealSleeperPlayer(for fakePlayer: SleeperPlayer) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Strategy 1: Direct ID match (if it's already a real Sleeper player)
        if let directMatch = PlayerDirectoryStore.shared.players[fakePlayer.playerID] {
            return directMatch
        }
        
        // For ESPN/fake players, try to match by name and team
        if let firstName = fakePlayer.firstName,
           let lastName = fakePlayer.lastName,
           let team = fakePlayer.team,
           let position = fakePlayer.position {
            
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
    
    private func getPlayerInitial(_ player: SleeperPlayer) -> String {
        if let firstName = player.firstName, !firstName.isEmpty {
            return String(firstName.prefix(1)).uppercased()
        } else if let lastName = player.lastName, !lastName.isEmpty {
            return String(lastName.prefix(1)).uppercased()
        } else if let displayName = pick.displayName.split(separator: " ").first {
            return String(displayName.prefix(1)).uppercased()
        }
        return "?"
    }
    
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .purple
        case "RB": return .green
        case "WR": return .blue
        case "TE": return .orange
        case "K": return .gray
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
}

#Preview {
    LeagueDraftView(viewModel: DraftRoomViewModel())
}