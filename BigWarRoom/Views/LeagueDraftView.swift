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
                ProgressView(value: Double(viewModel.allDraftPicks.count), total: Double(expectedPicks))
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
                    LeagueDraftPickCard(pick: pick)
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
                
                // Positional rank badge (RB1, WR2, etc.) - NEW
                if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                // Position badge
                Text(pick.position)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(positionColor(pick.position))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Player section: image + name + details
            HStack(spacing: 14) {
                // Player image
                PlayerImageView(
                    player: pick.player,
                    size: 60,
                    team: pick.team
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    // Player name
                    Text(pick.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    // Fantasy rank and positional rank
                    HStack(spacing: 8) {
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
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(width: 175, height: 130)
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