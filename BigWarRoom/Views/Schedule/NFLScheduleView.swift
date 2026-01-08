//  NFLScheduleView.swift
//  BigWarRoom
//
//  NFL Schedule view matching FOX NFL graphics style
//
// MARK: -> NFL Schedule Main View

import SwiftUI

struct NFLScheduleView: View {
    @State private var viewModel: NFLScheduleViewModel?
    @Environment(MatchupsHubViewModel.self) private var matchupsHubViewModel
    @Environment(WeekSelectionManager.self) private var weekSelectionManager
    @Environment(NFLStandingsService.self) private var standingsService
    @Environment(TeamAssetManager.self) private var teamAssetManager
    @Environment(NFLGameDataService.self) private var nflGameDataService
    @Environment(NFLWeekService.self) private var nflWeekService
    @Environment(ESPNCredentialsManager.self) private var espnCredentials
    @State private var showingWeekPicker = false
    @State private var showingTeamMatchups = false
    @State private var selectedGame: ScheduleGame?
    @State private var navigationPath = NavigationPath()
    
    // 🔥 NEW: Store SleeperAPIClient locally (not observable, so can't be @Environment)
    @State private var sleeperAPIClient: SleeperAPIClient?
    
    // 🏈 NEW: Playoff bracket service - use @State with explicit binding to observe changes
    @State private var playoffBracketService: NFLPlayoffBracketService?
    @State private var bracketLoaded = false  // 🔥 Re-add this to force UI updates!
    
    // Keep legend pills same width so the explanation text aligns
    private let legendPillWidth: CGFloat = 78
    
    // 🔥 NEW: Add UnifiedLeagueManager for bye week impact analysis
    @State private var unifiedLeagueManager: UnifiedLeagueManager?
    
    // 🔥 Collapsible sections - all collapsed by default
    @State private var expandedDays: Set<String> = []
    @State private var expandedTimeSlots: Set<String> = []
    @State private var morgInitialized: Bool = false  // Track if Morg mode was initialized
    
    // 🔥 Card style: 0 = Compact, 1 = Full, 2 = Classic, 3 = Morg (minimal headers)
    @AppStorage("ScheduleCardStyle") private var cardStyle: Int = 2
    
    private var cardStyleLabel: String {
        switch cardStyle {
        case 0: return "Compact"
        case 1: return "Full"
        case 2: return "Classic"
        case 3: return "Morg"
        default: return "Compact"
        }
    }
    
    private var cardStyleIcon: String {
        switch cardStyle {
        case 0: return "rectangle.compress.vertical"
        case 1: return "rectangle.expand.vertical"
        case 2: return "list.bullet"
        case 3: return "text.alignleft"
        default: return "rectangle.compress.vertical"
        }
    }
    
    // Whether to show minimal headers (no backgrounds/strokes)
    private var useMinimalHeaders: Bool {
        cardStyle == 3
    }
    
    // 🔥 SIMPLIFIED: No params needed, use @Environment services
    init() {}
    
