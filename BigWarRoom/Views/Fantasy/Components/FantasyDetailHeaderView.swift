//
//  FantasyDetailHeaderView.swift
//  BigWarRoom
//
//  Header component for fantasy matchup detail view with enhanced sorting controls
//  ENHANCED: Full All Live Players style controls with search, position filter, active filter
//  CONNECTED: Filter states now properly bound to parent view
//

import SwiftUI

/// Header view for fantasy matchup details with team comparison and comprehensive sorting controls
struct FantasyDetailHeaderView: View {
    let leagueName: String
    let matchup: FantasyMatchup
    let awayTeamIsWinning: Bool
    let homeTeamIsWinning: Bool
    let fantasyViewModel: FantasyViewModel?
    
    // Enhanced sorting and filtering parameters
    let sortingMethod: MatchupSortingMethod
    let sortHighToLow: Bool
    let onSortingMethodChanged: (MatchupSortingMethod) -> Void
    let onSortDirectionChanged: () -> Void
    
    // NEW: Bound filter states (connected to parent)
    @Binding var selectedPosition: FantasyPosition
    @Binding var showActiveOnly: Bool
    @Binding var showYetToPlayOnly: Bool
    @FocusState private var isSearchFocused: Bool
    
    // 👁️ NEW: Watched Players Sheet state
    @State private var showingWatchedPlayers = false
    // 🔥 PHASE 3 DI: Remove .shared assignment, will be passed from parent
    @State private var watchService: PlayerWatchService
    
    // 🔥 PHASE 3 DI: Accept GameStatusService for "yet to play" calculations  
    let gameStatusService: GameStatusService?
    
    // Projected scores state
    @State private var homeProjected: Double = 0.0
    @State private var awayProjected: Double = 0.0
    @State private var projectionsLoaded = false
    @State private var homeYetToPlayProjected: Double = 0.0
    @State private var awayYetToPlayProjected: Double = 0.0
    
    // 🔥 PHASE 3 DI: Add initializer with watchService
    init(
        leagueName: String,
        matchup: FantasyMatchup,
        awayTeamIsWinning: Bool,
        homeTeamIsWinning: Bool,
        fantasyViewModel: FantasyViewModel?,
        sortingMethod: MatchupSortingMethod,
        sortHighToLow: Bool,
        onSortingMethodChanged: @escaping (MatchupSortingMethod) -> Void,
        onSortDirectionChanged: @escaping () -> Void,
        selectedPosition: Binding<FantasyPosition>,
        showActiveOnly: Binding<Bool>,
        showYetToPlayOnly: Binding<Bool>,
        watchService: PlayerWatchService,
        gameStatusService: GameStatusService? = nil
    ) {
        self.leagueName = leagueName
        self.matchup = matchup
        self.awayTeamIsWinning = awayTeamIsWinning
        self.homeTeamIsWinning = homeTeamIsWinning
        self.fantasyViewModel = fantasyViewModel
        self.sortingMethod = sortingMethod
        self.sortHighToLow = sortHighToLow
        self.onSortingMethodChanged = onSortingMethodChanged
        self.onSortDirectionChanged = onSortDirectionChanged
        self._selectedPosition = selectedPosition
        self._showActiveOnly = showActiveOnly
        self._showYetToPlayOnly = showYetToPlayOnly
        self._watchService = State(initialValue: watchService)
        self.gameStatusService = gameStatusService
    }
    
