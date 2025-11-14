//
//  LineupRXView.swift
//  BigWarRoom
//
//  💊 Lineup RX - AI-powered lineup optimization and waiver recommendations
//

import SwiftUI

struct LineupRXView: View {
    let matchup: UnifiedMatchup
    
    @Environment(\.dismiss) private var dismiss
    @State private var isInitialLoad = true // 🔥 NEW: Track first load vs refresh
    @State private var isLoading = false // 🔥 CHANGED: Don't start as true
    @State private var optimizationResult: LineupOptimizerService.OptimizationResult?
    @State private var waiverRecommendations: [LineupOptimizerService.WaiverRecommendation] = []
    @State private var errorMessage: String?
    @State private var showingWeekPicker = false
    @State private var currentWeek: Int = WeekSelectionManager.shared.selectedWeek
    
    // 🔥 NEW: View owns its own optimizer instance - NO SINGLETON
    @State private var optimizer = LineupOptimizerService()
    
    // Performance caches
    @State private var sleeperPlayerCache: [String: SleeperPlayer] = [:]
    @State private var matchupInfoCache: [String: MatchupInfo] = [:]
    @State private var groupedWaivers: [WaiverGroup] = []
    @State private var changeInfoCache: [String: (isChanged: Bool, improvement: Double?)] = [:]
    @State private var gameTimeCache: [String: String] = [:]
    @State private var alertsCache: [PlayerAlert] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Image("BG7")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: 20, pinnedViews: []) {
                        // Header
                        headerSection
                        
                        if let error = errorMessage {
                            errorView(error)
                        } else if optimizationResult == nil && isInitialLoad {
                            // 🔥 SKELETON SCREEN: Show immediately on first load
                            skeletonLoadingView
                        } else {
                            // Content sections - ALL EXTERNAL VIEWS NOW
                            if let result = optimizationResult {
                                CurrentLineupAnalysisView(result: result)
                                    .id("analysis")
                                
                                if !result.changes.isEmpty {
                                    RecommendedChangesView(
                                        result: result,
                                        sleeperPlayerCache: sleeperPlayerCache,
                                        matchupInfoCache: matchupInfoCache,
                                        gameTimeCache: gameTimeCache
                                    )
                                    .id("changes")
                                    
                                    MoveInstructionsView(result: result)
                                        .id("instructions")
                                }
                                
                                ByeWeekAlertsView(alerts: alertsCache)
                                    .id("bye")
                                
                                if !waiverRecommendations.isEmpty {
                                    WaiverWireView(
                                        groupedWaivers: groupedWaivers,
                                        sleeperPlayerCache: sleeperPlayerCache,
                                        matchupInfoCache: matchupInfoCache,
                                        gameTimeCache: gameTimeCache
                                    )
                                    .id("waiver")
                                }
                                
                                OptimalLineupView(
                                    result: result,
                                    sleeperPlayerCache: sleeperPlayerCache,
                                    changeInfoCache: changeInfoCache
                                )
                                .id("optimal")
                            }
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.visible)
            }
            .navigationTitle("Lineup RX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await loadData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.gpBlue)
                    }
                }
            }
            .onAppear {
                currentWeek = WeekSelectionManager.shared.selectedWeek
                Task {
                    await loadData()
                }
            }
        }
        .fullScreenCover(isPresented: $showingWeekPicker) {
            WeekPickerView(
                weekManager: WeekSelectionManager.shared,
                isPresented: $showingWeekPicker
            )
        }
        .onChange(of: showingWeekPicker) { oldValue, newValue in
            if !newValue && currentWeek != WeekSelectionManager.shared.selectedWeek {
                currentWeek = WeekSelectionManager.shared.selectedWeek
                Task {
                    await loadData()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // 🔥 NEW: Platform logo indicator
                if matchup.league.source == .espn {
                    AppConstants.espnLogo
                        .frame(width: 24, height: 24)
                } else {
                    AppConstants.sleeperLogo
                        .frame(width: 24, height: 24)
                }
                
                Text(matchup.league.league.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingWeekPicker = true
                }) {
                    HStack(spacing: 6) {
                        Text("WEEK \(currentWeek)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gpBlue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpBlue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gpBlue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gpBlue.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
            }
            
            if let myTeam = matchup.myTeam {
                HStack {
                    if let avatarURL = myTeam.avatarURL {
                        AsyncImage(url: avatarURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Circle()
                                    .fill(Color.gpBlue.opacity(0.3))
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(myTeam.ownerName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let record = myTeam.record?.displayString {
                            Text("Record: \(record)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Loading & Error Views
    
    // 🔥 NEW: Skeleton loading screen (way better UX than spinner)
    private var skeletonLoadingView: some View {
        VStack(spacing: 16) {
            // Skeleton cards with shimmer effect
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: isLoading ? 300 : -300)
                            .animation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isLoading
                            )
                    )
            }
            
            Text("Analyzing lineup and fetching projections...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 8)
        }
        .onAppear {
            isLoading = true
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gpBlue))
                .scaleEffect(1.5)
            
            Text("Analyzing your lineup...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("Fetching projections and optimizing...")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.gpRedPink)
            
            Text("Error")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpRedPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Types
    
    struct MatchupInfo {
        let opponent: String
        let opponentTeam: String
        let isHome: Bool
        let oprk: Int?
    }
    
    // MARK: - Cache Population
    
    private func populateCaches(result: LineupOptimizerService.OptimizationResult) {
        // Populate sleeper player cache for roster players
        if let myTeam = matchup.myTeam {
            for player in myTeam.roster {
                if let sleeperID = player.sleeperID,
                   let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID) {
                    sleeperPlayerCache[sleeperID] = sleeperPlayer
                }
            }
        }
        
        // Cache waiver wire players
        for rec in waiverRecommendations {
            let playerID = rec.playerToAdd.playerID
            if sleeperPlayerCache[playerID] == nil,
               let sleeperPlayer = PlayerDirectoryStore.shared.player(for: playerID) {
                sleeperPlayerCache[playerID] = sleeperPlayer
            }
        }
        
        // Populate matchup info cache
        if let myTeam = matchup.myTeam {
            for player in myTeam.roster {
                guard let team = player.team else { continue }
                let cacheKey = "\(team)_\(player.position)"
                
                if matchupInfoCache[cacheKey] == nil {
                    if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
                        let isHome = gameInfo.homeTeam == team
                        let opponent = isHome ? "vs \(gameInfo.awayTeam)" : "@ \(gameInfo.homeTeam)"
                        let opponentTeam = isHome ? gameInfo.awayTeam : gameInfo.homeTeam
                        let oprk = OPRKService.shared.getOPRK(forTeam: opponentTeam, position: player.position)
                        
                        matchupInfoCache[cacheKey] = MatchupInfo(
                            opponent: opponent,
                            opponentTeam: opponentTeam,
                            isHome: isHome,
                            oprk: oprk
                        )
                        
                        if gameTimeCache[team] == nil {
                            gameTimeCache[team] = gameInfo.formattedGameTime
                        }
                    }
                }
            }
        }
        
        // Populate change info cache
        for change in result.changes {
            let cacheKey = "\(change.playerIn.id)_\(change.position)"
            changeInfoCache[cacheKey] = (true, change.improvement)
        }
        
        // Populate alerts cache
        alertsCache = getByeWeekAndInjuryAlerts()
    }
    
    private func getByeWeekAndInjuryAlerts() -> [PlayerAlert] {
        guard let myTeam = matchup.myTeam else { return [] }
        
        var alerts: [PlayerAlert] = []
        
        let benchSlots = ["BENCH", "BN", "IR"]
        let starters = myTeam.roster.filter { player in
            guard let slot = player.lineupSlot else { return false }
            return !benchSlots.contains(slot)
        }
        
        for player in starters {
            var isOnBye = false
            
            if let sleeperID = player.sleeperID,
               let sleeperPlayer = sleeperPlayerCache[sleeperID],
               let status = sleeperPlayer.injuryStatus?.uppercased(),
               status == "BYE" {
                isOnBye = true
            }
            
            if !isOnBye, let team = player.team {
                if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
                    if gameInfo.gameStatus.lowercased() == "bye" {
                        isOnBye = true
                    }
                } else {
                    let realNFLTeams = ["ARI", "ATL", "BAL", "BUF", "CAR", "CHI", "CIN", "CLE", "DAL", "DEN",
                                       "DET", "GB", "HOU", "IND", "JAX", "KC", "LAC", "LAR", "LV", "MIA",
                                       "MIN", "NE", "NO", "NYG", "NYJ", "PHI", "PIT", "SEA", "SF", "TB",
                                       "TEN", "WAS", "WSH"]
                    if realNFLTeams.contains(team.uppercased()) {
                        isOnBye = true
                    }
                }
            }
            
            if isOnBye {
                alerts.append(PlayerAlert(
                    player: player,
                    type: .bye,
                    message: "*BYE*"
                ))
                continue
            }
            
            if let sleeperID = player.sleeperID,
               let sleeperPlayer = sleeperPlayerCache[sleeperID],
               let status = sleeperPlayer.injuryStatus?.uppercased(),
               ["Q", "D", "O", "IR", "OUT", "DOUBTFUL", "QUESTIONABLE"].contains(status) {
                alerts.append(PlayerAlert(
                    player: player,
                    type: .injury,
                    message: status
                ))
            }
        }
        
        return alerts
    }
    
    private func groupWaiverRecommendations() {
        var groups: [String: WaiverGroup] = [:]
        
        for rec in waiverRecommendations {
            let dropID = rec.playerToDrop.id
            let improvement = rec.playerToAdd.projectedPoints - rec.projectedPointsDrop
            
            if var existing = groups[dropID] {
                existing.addOptions.append(WaiverAddOption(
                    playerID: rec.playerToAdd.playerID,
                    name: rec.playerToAdd.name,
                    position: rec.playerToAdd.position,
                    team: rec.playerToAdd.team,
                    projectedPoints: rec.playerToAdd.projectedPoints,
                    reason: rec.reason,
                    improvement: improvement
                ))
                groups[dropID] = existing
            } else {
                groups[dropID] = WaiverGroup(
                    dropPlayer: rec.playerToDrop,
                    dropProjectedPoints: rec.projectedPointsDrop,
                    addOptions: [WaiverAddOption(
                        playerID: rec.playerToAdd.playerID,
                        name: rec.playerToAdd.name,
                        position: rec.playerToAdd.position,
                        team: rec.playerToAdd.team,
                        projectedPoints: rec.playerToAdd.projectedPoints,
                        reason: rec.reason,
                        improvement: improvement
                    )]
                )
            }
        }
        
        groupedWaivers = Array(groups.values).sorted { $0.dropPlayer.fullName < $1.dropPlayer.fullName }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        // 🔥 DON'T show loading spinner - use skeleton instead
        errorMessage = nil
        
        sleeperPlayerCache.removeAll()
        matchupInfoCache.removeAll()
        changeInfoCache.removeAll()
        gameTimeCache.removeAll()
        alertsCache.removeAll()
        
        do {
            let week = WeekSelectionManager.shared.selectedWeek
            let year = SeasonYearManager.shared.selectedYear
            
            guard let myTeam = matchup.myTeam else {
                throw LineupRXError.noTeamData
            }
            
            let scoringFormat = "ppr"
            
            // 🔥 FAST PATH: Load lineup optimization
            let result = try await optimizer.optimizeLineup(
                for: matchup,
                week: week,
                year: year,
                scoringFormat: scoringFormat
            )
            
            optimizationResult = result
            populateCaches(result: result)
            
            // 🔥 SHOW DATA IMMEDIATELY
            isInitialLoad = false
            
            // 🔥 BACKGROUND: Load waiver recs without blocking
            Task.detached(priority: .userInitiated) { @MainActor in
                do {
                    let waiver = try await self.optimizer.getWaiverRecommendations(
                        for: self.matchup,
                        week: week,
                        year: year,
                        limit: 5,
                        scoringFormat: scoringFormat
                    )
                    
                    self.waiverRecommendations = waiver
                    self.groupWaiverRecommendations()
                } catch {
                    // Silently fail waiver recs
                    print("⚠️ Failed to load waiver recommendations: \(error)")
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
            isInitialLoad = false
        }
    }
    
    enum LineupRXError: Error, LocalizedError {
        case noTeamData
        
        var errorDescription: String? {
            switch self {
            case .noTeamData:
                return "No team data available for this matchup"
            }
        }
    }
}
