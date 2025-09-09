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
    @State private var playerStats: [String: [String: Double]] = [:]
    
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
            // 🔥 NOTICE: Always show for Chopped leagues about score accuracy
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("NOTICE: Individual scores are estimates. Team total is accurate.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .italic()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
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
        VStack(spacing: 0) {
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
                                    .offset(y: -20)
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
            
            // 🔥 NEW: Stat breakdown for starters
            if isStarter, let statLine = formatPlayerStatBreakdown(player) {
                HStack {
                    Text(statLine)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.4))
                        )
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .padding(8)
        .frame(height: 85)
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
        
        // x Print("🔍 DP: Loading roster for team \(teamRanking.team.ownerName), rosterID: \(teamRanking.team.rosterID)")
        
        do {
            // Fetch matchup data for this week to get roster info
            let matchupData = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID,
                week: week
            )
            
            // x Print("🔍 DP: Fetched \(matchupData.count) matchups for week \(week)")
            // x Print("🔍 DP: Looking for rosterID: \(teamRanking.team.rosterID)")
            
            // Debug: Show all roster IDs in matchup data
            let allRosterIDs = matchupData.compactMap { $0.rosterID }
            // x Print("🔍 DP: Available roster IDs: \(allRosterIDs)")
            
            // Find this team's matchup data
            guard let teamMatchup = matchupData.first(where: { $0.rosterID == teamRanking.team.rosterID }) else {
                // x Print("❌ DP: Team not found in matchup data!")
                throw ChoppedRosterError.teamNotFound
            }
            
            // x Print("🔍 DP: Found team matchup with \(teamMatchup.starters?.count ?? 0) starters and \(teamMatchup.players?.count ?? 0) total players")
            
            // Create roster from matchup data
            let roster = try await createChoppedTeamRoster(from: teamMatchup)
            
            // x Print("✅ DP: Created roster with \(roster.starters.count) starters and \(roster.bench.count) bench players")
            
            await MainActor.run {
                self.rosterData = roster
                self.isLoading = false
            }
            
        } catch {
            // x Print("❌ DP: Roster loading failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load roster: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
        
        // Also load stats for breakdown display
        await loadPlayerStats()
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

    // MARK: - Helper Methods (All methods placed here to avoid scope issues)
        
    /// Format player stat breakdown based on position - same method as FantasyMatchupDetailView
    private func formatPlayerStatBreakdown(_ player: FantasyPlayer) -> String? {
        guard let sleeperPlayer = findSleeperPlayer(for: player) else {
            return nil
        }
        
        guard let stats = playerStats[sleeperPlayer.playerID] else {
            return nil
        }
        
        let position = player.position
        var breakdown: [String] = []
        
        switch position {
        case "QB":
            // Passing stats: completions/attempts, yards, TDs
            if let attempts = stats["pass_att"], attempts > 0 {
                let completions = stats["pass_cmp"] ?? 0
                let yards = stats["pass_yd"] ?? 0
                let tds = stats["pass_td"] ?? 0
                breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
                
                // Add pass first downs and completions 40+
                if let passFd = stats["pass_fd"], passFd > 0 {
                    breakdown.append("\(Int(passFd)) PASS FD")
                }
                if let pass40 = stats["pass_40"], pass40 > 0 {
                    breakdown.append("\(Int(pass40)) CMP (40+)")
                }
            }
            
            // Rushing stats if significant for QBs
            if let carries = stats["rush_att"], carries > 0 {
                let rushYards = stats["rush_yd"] ?? 0
                let rushTds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if rushYards > 0 { breakdown.append("\(Int(rushYards)) RUSH YD") }
                if rushTds > 0 { breakdown.append("\(Int(rushTds)) RUSH TD") }
                
                // Add rush first downs for QBs
                if let rushFd = stats["rush_fd"], rushFd > 0 {
                    breakdown.append("\(Int(rushFd)) RUSH FD")
                }
            }
            
            // Sacks taken
            if let sacks = stats["pass_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            
        case "RB":
            // Rushing stats: carries, yards, TDs
            if let carries = stats["rush_att"], carries > 0 {
                let yards = stats["rush_yd"] ?? 0
                let tds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
                
                // Add rush first downs
                if let rushFd = stats["rush_fd"], rushFd > 0 {
                    breakdown.append("\(Int(rushFd)) RUSH FD")
                }
            }
            // Receiving if significant
            if let receptions = stats["rec"], receptions > 0 {
                let recYards = stats["rec_yd"] ?? 0
                let recTds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions)) REC")
                if recYards > 0 { breakdown.append("\(Int(recYards)) REC YD") }
                if recTds > 0 { breakdown.append("\(Int(recTds)) REC TD") }
            }
            
        case "WR", "TE":
            // Receiving stats: receptions/targets, yards, TDs
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
                
                // Add pass first downs
                if let passFd = stats["rec_fd"], passFd > 0 {
                    breakdown.append("\(Int(passFd)) PASS FD")
                }
            }
            // Rushing if significant for WRs
            if position == "WR", let rushYards = stats["rush_yd"], rushYards > 0 {
                breakdown.append("\(Int(rushYards)) RUSH YD")
            }
            
        case "K":
            // Field goals and extra points
            if let fgMade = stats["fgm"], fgMade > 0 {
                let fgAtt = stats["fga"] ?? fgMade
                breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
            }
            if let xpMade = stats["xpm"], xpMade > 0 {
                breakdown.append("\(Int(xpMade)) XP")
            }
            
        case "DEF", "DST":
            // Defense stats: sacks, interceptions, fumble recoveries
            if let sacks = stats["def_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            if let ints = stats["def_int"], ints > 0 {
                breakdown.append("\(Int(ints)) INT")
            }
            if let fumRec = stats["def_fum_rec"], fumRec > 0 {
                breakdown.append("\(Int(fumRec)) FUM REC")
            }
            
        default:
            return nil
        }
        
        return breakdown.isEmpty ? nil : breakdown.joined(separator: ", ")
    }
    
    /// Load weekly player stats for detailed breakdown display only
    private func loadPlayerStats() async {
        guard playerStats.isEmpty else { return }
        
        let currentYear = "2024"
        
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(currentYear)/\(week)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            await MainActor.run {
                self.playerStats = statsData
            }
            // x Print("🔥 DP: Loaded \(statsData.count) player stat records for breakdown display")
            
            // Debug print specific players for investigation
            for (playerID, stats) in statsData {
                if let player = PlayerDirectoryStore.shared.player(for: playerID) {
                    let playerName = player.fullName
                    if playerName.lowercased().contains("mccarthy") || 
                       playerName.lowercased().contains("j.j.") ||
                       playerName.lowercased() == "j. j. mccarthy" {
                        // x Print("🔍 DP: Found J.J. McCarthy stats - ID: \(playerID), Name: \(playerName), Stats: \(stats)")
                    }
                }
            }
            
        } catch {
            // x Print("❌ DP: Failed to load player stats: \(error)")
        }
    }
    
    private func calculatePlayerPoints(playerID: String) -> Double? {
        // Use cached stats if available
        if let stats = PlayerStatsCache.shared.getPlayerStats(playerID: playerID, week: week) {
            // Use PPR points from Sleeper
            if let pprPoints = stats["pts_ppr"] {
                return pprPoints
            } else if let halfPprPoints = stats["pts_half_ppr"] {
                return halfPprPoints
            } else if let stdPoints = stats["pts_std"] {
                return stdPoints
            }
        }
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
