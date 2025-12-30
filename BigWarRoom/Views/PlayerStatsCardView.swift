//
//  PlayerStatsCardView.swift
//  BigWarRoom
//
//  Clean MVVM coordinator for detailed player stats
//  Refactored from 1,286 lines to ~80 lines with proper separation of concerns
//
//  🔧 BLANK SHEET FIX: Modified to use conditional view rendering based on loading state
//  instead of always showing main content (which caused blank screens during data loading)

import SwiftUI

// MARK: - Height Conversion Extension (Keep existing utility)
extension String {
    /// Converts height from inches to feet and inches format
    /// E.g., "73" becomes "6' 1""
    var formattedHeight: String {
        // Check if already in feet/inches format
        if self.contains("'") || self.contains("\"") || self.contains("ft") {
            return self
        }
        
        // Try to convert from inches
        guard let totalInches = Int(self) else {
            return self // Return original if not a number
        }
        
        let feet = totalInches / 12
        let remainingInches = totalInches % 12
        
        if remainingInches == 0 {
            return "\(feet)'"
        } else {
            return "\(feet)' \(remainingInches)\""
        }
    }
}

/// **CLEAN MVVM COORDINATOR VIEW**
/// 
/// This view now only handles:
/// - UI coordination and navigation
/// - Component composition
/// - State management for dismiss
/// - 🔧 BLANK SHEET FIX: Loading states and progress indication
/// - 🔧 BLANK SHEET FIX: Error handling and recovery
/// - 🏈 PLAYER NAVIGATION: Mutable player state for depth chart navigation
/// 
/// All business logic has been moved to PlayerStatsViewModel
/// All UI components have been extracted to separate, reusable view files
struct PlayerStatsCardView: View {
    // 🏈 PLAYER NAVIGATION: Convert to mutable state for updating current player
    @State private var currentPlayer: SleeperPlayer
    @State private var currentTeam: NFLTeam?
    
    @Environment(\.dismiss) private var dismiss
    
    // 🔥 USE ENVIRONMENT to get dependencies
    @Environment(AllLivePlayersViewModel.self) private var livePlayersViewModel
    @Environment(PlayerDirectoryStore.self) private var playerDirectory
    @Environment(MatchupsHubViewModel.self) private var matchupsHubViewModel
    
    // 🔥 CREATE ViewModel with environment dependencies
    @State private var playerStatsViewModel: PlayerStatsViewModel?
    
    // 🏈 PLAYER NAVIGATION: Keep original initializer for external navigation
    init(player: SleeperPlayer, team: NFLTeam?) {
        self._currentPlayer = State(initialValue: player)
        self._currentTeam = State(initialValue: team)
    }
    
    var body: some View {
        Group {
            if let viewModel = playerStatsViewModel {
                // 🔧 BLANK SHEET FIX: CRITICAL CHANGE - Conditional view rendering
                if viewModel.isLoadingPlayerData {
                    PlayerStatsLoadingView(
                        player: currentPlayer,
                        team: currentTeam,
                        loadingMessage: viewModel.loadingMessage
                    )
                } else {
                    mainContentView(viewModel: viewModel)
                        .overlay(alignment: .top) {
                            if viewModel.hasLoadingError {
                                timeoutWarningBanner
                            }
                        }
                }
            } else {
                ProgressView("Initializing...")
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // 🔥 CREATE ViewModel with environment dependencies on appear
            if playerStatsViewModel == nil {
                playerStatsViewModel = PlayerStatsViewModel(
                    livePlayersViewModel: livePlayersViewModel,
                    playerDirectory: playerDirectory
                )
            }
        }
        .task(id: currentPlayer.playerID) {
            // 🔧 BLANK SHEET FIX: Initialize ViewModel with player data
            playerStatsViewModel?.setupPlayer(currentPlayer)
        }
    }
    
    // 🏈 PLAYER NAVIGATION: Callback to update current player from depth chart
    private func updateCurrentPlayer(_ newPlayer: SleeperPlayer) {
        currentPlayer = newPlayer
        currentTeam = NFLTeam.team(for: newPlayer.team ?? "")
    }
    
    // MARK: - Main Content View
    
    private func mainContentView(viewModel: PlayerStatsViewModel) -> some View {
        ZStack {
            Image("BG1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    PlayerStatsHeaderView(player: currentPlayer, team: currentTeam)
                        .padding(.horizontal, 24)
                    
                    PlayerLiveStatsView(
                        playerStatsData: viewModel.playerStatsData,
                        team: currentTeam,
                        isLoading: viewModel.isLoadingStats
                    )
                    .padding(.horizontal, 24)
                    
                    PlayerRosteredSectionView(
                        player: currentPlayer, 
                        team: currentTeam,
                        matchups: matchupsHubViewModel.myMatchups
                    )
                        .padding(.horizontal, 24)
                    
                    // 🔥 PURE DI: Pass environment dependency
                    TeamDepthChartView(
                        depthChartData: viewModel.depthChartData,
                        team: currentTeam,
                        onPlayerTap: updateCurrentPlayer,
                        allLivePlayersViewModel: livePlayersViewModel
                    )
                    .padding(.horizontal, 24)
                    
                    PlayerDetailsInfoView(player: currentPlayer)
                        .padding(.horizontal, 24)
                    
                    FantasyAnalysisView(
                        fantasyAnalysisData: viewModel.fantasyAnalysisData
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
    }
    
    // MARK: - 🔧 BLANK SHEET FIX: Timeout Warning Banner
    // Shows if data loading times out but we still want to display partial content
    
    private var timeoutWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("Some stats may be unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}