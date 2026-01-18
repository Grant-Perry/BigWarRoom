//
//  NFLPlayoffBracketView.swift
//  BigWarRoom
//
//  ESPN-style playoff bracket with blue gradient and bracket connector lines
//

import SwiftUI

struct NFLPlayoffBracketView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(TeamAssetManager.self) private var teamAssets
    @Environment(NFLStandingsService.self) private var standingsService
    @Environment(BettingOddsService.self) private var bettingOddsService
    @State private var bracketService: NFLPlayoffBracketService?
    @State private var selectedSeason: Int
    @State private var yearManager = SeasonYearManager.shared
    @State private var refreshTimer: Timer?
    @State private var isLandscape: Bool = false
    
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
            if !shouldShowLandscape {
                Image("BG3")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
            
            if shouldShowLandscape {
                landscapeView
            } else {
                portraitView
            }
        }
        .navigationTitle("")
        .preferredColorScheme(.dark)
        .task {
            if bracketService == nil {
                bracketService = NFLPlayoffBracketService(
                    weekSelectionManager: weekSelectionManager,
                    appLifecycleManager: appLifecycleManager,
                    bettingOddsService: bettingOddsService
                )
            }
            
            if bracketService?.currentBracket == nil {
                await loadBracket()
            } else {
                DebugPrint(mode: .appLoad, "✅ Bracket already loaded, skipping fetch")
            }
        }
        .onChange(of: selectedSeason) { _, newSeason in
            Task {
                standingsService.fetchStandings(forceRefresh: true, season: newSeason)
                await loadBracket(forceRefresh: true)
            }
        }
        .onChange(of: yearManager.selectedYear) { _, newYear in
            if let year = Int(newYear), year != selectedSeason {
                selectedSeason = year
            }
        }
        .onAppear {
            if let year = Int(yearManager.selectedYear), year != selectedSeason {
                selectedSeason = year
            }
            standingsService.fetchStandings(season: selectedSeason)
            startLiveUpdatesIfNeeded()
            setupOrientationMonitoring()
        }
        .onDisappear {
            stopLiveUpdates()
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
    
    @ViewBuilder
    private var landscapeView: some View {
        if let service = bracketService {
            NFLLandscapeBracketView(playoffService: service)
                .scaleEffect(UIDevice.current.userInterfaceIdiom == .pad ? 1.3 : 1.0)
                .onAppear {
                    DebugPrint(mode: .appLoad, "🎨 [LANDSCAPE] NFLLandscapeBracketView appeared")
                }
        }
    }
    
    @ViewBuilder
    private var portraitView: some View {
        if bracketService?.isLoading == true && bracketService?.currentBracket == nil {
            PlayoffBracketLoadingView()
        } else if let bracket = bracketService?.currentBracket {
            PlayoffBracketPortraitView(
                bracket: bracket,
                currentRound: PlayoffBracketHelpers.weekToPlayoffRound(weekSelectionManager.selectedWeek),
                weekSelectionManager: weekSelectionManager,
                onRefresh: {
                    await loadBracket(forceRefresh: true)
                }
            )
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
    
    private var shouldShowLandscape: Bool {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            return isLandscape
        } else {
            return verticalSizeClass == .compact
        }
    }
    
    private func setupOrientationMonitoring() {
        updateOrientation()
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            updateOrientation()
        }
    }
    
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
            DebugPrint(mode: .appLoad, "🔄 [ORIENTATION] Unknown orientation, keeping current state")
        }
    }
    
    private func loadBracket(forceRefresh: Bool = false) async {
        guard let service = bracketService else { return }
        await service.fetchPlayoffBracket(for: selectedSeason, forceRefresh: forceRefresh)
        startLiveUpdatesIfNeeded()
    }
    
    private func startLiveUpdatesIfNeeded() {
        guard let bracket = bracketService?.currentBracket else { return }
        
        if bracket.hasLiveGames {
            DebugPrint(mode: .nflData, "🔥 [PLAYOFF BRACKET] Live games detected - starting fast refresh")
            startPeriodicRefresh(isLive: true)
        } else if PlayoffGameHelpers.hasUpcomingGames(bracket: bracket) {
            DebugPrint(mode: .nflData, "⏰ [PLAYOFF BRACKET] Upcoming games - starting slow check-in refresh")
            startPeriodicRefresh(isLive: false)
        } else {
            DebugPrint(mode: .nflData, "✅ [PLAYOFF BRACKET] No games today - stopping auto-refresh")
            stopLiveUpdates()
        }
    }
    
    private func startPeriodicRefresh(isLive: Bool) {
        stopLiveUpdates()
        
        let refreshInterval = isLive ? TimeInterval(AppConstants.MatchupRefresh) : TimeInterval(180)
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
                self.startLiveUpdatesIfNeeded()
            }
        }
        
        DebugPrint(mode: .bracketTimer, "✅ [BRACKET TIMER] Timer scheduled successfully with \(intervalType) interval")
    }
    
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
