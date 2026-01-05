//
//  FantasyMatchupDetailView.swift
//  BigWarRoom
//
//  🔥 PHASE 2 MVVM REFACTOR: Updated to use proper View components
//  REMOVED: Direct ViewModel UI calls (MVVM violation)
//  ADDED: Proper View components from FantasyMatchupRosterSections
//  ENHANCED: Connected filter controls to actual roster display logic
//

import SwiftUI

/// Main view for displaying detailed fantasy matchup information
struct FantasyMatchupDetailView: View {
    let matchup: FantasyMatchup
    let leagueName: String
    var fantasyViewModel: FantasyViewModel? = nil
    let logoSize: CGFloat = 32
    @Environment(\.dismiss) private var dismiss
    @Environment(MatchupsHubViewModel.self) private var matchupsHubViewModel
    @Environment(FantasyViewModel.self) private var defaultFantasyViewModel
    @Environment(NFLWeekService.self) private var nflWeekService

    // Shared instance to ensure stats are loaded early
    // 🔥 PHASE 3 DI: Injected via initializer
    @State private var livePlayersViewModel: AllLivePlayersViewModel
    
    // 🔥 FIX: Persist sorting state across ALL matchup views using AppStorage
    @AppStorage("MatchupDetail_SortMethod") private var sortingMethodRaw: String = MatchupSortingMethod.position.rawValue
    @AppStorage("MatchupDetail_SortHighToLow") private var sortHighToLow: Bool = false
    
    private var sortingMethod: MatchupSortingMethod {
        MatchupSortingMethod(rawValue: sortingMethodRaw) ?? .position
    }
    
    // NEW: Filter states - now managed at the parent level
    @State private var selectedPosition: FantasyPosition = .all
    @State private var showActiveOnly: Bool = false
    @State private var showRosteredOnly: Bool = false
    @State private var showYetToPlayOnly: Bool = false
    
    // 🔥 NEW: Force view update when hub refreshes
    @State private var observedUpdateTime: Date = Date.distantPast

    // MARK: - Initializers

