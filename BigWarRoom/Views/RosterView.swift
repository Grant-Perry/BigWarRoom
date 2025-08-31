//
//  RosterView.swift
//  BigWarRoom
//
//  Team-by-team roster view showing each manager's draft picks
//
// MARK: -> Roster View

import SwiftUI

struct RosterView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State for collapsible teams - changed to single team instead of Set
    @State private var expandedTeam: Int? = nil
    
    // State for player stats (same as Draft Board)
    @State private var selectedPlayerForStats: SleeperPlayer?
    @State private var showingPlayerStats = false
    
    // Customizable styling properties
    @State private var boxGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color.gpBlueDarkL, location: 0.0),
            .init(color: Color.clear, location: 1.0)
		]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    @State private var boxForeColor = Color.gpYellow

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Draft Header Info
                    if let selectedDraft = viewModel.selectedDraft {
                        draftHeaderCard(selectedDraft)
                    }
                    
                    // Team Rosters
                    if !viewModel.allDraftPicks.isEmpty {
                        teamRostersSection
                    } else {
                        emptyRosterState
                    }
                }
                .padding()
            }
            .navigationTitle("Team Rosters")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Expand All Teams") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                // For expand all, we'll just expand the first team
                                let allTeamSlots = Set(viewModel.allDraftPicks.map { $0.draftSlot })
                                expandedTeam = allTeamSlots.sorted().first
                            }
                        }
                        
                        Button("Collapse All Teams") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedTeam = nil
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPlayerStats) {
            if let player = selectedPlayerForStats,
               let team = NFLTeam.team(for: player.team ?? "") {
                PlayerStatsCardView(player: player, team: team)
            }
        }
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
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Team Rosters Section
    
    private var teamRostersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Team Rosters")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(expandedTeam != nil ? "1 team expanded" : "All teams collapsed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Group picks by draft slot (team)
            let picksByTeam = Dictionary(grouping: viewModel.allDraftPicks) { $0.draftSlot }
            let sortedTeamSlots = picksByTeam.keys.sorted()
            
            LazyVStack(spacing: 16) {
                ForEach(sortedTeamSlots, id: \.self) { teamSlot in
                    let teamPicks = picksByTeam[teamSlot] ?? []
                    collapsibleTeamRosterCard(teamSlot: teamSlot, picks: teamPicks)
                }
            }
        }
    }
    
    private var uniqueTeamCount: Int {
        Set(viewModel.allDraftPicks.map { $0.draftSlot }).count
    }
    
    private func collapsibleTeamRosterCard(teamSlot: Int, picks: [EnhancedPick]) -> some View {
        let isExpanded = expandedTeam == teamSlot
        
        return VStack(alignment: .leading, spacing: 0) {
            // Collapsible Team Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if isExpanded {
                        // If this team is already expanded, collapse it
                        expandedTeam = nil
                    } else {
                        // Expand this team (automatically collapses any other)
                        expandedTeam = teamSlot
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(teamDisplayName(for: teamSlot, from: picks))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(boxForeColor)
                        
                        Text("Draft Slot \(teamSlot)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(picks.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text("picks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(boxGradient)
//				.opacity(0.35)
            }
            
            // Collapsible Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Team roster organized by position
                    let rosterByPosition = organizeRosterByPosition(picks)
                    
                    if !picks.isEmpty {
                        VStack(spacing: 20) {
                            ForEach(rosterPositionOrder, id: \.self) { position in
                                if let playersAtPosition = rosterByPosition[position], !playersAtPosition.isEmpty {
                                    positionGroupCard(position: position, players: playersAtPosition)
                                }
                            }
                        }
                    } else {
                        Text("No picks yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .background(Color(.systemGray6).opacity(0.05))
            }
        }
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpanded ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    private func positionGroupCard(position: String, players: [EnhancedPick]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Position header
            HStack {
                Text(position)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(positionColor(position))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Spacer()
                
                Text("\(players.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Players at this position (vertical list for better spacing)
            VStack(spacing: 12) {
                ForEach(players.sorted { $0.pickNumber < $1.pickNumber }) { player in
                    CompactTeamRosterPlayerCard(
                        pick: player,
                        onPlayerTap: { sleeperPlayer in
                            selectedPlayerForStats = sleeperPlayer
                            showingPlayerStats = true
                        },
                        viewModel: viewModel // Pass viewModel for pick order calculation
                    )
                }
            }
        }
        .padding(16)
        .background(
            // Add the gpBlue to clear gradient background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.gpBlue.opacity(0.2), location: 0.0),
                    .init(color: Color.clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Empty State
    
    private var emptyRosterState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Team Rosters")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Connect to a draft to see team rosters")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Back to Draft Board") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 60)
    }
    
    // MARK: -> Helpers
    
    /// Get team/manager display name using ViewModel's public method - show first names only
    private func teamDisplayName(for teamSlot: Int, from picks: [EnhancedPick]) -> String {
        let fullName = viewModel.teamDisplayName(for: teamSlot)
        
        // Extract first name from the full manager name
        let components = fullName.components(separatedBy: " ")
        if let firstName = components.first, !firstName.isEmpty {
            // Check if it's a meaningful first name (not generic like "Team" or "Manager")
            if !firstName.lowercased().hasPrefix("team") && 
               !firstName.lowercased().hasPrefix("manager") && 
               firstName.count > 1 {
                return firstName
            }
        }
        
        // Fallback to full name if we can't extract a meaningful first name
        return fullName
    }
    
    /// Organize picks by fantasy position
    private func organizeRosterByPosition(_ picks: [EnhancedPick]) -> [String: [EnhancedPick]] {
        return Dictionary(grouping: picks) { pick in
            pick.position.uppercased()
        }
    }
    
    /// Standard fantasy roster position order
    private let rosterPositionOrder = ["QB", "RB", "WR", "TE", "K", "DEF", "DST"]
    
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

// MARK: -> Enhanced Compact Team Roster Player Card

struct CompactTeamRosterPlayerCard: View {
    let pick: EnhancedPick
    let onPlayerTap: (SleeperPlayer) -> Void
    @ObservedObject var viewModel: DraftRoomViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Top row: Pick # + Team Logo + Position (all smaller)
            HStack(spacing: 8) {
                // Smaller pick number
                Text(roundPickOrderFormat)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 16)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gpBlue)
                    )
                
                Spacer()
                
                // Team logo (smaller)
                TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                    .frame(width: 14, height: 14)
                
                // Position badge (smaller)
                if let realPlayer = findRealSleeperPlayer(),
                   let positionRank = realPlayer.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                } else if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                } else {
                    Text(pick.position)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(positionColor(pick.position))
                        )
                }
            }
            
            // Second row: Larger player image + Player name taking full width
            HStack(spacing: 12) {
                // Larger player image
                ZStack {
                    Circle()
                        .fill(positionColor(pick.position).opacity(0.3))
                        .frame(width: 52, height: 52)
                        .blur(radius: 2)
                    
                    playerImageForPick()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(positionColor(pick.position).opacity(0.6), lineWidth: 2)
                        )
                }
                
                // Player name taking full width
                HStack {
                    Text(pick.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    // Fantasy rank (if available)
                    if let realPlayer = findRealSleeperPlayer(),
                       let searchRank = realPlayer.searchRank {
                        Text("#\(searchRank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpYellow)
                    } else if let searchRank = pick.player.searchRank {
                        Text("#\(searchRank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpYellow)
                    }
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(0.7), location: 0.0),
                    .init(color: positionColor(pick.position).opacity(0.2), location: 0.5),
                    .init(color: Color.black.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(positionColor(pick.position).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            if let realSleeperPlayer = findRealSleeperPlayer() {
                onPlayerTap(realSleeperPlayer)
            }
        }
    }
    
    // MARK: -> Round.Pick.Order Format Helper
    
    private var roundPickOrderFormat: String {
        let actualRound = pick.round
        let actualPickInRound = pick.pickInRound
        
        let allTeamPicks = viewModel.allDraftPicks
            .filter { $0.draftSlot == pick.draftSlot }
            .sorted { $0.pickNumber < $1.pickNumber }
        
        let pickOrder = (allTeamPicks.firstIndex { $0.pickNumber == pick.pickNumber } ?? 0) + 1
        
        return "\(actualRound).\(actualPickInRound).\(pickOrder)"
    }
    
    // MARK: -> Enhanced Player Image with Real Sleeper Lookup
    
    @ViewBuilder
    private func playerImageForPick() -> some View {
        if let realSleeperPlayer = findRealSleeperPlayer() {
            PlayerImageView(
                player: realSleeperPlayer,
                size: 48,
                team: pick.team
            )
        } else {
            PlayerImageView(
                player: pick.player,
                size: 48,
                team: pick.team
            )
        }
    }
    
    // MARK: -> Enhanced Sleeper Player Lookup
    
    private func findRealSleeperPlayer() -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        if let directMatch = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            return directMatch
        }
        
        if let firstName = pick.player.firstName,
           let lastName = pick.player.lastName,
           let team = pick.player.team,
           let position = pick.player.position {
            
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
            
            let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperFirst = sleeperPlayer.firstName,
                      let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == firstName.prefix(1).uppercased()
                let lastNameContains = sleeperLast.lowercased().contains(lastName.lowercased()) || 
                                       lastName.lowercased().contains(sleeperLast.lowercased())
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                
                return firstInitialMatches && lastNameContains && teamMatches
            }
            
            return fuzzyMatch
        }
        
        return nil
    }
    
    // Enhanced position colors
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