//
//  MyRosterView.swift
//  BigWarRoom
//
//  A dedicated view to display the user's roster using enhanced player card styling.
//

import SwiftUI

struct MyRosterView: View {
    @ObservedObject var viewModel: DraftRoomViewModel
    
    @State private var selectedPlayer: SleeperPlayer?
    @State private var showStats = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Starting Lineup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tap a player for stats and details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Lineup
                VStack(spacing: 14) {
                    rosterSlotRow(label: "QB", player: viewModel.roster.qb)
                    rosterSlotRow(label: "RB1", player: viewModel.roster.rb1)
                    rosterSlotRow(label: "RB2", player: viewModel.roster.rb2)
                    rosterSlotRow(label: "WR1", player: viewModel.roster.wr1)
                    rosterSlotRow(label: "WR2", player: viewModel.roster.wr2)
                    rosterSlotRow(label: "WR3", player: viewModel.roster.wr3)
                    rosterSlotRow(label: "TE", player: viewModel.roster.te)
                    rosterSlotRow(label: "FLEX", player: viewModel.roster.flex)
                    rosterSlotRow(label: "K", player: viewModel.roster.k)
                    rosterSlotRow(label: "DST", player: viewModel.roster.dst)
                }
                
                // Bench
                VStack(alignment: .leading, spacing: 10) {
                    Text("Bench")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if viewModel.roster.bench.isEmpty {
                        emptyBenchCard
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.roster.bench.enumerated()), id: \.offset) { _, player in
                                enhancedPlayerCard(player)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("My Roster")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showStats) {
            if let sp = selectedPlayer {
                PlayerStatsCardView(
                    player: sp,
                    team: NFLTeam.team(for: sp.team ?? "")
                )
            }
        }
    }
    
    // MARK: - Enhanced Player Card (matching Draft War Room style)
    
    private func enhancedPlayerCard(_ player: Player) -> some View {
        HStack(spacing: 12) {
            // Player headshot - improved lookup logic
            playerImageForPlayer(player)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Custom player name and position display
                    playerNameAndPositionView(for: player)
                    
                    // Tier badge (T1 = Elite, T2 = Very Good, etc.)
                    tierBadge(player.tier)
                    
                    // Team logo (much larger size)
                    TeamAssetManager.shared.logoOrFallback(for: player.team)
                        .frame(width: 42, height: 42)
                    
                    Spacer()
                }
                
                // Player details: fantasy rank, jersey, years, injury status all on one line
                playerDetailsRow(for: player)
            }
        }
        .padding(12)
        .background(
            TeamAssetManager.shared.teamBackground(for: player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Tap to show player stats
            if let sleeperPlayer = findSleeperPlayer(for: player) {
                presentStats(sleeperPlayer)
            }
        }
    }
    
    // MARK: - Player Image Helper
    
    @ViewBuilder
    private func playerImageForPlayer(_ player: Player) -> some View {
        // Try multiple lookup strategies to find the Sleeper player
        if let sleeperPlayer = findSleeperPlayer(for: player) {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: player.team)
            )
        } else {
            // Fallback with team colors
            Circle()
                .fill(NFLTeam.team(for: player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(player.firstInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: player.team)?.accentColor ?? .white)
                )
                .frame(width: 60, height: 60)
        }
    }
    
    // MARK: - Player Details Row
    
    private func playerDetailsRow(for player: Player) -> some View {
        HStack(spacing: 8) {
            // Try to get Sleeper player data for detailed info
            if let sleeperPlayer = findSleeperPlayer(for: player) {
                // Fantasy Rank
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Jersey number  
                if let number = sleeperPlayer.number {
                    Text("#: \(number)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Years of experience
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                // Injury status (red text if present)
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                    Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                // Fallback when no Sleeper data
                Text("Tier \(player.tier) • \(player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Player Name and Position View
    
    private func playerNameAndPositionView(for player: Player) -> some View {
        HStack(spacing: 6) {
            // Player name - smaller font
            Text("\(player.firstInitial) \(player.lastName)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Position (smaller font) - only show if no positional rank available
            if let sleeperPlayer = findSleeperPlayer(for: player),
               let positionRank = sleeperPlayer.positionalRank {
                // Show positional rank instead of basic position
                Text("- \(positionRank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } else {
                // Fallback to basic position if no positional rank
                Text("- \(player.position.rawValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tierBadge(_ tier: Int) -> some View {
        Text("T\(tier)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(tierColor(tier))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple        // Elite players - purple background
        case 2: return .blue          // Very good players - blue  
        case 3: return .orange        // Decent players - orange
        default: return .gray         // Deep/bench players - gray
        }
    }
    
    // MARK: - Subviews
    
    private func rosterSlotRow(label: String, player: Player?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let player {
                enhancedPlayerCard(player)
            } else {
                emptySlotCard(position: label)
            }
        }
    }
    
    private func emptySlotCard(position: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(position.prefix(3))
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(.secondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Empty \(position) slot")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text("No player assigned")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                )
        )
    }
    
    private var emptyBenchCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.title3)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("No bench players")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Add players to your bench as the draft progresses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helpers
    
    private func presentStats(_ player: SleeperPlayer) {
        selectedPlayer = player
        DispatchQueue.main.async {
            showStats = true
        }
    }
    
    /// Attempts to match the internal Player to a SleeperPlayer for richer display.
    private func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        let directory = PlayerDirectoryStore.shared
        let all = directory.players.values
        
        if let direct = directory.players[player.id] {
            return direct
        }
        
        if let nameMatch = all.first(where: { sp in
            let nameMatches = sp.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sp.position?.uppercased() == player.position.rawValue
            let teamMatches = sp.team?.uppercased() == player.team.uppercased()
            return nameMatches && positionMatches && teamMatches
        }) {
            return nameMatch
        }
        
        if let fuzzy = all.first(where: { sp in
            guard let spFirst = sp.firstName, let spLast = sp.lastName else { return false }
            let firstInitialMatches = spFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = spLast.lowercased().contains(player.lastName.lowercased()) ||
                                  player.lastName.lowercased().contains(spLast.lowercased())
            let teamMatches = sp.team?.uppercased() == player.team.uppercased()
            return firstInitialMatches && lastNameMatches && teamMatches
        }) {
            return fuzzy
        }
        
        return nil
    }
}