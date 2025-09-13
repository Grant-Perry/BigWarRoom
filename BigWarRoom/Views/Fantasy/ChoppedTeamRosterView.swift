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
    @State private var opponentInfo: OpponentInfo? // NEW: Store opponent data
    
    // NFL Game Data Integration - NEW
    @StateObject private var nflGameService = NFLGameDataService.shared
    @State private var gameDataLoaded = false
    
    // Collapsible section states
    @State private var showStartingLineup = true
    @State private var showBench = true
    
    // Player stats sheet
    @State private var selectedPlayer: SleeperPlayer?
    @State private var showStats = false
    
    // Sorting states - NEW
    @State private var sortingMethod: MatchupSortingMethod = .position
    @State private var sortHighToLow = false

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white) // Ensure button is visible
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
                
                // NEW: Sorting controls
                PlayerSortingControlsView(
                    sortingMethod: $sortingMethod, 
                    sortHighToLow: $sortHighToLow
                )

                // Starting Lineup Section
                if !roster.starters.isEmpty {
                    startingLineupSection(sortPlayers(roster.starters))
                }
                
                // Bench Section
                if !roster.bench.isEmpty {
                    benchSection(sortPlayers(roster.bench))
                }
            }
            .padding()
        }
        .task {
            // Load NFL game data for real game times
            await loadNFLGameData()
        }
    }
    
    // MARK: - Player Sorting Logic (DRY)
    
    private func sortPlayers(_ players: [FantasyPlayer]) -> [FantasyPlayer] {
        return PlayerSortingService.sortPlayers(
            players, 
            by: sortingMethod, 
            highToLow: sortHighToLow,
            getPlayerPoints: { player in
                return getActualPlayerPoints(for: player)
            }
        )
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
    
    // MARK: - Starting Lineup Section - UPDATED to remove notice (moved to main view)
    
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
                VStack(spacing: 18) { // INCREASED: spacing from 12 to 18
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
                    VStack(spacing: 18) { // INCREASED: spacing from 12 to 18
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
    
    // MARK: - Enhanced Player Card (UPDATED with FantasyPlayerCard styling) - UPDATED with matchup info
    
    private func enhancedPlayerCard(_ player: FantasyPlayer, isStarter: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            // Background jersey number - FIXED with proper shadows for contrast
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Spacer()
                            .frame(width: geometry.size.width * 0.6) // Position in the right area
                        
                        HStack(alignment: .top, spacing: 2) {
                            // Small "#" symbol with outline effect
                            Text("#")
                                .font(.system(size: 40, weight: .thin))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -1, y: -1)
                                .shadow(color: .black, radius: 0, x: 1, y: -1)
                                .shadow(color: .black, radius: 0, x: -1, y: 1)
                                .shadow(color: .black, radius: 0, x: 1, y: 1)
                                .offset(x: 20, y: 25)
								.opacity(0.75)

                            // Big jersey number with outline effect
                            Text(player.jerseyNumber ?? findSleeperPlayer(for: player)?.number?.description ?? "")
                                .font(.system(size: 80, weight: .thin))
                                .italic()
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 0, x: -2, y: -2)
                                .shadow(color: .black, radius: 0, x: 2, y: -2)
                                .shadow(color: .black, radius: 0, x: -2, y: 2)
                                .shadow(color: .black, radius: 0, x: 2, y: 2)
                                .shadow(color: .black, radius: 1, x: 0, y: 0)
                                .offset(x: 0, y: 15)
                        }
						.offset(y: 10)

                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Team gradient background
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple, .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Team logo (subtle background)
            Group {
                if let team = player.team, let nflTeam = NFLTeam.team(for: team) {
				   let logoSize: CGFloat = 180
                    TeamAssetManager.shared.logoOrFallback(for: team)
					  .frame(width: logoSize, height: logoSize)
                        .offset(x: 30, y: -30)
                        .opacity(hasWeekStarted() && getActualPlayerPoints(for: player) != nil ? 0.6 : 0.35)
                        .shadow(color: nflTeam.primaryColor.opacity(0.5), radius: 10, x: 0, y: 0)
                }
            }
            
            // Main content stack - Player image
            HStack(spacing: 12) {
                // Player headshot
                playerImageForPlayer(player)
                    .frame(width: 140, height: 140)
                    .offset(x: -15, y: -6)
                    .zIndex(2)
                
                Spacer()
                
                // Score display (trailing) - FIXED clipping with offset
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 4) {
                        Spacer()
                        
                        // Points display
                        VStack(alignment: .trailing, spacing: 1) {
                            if hasWeekStarted(), let points = getActualPlayerPoints(for: player), points > 0 {
                                Text(String(format: "%.1f", points))
								  .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                            } else {
                                Text("")
								  .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.gray)
                                    .shadow(color: .black.opacity(0.9), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 12)
                    .offset(y: -10) // FIXED: Prevent clipping with stat line
                }
                .zIndex(3)
            }
            
            // Player name and position (right-justified)
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(player.fullName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                    
                    // Starter/Bench badge
                    Text(isStarter ? "STARTER" : "BENCH")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.8))
                                .stroke((isStarter ? Color.green : Color.gray).opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
            }
			.offset(y: 30)
//            .padding(.top, 30)
            .padding(.trailing, 8)
            .zIndex(4)
            
            // Game matchup (centered) with DRY component
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MatchupTeamFinalView(player: player, scaleEffect: 1.1)
                    Spacer()
                }
                .padding(.bottom, 45)
            }
            .zIndex(5)
            
            // Stats section with reserved space
            VStack {
                Spacer()
                HStack {
                    if isStarter, hasWeekStarted(), let actualPoints = getActualPlayerPoints(for: player), actualPoints > 0, let statLine = formatPlayerStatBreakdown(player) {
                        Text(statLine)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.7))
                                    .stroke((NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple).opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    } else {
                        // Invisible spacer to reserve space when no stats
                        Text(" ")
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.clear)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .zIndex(6)
        }
        .frame(height: 140) // UNCHANGED: Keep card height at 140px
        .background(
            // Card background with team colors
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black, 
                            (NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple).opacity(0.1), 
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: (NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple).opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 0
                )
        )
        .overlay(
            // Card border with team colors
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    LinearGradient(
                        colors: [
                            (NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple).opacity(0.6),
                            .clear,
                            (NFLTeam.team(for: player.team ?? "")?.primaryColor ?? .purple).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .opacity(0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
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
                size: 100,
                team: NFLTeam.team(for: player.team ?? "")
            )
			.offset(x: -25, y: 1)
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
    
    // MARK: - Data Loading - UPDATED to also load opponent
    
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
            
            // NEW: Find opponent in the same matchup
            if let matchupID = teamMatchup.matchupID {
                print("🔍 Looking for opponent with matchupID: \(matchupID)")
                let opponent = matchupData.first { matchup in
                    matchup.matchupID == matchupID && matchup.rosterID != teamRanking.team.rosterID
                }
                
                if let opponentMatchup = opponent {
                    print("✅ Found opponent with rosterID: \(opponentMatchup.rosterID), points: \(opponentMatchup.points ?? 0)")
                    // Load opponent team info from league data
                    await loadOpponentInfo(rosterID: opponentMatchup.rosterID, points: opponentMatchup.points ?? 0.0)
                } else {
                    print("❌ No opponent found for matchupID: \(matchupID)")
                }
            } else {
                print("❌ No matchupID found in team matchup")
            }
            
            // Create roster from matchup data
            let roster = try await createChoppedTeamRoster(from: teamMatchup)
            
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
    
    // MARK: - NFL Game Data Loading - NEW
    
    private func loadNFLGameData() async {
        guard !gameDataLoaded else { return }
        
        // Load real NFL game data for this week
        await MainActor.run {
            nflGameService.fetchGameData(forWeek: week, year: AppConstants.currentSeasonYearInt)
            gameDataLoaded = true
        }
    }

    // NEW: Load opponent information
    private func loadOpponentInfo(rosterID: Int, points: Double) async {
        do {
            // Fetch league rosters to get owner names
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            
            // Find the opponent roster
            if let opponentRoster = rosters.first(where: { $0.rosterID == rosterID }) {
                // Fetch users to get owner names - FIXED method name
                let users = try await SleeperAPIClient.shared.fetchUsers(leagueID: leagueID)
                let ownerName = users.first(where: { $0.userID == opponentRoster.ownerID })?.displayName ?? "Unknown"
                
                // Create opponent info
                let opponent = OpponentInfo(
                    ownerName: ownerName,
                    score: points,
                    rankDisplay: "Opp", // Could calculate actual rank if needed
                    teamColor: Color.blue, // Default color
                    teamInitials: String(ownerName.prefix(2)).uppercased(),
                    avatarURL: users.first(where: { $0.userID == opponentRoster.ownerID })?.avatar.flatMap { URL(string: "https://sleepercdn.com/avatars/\($0)") }
                )
                
                await MainActor.run {
                    self.opponentInfo = opponent
                }
            }
        } catch {
            print("❌ Failed to load opponent info: \(error)")
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
                        projectedPoints: nil,
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
                        projectedPoints: nil,
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

    // MARK: - Week Validation Helper
    
    /// 🔥 NEW: Check if the current week has actually started (games have been played)
    private func hasWeekStarted() -> Bool {
        // For now, check if we have any actual stats data for this week
        // If playerStats is empty or no players have points, week hasn't started
        if playerStats.isEmpty {
            return false
        }
        
        // Check if any players in this roster have actual points for this week
        let hasAnyPoints = playerStats.values.contains { stats in
            if let pprPoints = stats["pts_ppr"], pprPoints > 0 { return true }
            if let halfPprPoints = stats["pts_half_ppr"], halfPprPoints > 0 { return true }
            if let stdPoints = stats["pts_std"], stdPoints > 0 { return true }
            return false
        }
        
        return hasAnyPoints
    }

    // MARK: - Helper Methods (All methods placed here to avoid scope issues)
    
    /// 🔥 FIXED: Get actual player points ONLY if week has started
    private func getActualPlayerPoints(for player: FantasyPlayer) -> Double? {
        // If week hasn't started, don't show any points
        guard hasWeekStarted() else { return nil }
        
        guard let sleeperPlayer = findSleeperPlayer(for: player) else { return nil }
        
        // First try to get from loaded playerStats FOR THIS SPECIFIC WEEK
        if let stats = playerStats[sleeperPlayer.playerID] {
            // Use PPR points from Sleeper (most comprehensive)
            if let pprPoints = stats["pts_ppr"], pprPoints > 0 { return pprPoints }
            if let halfPprPoints = stats["pts_half_ppr"], halfPprPoints > 0 { return halfPprPoints }
            if let stdPoints = stats["pts_std"], stdPoints > 0 { return stdPoints }
        }
        
        // Fallback to cache - BUT ONLY FOR THE CURRENT WEEK
        if let cachedStats = PlayerStatsCache.shared.getPlayerStats(playerID: sleeperPlayer.playerID, week: week) {
            if let pprPoints = cachedStats["pts_ppr"], pprPoints > 0 { return pprPoints }
            if let halfPprPoints = cachedStats["pts_half_ppr"], halfPprPoints > 0 { return halfPprPoints }
            if let stdPoints = cachedStats["pts_std"], stdPoints > 0 { return stdPoints }
        }
        
        // If no valid stats for THIS week, return nil (don't use player.currentPoints)
        return nil
    }
    
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
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) REC TD") }
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
    
    /// Load weekly player stats for detailed breakdown display only - FIXED week validation
    private func loadPlayerStats() async {
        guard playerStats.isEmpty else { return }
        
        // 🔥 FIXED: Use SSOT for current season year
        let currentYear = AppConstants.currentSeasonYearInt
        
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(currentYear)/\(week)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            await MainActor.run {
                self.playerStats = statsData
            }
            
            // 🔥 DEBUG: Check if this week actually has data
            let totalPointsThisWeek = statsData.values.reduce(0) { total, stats in
                let playerPoints = stats["pts_ppr"] ?? stats["pts_half_ppr"] ?? stats["pts_std"] ?? 0
                return total + playerPoints
            }
            
            print("🔥 Week \(week) Stats Summary (Year \(currentYear) via SSOT): \(statsData.count) players, Total Points: \(totalPointsThisWeek)")
            
            if totalPointsThisWeek == 0 {
                print("⚠️ Week \(week) has no scoring data yet - games haven't started!")
            }
            
        } catch {
            print("❌ Failed to load player stats for week \(week), year \(currentYear): \(error)")
        }
    }
    
    private func calculatePlayerPoints(playerID: String) -> Double? {
        // 🔥 FIXED: Only return points if week has started
        guard hasWeekStarted() else { return nil }
        
        // Use cached stats if available FOR THIS SPECIFIC WEEK
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
        
        // If no valid stats for this week, return nil
        return nil
    }
    
    private func createMockGameStatus() -> GameStatus {
        return GameStatus(status: "live")
    }
    
    private func findSleeperPlayer(for player: FantasyPlayer) -> SleeperPlayer? {
        if let sleeperID = player.sleeperID {
            let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID)
            if sleeperPlayer == nil {
                print("⚠️ No SleeperPlayer found for \(player.fullName) with ID: \(sleeperID)")
            } else if sleeperPlayer?.number == nil {
                print("⚠️ SleeperPlayer \(player.fullName) found but has no jersey number")
            }
            return sleeperPlayer
        } else {
            print("⚠️ No sleeperID found for player: \(player.fullName)")
            return nil
        }
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

// NEW: Supporting model for opponent info - MOVED to bottom
private struct OpponentInfo {
    let ownerName: String
    let score: Double
    let rankDisplay: String
    let teamColor: Color
    let teamInitials: String
    let avatarURL: URL?
}