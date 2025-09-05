//
//  ChoppedLeaderboardViewModel.swift
//  BigWarRoom
//
//  💀🔥 CHOPPED LEADERBOARD VIEWMODEL 🔥💀
//  Business logic for the most INSANE elimination fantasy experience
//

import SwiftUI
import Combine

/// **ChoppedLeaderboardViewModel**
/// 
/// Handles all business logic, animations, and state management for the Chopped Leaderboard.
/// Follows MVVM pattern to keep views clean and focused on presentation.
@MainActor
class ChoppedLeaderboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var showEliminationCeremony = false
    @Published var pulseAnimation = false
    @Published var dangerPulse = false
    
    // MARK: - Data Properties
    let choppedSummary: ChoppedWeekSummary
    let leagueName: String
    
    // MARK: - Initialization
    init(choppedSummary: ChoppedWeekSummary, leagueName: String) {
        self.choppedSummary = choppedSummary
        self.leagueName = leagueName
    }
    
    // MARK: - Business Logic Methods
    
    /// Start all dramatic animations when view appears
    func startAnimations() {
        pulseAnimation = true
        dangerPulse = true
    }
    
    /// Show the elimination ceremony modal
    func showEliminationCeremonyModal() {
        showEliminationCeremony = true
    }
    
    /// Dismiss the elimination ceremony modal
    func dismissEliminationCeremony() {
        showEliminationCeremony = false
    }
    
    // MARK: - Computed Properties for Business Logic
    
    /// Determines if we should show the apocalyptic danger background
    var shouldShowDangerBackground: Bool {
        !choppedSummary.criticalTeams.isEmpty
    }
    
    /// Determines if elimination ceremony button should be shown
    var shouldShowEliminationCeremonyButton: Bool {
        choppedSummary.isComplete && choppedSummary.eliminatedTeam != nil
    }
    
    /// Format elimination line score for display
    var eliminationLineDisplay: String {
        String(format: "%.1f", choppedSummary.cutoffScore)
    }
    
    /// Format average score for display
    var averageScoreDisplay: String {
        String(format: "%.1f", choppedSummary.averageScore)
    }
    
    /// Format top score for display
    var topScoreDisplay: String {
        String(format: "%.1f", choppedSummary.highestScore)
    }
    
    /// Get league name in dramatic uppercase format
    var dramaticLeagueName: String {
        leagueName.uppercased()
    }
    
    /// Get current week display
    var weekDisplay: String {
        "WEEK \(choppedSummary.week)"
    }
    
    /// Get total survivors count
    var survivorsCount: String {
        "\(choppedSummary.totalSurvivors)"
    }
    
    /// Get eliminated count
    var eliminatedCount: String {
        "\(choppedSummary.eliminatedTeams.count)"
    }
    
    /// Get danger zone count
    var dangerZoneCount: String {
        "\(choppedSummary.dangerZoneTeams.count)"
    }
    
    /// Get fallen count from history
    var fallenCount: String {
        "\(choppedSummary.eliminationHistory.count)"
    }
    
    // MARK: - Section Visibility Logic
    
    var hasChampion: Bool {
        choppedSummary.champion != nil
    }
    
    var hasSafeTeams: Bool {
        !choppedSummary.safeTeams.isEmpty
    }
    
    var hasWarningTeams: Bool {
        !choppedSummary.warningTeams.isEmpty
    }
    
    var hasDangerZoneTeams: Bool {
        !choppedSummary.dangerZoneTeams.isEmpty
    }
    
    var hasCriticalTeams: Bool {
        !choppedSummary.criticalTeams.isEmpty
    }
    
    var hasEliminationHistory: Bool {
        !choppedSummary.eliminationHistory.isEmpty
    }
}