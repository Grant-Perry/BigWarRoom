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
    @State private var playerStatsViewModel = PlayerStatsViewModel()
    
    // 🏈 PLAYER NAVIGATION: Keep original initializer for external navigation
    init(player: SleeperPlayer, team: NFLTeam?) {
        self._currentPlayer = State(initialValue: player)
        self._currentTeam = State(initialValue: team)
    }
    
    var body: some View {
        // 🔧 BLANK SHEET FIX: CRITICAL CHANGE - Conditional view rendering
        // BEFORE: Always showed mainContentView (which was blank during loading)
        // AFTER: Shows loading view during data loading, then switches to main content
        Group {
            if playerStatsViewModel.isLoadingPlayerData {
                // 🔧 BLANK SHEET FIX: Show loading view instead of blank screen
                // This displays player info + loading spinner immediately when sheet opens
                PlayerStatsLoadingView(
                    player: currentPlayer,
                    team: currentTeam,
                    loadingMessage: playerStatsViewModel.loadingMessage
                )
            } else {
                // 🔧 BLANK SHEET FIX: Show main content once loaded (even with partial data after timeout)
                mainContentView
                    .overlay(alignment: .top) {
                        // 🔧 BLANK SHEET FIX: Show timeout warning banner if loading failed but we have partial data
                        if playerStatsViewModel.hasLoadingError {
                            timeoutWarningBanner
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task(id: currentPlayer.playerID) { // 🏈 PLAYER NAVIGATION: Re-run task when player changes
            // 🔧 BLANK SHEET FIX: Initialize ViewModel with player data
            // This triggers the loading process which will set isLoadingPlayerData = true
            playerStatsViewModel.setupPlayer(currentPlayer)
        }
    }
    
    // 🏈 PLAYER NAVIGATION: Callback to update current player from depth chart
    private func updateCurrentPlayer(_ newPlayer: SleeperPlayer) {
        // Update the current player and team
        currentPlayer = newPlayer
        currentTeam = NFLTeam.team(for: newPlayer.team ?? "")
        
        // ViewModel will automatically reload due to task(id: currentPlayer.playerID)
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
    
    // MARK: - Main Content View (Unchanged - original implementation)
    
    private var mainContentView: some View {
        ZStack {
            // BG1 background
            Image("BG1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.25)
                .ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with player image and basic info
                    PlayerStatsHeaderView(player: currentPlayer, team: currentTeam)
                        .padding(.horizontal, 24) // Much more padding to header
                    
                    // Live stats section
                    PlayerLiveStatsView(
                        playerStatsData: playerStatsViewModel.playerStatsData,
                        team: currentTeam,
                        isLoading: playerStatsViewModel.isLoadingStats
                    )
                    .padding(.horizontal, 24) // Much more padding to each section
                    
                    // Rostered section
                    PlayerRosteredSectionView(
                        player: currentPlayer, 
                        team: currentTeam,
                        matchups: MatchupsHubViewModel.shared.myMatchups // Pass matchups data
                    )
                        .padding(.horizontal, 24) // Much more padding to each section
                    
                    // Team depth chart section
                    TeamDepthChartView(
                        depthChartData: playerStatsViewModel.depthChartData,
                        team: currentTeam,
                        onPlayerTap: updateCurrentPlayer // 🏈 PLAYER NAVIGATION: Pass callback down
                    )
                    .padding(.horizontal, 24) // Much more padding to each section
                    
                    // Player details section
                    PlayerDetailsInfoView(player: currentPlayer)
                        .padding(.horizontal, 24) // Much more padding to each section
                    
                    // Fantasy analysis section
                    FantasyAnalysisView(
                        fantasyAnalysisData: playerStatsViewModel.fantasyAnalysisData
                    )
                    .padding(.horizontal, 24) // Much more padding to each section
                }
                .padding(.horizontal, 32) // PLUS the existing container padding
                .padding(.vertical, 24)
            }
        }
    }
}