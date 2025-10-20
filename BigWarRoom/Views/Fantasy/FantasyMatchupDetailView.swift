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

    // Shared instance to ensure stats are loaded early
    @ObservedObject private var livePlayersViewModel = AllLivePlayersViewModel.shared

    // Sorting state for matchup details
    @State private var sortingMethod: MatchupSortingMethod = .position
    @State private var sortHighToLow = false // Position: A-Z, Score: High-Low by default
    
    // NEW: Filter states - now managed at the parent level
    @State private var selectedPosition: FantasyPosition = .all
    @State private var showActiveOnly: Bool = false
    @State private var showRosteredOnly: Bool = false

    // MARK: - Initializers

    /// Default initializer for backward compatibility
    init(matchup: FantasyMatchup, leagueName: String) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = nil
    }

    /// Full initializer with FantasyViewModel
    init(matchup: FantasyMatchup, fantasyViewModel: FantasyViewModel, leagueName: String) {
        self.matchup = matchup
        self.leagueName = leagueName
        self.fantasyViewModel = fantasyViewModel
    }

    // MARK: - Body

    var body: some View {
        let awayTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 0) ?? matchup.awayTeam.currentScore ?? 0.0
        let homeTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 1) ?? matchup.homeTeam.currentScore ?? 0.0
        let awayTeamIsWinning = awayTeamScore > homeTeamScore
        let homeTeamIsWinning = homeTeamScore > awayTeamScore

        // 🔥 FIX: Only add background when NOT embedded in LeagueMatchupsTabView
        if isEmbeddedInTabView {
            // Embedded in LeagueMatchupsTabView - no background, content only
            contentView
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
        }
    }

    // 🔥 FIX: Extract content to separate view with proper padding
    private var contentView: some View {
        let awayTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 0) ?? matchup.awayTeam.currentScore ?? 0.0
        let homeTeamScore = fantasyViewModel?.getScore(for: matchup, teamIndex: 1) ?? matchup.homeTeam.currentScore ?? 0.0
        let awayTeamIsWinning = awayTeamScore > homeTeamScore
        let homeTeamIsWinning = homeTeamScore > awayTeamScore
        
        return VStack(spacing: 0) {
            // Fantasy detail header with team comparison
            FantasyDetailHeaderView(
                leagueName: leagueName,
                matchup: matchup,
                awayTeamIsWinning: awayTeamIsWinning,
                homeTeamIsWinning: homeTeamIsWinning,
                fantasyViewModel: fantasyViewModel,
                sortingMethod: sortingMethod,
                sortHighToLow: sortHighToLow,
                onSortingMethodChanged: { method in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortingMethod = method
                        // Reset sort direction to logical default for each method
                        sortHighToLow = (method == .score) // Score: High-Low, others: A-Z
                    }
                },
                onSortDirectionChanged: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sortHighToLow.toggle()
                    }
                },
                selectedPosition: $selectedPosition,
                showActiveOnly: $showActiveOnly
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .zIndex(99)

            // Roster content
            rosterScrollView
                .zIndex(1)
        }
        // 🔥 FIX: Add proper safe area padding to prevent clipping
        .padding(.horizontal, isEmbeddedInTabView ? 0 : 0) // Let individual components handle their own padding
        .onAppear {
            handleViewAppearance()
        }
        .task {
            await handleViewTask()
        }
    }

    // 🔥 FIX: Detect if this view is embedded in LeagueMatchupsTabView
    private var isEmbeddedInTabView: Bool {
        // Check if the parent view has fantasyViewModel (indicating it's from LeagueMatchupsTabView)
        return fantasyViewModel != nil
    }

    private var rosterScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let viewModel = fantasyViewModel {
                    // 🔥 MVVM REFACTOR: Using proper View components with filter parameters
                    FantasyMatchupActiveRosterSectionFiltered(
                        matchup: matchup,
                        fantasyViewModel: viewModel,
                        sortMethod: sortingMethod,
                        highToLow: sortHighToLow,
                        selectedPosition: selectedPosition,
                        showActiveOnly: showActiveOnly
                    )
                    
                    FantasyMatchupBenchSectionFiltered(
                        matchup: matchup,
                        fantasyViewModel: viewModel,
                        sortMethod: sortingMethod,
                        highToLow: sortHighToLow,
                        selectedPosition: selectedPosition,
                        showActiveOnly: showActiveOnly
                    )
                } else {
                    // Fallback content when no view model is available
                    simplifiedRosterView
                }
            }
            .padding(.top, 8)
            // 🔥 FIX: Increase horizontal padding to prevent clipping
            .padding(.horizontal, 16) // Increased from 8 to 16
        }
        .clipped()
    }

    // MARK: - Simplified Roster View (Fallback)

    /// Simplified roster view for when no FantasyViewModel is available
    private var simplifiedRosterView: some View {
        VStack(spacing: 16) {
            // HOME team roster first
            VStack(alignment: .leading, spacing: 8) {
                Text("\(matchup.homeTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(matchup.homeTeam.roster.filter { $0.isStarter }) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? FantasyViewModel.shared,
                            matchup: matchup,
                            teamIndex: 1, // Home team index
                            isBench: false
                        )
                        // 🔥 FIX: Reduce horizontal padding to prevent double padding
                        .padding(.horizontal, 8) // Reduced from default
                    }
                }
            }

            // AWAY team roster second
            VStack(alignment: .leading, spacing: 8) {
                Text("\(matchup.awayTeam.name) Roster")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                    ForEach(matchup.awayTeam.roster.filter { $0.isStarter }) { player in
                        FantasyPlayerCard(
                            player: player,
                            fantasyViewModel: fantasyViewModel ?? FantasyViewModel.shared,
                            matchup: matchup,
                            teamIndex: 0, // Away team index
                            isBench: false
                        )
                        // 🔥 FIX: Reduce horizontal padding to prevent double padding
                        .padding(.horizontal, 8) // Reduced from default
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handleViewAppearance() {
        // Always load stats when this view appears
        print("🏈 FantasyMatchupDetailView onAppear - forcing stats load")
        Task {
            await livePlayersViewModel.forceLoadStats()
        }
    }

    private func handleViewTask() async {
        // Aggressive stats loading for Mission Control navigation
        print("🏈 FantasyMatchupDetailView task - checking stats state")
        print("📊 Stats loaded: \(livePlayersViewModel.statsLoaded)")
        print("👥 Player stats count: \(livePlayersViewModel.playerStats.keys.count)")

        // Always ensure we have stats - don't rely on statsLoaded flag alone
        if livePlayersViewModel.playerStats.isEmpty {
            print("⚠️ No player stats found - forcing full reload")
            await livePlayersViewModel.loadAllPlayers()
        } else {
            print("✅ Player stats already available - refreshing to ensure latest data")
            await livePlayersViewModel.forceLoadStats()
        }
    }
}