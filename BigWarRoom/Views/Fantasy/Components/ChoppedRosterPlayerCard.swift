//
//  ChoppedRosterPlayerCard.swift
//  BigWarRoom
//
//  🔥 REPLICATES ALL LIVE PLAYERS DESIGN: Beautiful horizontal cards with large images
//

import SwiftUI

/// **ChoppedRosterPlayerCard - REPLICATES ALL LIVE PLAYERS DESIGN**
/// 
/// **Strategy:** Match the exact design from All Live Players - large image, game info, stats
struct ChoppedRosterPlayerCard: View {
    @State private var viewModel: ChoppedPlayerCardViewModel
    let onPlayerTap: (SleeperPlayer) -> Void
    let compact: Bool
    
    @State private var showingScoreBreakdown = false
    // 🔥 PURE DI: Accept from parent, no more .shared
    @State private var watchService: PlayerWatchService
    @State private var allLivePlayersViewModel: AllLivePlayersViewModel?
    @State private var playerDirectory = PlayerDirectoryStore.shared
    
    // 🔥 PURE DI: Inject from environment
    @Environment(NFLGameDataService.self) private var nflGameDataService
    
    // 🔥 PURE DI: allLivePlayersViewModel is OPTIONAL for Chopped views (they don't need it)
    init(
        player: FantasyPlayer,
        isStarter: Bool,
        parentViewModel: ChoppedTeamRosterViewModel,
        onPlayerTap: @escaping (SleeperPlayer) -> Void,
        compact: Bool = false,
        watchService: PlayerWatchService,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil
    ) {
        self.viewModel = ChoppedPlayerCardViewModel(
            player: player,
            isStarter: isStarter,
            parentViewModel: parentViewModel
        )
        self.onPlayerTap = onPlayerTap
        self.compact = compact
        self._watchService = State(initialValue: watchService)
        self._allLivePlayersViewModel = State(initialValue: allLivePlayersViewModel)
    }
    
    private let cardHeight: Double = 110.0 // Match All Live Players height
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Jersey number as bottom layer (like All Live Players)
            HStack {
                Spacer()
                if let jerseyNumber = getJerseyNumber() {
                    JerseyNumberView(
                        jerseyNumber: jerseyNumber,
                        teamColor: getContrastingJerseyColor(for: viewModel.player.team ?? "")
                    )
                    .offset(x: -60, y: 15)
                }
                Spacer()
            }
            
