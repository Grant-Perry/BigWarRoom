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
    @State private var showingWeekPicker = false
    @State private var showingTeamFilteredMatchups = false
    @State private var selectedGameForMatchups: ScheduleGame?
    
    var body: some View {
        NavigationView {
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
            .sheet(isPresented: $showingWeekPicker) {
                WeekPickerSheet(
                    selectedWeek: $viewModel.selectedWeek,
                    onWeekSelected: { week in
                        viewModel.selectWeek(week)
                        showingWeekPicker = false
                    }
                )
            }
            .sheet(isPresented: $showingTeamFilteredMatchups) {
                if let game = selectedGameForMatchups {
                    TeamFilteredMatchupsView(
                        awayTeam: game.awayTeam,
                        homeTeam: game.homeTeam,
                        matchupsHubViewModel: matchupsHubViewModel
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Load matchup data when view appears
            Task {
                await matchupsHubViewModel.loadAllMatchups()
            }
        }
    }
    
    // MARK: -> FOX Style Background
    private var foxStyleBackground: some View {
        // Use BG1 asset from assets folder with reduced opacity
        Image("BG1")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.35) // Reduced opacity for better text readability
            .ignoresSafeArea(.all)
    }
    
    // MARK: -> Header Section
    private var scheduleHeader: some View {
        VStack(spacing: 12) {
            // Large "WEEK" title like FOX - CENTERED
            Text("WEEK \(viewModel.selectedWeek)")
                .font(.system(size: 60, weight: .bold, design: .default))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
                .frame(maxWidth: .infinity, alignment: .center) // Changed from .leading to .center
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            // NFL Schedule title and controls
            HStack {
                Text("NFL SCHEDULE")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Week picker
                    Button(action: { showingWeekPicker = true }) {
                        HStack(spacing: 4) {
                            Text("Week \(viewModel.selectedWeek)")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Refresh button
                    Button(action: { viewModel.refreshSchedule() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isLoading ? 
                                .linear(duration: 1).repeatForever(autoreverses: false) : 
                                .default, 
                                value: viewModel.isLoading
                            )
                    }
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .buttonStyle(PlainButtonStyle())
                }
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
            
            Button("Try Again") {
                viewModel.refreshSchedule()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .font(.system(size: 14, weight: .medium))
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
                ForEach(viewModel.games) { game in
                    ScheduleGameCard(game: game) {
                        selectedGameForMatchups = game
                        showingTeamFilteredMatchups = true
                    }
                    .frame(maxWidth: .infinity)
                    .frame(width: UIScreen.main.bounds.width * 0.8) // 80% of screen width
                }
            }
            .frame(maxWidth: .infinity) // Center the stack
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }
}

#Preview("NFL Schedule") {
    NFLScheduleView()
        .preferredColorScheme(.dark)
}