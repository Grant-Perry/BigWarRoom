//
//  NFLScheduleView.swift
//  BigWarRoom
//
//  NFL Schedule view matching FOX NFL graphics style
//
// MARK: -> NFL Schedule Main View

import SwiftUI

struct NFLScheduleView: View {
    @StateObject private var viewModel = NFLScheduleViewModel()
    @StateObject private var matchupsHubViewModel = MatchupsHubViewModel()
    @StateObject private var weekManager = WeekSelectionManager.shared // Use shared week manager
    @State private var showingWeekPicker = false
    
    // 🔥 NEW: Sheet state for team filtered matchups
    @State private var showingTeamMatchups = false
    // 🔥 NEW: Navigation state for team filtered matchups  
    @State private var selectedGame: ScheduleGame?
    // 🔥 NUCLEAR: Use NavigationPath for programmatic navigation
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        // 🏈 NAVIGATION FREEDOM: Remove NavigationStack - parent TabView provides it
        ZStack {
            // FOX-style background
            foxStyleBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section
                scheduleHeader
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                
                // Games List
                gamesList
            }
            
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showingGameDetail) {
            if let game = viewModel.selectedGame {
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
            WeekPickerView(isPresented: $showingWeekPicker)
        }
        // Sync with shared week manager
        .onChange(of: weekManager.selectedWeek) { _, newWeek in
            viewModel.selectWeek(newWeek)
        }
        .onAppear {
            print("🔍 SCHEDULE DEBUG: NFLScheduleView appeared")
            // Sync initial week
            viewModel.selectWeek(weekManager.selectedWeek)
            
            // Load matchup data when view appears
            Task {
                print("🔍 SCHEDULE DEBUG: Starting matchup data load...")
                await matchupsHubViewModel.loadAllMatchups()
                print("🔍 SCHEDULE DEBUG: Matchup data load complete - \(matchupsHubViewModel.myMatchups.count) matchups loaded")
            }
            
            // Start global auto-refresh for live scores
            viewModel.refreshSchedule() // Initial load only
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
    private var scheduleHeader: some View {
        VStack(spacing: 12) {
            // Large "WEEK" title like FOX - CENTERED
            VStack(spacing: 4) {
                Text("WEEK \(weekManager.selectedWeek)") // Use weekManager instead of viewModel
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
                    Text("Week \(weekManager.selectedWeek)") // Use weekManager
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
    private var gamesList: some View {
        Group {
            if viewModel.isLoading && viewModel.games.isEmpty {
                loadingView
            } else if viewModel.errorMessage?.isEmpty == false {
                errorView
            } else if viewModel.games.isEmpty {
                emptyStateView
            } else {
                gamesScrollView
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
    private var gamesScrollView: some View {
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
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helper function to get week start date
    private func getWeekStartDate() -> String {
        // NFL 2024 season start date (Week 1 starts September 5, 2024)
        let season2024Start = Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 5))!
        let calendar = Calendar.current
        
        // Calculate the start date for the selected week
        let weekStartDate = calendar.date(byAdding: .day, value: (weekManager.selectedWeek - 1) * 7, to: season2024Start)!
        
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