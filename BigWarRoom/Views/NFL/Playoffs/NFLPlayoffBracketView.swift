//
//  NFLPlayoffBracketView.swift
//  BigWarRoom
//
//  ESPN-style playoff bracket with blue gradient and bracket lines
//

import SwiftUI

struct NFLPlayoffBracketView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(NFLStandingsService.self) private var standingsService
    @Environment(BettingOddsService.self) private var bettingOddsService
    @State private var bracketService: NFLPlayoffBracketService?
    @State private var selectedSeason: Int
    
    // 🔥 FIX: Observe the year manager
    @State private var yearManager = SeasonYearManager.shared
    
    // 🔥 NEW: Add refresh timer state
    @State private var refreshTimer: Timer?
    
    // 🔥 NEW: Track device orientation for iPad
    @State private var isLandscape: Bool = false
    
    // Dependencies
    let weekSelectionManager: WeekSelectionManager
    let appLifecycleManager: AppLifecycleManager
    let fantasyViewModel: FantasyViewModel?
    
    init(
        weekSelectionManager: WeekSelectionManager,
        appLifecycleManager: AppLifecycleManager,
        fantasyViewModel: FantasyViewModel? = nil,
        initialSeason: Int? = nil,
        bracketService: NFLPlayoffBracketService? = nil
    ) {
        self.weekSelectionManager = weekSelectionManager
        self.appLifecycleManager = appLifecycleManager
        self.fantasyViewModel = fantasyViewModel
        
        _bracketService = State(initialValue: bracketService)
        _selectedSeason = State(initialValue: initialSeason ?? AppConstants.currentSeasonYearInt)
    }
    
    var body: some View {
        ZStack {
            // Only apply the BG3 for the portrait view
            if !shouldShowLandscape {
                Image("BG3")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
            
            // --- ORIENTATION SWITCHER ---
            if shouldShowLandscape {
                // --- LANDSCAPE ---
                if let service = bracketService {
                    NFLLandscapeBracketView(playoffService: service)
                        .scaleEffect(UIDevice.current.userInterfaceIdiom == .pad ? 1.3 : 1.0)
                        .onAppear {
                            DebugPrint(mode: .appLoad, "🎨 [LANDSCAPE] NFLLandscapeBracketView appeared")
                        }
                }
            } else {
                // --- PORTRAIT ---
                if bracketService?.isLoading == true && bracketService?.currentBracket == nil {
                    PlayoffBracketLoadingView()
                } else if let bracket = bracketService?.currentBracket {
                    bracketContent(bracket)
                } else if let error = bracketService?.errorMessage {
                    PlayoffBracketErrorView(error: error) {
                        Task {
                            await loadBracket(forceRefresh: true)
                        }
                    }
                } else {
                    PlayoffBracketEmptyView()
                }
            }
        }
        .navigationTitle("")
        .preferredColorScheme(.dark)
        .task {
            // 🔥 Create service with proper DI if not provided
            if bracketService == nil {
                bracketService = NFLPlayoffBracketService(
                    weekSelectionManager: weekSelectionManager,
                    appLifecycleManager: appLifecycleManager,
                    bettingOddsService: bettingOddsService
                )
            }
            
            // 🔥 FIX: Only load if bracket isn't already loaded
            if bracketService?.currentBracket == nil {
                await loadBracket()
            } else {
                DebugPrint(mode: .appLoad, "✅ Bracket already loaded, skipping fetch")
            }
        }
        .onChange(of: selectedSeason) { _, newSeason in
            Task {
                // 🔥 FIX: Fetch standings for new season
                standingsService.fetchStandings(forceRefresh: true, season: newSeason)
                await loadBracket(forceRefresh: true)
            }
        }
        // 🔥 NEW: Watch for year changes from SeasonYearManager
        .onChange(of: yearManager.selectedYear) { _, newYear in
            if let year = Int(newYear), year != selectedSeason {
                selectedSeason = year
            }
        }
        .onAppear {
            // 🔥 FIX: Sync with year manager on appear
            if let year = Int(yearManager.selectedYear), year != selectedSeason {
                selectedSeason = year
            }
            // Fetch standings for selected season on appear
            standingsService.fetchStandings(season: selectedSeason)
            
            // 🔥 NEW: Start live updates if there are live games
            startLiveUpdatesIfNeeded()
            
            // 🔥 NEW: Setup orientation monitoring for iPad
            setupOrientationMonitoring()
        }
        .onDisappear {
            // Stop live updates when view disappears to prevent crashes
            stopLiveUpdates()
            
            // 🔥 NEW: Remove orientation observer
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
    
    // MARK: - Orientation Detection
    
    /// Determines if landscape view should be shown
    /// - iPhone: Uses verticalSizeClass (works perfectly)
    /// - iPad: Uses tracked orientation state
    private var shouldShowLandscape: Bool {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            // iPad: Use our tracked orientation state
            return isLandscape
        } else {
            // iPhone: Use size class (existing perfect behavior)
            return verticalSizeClass == .compact
        }
    }
    
    /// Setup orientation change monitoring for iPad
    private func setupOrientationMonitoring() {
        // Initial orientation check
        updateOrientation()
        
        // Listen for orientation changes
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            updateOrientation()
        }
    }
    
    /// Update the landscape state based on device orientation
    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            isLandscape = true
            DebugPrint(mode: .appLoad, "🔄 [ORIENTATION] Switched to LANDSCAPE")
        case .portrait, .portraitUpsideDown:
            isLandscape = false
            DebugPrint(mode: .appLoad, "🔄 [ORIENTATION] Switched to PORTRAIT")
        default:
            // Keep current state for .unknown or .faceUp/.faceDown
            DebugPrint(mode: .appLoad, "🔄 [ORIENTATION] Unknown orientation, keeping current state")
        }
    }
    
    // MARK: - Bracket Content
    
    @ViewBuilder
    private func bracketContent(_ bracket: PlayoffBracket) -> some View {
        let currentYear = Int(SeasonYearManager.shared.selectedYear) ?? AppConstants.currentSeasonYearInt
        
        // 🔥 Determine current playoff round
        let currentRound = weekToPlayoffRound(weekSelectionManager.selectedWeek)
        
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) {
                // Title - CENTERED with dynamic year + round name
                VStack(spacing: 2) {
                    Text("CURRENT \(String(currentYear))")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                    
                    Text(playoffRoundTitle(currentRound))
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                
                // 🔥 Pass FULL bracket but tell it what round to display
                HStack(alignment: .top, spacing: 30) {
                    // AFC Bracket - show only current round's games
                    PlayoffBracketConferenceColumn(
                        conference: .afc,
                        bracket: bracket,
                        currentRound: currentRound,
                        getSeedsForConference: getSeedsForConference,
                        findGame: findGame,
                        determineWinner: determineWinner,
                        shouldShowGameTime: shouldShowGameTime
                    )
                    
                    // NFC Bracket - show only current round's games
                    PlayoffBracketConferenceColumn(
                        conference: .nfc,
                        bracket: bracket,
                        currentRound: currentRound,
                        getSeedsForConference: getSeedsForConference,
                        findGame: findGame,
                        determineWinner: determineWinner,
                        shouldShowGameTime: shouldShowGameTime
                    )
                }
                .padding(.leading, 12)
                .padding(.trailing, 32)
                .padding(.bottom, 20)
                
                Spacer()
                
                // Notice to turn sideways
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "rotate.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Text("HEY! You gotta turn your device sideways\nand interact with the full bracket.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .scaleEffect(0.9)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .offset(x: -12, y: -50)
        .refreshable {
            await loadBracket(forceRefresh: true)
        }
    }
    
    // MARK: - Helper Methods - Playoff Round Mapping
    
    /// Map week number to playoff round
    private func weekToPlayoffRound(_ week: Int) -> PlayoffRound {
        switch week {
        case 19: return .wildCard
        case 20: return .divisional
        case 21: return .conference
        case 23: return .superBowl
        default: return .wildCard  // Default to Wild Card if unknown
        }
    }
    
    /// Get title for playoff round
    private func playoffRoundTitle(_ round: PlayoffRound) -> String {
        switch round {
        case .wildCard: return "WILD CARD ROUND"
        case .divisional: return "DIVISIONAL ROUND"
        case .conference: return "CONFERENCE CHAMPIONSHIPS"
        case .superBowl: return "SUPER BOWL"
        }
    }
    
    // MARK: - Helper Methods
    
    private func teamColor(for teamCode: String) -> Color {
        teamAssets.team(for: teamCode)?.primaryColor ?? Color.blue.opacity(0.6)
    }
    
    /// Check if we should show the game time (hide if it's 12:00 AM which is clearly wrong)
    private func shouldShowGameTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // If it's exactly midnight (12:00 AM), don't show time
        return !(hour == 0 && minute == 0)
    }
    
    private func getSeedsForConference(bracket: PlayoffBracket, conference: PlayoffGame.Conference) -> [Int: PlayoffTeam] {
        var seeds: [Int: PlayoffTeam] = [:]
        
        let games = conference == .afc ? bracket.afcGames : bracket.nfcGames
        
        // Extract all teams with their seeds - prioritize teams from later rounds (they have updated scores)
        for game in games.reversed() {
            if let awaySeed = game.awayTeam.seed {
                seeds[awaySeed] = game.awayTeam
            }
            if let homeSeed = game.homeTeam.seed {
                seeds[homeSeed] = game.homeTeam
            }
        }
        
        return seeds
    }
    
    private func findGame(team1: PlayoffTeam, team2: PlayoffTeam, in games: [PlayoffGame]) -> PlayoffGame? {
        games.first { game in
            (game.homeTeam.abbreviation == team1.abbreviation && game.awayTeam.abbreviation == team2.abbreviation) ||
            (game.homeTeam.abbreviation == team2.abbreviation && game.awayTeam.abbreviation == team1.abbreviation)
        }
    }
    
    /// Determine the winner of a completed game
    private func determineWinner(game: PlayoffGame?) -> String? {
        guard let game = game, game.isCompleted else { return nil }
        guard let homeScore = game.homeTeam.score, let awayScore = game.awayTeam.score else { return nil }
        
        if homeScore > awayScore {
            return game.homeTeam.abbreviation
        } else if awayScore > homeScore {
            return game.awayTeam.abbreviation
        }
        return nil
    }
    
    private func loadBracket(forceRefresh: Bool = false) async {
        guard let service = bracketService else { return }
        await service.fetchPlayoffBracket(for: selectedSeason, forceRefresh: forceRefresh)
        
        // 🔥 NEW: Check for live games after loading and start/stop timer accordingly
        startLiveUpdatesIfNeeded()
    }
    
    // 🔥 NEW: Start live updates if bracket has live games OR if games are upcoming
    private func startLiveUpdatesIfNeeded() {
        guard let bracket = bracketService?.currentBracket else { return }
        
        if bracket.hasLiveGames {
            DebugPrint(mode: .nflData, "🔥 [PLAYOFF BRACKET] Live games detected - starting fast refresh")
            startPeriodicRefresh(isLive: true)
        } else if hasUpcomingGames(bracket: bracket) {
            DebugPrint(mode: .nflData, "⏰ [PLAYOFF BRACKET] Upcoming games - starting slow check-in refresh")
            startPeriodicRefresh(isLive: false)
        } else {
            DebugPrint(mode: .nflData, "✅ [PLAYOFF BRACKET] No games today - stopping auto-refresh")
            stopLiveUpdates()
        }
    }
    
    // 🔥 NEW: Check if there are games happening today or in near future
    private func hasUpcomingGames(bracket: PlayoffBracket) -> Bool {
        let now = Date()
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        let allGames = bracket.afcGames + bracket.nfcGames + (bracket.superBowl != nil ? [bracket.superBowl!] : [])
        
        // Check if any games are scheduled for today or in the next 24 hours
        return allGames.contains { game in
            game.status == .scheduled && game.gameDate >= now && game.gameDate <= todayEnd
        }
    }
    
    // 🔥 UPDATED: Start periodic refresh with dynamic interval based on game status
    private func startPeriodicRefresh(isLive: Bool) {
        // Stop any existing timer
        stopLiveUpdates()
        
        // Use fast interval for live games, slow interval for checking upcoming games
        let refreshInterval = isLive ? TimeInterval(AppConstants.MatchupRefresh) : TimeInterval(180) // 3 minutes for check-in
        
        // 🔥 NEW: Add counter for tracking
        var refreshCount = 0
        
        let startTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let intervalType = isLive ? "FAST (live)" : "SLOW (check-in)"
        DebugPrint(mode: .bracketTimer, "🔄 [BRACKET TIMER START] Started at: \(startTime), Type: \(intervalType), Interval: \(refreshInterval)s")
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor [weak bracketService] in
                guard let service = bracketService else { return }
                
                refreshCount += 1
                let updateTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                DebugPrint(mode: .bracketTimer, "🔄 [BRACKET TIMER FIRE] Updated at: \(updateTime) - Count: \(refreshCount), Type: \(intervalType)")
                
                await service.fetchPlayoffBracket(for: selectedSeason, forceRefresh: true)
                
                // 🔥 Re-evaluate what kind of refresh we need
                self.startLiveUpdatesIfNeeded()
            }
        }
        
        DebugPrint(mode: .bracketTimer, "✅ [BRACKET TIMER] Timer scheduled successfully with \(intervalType) interval")
    }
    
    // 🔥 NEW: Stop all timers
    private func stopLiveUpdates() {
        if refreshTimer != nil {
            let stopTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            DebugPrint(mode: .bracketTimer, "🛑 [BRACKET TIMER STOP] Stopped at: \(stopTime)")
        }
        refreshTimer?.invalidate()
        refreshTimer = nil
        bracketService?.stopLiveUpdates()
    }
}