    /// Dynamic sort direction text based on current method and direction
    private var sortDirectionText: String {
        switch sortingMethod {
        case .score, .recentActivity:
            return sortHighToLow ? "↓" : "↑"
        case .name, .position, .team:
            return sortHighToLow ? "Z-A" : "A-Z"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Team comparison row - COMPACT VERSION
            teamComparisonRow
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
            
            // Enhanced controls section with distinct background
            enhancedControlsSection
                .background(
                    // Darker, distinct background for filter row
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    // Subtle border to separate from header
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(
            ZStack {
                // Main gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.nyyDark.opacity(0.9),
                        Color.black.opacity(0.7),
                        Color.nyyDark.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle overlay pattern
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.nyyDark.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.nyyDark.opacity(0.8), 
                            Color.white.opacity(0.2),
                            Color.nyyDark.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: Color.nyyDark.opacity(0.4),
            radius: 8, 
            x: 0, 
            y: 4
        )
        // 👁️ NEW: Watched Players Sheet
        .sheet(isPresented: $showingWatchedPlayers) {
            WatchedPlayersSheet(watchService: watchService)
        }
    }
    
    // MARK: - View Components
    
    private var teamComparisonRow: some View {
        HStack(spacing: 20) {
            // Home team (left side) - COMPACT
            VStack(spacing: 3) {
                // Manager name FIRST
                Text(matchup.homeTeam.ownerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Avatar and Record on same line
                HStack(spacing: 6) {
                    // Smaller Avatar with border
                    ZStack {
                        if let url = matchup.homeTeam.avatarURL {
                            AsyncTeamAvatarView(
                                url: url,
                                size: 32,
                                fallbackInitials: getInitials(from: matchup.homeTeam.ownerName)
                            )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(getInitials(from: matchup.homeTeam.ownerName))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        if homeTeamIsWinning {
                            Circle()
                                .strokeBorder(Color.gpGreen, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }
                    
                    // Record (lose "Record:" label)
                    let homeRecordText: String = {
                        let managerID = matchup.homeTeam.id
                        
                        if let record = matchup.homeTeam.record {
                            return record.displayString
                        }
                        
                        if let teamId = Int(managerID),
                           let record = fantasyViewModel?.espnTeamRecords[teamId] {
                            return record.displayString
                        }
                        
                        if let record = fantasyViewModel?.getManagerRecord(managerID: managerID), !record.isEmpty {
                            return record
                        }
                        
                        return "N/A"
                    }()
                    Text(homeRecordText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                // SCORE
                Text(String(format: "%.2f", matchup.homeTeam.currentScore ?? 0.0))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                
                // Projected scores thermometer (if loaded)
                if projectionsLoaded && homeProjected > 0 && awayProjected > 0 {
                    projectedThermometerView(
                        myProjected: homeProjected,
                        opponentProjected: awayProjected,
                        isHomeTeam: true
                    )
                    .padding(.vertical, 4)
                }
                
                // Yet to play - larger number with projected points
                VStack(spacing: 2) {
                    Text("Yet to play:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(homeTeamYetToPlay)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(homeTeamIsWinning ? .gpGreen : .red)
                        
                        if homeYetToPlayProjected > 0 {
                            Text("~ +\(String(format: "%.1f", homeYetToPlayProjected))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gpGreen.opacity(0.8))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Center VS section - COMPACT
            VStack(spacing: 2) {
                Text("VS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Week \(fantasyViewModel?.selectedWeek ?? matchup.week)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                if let scoreDiff = fantasyViewModel?.scoreDifferenceText(matchup: matchup), !scoreDiff.isEmpty {
                    Text(scoreDiff)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gpGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.4))
                        )
                }
                
                // 🔥 NEW: Countdown timer (only during live games)
                if SmartRefreshManager.shared.hasLiveGames {
                    RefreshCountdownTimerView()
                        .scaleEffect(0.8)
                        .padding(.top, 4)
                }
            }
            .frame(width: 60)
            
            // Away team (right side) - COMPACT
            VStack(spacing: 3) {
                // Manager name FIRST
                Text(matchup.awayTeam.ownerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Avatar and Record on same line
                HStack(spacing: 6) {
                    // Record (lose "Record:" label)
                    let awayRecordText: String = {
                        let managerID = matchup.awayTeam.id
                        
                        if let record = matchup.awayTeam.record {
                            return record.displayString
                        }
                        
                        if let teamId = Int(managerID),
                           let record = fantasyViewModel?.espnTeamRecords[teamId] {
                            return record.displayString
                        }
                        
                        if let record = fantasyViewModel?.getManagerRecord(managerID: managerID), !record.isEmpty {
                            return record
                        }
                        
                        return "N/A"
                    }()
                    Text(awayRecordText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                    
                    // Smaller Avatar with border
                    ZStack {
                        if let url = matchup.awayTeam.avatarURL {
                            AsyncTeamAvatarView(
                                url: url,
                                size: 32,
                                fallbackInitials: getInitials(from: matchup.awayTeam.ownerName)
                            )
                        } else {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.6), Color.red.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(getInitials(from: matchup.awayTeam.ownerName))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        if awayTeamIsWinning {
                            Circle()
                                .strokeBorder(Color.gpGreen, lineWidth: 2)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
                
                // SCORE
                Text(String(format: "%.2f", matchup.awayTeam.currentScore ?? 0.0))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                
                // Projected scores thermometer (if loaded)
                if projectionsLoaded && homeProjected > 0 && awayProjected > 0 {
                    projectedThermometerView(
                        myProjected: awayProjected,
                        opponentProjected: homeProjected,
                        isHomeTeam: false
                    )
                    .padding(.vertical, 4)
                }
                
                // Yet to play - larger number with projected points
                VStack(spacing: 2) {
                    Text("Yet to play:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("\(awayTeamYetToPlay)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(awayTeamIsWinning ? .gpGreen : .red)
                        
                        if awayYetToPlayProjected > 0 {
                            Text("~ +\(String(format: "%.1f", awayYetToPlayProjected))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gpGreen.opacity(0.8))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            await loadProjectedScores()
        }
    }
    
    // MARK: - Enhanced Controls Section
    
    private var enhancedControlsSection: some View {
        HStack(spacing: 12) {
            // Sort Method with conditional arrow
            HStack(spacing: 6) {
                // Sort Method Menu
                Menu {
                    ForEach(MatchupSortingMethod.allCases) { method in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onSortingMethodChanged(method)
                            }
                        }) {
                            HStack {
                                Text(method.displayName)
                                if sortingMethod == method {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text(sortingMethod.displayName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        
                        Text("Sort By")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                // Sort Direction Arrow (only show for Score)
                if sortingMethod == .score {
                    Button(action: {
                        onSortDirectionChanged()
                    }) {
                        Image(systemName: sortHighToLow ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gpGreen)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            // Position filter with picker
            Menu {
                ForEach(FantasyPosition.allCases) { position in
                    Button(action: {
                        selectedPosition = position
                    }) {
                        HStack {
                            Text(position.displayName)
                            if selectedPosition == position {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    Text(selectedPosition.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(selectedPosition == .all ? .gpBlue : .purple)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Position")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            Spacer()
            
            // Active Only toggle
            Button(action: {
                showActiveOnly.toggle()
            }) {
                VStack(spacing: 1) {
                    Text(showActiveOnly ? "Yes" : "No")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(showActiveOnly ? .gpGreen : .gpRedPink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Active Only")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Yet to Play toggle
            Button(action: {
                showYetToPlayOnly.toggle()
            }) {
                VStack(spacing: 1) {
                    Text(showYetToPlayOnly ? "Only" : "All")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(showYetToPlayOnly ? .gpYellow : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text("Yet to Play")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 60)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: {
                showingWatchedPlayers = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gpYellow)
                    
                    // Red circle badge if there are watched players
                    if watchService.watchedPlayers.count > 0 {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 14, height: 14)
                            
                            Text("\(watchService.watchedPlayers.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Computed Properties (Data Only)
    
    /// Calculate number of players yet to play for home team
    private var homeTeamYetToPlay: Int {
        matchup.homeTeam.playersYetToPlay(gameStatusService: gameStatusService ?? GameStatusService.shared)
    }
    
    /// Calculate number of players yet to play for away team
    private var awayTeamYetToPlay: Int {
        matchup.awayTeam.playersYetToPlay(gameStatusService: gameStatusService ?? GameStatusService.shared)
    }
    
    // MARK: - Helper Methods
    
    /// Projected thermometer view
    private func projectedThermometerView(myProjected: Double, opponentProjected: Double, isHomeTeam: Bool) -> some View {
        // Use SSOT: Always get the win probability from actual engine (via a correctly constructed UnifiedMatchup)
        // If detail screen doesn't already have a UnifiedMatchup, create a local one for this matchup

        // Minimal league struct to satisfy required fields. Replace with real league object whenever possible.
        let fakeSleeperLeague = SleeperLeague(
            leagueID: "detail",
            name: leagueName,
            status: .inSeason,
            sport: "nfl",
            season: Calendar.current.component(.year, from: Date()).description,
            seasonType: "regular",
            totalRosters: 0,
            draftID: nil,
            avatar: nil,
            settings: nil,
            scoringSettings: nil,
            rosterPositions: nil
        )

        let leagueWrapper = UnifiedLeagueManager.LeagueWrapper(
            id: "detail",
            league: fakeSleeperLeague,
            source: .sleeper, // or .espn if you wish
            client: SleeperAPIClient()
        )

        let matchupForProb = UnifiedMatchup(
            id: matchup.id,
            league: leagueWrapper,
            fantasyMatchup: matchup,
            choppedSummary: nil,
            lastUpdated: Date(),
            myTeamRanking: nil,
            myIdentifiedTeamID: isHomeTeam ? matchup.homeTeam.id : matchup.awayTeam.id,
            authenticatedUsername: "",
            allLeagueMatchups: nil
        )

        // Use actual probability
        let winProb: Double = matchupForProb.myWinProbability ?? 0.5
        let isWinning: Bool = winProb >= 0.5

        return VStack(spacing: 2) {
            // Thermometer bar with win %
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    // Filled portion from win probability, not projections
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isWinning ? Color.gpGreen : Color.gpRedPink,
                                    isWinning ? Color.gpGreen.opacity(0.7) : Color.gpRedPink.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(winProb), height: 6)

                    // Win probability percent in center (integer, SSOT)
                    HStack {
                        Spacer()
                        Text("\(Int(winProb * 100))%")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 0)
                        Spacer()
                    }
                }
            }
            .frame(height: 6)

            // Show actual score, not projections, under bar
            Text(String(format: "%.1f", isHomeTeam ? (matchup.homeTeam.currentScore ?? 0) : (matchup.awayTeam.currentScore ?? 0)))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isWinning ? .gpGreen : .gpRedPink)
        }
        .frame(width: 100)
    }
    
    private func loadProjectedScores() async {
        let projections = await ProjectedPointsManager.shared.getProjectedTeamScore(for: matchup.homeTeam)
        let awayProjections = await ProjectedPointsManager.shared.getProjectedTeamScore(for: matchup.awayTeam)
        
        // Calculate "yet to play" projected points
        let homeYetToPlayProj = await calculateYetToPlayProjected(for: matchup.homeTeam)
        let awayYetToPlayProj = await calculateYetToPlayProjected(for: matchup.awayTeam)
        
        await MainActor.run {
            self.homeProjected = projections
            self.awayProjected = awayProjections
            self.homeYetToPlayProjected = homeYetToPlayProj
            self.awayYetToPlayProjected = awayYetToPlayProj
            self.projectionsLoaded = true
        }
    }
    
    /// Calculate sum of projected points for players yet to play
    private func calculateYetToPlayProjected(for team: FantasyTeam) async -> Double {
        var total: Double = 0.0
        
        let gameStatusService = self.gameStatusService ?? GameStatusService.shared
        
        for player in team.roster {
            // Only count starters who are yet to play
            guard player.isStarter else { continue }
            
            // Check if player is yet to play using GameStatusService
            let isYetToPlay = gameStatusService.isPlayerYetToPlay(
                playerTeam: player.team,
                currentPoints: player.currentPoints
            )
            
            if isYetToPlay {
                // Get projected points for this player
                if let projection = await ProjectedPointsManager.shared.getProjectedPoints(for: player) {
                    total += projection
                }
            }
        }
        
        return total
    }
    
    /// Get initials from manager name for avatar fallback
    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
}