//
//  NFLScheduleView.swift
//  BigWarRoom
//
//  NFL Schedule view matching FOX NFL graphics style
//
// MARK: -> NFL Schedule Main View

import SwiftUI

struct NFLScheduleView: View {
    @State private var viewModel: NFLScheduleViewModel?
    @State private var matchupsHubViewModel = MatchupsHubViewModel.shared
    @State private var showingWeekPicker = false
    @State private var showingTeamMatchups = false
    @State private var selectedGame: ScheduleGame?
    @State private var navigationPath = NavigationPath()
    @State private var standingsService = NFLStandingsService.shared
    
    // Keep legend pills same width so the explanation text aligns
    private let legendPillWidth: CGFloat = 78
    
    // 🔥 NEW: Add UnifiedLeagueManager for bye week impact analysis
    @State private var unifiedLeagueManager: UnifiedLeagueManager?
    
    // 🔥 Collapsible sections - all collapsed by default
    @State private var expandedDays: Set<String> = []
    @State private var expandedTimeSlots: Set<String> = []
    
    // 🔥 Card style toggle - compact vs full (default to COMPACT)
    @AppStorage("ScheduleCardStyleCompact") private var useCompactCards: Bool = true
    
    // 🔥 SIMPLIFIED: No params needed, use .shared internally
    init() {}
    