            // Main card content
            HStack(spacing: 0) {
                // Empty space for where image will be overlaid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 65)
                
                // Center game status section (replicate the matchup display)
                VStack {
                    Spacer()
                    buildGameStatusSection()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .offset(x: 37)
                .scaleEffect(1.1)
                
                // Player info section (right side)
                VStack(alignment: .trailing, spacing: 4) {
                    // Player name at top
                    HStack(spacing: 6) {
                        Spacer()
                        Text(formattedPlayerName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    
                    // League banner and position badge
                    HStack(spacing: 6) {
                        Spacer()
                        buildLeagueBanner()
                        buildPositionBadge()
                    }
                    
                    Spacer()
                    
                    // Action buttons and score
                    HStack(spacing: 8) {
                        // Watch button
                        Button(action: toggleWatch) {
                            Image(systemName: isWatching ? "eye.fill" : "eye")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isWatching ? .gpOrange : .gray)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(isWatching ? Color.gpOrange.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -20)
                        
                        // Score breakdown button
                        Button(action: { showingScoreBreakdown = true }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(y: -20)
                        
                        // Score display
                        VStack(alignment: .trailing, spacing: 2) {
                            Button(action: { showingScoreBreakdown = true }) {
                                HStack(spacing: 8) {
                                    Text(currentScoreString)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundColor(scoreColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    
                                    Text("pts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(scoreColor.opacity(0.4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(scoreColor.opacity(0.6), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .offset(y: -20)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(buildCardBackground())
            
            // Stats display at bottom (like All Live Players)
            if let points = viewModel.actualPoints, points > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Text(simpleStatsDisplay)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            
            // Player image overlay (large, like All Live Players)
            HStack {
                ZStack {
                    // Large team logo background
                    if let team = viewModel.player.team {
                        TeamAssetManager.shared.logoOrFallback(for: team)
                            .frame(width: 140, height: 140)
                            .opacity(0.25)
                            .offset(x: 20, y: 15)
                            .zIndex(0)
                    }
                    
                    // Player image
                    buildPlayerImage()
                        .zIndex(1)
                        .offset(x: -35)
                    
                    // Injury badge (if applicable)
                    if let injuryStatus = getSleeperPlayerData()?.injuryStatus, !injuryStatus.isEmpty {
                        InjuryStatusBadgeView(injuryStatus: injuryStatus)
                            .scaleEffect(0.8)
                            .offset(x: 25, y: 5)
                            .zIndex(15)
                    }
                }
                .frame(height: 80)
                .frame(maxWidth: 180)
                .offset(x: -10)
                Spacer()
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // BYE border matches green live border style
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    viewModel.player.isOnBye(gameDataService: nflGameDataService) ?
                        // BYE: Pink border with glassy gradient like green
                        LinearGradient(
                            colors: [.gpPink, .gpPink.opacity(0.8), .gpRedPink.opacity(0.6), .gpPink.opacity(0.9), .gpPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        // LIVE: Green/blue glassy gradient
                        (viewModel.player.isLive(gameDataService: nflGameDataService) ?
                            LinearGradient(colors: [.blue, .gpGreen], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.gpYellow], startPoint: .topLeading, endPoint: .bottomTrailing)),
                    lineWidth: (viewModel.player.isOnBye(gameDataService: nflGameDataService) || viewModel.player.isLive(gameDataService: nflGameDataService)) ? 3 : 2
                )
                .opacity((viewModel.player.isOnBye(gameDataService: nflGameDataService) || viewModel.player.isLive(gameDataService: nflGameDataService)) ? 0.8 : 0.6)
                .shadow(
                    color: viewModel.player.isOnBye(gameDataService: nflGameDataService) ? .gpPink.opacity(0.8) : (viewModel.player.isLive(gameDataService: nflGameDataService) ? .gpGreen.opacity(0.8) : .clear),
                    radius: (viewModel.player.isOnBye(gameDataService: nflGameDataService) || viewModel.player.isLive(gameDataService: nflGameDataService)) ? 15 : 0,
                    x: 0,
                    y: 0
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let sleeperPlayer = viewModel.sleeperPlayer {
                onPlayerTap(sleeperPlayer)
            }
        }
        .sheet(isPresented: $showingScoreBreakdown) {
            buildScoreBreakdownSheet()
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func buildGameStatusSection() -> some View {
        VStack(spacing: 2) {
            // Team matchup display (like "CAR vs DEN")
            if let team = viewModel.player.team {
                HStack(spacing: 4) {
                    Text(team)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gpGreen)
                    
                    Text("vs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("OPP") // Simplified opponent display
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.6))
                )
            }
            
            // Game status (FINAL, LIVE, etc.)
            Text(gameStatusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(gameStatusColor)
                )
        }
    }
    
    @ViewBuilder
    private func buildLeagueBanner() -> some View {
        Text("CHOPPED")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange.opacity(0.8))
            )
    }
    
    @ViewBuilder
    private func buildPositionBadge() -> some View {
        Text(viewModel.player.position)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(positionColor.opacity(0.8))
            )
    }
    
    @ViewBuilder
    private func buildPlayerImage() -> some View {
        Group {
            if let sleeperPlayer = viewModel.sleeperPlayer,
               let imageURL = sleeperPlayer.headshotURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    buildPlayerImageFallback()
                }
            } else {
                buildPlayerImageFallback()
            }
        }
    }
    
    @ViewBuilder
    private func buildPlayerImageFallback() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(viewModel.teamPrimaryColor.opacity(0.6))
            .frame(width: 80, height: 80)
            .overlay(
                Text(viewModel.player.position)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    @ViewBuilder
    private func buildCardBackground() -> some View {
        // Match All Live Players background with score bar effect
        let scoreBarWidth = calculateScoreBarWidth()
        
        ZStack(alignment: .leading) {
            // Base team gradient background
            RoundedRectangle(cornerRadius: 12)
                .fill(teamGradient)
            
            // Score bar overlay (similar to All Live Players)
            if scoreBarWidth > 0 {
                RoundedRectangle(cornerRadius: 12)
                    .fill(scoreBarColor)
                    .frame(width: scoreBarWidth * 320) // Adjust width as needed
            }
            
            // Dark overlay for text readability
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
        }
    }
    
    @ViewBuilder
    private func buildScoreBreakdownSheet() -> some View {
        if let breakdown = createScoreBreakdown() {
            ScoreBreakdownView(breakdown: breakdown)
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        } else {
            ScoreBreakdownView(breakdown: createEmptyBreakdown())
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedPlayerName: String {
        let fullName = viewModel.player.fullName
        let shortName = viewModel.player.shortName
        let shortComponents = shortName.split(separator: " ")
        
        if shortComponents.count >= 2 {
            let firstName = String(shortComponents[0])
            if firstName.count == 1 && !fullName.isEmpty {
                return fullName
            }
            if firstName.count == 1 {
                let lastName = shortComponents[1...]
                return firstName + ". " + lastName.joined(separator: " ")
            }
        }
        
        return !fullName.isEmpty ? fullName : shortName
    }
    
    private var currentScoreString: String {
        if let points = viewModel.actualPoints {
            return String(format: "%.1f", points)
        }
        return "0.0"
    }
    
    private var scoreColor: Color {
        if let points = viewModel.actualPoints {
            if points >= 20 { return .gpGreen }
            else if points >= 12 { return .blue }
            else if points >= 8 { return .orange }
            else { return .gpRedPink }
        }
        return .gray
    }
    
    private var positionColor: Color {
        switch viewModel.player.position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private var teamGradient: LinearGradient {
        if let team = NFLTeam.team(for: viewModel.player.team ?? "") {
            return team.gradient
        }
        return LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    private var scoreBarColor: Color {
        let percentage = calculateScoreBarWidth()
        if percentage >= 0.8 { return .gpGreen.opacity(0.4) }
        else if percentage >= 0.5 { return .blue.opacity(0.3) }
        else if percentage >= 0.25 { return .orange.opacity(0.3) }
        else { return .red.opacity(0.2) }
    }
    
    private var gameStatusText: String {
        // Get actual game status from NFLGameDataService
        if let team = viewModel.player.team,
           let gameInfo = nflGameDataService.getGameInfo(for: team) {
            return gameInfo.statusBadgeText
        }
        
        // Fallback to simple check
        if viewModel.player.isLive(gameDataService: nflGameDataService) {
            return "LIVE"
        } else {
            return "FINAL"
        }
    }
    
    private var gameStatusColor: Color {
        // Get actual game status color from NFLGameDataService
        if let team = viewModel.player.team,
           let gameInfo = nflGameDataService.getGameInfo(for: team) {
            return gameInfo.statusColor
        }
        
        // Fallback
        return viewModel.player.isLive(gameDataService: nflGameDataService) ? .red : .gray
    }
    
    private var simpleStatsDisplay: String {
        let position = viewModel.player.position
        let score = viewModel.actualPoints ?? 0.0
        
        if score > 0 {
            if let statLine = viewModel.statBreakdown {
                return statLine
            }
            return "\(position) • \(String(format: "%.1f", score)) pts"
        } else {
            return "\(position) • No stats yet"
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateScoreBarWidth() -> Double {
        let maxPoints: Double = 40.0
        let currentPoints = viewModel.actualPoints ?? 0.0
        return min(currentPoints / maxPoints, 1.0)
    }
    
    private func getJerseyNumber() -> String? {
        if let sleeperPlayer = PlayerDirectoryStore.shared.player(for: viewModel.player.id) {
            return sleeperPlayer.number?.description
        }
        return viewModel.player.jerseyNumber
    }
    
    private func getContrastingJerseyColor(for teamCode: String) -> Color {
        guard let team = NFLTeam.team(for: teamCode) else {
            return .white
        }
        return team.primaryColor.adaptedTextColor()
    }
    
    private func getSleeperPlayerData() -> SleeperPlayer? {
        let playerName = viewModel.player.fullName.lowercased()
        let shortName = viewModel.player.shortName.lowercased()
        let team = viewModel.player.team?.lowercased()
        
        return playerDirectory.players.values.first { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == shortName &&
             sleeperPlayer.team?.lowercased() == team)
        }
    }
    
    // MARK: - Watch Functionality
    
    private var isWatching: Bool {
        watchService.isWatching(viewModel.player.id)
    }
    
    private func toggleWatch() {
        if isWatching {
            watchService.unwatchPlayer(viewModel.player.id)
        } else {
            let opponentPlayer = OpponentPlayer(
                id: UUID().uuidString,
                player: viewModel.player,
                isStarter: viewModel.isStarter,
                currentScore: viewModel.actualPoints ?? 0.0,
                projectedScore: viewModel.player.projectedPoints ?? 0.0,
                threatLevel: .moderate,
                matchupAdvantage: .neutral,
                percentageOfOpponentTotal: 0.0
            )
            
            let opponentRefs = [OpponentReference(
                id: "chopped_roster",
                opponentName: "Chopped Team",
                leagueName: "Chopped League",
                leagueSource: "sleeper"
            )]
            
            let success = watchService.watchPlayer(opponentPlayer, opponentReferences: opponentRefs)
            if !success {
            }
        }
    }
    
    // MARK: - Score Breakdown Methods
    
    private func createScoreBreakdown() -> PlayerScoreBreakdown? {
        guard viewModel.sleeperPlayer != nil else { return nil }
        
        let rosterWeek = viewModel.getCurrentWeek()
        let authoritativeScore = viewModel.actualPoints ?? 0.0
        
        let leagueContext = LeagueContext(
            leagueID: "chopped",
            source: .sleeper,
            isChopped: true,
            customScoringSettings: viewModel.parentViewModel.getLeagueScoringSettings()
        )
        
        let localStatsProvider: LocalStatsProvider = viewModel.parentViewModel
        
        // 🔥 PURE DI: Pass optional allLivePlayersViewModel (nil for Chopped views)
        let breakdown = ScoreBreakdownFactory.createBreakdown(
            for: viewModel.player,
            week: rosterWeek,
            localStatsProvider: localStatsProvider,
            leagueContext: leagueContext,
            allLivePlayersViewModel: allLivePlayersViewModel,
            weekSelectionManager: WeekSelectionManager.shared,
            idCanonicalizer: ESPNSleeperIDCanonicalizer.shared,
            playerDirectoryStore: PlayerDirectoryStore.shared,
            playerStatsCache: PlayerStatsCache.shared,
            scoringSettingsManager: ScoringSettingsManager.shared
        ).withLeagueName("Chopped League")
        
        return PlayerScoreBreakdown(
            player: breakdown.player,
            week: breakdown.week,
            items: breakdown.items,
            totalScore: authoritativeScore,
            isChoppedLeague: breakdown.isChoppedLeague,
            hasRealScoringData: true,
            leagueContext: breakdown.leagueContext,
            leagueName: breakdown.leagueName
        )
    }
    
    private func createEmptyBreakdown() -> PlayerScoreBreakdown {
        let rosterWeek = viewModel.getCurrentWeek()
        let authoritativeScore = viewModel.actualPoints ?? 0.0
        
        return PlayerScoreBreakdown(
            player: viewModel.player,
            week: rosterWeek,
            items: [],
            totalScore: authoritativeScore,
            isChoppedLeague: true,
            hasRealScoringData: true,
            leagueContext: LeagueContext(
                leagueID: "chopped",
                source: .sleeper,
                isChopped: true,
                customScoringSettings: nil
            ),
            leagueName: "Chopped League"
        )
    }
}