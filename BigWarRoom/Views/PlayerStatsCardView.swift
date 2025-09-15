//
//  PlayerStatsCardView.swift
//  BigWarRoom
//
//  Clean MVVM coordinator for detailed player stats
//  Refactored from 1,286 lines to ~80 lines with proper separation of concerns
//

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
/// 
/// All business logic has been moved to PlayerStatsViewModel
/// All UI components have been extracted to separate, reusable view files
struct PlayerStatsCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerStatsViewModel = PlayerStatsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with player image and basic info
                PlayerStatsHeaderView(player: player, team: team)
                
                // Live stats section
                PlayerLiveStatsView(
                    playerStatsData: playerStatsViewModel.playerStatsData,
                    team: team,
                    isLoading: playerStatsViewModel.isLoadingStats
                )
                
                // Rostered section
                PlayerRosteredSectionView(player: player, team: team)
                
                // Team depth chart section
                TeamDepthChartView(
                    depthChartData: playerStatsViewModel.depthChartData,
                    team: team
                )
                
                // Player details section
                PlayerDetailsInfoView(player: player)
                
                // Fantasy analysis section
                FantasyAnalysisView(
                    fantasyAnalysisData: playerStatsViewModel.fantasyAnalysisData
                )
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .background(Color(.systemBackground))
        .task {
            // Initialize ViewModel with player data
            playerStatsViewModel.setupPlayer(player)
        }
    }
}