    var body: some View {
        ZStack {
            // FOX-style background
            foxStyleBackground
                .ignoresSafeArea()
            
            if let viewModel = viewModel {
                // 🏈 NEW: Show playoff bracket for weeks > 18
                if weekSelectionManager.selectedWeek > 18 {
                    // 🔥 SIMPLIFIED: Check bracketLoaded flag instead of service state
                    if bracketLoaded, let service = playoffBracketService, service.currentBracket != nil {
                        playoffBracketContent
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading playoff bracket...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header Section
                        scheduleHeader(viewModel: viewModel)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                        
                        // Games List
                        gamesList(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView("Loading...")
                    .task {
                        // 🔥 CREATE services with injected dependencies
                        let sleeperAPI = SleeperAPIClient()
                        sleeperAPIClient = sleeperAPI
                        
                        viewModel = NFLScheduleViewModel(
                            gameDataService: nflGameDataService,
                            weekService: nflWeekService
                        )
                        
                        // 🔥 CREATE UnifiedLeagueManager with proper credentials
                        let espnAPIClient = ESPNAPIClient(credentialsManager: espnCredentials)
                        unifiedLeagueManager = UnifiedLeagueManager(
                            sleeperClient: sleeperAPI,
                            espnClient: espnAPIClient,
                            espnCredentials: espnCredentials
                        )
                    }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(
            get: { viewModel?.showingGameDetail ?? false },
            set: { if let vm = viewModel { vm.showingGameDetail = $0 } }
        )) {
            if let game = viewModel?.selectedGame {
                GameDetailView(game: game)
            }
        }
        // 🏈 NAVIGATION: Add destination handlers for Schedule tab - moved from AppEntryView
        .navigationDestination(for: String.self) { value in
            if value.hasPrefix("TEST_") {
                // Simple test view with no async operations
                VStack {
                    Text("TEST VIEW")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    Text("Team: \(String(value.dropFirst(5)))")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("If you can see this without bounce-back, navigation works!")
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Go Back") {
                        navigationPath.removeLast()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .navigationBarHidden(true)
            } else {
                EnhancedNFLTeamRosterView(teamCode: value)
            }
        }
        .navigationDestination(for: SleeperPlayer.self) { player in
            PlayerStatsCardView(
                player: player,
                team: NFLTeam.team(for: player.team ?? "")
            )
        }
        // 🏈 NAVIGATION FREEDOM: Remove sheet - using NavigationLink instead
        // BEFORE: .sheet(isPresented: $showingTeamMatchups) { TeamFilteredMatchupsView(...) }
        // AFTER: NavigationLinks in game cards handle navigation
        .sheet(isPresented: $showingWeekPicker) {
            WeekPickerView(
                weekManager: weekSelectionManager,
                yearManager: SeasonYearManager.shared,
                isPresented: $showingWeekPicker
            )
        }
        // Sync with shared week manager
        .onChange(of: weekSelectionManager.selectedWeek) { _, newWeek in
            DebugPrint(mode: .weekCheck, "📅 NFLScheduleView: WeekSelectionManager changed to week \(newWeek), updating view model")
            viewModel?.selectWeek(newWeek)
            
            // 🏈 NEW: Load playoff bracket if in playoffs
            ensurePlayoffServiceCreated()
            if newWeek > 18, let service = playoffBracketService {
                Task {
                    let season = Int(SeasonYearManager.shared.selectedYear) ?? AppConstants.currentSeasonYearInt
                    bracketLoaded = false  // 🔥 Reset flag before fetch
                    await service.fetchPlayoffBracket(for: season)
                    bracketLoaded = true   // 🔥 Set flag after fetch to trigger UI update
                }
            }
        }
        // 🔥 NEW: Also observe year changes to refresh playoff bracket
        .onChange(of: SeasonYearManager.shared.selectedYear) { oldYear, newYear in
            DebugPrint(mode: .weekCheck, "📅 NFLScheduleView: Year changed from \(oldYear) to \(newYear)")
            
            // Refresh schedule for new year
            viewModel?.refreshSchedule()
            
            // If we're viewing playoffs, refresh the bracket with new year
            if weekSelectionManager.selectedWeek > 18 {
                ensurePlayoffServiceCreated()
                if let service = playoffBracketService {
                    Task {
                        let season = Int(newYear) ?? AppConstants.currentSeasonYearInt
                        DebugPrint(mode: .appLoad, "📅 NFLScheduleView: Fetching playoff bracket for season \(season)")
                        bracketLoaded = false  // 🔥 Reset flag before fetch
                        await service.fetchPlayoffBracket(for: season, forceRefresh: true)
                        bracketLoaded = true   // 🔥 Set flag after fetch to trigger UI update
                    }
                }
            }
        }
        .onAppear {
            DebugPrint(mode: .appLoad, "📅 NFLScheduleView.onAppear - START at \(Date())")
            DebugPrint(mode: .weekCheck, "📅 NFLScheduleView: Syncing to WeekSelectionManager week \(weekSelectionManager.selectedWeek)")
            
            // Sync initial week
            viewModel?.selectWeek(weekSelectionManager.selectedWeek)
            
            // 🔥 ASYNC: Wrap heavy operations in Task to prevent blocking main thread
            Task {
                DebugPrint(mode: .appLoad, "📅 NFLScheduleView: Starting refreshSchedule at \(Date())")
                // Start global auto-refresh for live scores
                viewModel?.refreshSchedule() // Initial load only
                DebugPrint(mode: .appLoad, "📅 NFLScheduleView: refreshSchedule completed at \(Date())")
            }
            
            // 🏈 ASYNC: Create playoff service and load bracket if in playoffs
            Task {
                ensurePlayoffServiceCreated()
                if weekSelectionManager.selectedWeek > 18, let service = playoffBracketService {
                    DebugPrint(mode: .appLoad, "🏈 NFLScheduleView: Fetching playoff bracket (week > 18) at \(Date())")
                    let season = Int(SeasonYearManager.shared.selectedYear) ?? AppConstants.currentSeasonYearInt
                    await service.fetchPlayoffBracket(for: season)
                    bracketLoaded = true  // 🔥 Set flag after fetch completes
                    DebugPrint(mode: .appLoad, "🏈 NFLScheduleView: Playoff bracket fetch task completed at \(Date())")
                }
            }
        }
    }
    
    // 🏈 NEW: Create playoff service if needed
    private func ensurePlayoffServiceCreated() {
        guard playoffBracketService == nil else { return }
        
        playoffBracketService = NFLPlayoffBracketService(
            weekSelectionManager: weekSelectionManager,
            appLifecycleManager: AppLifecycleManager.shared
        )
    }
    
    // MARK: -> FOX Style Background
    private var foxStyleBackground: some View {
        Image("BG3")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.35)
            .ignoresSafeArea(.all)
    }
    
    // 🏈 NEW: Playoff Bracket Content
    @ViewBuilder
    private var playoffBracketContent: some View {
        if let service = playoffBracketService {
            ZStack(alignment: .top) {
                NFLPlayoffBracketView(
                    weekSelectionManager: weekSelectionManager,
                    appLifecycleManager: AppLifecycleManager.shared,
                    fantasyViewModel: nil,
                    initialSeason: Int(SeasonYearManager.shared.selectedYear),
                    bracketService: service  
                )
                
                playoffBracketHeader
                    .padding(.top, 12)
                    .zIndex(1) 
            }
        } else {
            ProgressView("Loading playoffs...")
        }
    }
    
    // 🏈 NEW: Playoff Bracket Header
    private var playoffBracketHeader: some View {
        VStack(spacing: 8) {
            TheWeekPicker(showingWeekPicker: $showingWeekPicker, weekManager: weekSelectionManager)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: -> Header Section
    private func scheduleHeader(viewModel: NFLScheduleViewModel) -> some View {
        VStack(spacing: 8) {
            TheWeekPicker(showingWeekPicker: $showingWeekPicker, weekManager: weekSelectionManager)
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(getWeekStartDate())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cardStyle = (cardStyle + 1) % 4
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: cardStyleIcon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(cardStyleLabel)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.gpGreen.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }
            
            if viewModel.games.contains(where: { $0.isLive }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                    
                    Text("LIVE GAMES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: -> Games List
    private func gamesList(viewModel: NFLScheduleViewModel) -> some View {
        Group {
            if viewModel.isLoading && viewModel.games.isEmpty {
                loadingView
            } else if viewModel.errorMessage?.isEmpty == false {
                errorView
            } else if viewModel.games.isEmpty {
                emptyStateView
            } else {
                if cardStyle == 2 {
                    classicFlatListView(viewModel: viewModel)
                } else {
                    gamesScrollView(viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: -> Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Loading schedule...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: -> Error View
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Unable to load schedule")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Scores will refresh automatically")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: -> Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No games scheduled")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: -> Classic Flat List View (original 12/25 layout - no grouping, no odds)
    private func classicFlatListView(viewModel: NFLScheduleViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.games, id: \.id) { game in
                    NavigationLink(destination: TeamFilteredMatchupsView(
                        awayTeam: game.awayTeam,
                        homeTeam: game.homeTeam,
                        matchupsHubViewModel: matchupsHubViewModel,
                        standingsService: standingsService,
                        gameData: game
                    )) {
                        ScheduleGameCard(
                            game: game,
                            odds: viewModel.gameOddsByGameID[game.id],  
                            action: {},
                            showDayTime: true
                        )
                        .frame(maxWidth: .infinity)
                        .frame(width: UIScreen.main.bounds.width * 0.92)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let manager = unifiedLeagueManager, !viewModel.byeWeekTeams.isEmpty {
                    ScheduleByeWeekSection(
                        byeTeams: viewModel.byeWeekTeams,
                        unifiedLeagueManager: manager,
                        matchupsHubViewModel: matchupsHubViewModel,
                        weekSelectionManager: weekSelectionManager,
                        standingsService: standingsService,
                        teamAssetManager: teamAssetManager
                    )
                    .padding(.top, 24)
                } else if viewModel.byeWeekTeams.isEmpty {
                    VStack(spacing: 10) {
                        noByeWeeksBanner
                        
                        if shouldShowPlayoffKey(for: viewModel) {
                            playoffStatusKey
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: -> Games Scroll View
    private func gamesScrollView(viewModel: NFLScheduleViewModel) -> some View {
        let groupedByDay = groupGamesByDay(viewModel.games)
        let sortedDays = groupedByDay.keys.sorted { day1, day2 in
            guard let game1 = groupedByDay[day1]?.values.flatMap({ $0 }).first?.startDate,
                  let game2 = groupedByDay[day2]?.values.flatMap({ $0 }).first?.startDate else { return false }
            return game1 < game2
        }
        
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: useMinimalHeaders ? 2 : 16) {
                ForEach(sortedDays, id: \.self) { day in
                    if let timeSlots = groupedByDay[day] {
                        daySectionView(
                            day: day,
                            timeSlots: timeSlots,
                            viewModel: viewModel
                        )
                    }
                }
                .onAppear {
                    if useMinimalHeaders && !morgInitialized {
                        morgInitialized = true
                        for day in sortedDays {
                            expandedDays.insert(day)
                            if let timeSlots = groupedByDay[day] {
                                for time in timeSlots.keys {
                                    expandedTimeSlots.insert("\(day)_\(time)")
                                }
                            }
                        }
                    } else if expandedDays.isEmpty, let firstDay = sortedDays.first {
                        expandedDays.insert(firstDay)
                        if let timeSlots = groupedByDay[firstDay] {
                            for time in timeSlots.keys {
                                expandedTimeSlots.insert("\(firstDay)_\(time)")
                            }
                        }
                    }
                }
                .onChange(of: cardStyle) { _, newStyle in
                    if newStyle == 3 {
                        for day in sortedDays {
                            expandedDays.insert(day)
                            if let timeSlots = groupedByDay[day] {
                                for time in timeSlots.keys {
                                    expandedTimeSlots.insert("\(day)_\(time)")
                                }
                            }
                        }
                    }
                }
                
                if let manager = unifiedLeagueManager, !viewModel.byeWeekTeams.isEmpty {
                    ScheduleByeWeekSection(
                        byeTeams: viewModel.byeWeekTeams,
                        unifiedLeagueManager: manager,
                        matchupsHubViewModel: matchupsHubViewModel,
                        weekSelectionManager: weekSelectionManager,
                        standingsService: standingsService,
                        teamAssetManager: teamAssetManager
                    )
                    .padding(.top, 12)
                }
                
                if viewModel.byeWeekTeams.isEmpty {
                    VStack(spacing: 10) {
                        noByeWeeksBanner
                        
                        if shouldShowPlayoffKey(for: viewModel) {
                            playoffStatusKey
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: -> Group Games by Day, then by Time
    private func groupGamesByDay(_ games: [ScheduleGame]) -> [String: [String: [ScheduleGame]]] {
        var grouped: [String: [String: [ScheduleGame]]] = [:]
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE" 
        
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a" 
        
        for game in games {
            let dayKey: String
            let timeKey: String
            
            if let date = game.startDate {
                dayKey = dayFormatter.string(from: date)
                timeKey = timeFormatter.string(from: date)
            } else {
                dayKey = game.dayName.isEmpty ? "TBD" : game.dayName
                timeKey = game.startTime.isEmpty ? "TBD" : game.startTime
            }
            
            if grouped[dayKey] == nil {
                grouped[dayKey] = [:]
            }
            if grouped[dayKey]?[timeKey] == nil {
                grouped[dayKey]?[timeKey] = []
            }
            grouped[dayKey]?[timeKey]?.append(game)
        }
        
        return grouped
    }
    
    // MARK: -> Day Section View
    private func daySectionView(
        day: String,
        timeSlots: [String: [ScheduleGame]],
        viewModel: NFLScheduleViewModel
    ) -> some View {
        let allGamesInDay = timeSlots.values.flatMap { $0 }
        let hasLiveGames = allGamesInDay.contains { $0.isLive }
        
        let isDayExpanded = hasLiveGames || expandedDays.contains(day)
        let totalGames = allGamesInDay.count
        
        let sortedTimeSlots = timeSlots.keys.sorted { time1, time2 in
            guard let game1 = timeSlots[time1]?.first?.startDate,
                  let game2 = timeSlots[time2]?.first?.startDate else { return false }
            return game1 < game2
        }
        
        let allGamesSorted = sortedTimeSlots.flatMap { timeSlots[$0] ?? [] }
        
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedDays.contains(day) {
                        expandedDays.remove(day)
                        for time in sortedTimeSlots {
                            expandedTimeSlots.remove("\(day)_\(time)")
                        }
                    } else {
                        if !useMinimalHeaders {
                            expandedDays.removeAll()
                            expandedTimeSlots.removeAll()
                        }
                        
                        expandedDays.insert(day)
                        for time in sortedTimeSlots {
                            expandedTimeSlots.insert("\(day)_\(time)")
                        }
                    }
                }
            } label: {
                dayHeader(
                    day: day,
                    gameCount: totalGames,
                    isExpanded: isDayExpanded,
                    isCollapsible: true,
                    hasLiveGames: hasLiveGames
                )
            }
            .buttonStyle(.plain)
            
            if isDayExpanded {
                if useMinimalHeaders {
                    VStack(spacing: 4) {
                        ForEach(allGamesSorted, id: \.id) { game in
                            NavigationLink(destination: TeamFilteredMatchupsView(
                                awayTeam: game.awayTeam,
                                homeTeam: game.homeTeam,
                                matchupsHubViewModel: matchupsHubViewModel,
                                standingsService: standingsService,
                                gameData: game
                            )) {
                                ScheduleGameCard(
                                    game: game,
                                    odds: viewModel.gameOddsByGameID[game.id],
                                    action: {},
                                    showStartTime: true  
                                )
                                .padding(.horizontal, 16)  
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(sortedTimeSlots, id: \.self) { time in
                            if let games = timeSlots[time] {
                                timeSlotSection(
                                    time: time,
                                    day: day,
                                    games: games,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.6))
                }
            }
        )
        .overlay(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.gpGreen.opacity(0.5), Color.gpGreen.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
        .padding(.horizontal, useMinimalHeaders ? 6 : 10)
    }
    
    // MARK: -> Day Header
    private func dayHeader(
        day: String,
        gameCount: Int,
        isExpanded: Bool,
        isCollapsible: Bool,
        hasLiveGames: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                .font(.system(size: useMinimalHeaders ? 16 : 20, weight: .bold))
                .foregroundStyle(
                    useMinimalHeaders
                        ? (hasLiveGames ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.white.opacity(0.7)))
                        : (hasLiveGames
                            ? AnyShapeStyle(LinearGradient(colors: [.red, .red.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [.gpGreen, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)))
                )
            
            Text(day.uppercased())
                .font(.system(size: useMinimalHeaders ? 16 : 18, weight: .black, design: .default))
                .foregroundColor(.white)
                .kerning(useMinimalHeaders ? 1.5 : 2.0)
            
            if hasLiveGames {
                Text("LIVE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Text("\(gameCount) game\(gameCount == 1 ? "" : "s")")
                .font(.system(size: useMinimalHeaders ? 14 : 11, weight: .medium))
                .foregroundColor(.white.opacity(useMinimalHeaders ? 0.5 : 0.6))
        }
        .padding(.horizontal, useMinimalHeaders ? 12 : 16)
        .padding(.vertical, useMinimalHeaders ? 8 : 14)
        .background(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gpGreen.opacity(0.3),
                                    Color.blue.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .overlay(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.gpGreen.opacity(0.6),
                                    Color.blue.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
        .shadow(color: useMinimalHeaders ? .clear : Color.gpGreen.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: -> Time Slot Section
    private func timeSlotSection(
        time: String,
        day: String,
        games: [ScheduleGame],
        viewModel: NFLScheduleViewModel
    ) -> some View {
        let slotKey = "\(day)_\(time)"
        let hasLiveGames = games.contains { $0.isLive }
        
        let isExpanded = hasLiveGames || expandedTimeSlots.contains(slotKey)
        
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedTimeSlots.contains(slotKey) {
                        expandedTimeSlots.remove(slotKey)
                    } else {
                        expandedTimeSlots.insert(slotKey)
                    }
                }
            } label: {
                timeSlotHeader(
                    time: time,
                    day: day,
                    gameCount: games.count,
                    isExpanded: isExpanded,
                    isCollapsible: true,
                    games: games,
                    viewModel: viewModel
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: useMinimalHeaders ? 4 : (cardStyle == 0 ? 6 : 10)) {
                    ForEach(games, id: \.id) { game in
                        NavigationLink(destination: TeamFilteredMatchupsView(
                            awayTeam: game.awayTeam,
                            homeTeam: game.homeTeam,
                            matchupsHubViewModel: matchupsHubViewModel,
                            standingsService: standingsService,
                            gameData: game
                        )) {
                            if cardStyle == 0 {
                                ScheduleGameCardCompact(
                                    game: game,
                                    odds: viewModel.gameOddsByGameID[game.id]
                                )
                            } else {
                                ScheduleGameCard(
                                    game: game,
                                    odds: viewModel.gameOddsByGameID[game.id],
                                    action: {}
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, useMinimalHeaders ? 0 : (cardStyle == 0 ? 12 : 8))
                .padding(.leading, useMinimalHeaders ? 16 : 0)
                .padding(.trailing, useMinimalHeaders ? 16 : 0)
                .padding(.top, useMinimalHeaders ? 0 : 8)
                .padding(.bottom, useMinimalHeaders ? 0 : 10)
            }
        }
    }
    
    // MARK: -> Time Slot Header
    private func timeSlotHeader(
        time: String,
        day: String,
        gameCount: Int,
        isExpanded: Bool,
        isCollapsible: Bool,
        games: [ScheduleGame],
        viewModel: NFLScheduleViewModel
    ) -> some View {
        let hasLiveGames = games.contains { $0.isLive }
        
        return HStack(spacing: 10) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: useMinimalHeaders ? 10 : 12, weight: .bold))
                .foregroundStyle(
                    useMinimalHeaders
                        ? (hasLiveGames ? AnyShapeStyle(Color.red) : AnyShapeStyle(Color.white.opacity(0.5)))
                        : (hasLiveGames
                            ? AnyShapeStyle(LinearGradient(colors: [.red, .red.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(LinearGradient(colors: [.gpGreen, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)))
                )
                .frame(width: 14)
            
            Text(time)
                .font(.system(size: useMinimalHeaders ? 14 : 16, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            if hasLiveGames {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
            
            Text("•")
                .foregroundColor(.white.opacity(0.4))
            
            Text("\(gameCount) game\(gameCount == 1 ? "" : "s")")
                .font(.system(size: useMinimalHeaders ? 10 : 11, weight: .medium))
                .foregroundColor(.white.opacity(useMinimalHeaders ? 0.4 : 0.6))
            
            Spacer()
            
            if !isExpanded {
                miniOddsPreview(games: games, viewModel: viewModel)
            }
            
            Text(day.uppercased())
                .font(.system(size: useMinimalHeaders ? 12 : 16, weight: .bold, design: .default))
                .foregroundColor(.white.opacity(useMinimalHeaders ? 0.4 : 0.7))
        }
        .padding(.horizontal, useMinimalHeaders ? 0 : 10)
        .padding(.vertical, useMinimalHeaders ? 6 : 10)
        .padding(.leading, useMinimalHeaders ? 12 : 0)
        .padding(.trailing, useMinimalHeaders ? 12 : 0)
        .background(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gpGreen.opacity(0.25),
                                    Color.blue.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .overlay(
            Group {
                if !useMinimalHeaders {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.gpGreen.opacity(0.5),
                                    Color.blue.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
        )
        .shadow(color: useMinimalHeaders ? .clear : Color.gpGreen.opacity(0.15), radius: 6, x: 0, y: 3)
    }
    
    // MARK: -> Mini Odds Preview (shown when collapsed)
    private func miniOddsPreview(games: [ScheduleGame], viewModel: NFLScheduleViewModel) -> some View {
        let previewGames = Array(games.prefix(3))
        
        return HStack(spacing: 4) {
            ForEach(previewGames, id: \.id) { game in
                if let odds = viewModel.gameOddsByGameID[game.id],
                   let team = odds.favoriteMoneylineTeamCode,
                   let ml = odds.favoriteMoneylineOdds {
                    HStack(spacing: 2) {
                        Text(team)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                        Text(ml)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.gpGreen)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            
            if games.count > 3 {
                Text("+\(games.count - 3)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
    
    // MARK: -> No Bye Weeks Banner
    private var noByeWeeksBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("FULL SLATE - NO BYES")
                        .font(.system(size: 14, weight: .black, design: .default))
                        .foregroundColor(.white)
                    
                    Text("All 32 teams are active in Week \(weekSelectionManager.selectedWeek).")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gpGreen.opacity(0.6), lineWidth: 1.5)
                    )
            )
        }
        .padding(.horizontal, 20)
    }
    
    private var playoffStatusKey: some View {
        VStack(spacing: 12) {
            playoffStatusSection
            
            if cardStyle != 2 {
                oddsSourceSection
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: -> Playoff Status Section (standalone)
    private var playoffStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("PLAYOFF STATUS")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .kerning(1.2)
                
                Spacer()
            }
            
            playoffStatusKeyExplanation
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpGreen.opacity(0.6), lineWidth: 1.5)
                )
        )
    }
    
    // MARK: -> Odds Source Section (standalone)
    private var oddsSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gpGreen)
                
                Text("ODDS SOURCE")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .kerning(1.2)
                
                Spacer()
            }
            
            sportsbookLegend
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gpGreen.opacity(0.6), lineWidth: 1.5)
                )
        )
    }
    
    private var playoffStatusKeyExplanation: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusExplainLine(code: "CLINCH", pillColor: .blue, text: "Clinched playoff berth")
            statusExplainLine(code: "HUNT", pillColor: .green, text: "Currently in a playoff spot (not clinched)")
            statusExplainLine(code: "BUBBLE", pillColor: .orange, text: "Outside the playoff spots, still alive")
            statusExplainLine(code: "OUT", pillColor: .red, text: "Eliminated from playoff contention")
        }
    }
    
    // MARK: -> Sportsbook Legend
    private var sportsbookLegend: some View {
        let row1: [Sportsbook] = [.draftkings, .fanduel, .betmgm, .caesars]
        let row2: [Sportsbook] = [.pointsbet, .betrivers, .pinnacle, .bestLine]
        
        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(row1) { book in
                    VStack(spacing: 3) {
                        SportsbookBadge(book: book, size: 11)
                        Text(book.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(row2) { book in
                    VStack(spacing: 3) {
                        SportsbookBadge(book: book, size: 11)
                        Text(book.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func statusExplainLine(code: String, pillColor: Color, text: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            statusKeyPill(text: code, color: pillColor)
                .frame(width: legendPillWidth, alignment: .center)
            
            Text(text)
                .font(.system(size: 11, weight: .medium)) 
                .foregroundColor(.white.opacity(0.75))
        }
    }
    
    private func statusKeyPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundColor(.white)
            .kerning(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.85))
            )
    }
    
    private func shouldShowPlayoffKey(for viewModel: NFLScheduleViewModel) -> Bool {
        let teamCodes = Set(viewModel.games.flatMap { [$0.awayTeam, $0.homeTeam] })
        for code in teamCodes {
            let status = standingsService.getPlayoffStatus(for: code)
            if status == .clinched || status == .eliminated {
                return true
            }
        }
        return false
    }
    
    // MARK: - Helper function to get week start date
    private func getWeekStartDate() -> String {
        let calendar = Calendar.current
        let selectedYearString = SeasonYearManager.shared.selectedYear
        let selectedYear = Int(selectedYearString) ?? 2025
        
        let seasonStartDate: Date
        if selectedYear == 2025 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 4))!
        } else if selectedYear == 2024 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        } else {
            var components = DateComponents(year: selectedYear, month: 9, day: 1)
            var startDate = calendar.date(from: components)!
            while calendar.component(.weekday, from: startDate) != 5 {
                startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            }
            seasonStartDate = startDate
        }
        
        let weekStartDate = calendar.date(byAdding: .day, value: (weekSelectionManager.selectedWeek - 1) * 7, to: seasonStartDate)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: weekStartDate)
    }
}

#Preview("NFL Schedule") {
    NFLScheduleView()
        .preferredColorScheme(.dark)
}