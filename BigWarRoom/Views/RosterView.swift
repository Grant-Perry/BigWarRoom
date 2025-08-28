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
            }
        }
        .preferredColorScheme(.dark)
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
            Text("Team Rosters")
                .font(.title2)
                .fontWeight(.bold)
            
            // Group picks by draft slot (team)
            let picksByTeam = Dictionary(grouping: viewModel.allDraftPicks) { $0.draftSlot }
            let sortedTeamSlots = picksByTeam.keys.sorted()
            
            LazyVStack(spacing: 20) {
                ForEach(sortedTeamSlots, id: \.self) { teamSlot in
                    let teamPicks = picksByTeam[teamSlot] ?? []
                    teamRosterCard(teamSlot: teamSlot, picks: teamPicks)
                }
            }
        }
    }
    
    private func teamRosterCard(teamSlot: Int, picks: [EnhancedPick]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Team header with name and pick count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(teamDisplayName(for: teamSlot, from: picks))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Draft Slot \(teamSlot)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(picks.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("picks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
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
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func positionGroupCard(position: String, players: [EnhancedPick]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Position header
            HStack {
                Text(position)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(positionColor(position))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Spacer()
                
                Text("\(players.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Players at this position (vertical list for better spacing)
            VStack(spacing: 12) {
                ForEach(players.sorted { $0.pickNumber < $1.pickNumber }) { player in
                    CompactTeamRosterPlayerCard(pick: player)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.2))
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
    
    /// Get team display name (use roster info if available, fallback to "Team X")
    private func teamDisplayName(for teamSlot: Int, from picks: [EnhancedPick]) -> String {
        // Try to get team name from any pick's roster info
        if let teamName = picks.first?.rosterInfo?.displayName, !teamName.isEmpty, teamName != "Team \(teamSlot)" {
            return teamName
        }
        return "Team \(teamSlot)"
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

// MARK: -> Compact Team Roster Player Card

struct CompactTeamRosterPlayerCard: View {
    let pick: EnhancedPick
    
    var body: some View {
        HStack(spacing: 12) {
            // Pick number in small blue circle
            Text("\(pick.pickNumber)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            // Player image
            PlayerImageView(
                player: pick.player,
                size: 40,
                team: pick.team
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 3) {
                Text(pick.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 6) {
                    // Position badge
                    Text(pick.position)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(positionColor(pick.position))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    // Positional rank badge (RB1, WR2, etc.) - NEW
                    if let positionRank = pick.player.positionalRank {
                        Text(positionRank)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                        .frame(width: 14, height: 14)
                    
                    Text(pick.teamCode)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if let searchRank = pick.player.searchRank {
                        Text("FR:\(searchRank)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.10),
                            Color.blue.opacity(0.03)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
        )
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

// MARK: -> Team Roster Player Card

struct TeamRosterPlayerCard: View {
    let pick: EnhancedPick
    
    var body: some View {
        CompactTeamRosterPlayerCard(pick: pick)
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
    RosterView(viewModel: DraftRoomViewModel())
}