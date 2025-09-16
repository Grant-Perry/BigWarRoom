//
//  PlayerRosteredSectionView.swift
//  BigWarRoom
//
//  Shows all leagues where this player is rostered for the user
//

import SwiftUI

/// Shows all leagues where this player is rostered for the user
struct PlayerRosteredSectionView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @StateObject private var matchupsHubViewModel = MatchupsHubViewModel()
    @State private var isExpanded: Bool = true // Changed to true for initial expanded state
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.fill.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.gpBlue)
                        
                        Text("Rostered")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(rosteredMatchups.count) leagues")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Collapsible Content
            if isExpanded {
                if rosteredMatchups.isEmpty {
                    emptyStateView
                } else {
                    rosteredContent
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(overlayBorder)
        .shadow(color: (team?.primaryColor ?? Color.gpBlue).opacity(0.2), radius: 4, x: 0, y: 2)
        .onAppear {
            // Load matchup data when view appears to ensure we have current roster info
            Task {
                await matchupsHubViewModel.loadAllMatchups()
            }
        }
    }
    
    // MARK: - Content Views
    
    private var rosteredContent: some View {
        LazyVStack(spacing: 6) {
            ForEach(rosteredMatchups, id: \.id) { matchup in
                RosteredLeagueRow(matchup: matchup)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Not rostered in any leagues")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Computed Properties
    
    /// Find all matchups where this player is on my team
    private var rosteredMatchups: [UnifiedMatchup] {
        return matchupsHubViewModel.myMatchups.filter { matchup in
            if matchup.isChoppedLeague {
                // Check if player is on my chopped team
                return matchup.myTeam?.roster.contains { rosterPlayer in
                    // More robust matching - check multiple identifiers
                    let nameMatch = rosterPlayer.fullName.lowercased() == self.player.fullName.lowercased()
                    let sleeperIDMatch = rosterPlayer.sleeperID == self.player.playerID
                    return nameMatch || sleeperIDMatch
                } ?? false
            } else {
                // Check if player is on my fantasy team
                return matchup.myTeam?.roster.contains { rosterPlayer in
                    // More robust matching - check multiple identifiers  
                    let nameMatch = rosterPlayer.fullName.lowercased() == self.player.fullName.lowercased()
                    let sleeperIDMatch = rosterPlayer.sleeperID == self.player.playerID
                    return nameMatch || sleeperIDMatch
                } ?? false
            }
        }
    }
    
    // MARK: - Background and Styling (Same as Live Game Stats)
    
    private var backgroundView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    team?.primaryColor.opacity(0.6) ?? Color.gpBlue.opacity(0.6),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle pattern overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                LinearGradient(
                    colors: [Color.gpBlue, team?.accentColor ?? Color.gpGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

/// Individual league row showing where player is rostered
private struct RosteredLeagueRow: View {
    let matchup: UnifiedMatchup
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationLink(destination: MatchupDetailSheetsView(matchup: matchup)) {
            HStack(spacing: 8) {
                // Platform logo (ESPN or Sleeper)
                platformLogo
                    .frame(width: 20, height: 20)
                
                // League name with CHOPPED suffix if applicable
                HStack(spacing: 4) {
                    Text(matchup.league.league.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if matchup.isChoppedLeague {
                        Text("-")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.gpYellow)
                        
                        Text("CHOPPED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.gpYellow)
                    }
                }
                
                Spacer()
                
                // Team record or status
                if matchup.isChoppedLeague {
                    if let ranking = matchup.myTeamRanking {
                        Text("#\(ranking.rank)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(eliminationStatusColor(ranking.eliminationStatus))
                    }
                } else {
                    if let myTeam = matchup.myTeam, let record = myTeam.record {
                        Text("\(record.wins)-\(record.losses)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var platformLogo: some View {
        Group {
            switch matchup.league.source {
            case .espn:
                Image("espnLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .sleeper:
                Image("sleeperLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
    
    private func eliminationStatusColor(_ status: EliminationStatus) -> Color {
        switch status {
        case .champion, .safe:
            return .gpGreen
        case .warning:
            return .gpYellow
        case .danger:
            return .orange
        case .critical, .eliminated:
            return .gpRedPink
        }
    }
}

#Preview {
    // Create a mock player with minimal required data
    let mockPlayerData = """
    {
        "player_id": "123",
        "first_name": "Josh",
        "last_name": "Allen",
        "position": "QB",
        "team": "BUF"
    }
    """.data(using: .utf8)!
    
    let mockPlayer = try! JSONDecoder().decode(SleeperPlayer.self, from: mockPlayerData)
    
    return PlayerRosteredSectionView(
        player: mockPlayer,
        team: nil
    )
}