    /// Default initializer for backward compatibility
    // 🔥 PHASE 3 DI: Require livePlayersViewModel parameter
    init(matchup: FantasyMatchup, leagueName: String, livePlayersViewModel: AllLivePlayersViewModel) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = nil
        self._livePlayersViewModel = State(initialValue: livePlayersViewModel)
    }

    /// Full initializer with FantasyViewModel
    // 🔥 PHASE 3 DI: Require livePlayersViewModel parameter
    init(matchup: FantasyMatchup, fantasyViewModel: FantasyViewModel, leagueName: String, livePlayersViewModel: AllLivePlayersViewModel) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = fantasyViewModel
        self._livePlayersViewModel = State(initialValue: livePlayersViewModel)
    }

    // MARK: - Body

    var body: some View {
        // FIX: Only add background when NOT embedded in LeagueMatchupsTabView
        Group {
            if isEmbeddedInTabView {
                // Embedded in LeagueMatchupsTabView - no background, content only
                contentView
                    .navigationDestination(for: SleeperPlayer.self) { player in
                        PlayerStatsCardView(
                            player: player,
                            team: NFLTeam.team(for: player.team ?? "")
                        )
                    }
            } else {
                // Standalone - add background
                ZStack {
                    // Background
                    ZStack {
                        Color.black
                        Image("BG7")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(0.35)
                    }
                    .ignoresSafeArea(.all)
                    
                    // Content
                    contentView
                }
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
                .preferredColorScheme(.dark)
                .navigationDestination(for: SleeperPlayer.self) { player in
                    PlayerStatsCardView(
                        player: player,
                        team: NFLTeam.team(for: player.team ?? "")
                    )
                }
            }
        }
        .onChange(of: sortingMethodRaw) { oldValue, newValue in
            DebugPrint(mode: .matchupSort, "🎯 SORT METHOD CHANGED: \(oldValue) → \(newValue)")
        }
        .onChange(of: sortHighToLow) { oldValue, newValue in
            DebugPrint(mode: .matchupSort, "🎯 SORT DIRECTION CHANGED: \(oldValue) → \(newValue)")
        }
    }

    // FIX: Extract content to separate view with proper padding
    private var contentView: some View {
        // 🔥 FIX: Observe matchupsHub update time to trigger re-render
        let _ = observedUpdateTime
        
        let awayTeamScore = fantasyViewModel?.getScore(for: currentMatchup, teamIndex: 0) ?? currentMatchup.awayTeam.currentScore ?? 0.0
        let homeTeamScore = fantasyViewModel?.getScore(for: currentMatchup, teamIndex: 1) ?? currentMatchup.homeTeam.currentScore ?? 0.0
        let awayTeamIsWinning = awayTeamScore > homeTeamScore
        let homeTeamIsWinning = homeTeamScore > awayTeamScore
        
        return VStack(spacing: 0) {
            // Fantasy detail header with team comparison
            FantasyDetailHeaderView(
                leagueName: leagueName,
                matchup: currentMatchup,
                awayTeamIsWinning: awayTeamIsWinning,
                homeTeamIsWinning: homeTeamIsWinning,
                fantasyViewModel: fantasyViewModel,
                sortingMethod: sortingMethod,
                sortHighToLow: sortHighToLow,
                onSortingMethodChanged: { method in
                    DebugPrint(mode: .matchupSort, "🎯 HEADER: Sort method tapped: \(method.displayName)")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortingMethodRaw = method.rawValue
                        // Reset sort direction to logical default for each method
                        // Score & Recent Activity: High-Low, others: A-Z
                        sortHighToLow = (method == .score || method == .recentActivity)
                        DebugPrint(mode: .matchupSort, "🎯 HEADER: After change - method=\(method.displayName), direction=\(sortHighToLow)")
                    }
                },
                onSortDirectionChanged: {
                    DebugPrint(mode: .matchupSort, "🎯 HEADER: Sort direction tapped")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortHighToLow.toggle()
                        DebugPrint(mode: .matchupSort, "🎯 HEADER: After toggle - direction=\(sortHighToLow)")
                    }
                },
                selectedPosition: $selectedPosition,
                showActiveOnly: $showActiveOnly,
                showYetToPlayOnly: $showYetToPlayOnly,
                watchService: PlayerWatchService(
                    weekManager: WeekSelectionManager.shared,
                    gameDataService: livePlayersViewModel.nflGameDataService,
                    allLivePlayersViewModel: livePlayersViewModel
                ),
                gameStatusService: GameStatusService.shared
            )
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 12)
            .zIndex(99)

            // Roster content
            rosterScrollView
                .zIndex(1)
        }
        // FIX: Add proper safe area padding to prevent clipping
        .padding(.horizontal, isEmbeddedInTabView ? 0 : 0) // Let individual components handle their own padding
        .onAppear {
            handleViewAppearance()
        }
        .task {
            await handleViewTask()
        }
        .onChange(of: matchupsHubViewModel.lastUpdateTime) { oldValue, newValue in
            // 🔥 NEW: Update observed time to force view re-render when hub refreshes
            DebugPrint(mode: .matchupSort, "🔄 MATCHUP DETAIL: Hub updated at \(newValue), refreshing view")
            observedUpdateTime = newValue
        }
    }

    // FIX: Detect if this view is embedded in LeagueMatchupsTabView
    private var isEmbeddedInTabView: Bool {
        // Check if the parent view has fantasyViewModel (indicating it's from LeagueMatchupsTabView)
        return fantasyViewModel != nil
    }

    private var currentMatchup: FantasyMatchup {
        if let updated = matchupsHubViewModel.myMatchups.first(where: { $0.fantasyMatchup?.id == matchup.id })?.fantasyMatchup {
            return updated
        }
        return matchup
    }

    private var rosterScrollView: some View {
        // 🔥 FIX: Create a @Binding-compatible wrapper for sortingMethod
        let sortingBinding = Binding<MatchupSortingMethod>(
            get: { self.sortingMethod },
            set: { self.sortingMethodRaw = $0.rawValue }
        )
        
        return ScrollView {
            VStack(spacing: 16) {
                if let viewModel = fantasyViewModel {
                    FantasyMatchupActiveRosterSectionFiltered(
                        matchup: currentMatchup,
                        fantasyViewModel: viewModel,
                        sortMethod: sortingBinding,
                        highToLow: $sortHighToLow,
                        selectedPosition: $selectedPosition,
                        showActiveOnly: $showActiveOnly,
                        showYetToPlayOnly: $showYetToPlayOnly,
                        hubUpdateTime: matchupsHubViewModel.lastUpdateTime
                    )
                    
                    FantasyMatchupBenchSectionFiltered(
                        matchup: currentMatchup,
                        fantasyViewModel: viewModel,
                        sortMethod: sortingBinding,
                        highToLow: $sortHighToLow,
                        selectedPosition: $selectedPosition,
                        showActiveOnly: $showActiveOnly,
                        showYetToPlayOnly: $showYetToPlayOnly,
                        hubUpdateTime: matchupsHubViewModel.lastUpdateTime
                    )
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 24)
        }
        .clipped()
    }

    // MARK: - Simplified Roster View (Fallback)

    /// Simplified roster view for when no FantasyViewModel is available
    private var simplifiedRosterView: some View {
        VStack(spacing: 16) {
            // HOME team roster first
            VStack(alignment: .leading, spacing: 8) {
                Text("\(currentMatchup.homeTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(currentMatchup.homeTeam.roster.filter { $0.isStarter }) { player in
                        // 🔥 PURE DI: Pass injected instance
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? defaultFantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 1,
                            isBench: false,
                            allLivePlayersViewModel: livePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                        .padding(.horizontal, 8)
                    }
                }
            }

            // AWAY team roster second
            VStack(alignment: .leading, spacing: 8) {
                Text("\(currentMatchup.awayTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(currentMatchup.awayTeam.roster.filter { $0.isStarter }) { player in
                        // 🔥 PURE DI: Pass injected instance
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? defaultFantasyViewModel,
                            matchup: currentMatchup,
                            teamIndex: 0,
                            isBench: false,
                            allLivePlayersViewModel: livePlayersViewModel,
                            nflWeekService: nflWeekService
                        )
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handleViewAppearance() {
        // 🔥 FIX: Ensure NFL game data is loaded for filtering to work
        Task {
            await ensureGameDataLoaded()
        }
        
        // 🔥 REMOVED: Don't trigger full hub refresh on view appear - causes 15+ second hang
        // The matchup data is already fresh from the previous view (Mission Control or LeagueMatchupsTabView)
        // If we need live updates, they'll come from the background auto-refresh in MatchupsHubViewModel
        
        // Keep the stats loading task in handleViewTask() - that's lightweight and doesn't block
    }
    
    // 🔥 NEW: Ensure game data is loaded for Active Only filter
    private func ensureGameDataLoaded() async {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        
        if livePlayersViewModel.nflGameDataService.gameData.isEmpty {
            livePlayersViewModel.nflGameDataService.fetchGameData(forWeek: selectedWeek, forceRefresh: false)
            
            // 🔥 CRITICAL: Wait for the fetch to complete before returning
            // Give it up to 2 seconds to load
            var attempts = 0
            while livePlayersViewModel.nflGameDataService.gameData.isEmpty && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                attempts += 1
            }
        }
    }

    private func handleViewTask() async {
        // Aggressive stats loading for Mission Control navigation
        
        // Always ensure we have stats - don't rely on statsLoaded flag alone
        if livePlayersViewModel.playerStats.isEmpty {
            await livePlayersViewModel.loadAllPlayers()
        } else {
            await livePlayersViewModel.forceLoadStats()
        }
    }
}