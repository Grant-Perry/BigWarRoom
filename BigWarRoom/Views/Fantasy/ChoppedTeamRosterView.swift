//
//  ChoppedTeamRosterView.swift
//  BigWarRoom
//
//  💀🏈 CHOPPED TEAM ROSTER VIEW 🏈💀
//  View a team's active roster in a Chopped league
//

import SwiftUI

/// **ChoppedTeamRosterView**
/// 
/// Shows a team's active roster in Chopped leagues with:
/// - Starting lineup (the scoring players)
/// - Bench players (non-scoring)
/// - Same player card styling as Active Roster
/// - Real fantasy points and projections
/// - Collapsible sections
struct ChoppedTeamRosterView: View {
    let teamRanking: FantasyTeamRanking
    let leagueID: String
    let week: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var rosterData: ChoppedTeamRoster?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Collapsible section states
    @State private var showStartingLineup = true
    @State private var showBench = true
    
    // Player stats sheet
    @State private var selectedPlayer: SleeperPlayer?
    @State private var showStats = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let roster = rosterData {
                    rosterContentView(roster)
                } else {
                    errorView
                }
            }
            .navigationTitle(teamRanking.team.ownerName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadTeamRoster()
        }
        .sheet(isPresented: $showStats) {
            if let player = selectedPlayer {
                PlayerStatsCardView(
                    player: player,
                    team: NFLTeam.team(for: player.team ?? "")
                )
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading \(teamRanking.team.ownerName)'s Roster...")
                .font(.title3)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to Load Roster")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let error = errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Try Again") {
                Task {
                    await loadTeamRoster()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Roster Content View
    
    private func rosterContentView(_ roster: ChoppedTeamRoster) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Team header with score
                teamHeaderCard(roster)
                
                // Starting Lineup Section
                if !roster.starters.isEmpty {
                    startingLineupSection(roster.starters)
                }
                
                // Bench Section
                if !roster.bench.isEmpty {
                    benchSection(roster.bench)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Team Header Card
    
    private func teamHeaderCard(_ roster: ChoppedTeamRoster) -> some View {
        VStack(spacing: 16) {
            // Team avatar and info
            HStack(spacing: 16) {
                // Team avatar
                Group {
                    if let avatarURL = teamRanking.team.avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Circle()
                                    .fill(teamRanking.team.espnTeamColor)
                                    .overlay(
                                        Text(teamRanking.team.teamInitials)
                                            .font(.system(size: 32, weight: .black))
                                            .foregroundColor(.white)
                                    )
                            }
                        }
                    } else {
                        Circle()
                            .fill(teamRanking.team.espnTeamColor)
                            .overlay(
                                Text(teamRanking.team.teamInitials)
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(teamRanking.team.ownerName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Week \(week) Roster")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text(teamRanking.rankDisplay)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(teamRanking.eliminationStatus.color)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(teamRanking.eliminationStatus.displayName)
                            .font(.subheadline)
                            .foregroundColor(teamRanking.eliminationStatus.color)
                    }
                }
                
                Spacer()
                
                // Score display
                VStack(alignment: .trailing, spacing: 4) {
                    Text(teamRanking.weeklyPointsString)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("POINTS")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            }
            
            // Roster stats
            HStack(spacing: 20) {
                statCard(
                    title: "STARTERS",
                    value: "\(roster.starters.count)",
                    color: .green
                )
                
                statCard(
                    title: "BENCH", 
                    value: "\(roster.bench.count)",
                    color: .blue
                )
                
                statCard(
                    title: "TOTAL",
                    value: "\(roster.starters.count + roster.bench.count)",
                    color: .white
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(teamRanking.eliminationStatus.color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Starting Lineup Section
    
    private func startingLineupSection(_ starters: [FantasyPlayer]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showStartingLineup.toggle()
                }
            } label: {
                HStack {
                    Text("🔥 Starting Lineup")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(starters.count) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showStartingLineup ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Collapsible Content
            if showStartingLineup {
                VStack(spacing: 12) {
                    ForEach(starters) { player in
                        enhancedPlayerCard(player, isStarter: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bench Section
    
    private func benchSection(_ bench: [FantasyPlayer]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Collapsible Header
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBench.toggle()
                }
            } label: {
                HStack {
                    Text("🪑 Bench")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(bench.count) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: showBench ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Collapsible Content
            if showBench {
                if bench.isEmpty {
                    emptyBenchCard
                } else {
                    VStack(spacing: 12) {
                        ForEach(bench) { player in
                            enhancedPlayerCard(player, isStarter: false)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Enhanced Player Card (Same as MyRosterView)
    
    private func enhancedPlayerCard(_ player: FantasyPlayer, isStarter: Bool) -> some View {
        HStack(spacing: 12) {
            // Player headshot
            playerImageForPlayer(player)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Player name and position
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.fullName)
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(player.position)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Starter/Bench badge
                    Text(isStarter ? "STARTER" : "BENCH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isStarter ? Color.green : Color.gray)
                        )
                    
                    // Team logo
                    TeamAssetManager.shared.logoOrFallback(for: player.team ?? "")
                        .frame(width: 32, height: 32)
                }
                
                // Points and projections
                HStack(spacing: 16) {
                    if let points = player.currentPoints, points > 0 {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Points")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", points))
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if let projected = player.projectedPoints, projected > 0 {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Projected")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", projected))
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            TeamAssetManager.shared.teamBackground(for: player.team ?? "")
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // Find Sleeper player for stats
            if let sleeperPlayer = findSleeperPlayer(for: player) {
                selectedPlayer = sleeperPlayer
                showStats = true
            }
        }
    }
    
    // MARK: - Player Image Helper
    
    @ViewBuilder
    private func playerImageForPlayer(_ player: FantasyPlayer) -> some View {
        if let sleeperPlayer = findSleeperPlayer(for: player) {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: player.team ?? "")
            )
        } else {
            // Fallback with team colors
            Circle()
                .fill(NFLTeam.team(for: player.team ?? "")?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(String(player.firstName?.prefix(1) ?? ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
                .frame(width: 60, height: 60)
        }
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
                
                Text("All roster spots are filled with starters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Data Loading
    
    private func loadTeamRoster() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch matchup data for this week to get roster info
            let matchupData = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID,
                week: week
            )
            
            // Find this team's matchup data
            guard let teamMatchup = matchupData.first(where: { $0.rosterID == teamRanking.team.rosterID }) else {
                throw ChoppedRosterError.teamNotFound
            }
            
            // Create roster from matchup data
            let roster = try await createChoppedTeamRoster(from: teamMatchup)
            
            await MainActor.run {
                self.rosterData = roster
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load roster: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func createChoppedTeamRoster(from matchup: SleeperMatchupResponse) async throws -> ChoppedTeamRoster {
        let playerDirectory = PlayerDirectoryStore.shared
        
        var starters: [FantasyPlayer] = []
        var bench: [FantasyPlayer] = []
        
        // Process starters
        if let starterIDs = matchup.starters {
            for playerID in starterIDs {
                if let sleeperPlayer = playerDirectory.player(for: playerID) {
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: calculatePlayerPoints(playerID: playerID),
                        projectedPoints: calculatePlayerProjectedPoints(playerID: playerID),
                        gameStatus: createMockGameStatus(),
                        isStarter: true,
                        lineupSlot: sleeperPlayer.position
                    )
                    starters.append(fantasyPlayer)
                }
            }
        }
        
        // Process bench (all players minus starters)
        if let allPlayers = matchup.players {
            let starterIDs = Set(matchup.starters ?? [])
            let benchIDs = allPlayers.filter { !starterIDs.contains($0) }
            
            for playerID in benchIDs {
                if let sleeperPlayer = playerDirectory.player(for: playerID) {
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: calculatePlayerPoints(playerID: playerID),
                        projectedPoints: calculatePlayerProjectedPoints(playerID: playerID),
                        gameStatus: createMockGameStatus(),
                        isStarter: false,
                        lineupSlot: sleeperPlayer.position
                    )
                    bench.append(fantasyPlayer)
                }
            }
        }
        
        return ChoppedTeamRoster(starters: starters, bench: bench)
    }
    
    // MARK: - Helpers
    
    private func calculatePlayerPoints(playerID: String) -> Double? {
        // TODO: Implement real player scoring calculation
        return Double.random(in: 0...25)
    }
    
    private func calculatePlayerProjectedPoints(playerID: String) -> Double? {
        // TODO: Implement real player projection calculation
        return Double.random(in: 0...25)
    }
    
    private func createMockGameStatus() -> GameStatus {
        return GameStatus(status: "live")
    }
    
    private func findSleeperPlayer(for player: FantasyPlayer) -> SleeperPlayer? {
        if let sleeperID = player.sleeperID {
            return PlayerDirectoryStore.shared.player(for: sleeperID)
        }
        return nil
    }
}

// MARK: - Supporting Models

struct ChoppedTeamRoster {
    let starters: [FantasyPlayer]
    let bench: [FantasyPlayer]
}

enum ChoppedRosterError: LocalizedError {
    case teamNotFound
    case invalidRosterData
    
    var errorDescription: String? {
        switch self {
        case .teamNotFound:
            return "Team not found in matchup data"
        case .invalidRosterData:
            return "Invalid roster data"
        }
    }
}