    var body: some View {
        ZStack {
            // FOX-style background
            foxStyleBackground
                .ignoresSafeArea()
            
            if let viewModel = viewModel {
                VStack(spacing: 0) {
                    // Header Section
                    scheduleHeader(viewModel: viewModel)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    
                    // Games List
                    gamesList(viewModel: viewModel)
                }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        // 🔥 CREATE ViewModel with .shared services
                        viewModel = NFLScheduleViewModel(
                            gameDataService: NFLGameDataService.shared,
                            weekService: NFLWeekService.shared
                        )
                        
                        // 🔥 CREATE UnifiedLeagueManager with proper ESPN credentials
                        unifiedLeagueManager = UnifiedLeagueManager(
                            sleeperClient: SleeperAPIClient(),
                            espnClient: ESPNAPIClient(credentialsManager: ESPNCredentialsManager.shared),
                            espnCredentials: ESPNCredentialsManager.shared
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
            WeekPickerView(weekManager: WeekSelectionManager.shared, isPresented: $showingWeekPicker)
        }
        // Sync with shared week manager
        .onChange(of: WeekSelectionManager.shared.selectedWeek) { _, newWeek in
            DebugPrint(mode: .weekCheck, "📅 NFLScheduleView: WeekSelectionManager changed to week \(newWeek), updating view model")
            viewModel?.selectWeek(newWeek)
        }
        .onAppear {
            print("🔍 SCHEDULE DEBUG: NFLScheduleView appeared")
            
            DebugPrint(mode: .weekCheck, "📅 NFLScheduleView: Syncing to WeekSelectionManager week \(WeekSelectionManager.shared.selectedWeek)")
            
            // Sync initial week
            viewModel?.selectWeek(WeekSelectionManager.shared.selectedWeek)
            
            // Start global auto-refresh for live scores
            viewModel?.refreshSchedule() // Initial load only
        }
    }
    
    // MARK: -> FOX Style Background
    private var foxStyleBackground: some View {
        // Use BG3 asset with reduced opacity
        Image("BG3")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.35)
            .ignoresSafeArea(.all)
    }
    
    // MARK: -> Header Section
    private func scheduleHeader(viewModel: NFLScheduleViewModel) -> some View {
        VStack(spacing: 8) {
            // Week picker - using reusable TheWeekPicker component
            TheWeekPicker(showingWeekPicker: $showingWeekPicker)
            
            // Week starting date + Card style toggle
            HStack {
                // Week starting date with calendar icon
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
                
                // Card style toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        useCompactCards.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: useCompactCards ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.system(size: 11, weight: .semibold))
                        Text(useCompactCards ? "Compact" : "Full")
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
            
            // Live indicator (only show if live games)
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
                gamesScrollView(viewModel: viewModel)
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
    
    // MARK: -> Games Scroll View
    private func gamesScrollView(viewModel: NFLScheduleViewModel) -> some View {
        let groupedByDay = groupGamesByDay(viewModel.games)
        let sortedDays = groupedByDay.keys.sorted { day1, day2 in
            guard let game1 = groupedByDay[day1]?.values.flatMap({ $0 }).first?.startDate,
                  let game2 = groupedByDay[day2]?.values.flatMap({ $0 }).first?.startDate else { return false }
            return game1 < game2
        }
        
        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
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
                    // Expand first day initially (if nothing is expanded yet)
                    if expandedDays.isEmpty, let firstDay = sortedDays.first {
                        expandedDays.insert(firstDay)
                        // Also expand all time slots in the first day
                        if let timeSlots = groupedByDay[firstDay] {
                            for time in timeSlots.keys {
                                expandedTimeSlots.insert("\(firstDay)_\(time)")
                            }
                        }
                    }
                }
                
                // BYE Week Section
                if let manager = unifiedLeagueManager, !viewModel.byeWeekTeams.isEmpty {
                    ScheduleByeWeekSection(
                        byeTeams: viewModel.byeWeekTeams,
                        unifiedLeagueManager: manager,
                        matchupsHubViewModel: matchupsHubViewModel
                    )
                    .padding(.top, 12)
                }
                
                // FULL SLATE banner + key
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
        dayFormatter.dateFormat = "EEEE" // e.g., "Sunday"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a" // e.g., "1:00 PM"
        
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
        // Check if day has any LIVE games (not just completed)
        let allGamesInDay = timeSlots.values.flatMap { $0 }
        let hasLiveGames = allGamesInDay.contains { $0.isLive }
        
        // Only force-expand if there are LIVE games
        let isDayExpanded = hasLiveGames || expandedDays.contains(day)
        let totalGames = allGamesInDay.count
        
        // Sort time slots by actual time
        let sortedTimeSlots = timeSlots.keys.sorted { time1, time2 in
            guard let game1 = timeSlots[time1]?.first?.startDate,
                  let game2 = timeSlots[time2]?.first?.startDate else { return false }
            return game1 < game2
        }
        
        return VStack(spacing: 0) {
            // Day Header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedDays.contains(day) {
                        expandedDays.remove(day)
                        // Also collapse all time slots in this day
                        for time in sortedTimeSlots {
                            expandedTimeSlots.remove("\(day)_\(time)")
                        }
                    } else {
                        expandedDays.insert(day)
                        // Also expand all time slots in this day
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
            
            // Time Slots (if day is expanded)
            if isDayExpanded {
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.gpGreen.opacity(0.5), Color.gpGreen.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 12)
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
            // Chevron with gradient
            Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    hasLiveGames 
                        ? LinearGradient(colors: [.red, .red.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.gpGreen, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            // Day name
            Text(day.uppercased())
                .font(.system(size: 18, weight: .black, design: .default))
                .foregroundColor(.white)
                .kerning(2.0)
            
            // Live indicator
            if hasLiveGames {
                Text("LIVE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red))
            }
            
            Spacer()
            
            // Game count badge - styled like Week 17 picker
            Text("\(gameCount)")
                .font(.custom("BebasNeue-Regular", size: 22))
                .foregroundColor(.white)
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gpGreen.opacity(0.8), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.gpGreen.opacity(0.6), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
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
        )
        .overlay(
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
        )
        .shadow(color: Color.gpGreen.opacity(0.2), radius: 8, x: 0, y: 4)
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
        
        // Only force-expand if there are LIVE games
        let isExpanded = hasLiveGames || expandedTimeSlots.contains(slotKey)
        
        return VStack(spacing: 0) {
            // Time Header
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
            
            // Games (if expanded) - indented narrower than header
            if isExpanded {
                VStack(spacing: useCompactCards ? 6 : 10) {
                    ForEach(games, id: \.id) { game in
                        NavigationLink(destination: TeamFilteredMatchupsView(
                            awayTeam: game.awayTeam,
                            homeTeam: game.homeTeam,
                            matchupsHubViewModel: matchupsHubViewModel,
                            gameData: game
                        )) {
                            if useCompactCards {
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
                .padding(.horizontal, useCompactCards ? 20 : 12) // Less indent for full cards
                .padding(.top, 8)
                .padding(.bottom, 10)
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
            // Chevron with gradient
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(
                    hasLiveGames
                        ? LinearGradient(colors: [.red, .red.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.gpGreen, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 14)
            
            // Time text - larger
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            // Live indicator
            if hasLiveGames {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }
            
            Text("•")
                .foregroundColor(.white.opacity(0.4))
            
            Text("\(gameCount) game\(gameCount == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            // Mini odds preview (when collapsed)
            if !isExpanded {
                miniOddsPreview(games: games, viewModel: viewModel)
            }
            
            // Day name on trailing - same size as time, so when scrolled you know the day
            Text(day.uppercased())
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
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
        )
        .overlay(
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
        )
        .shadow(color: Color.gpGreen.opacity(0.15), radius: 6, x: 0, y: 3)
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
                    
                    Text("All 32 teams are active in Week \(WeekSelectionManager.shared.selectedWeek).")
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
            // Playoff Status Section - styled like FULL SLATE
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
            
            // Sportsbook Legend Section - styled like FULL SLATE
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
        .padding(.horizontal, 20)
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
            // Row 1: DK, FD, MGM, CZR
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
            
            // Row 2: PB, BR, PIN, Best
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
            
//            Text(":")
//                .font(.system(size: 11, weight: .bold))
//                .foregroundColor(.white.opacity(0.85))
            
            Text(text)
                .font(.system(size: 11, weight: .medium)) // bump 1 step
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
        // Show the key only when at least one team on this week's slate is clinched or eliminated.
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
        
        // NFL season start date - Week 1 starts first Thursday of September
        // 2024 season: September 5, 2024
        // 2025 season: September 4, 2025
        let seasonStartDate: Date
        if selectedYear == 2025 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2025, month: 9, day: 4))!
        } else if selectedYear == 2024 {
            seasonStartDate = calendar.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        } else {
            // Fallback: estimate first Thursday of September for any year
            var components = DateComponents(year: selectedYear, month: 9, day: 1)
            var startDate = calendar.date(from: components)!
            // Find first Thursday (weekday 5)
            while calendar.component(.weekday, from: startDate) != 5 {
                startDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
            }
            seasonStartDate = startDate
        }
        
        // Calculate the start date for the selected week
        let weekStartDate = calendar.date(byAdding: .day, value: (WeekSelectionManager.shared.selectedWeek - 1) * 7, to: seasonStartDate)!
        
        // Format as "Thursday, Dec 5"
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: weekStartDate)
    }
}

#Preview("NFL Schedule") {
    NFLScheduleView()
        .preferredColorScheme(.dark)
}
