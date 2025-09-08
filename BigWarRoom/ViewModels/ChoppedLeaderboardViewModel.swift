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
    
    // MARK: - Personal Stats (NEW!) 
    
    /// Find the authenticated user's team ranking
    var myTeamRanking: FantasyTeamRanking? {
        // Strategy 1: Try to find by authenticated user patterns
        let authenticatedUsername = SleeperCredentialsManager.shared.currentUsername
        
        if !authenticatedUsername.isEmpty {
            if let myRanking = choppedSummary.rankings.first(where: { 
                $0.team.ownerName.lowercased() == authenticatedUsername.lowercased() 
            }) {
                return myRanking
            }
        }
        
        // Strategy 2: Look for "Gp" pattern (your specific case)
        if let gpRanking = choppedSummary.rankings.first(where: { 
            $0.team.ownerName.lowercased().contains("gp") 
        }) {
            return gpRanking
        }
        
        // Strategy 3: Look for patterns like "Lamarvelous" or "King"
        if let lamarRanking = choppedSummary.rankings.first(where: { 
            $0.team.ownerName.lowercased().contains("lamar") ||
            $0.team.ownerName.lowercased().contains("king")
        }) {
            return lamarRanking
        }
        
        // Fallback: Return first team
        return choppedSummary.rankings.first
    }
    
    /// Your rank display (e.g., "1ST", "2ND", "3RD")
    var myRankDisplay: String {
        guard let myTeam = myTeamRanking else { return "?" }
        
        let rank = myTeam.rank
        switch rank {
        case 1:
            return "1ST"
        case 2:
            return "2ND"  
        case 3:
            return "3RD"
        default:
            return "\(rank)TH"
        }
    }
    
    /// Your score display with formatting
    var myScoreDisplay: String {
        guard let myTeam = myTeamRanking else { return "0.0" }
        return String(format: "%.1f", myTeam.weeklyPoints)
    }
    
    /// Your status color based on elimination status
    var myStatusColor: Color {
        guard let myTeam = myTeamRanking else { return .gray }
        
        switch myTeam.eliminationStatus {
        case .champion:
            return .yellow
        case .safe:
            return .green
        case .warning:
            return .blue
        case .danger:
            return .orange
        case .critical:
            return .red
        case .eliminated:
            return .gray
        }
    }
    
    /// Your status emoji based on elimination status
    var myStatusEmoji: String {
        guard let myTeam = myTeamRanking else { return "❓" }
        
        switch myTeam.eliminationStatus {
        case .champion:
            return "👑"
        case .safe:
            return "🛡️"
        case .warning:
            return "⚡"
        case .danger:
            return "⚠️"
        case .critical:
            return "💀"
        case .eliminated:
            return "🪦"
        }
    }
    
    /// Your status text based on elimination status
    var myStatusText: String {
        guard let myTeam = myTeamRanking else { return "UNKNOWN" }
        
        switch myTeam.eliminationStatus {
        case .champion:
            return "CHAMPION"
        case .safe:
            return "SAFE"
        case .warning:
            return "WARNING"
        case .danger:
            return "DANGER"
        case .critical:
            return "CRITICAL"
        case .eliminated:
            return "ELIMINATED"
        }
    }
    
    /// Check if your team is in danger (for pulsing animation)
    var isMyTeamInDanger: Bool {
        guard let myTeam = myTeamRanking else { return false }
        return myTeam.eliminationStatus == .critical || myTeam.eliminationStatus == .danger
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