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
    
    // 🔥 NEW: Add UnifiedLeagueManager for bye week impact analysis
    @State private var unifiedLeagueManager: UnifiedLeagueManager?
    
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
        // Use BG2 asset from assets folder with reduced opacity
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4) // Set to 0.4 opacity as requested
            .ignoresSafeArea(.all)
    }
    
    // MARK: -> Header Section
    private func scheduleHeader(viewModel: NFLScheduleViewModel) -> some View {
        VStack(spacing: 12) {
            // Large "WEEK" title like FOX - CENTERED
            VStack(spacing: 4) {
                Text("WEEK \(WeekSelectionManager.shared.selectedWeek)")
                    .font(.system(size: 60, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
                
                // Week starting date
                Text("Week starting: \(getWeekStartDate())")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            // NFL Schedule title and controls
            HStack {
                Text("NFL SCHEDULE")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Week picker - now uses Mission Control's WeekPickerView
                Button(action: { showingWeekPicker = true }) {
                    Text("Week \(WeekSelectionManager.shared.selectedWeek)")
                        .font(.subheadline)
                        .foregroundColor(.gpPostBot)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // Live indicator
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
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
        }
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
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.games, id: \.id) { game in
                    // 🏈 NAVIGATION FREEDOM: Use NavigationLink instead of Button + sheet
                    NavigationLink(destination: TeamFilteredMatchupsView(
                                    awayTeam: game.awayTeam,
                                    homeTeam: game.homeTeam,
                                    matchupsHubViewModel: matchupsHubViewModel,
                                    gameData: game
                                )) {
                        ScheduleGameCard(game: game) {
                            // NavigationLink handles navigation
                        }
                        .frame(maxWidth: .infinity)
                        .frame(width: UIScreen.main.bounds.width * 0.8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // BYE Week Section - 🔥 UPDATED: Pass dependencies for impact analysis
                if let manager = unifiedLeagueManager, !viewModel.byeWeekTeams.isEmpty {
                    ScheduleByeWeekSection(
                        byeTeams: viewModel.byeWeekTeams,
                        unifiedLeagueManager: manager,
                        matchupsHubViewModel: matchupsHubViewModel
                    )
                    .padding(.top, 24)
                } else if viewModel.byeWeekTeams.isEmpty {
                    noByeWeeksBanner
                        .padding(.top, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 32)
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

    // MARK: - Helper function to get week start date
    private func getWeekStartDate() -> String {
        // NFL 2024 season start date (Week 1 starts September 5, 2024)
        let season2024Start = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        let calendar = Calendar.current
        
        // Calculate the start date for the selected week
        let weekStartDate = calendar.date(byAdding: .day, value: (WeekSelectionManager.shared.selectedWeek - 1) * 7, to: season2024Start)!
        
        // Format as "Thursday, January 4"
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: weekStartDate)
    }
}

#Preview("NFL Schedule") {
    NFLScheduleView()
        .preferredColorScheme(.dark)
}