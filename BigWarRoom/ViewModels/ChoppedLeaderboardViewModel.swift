//
//  ChoppedLeaderboardViewModel.swift
//  BigWarRoom
//
//  💀🔥 CHOPPED LEADERBOARD VIEWMODEL 🔥💀
//  Business logic for the most INSANE elimination fantasy experience
//

import SwiftUI
import Observation

/// **ChoppedLeaderboardViewModel**
/// 
/// Handles all business logic, animations, and state management for the Chopped Leaderboard.
/// Follows MVVM pattern to keep views clean and focused on presentation.
@Observable
@MainActor
final class ChoppedLeaderboardViewModel {
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var showEliminationCeremony = false
    var pulseAnimation = false
    var dangerPulse = false
    
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
    
    /// Check if the week has started (any scoring has happened)
    var hasWeekStarted: Bool {
        return !choppedSummary.isScheduled
    }
    
    /// Determines if we should show survival stats (only if week has started)
    var shouldShowSurvivalStats: Bool {
        return hasWeekStarted
    }
    
    /// Determines if we should show the apocalyptic danger background
    var shouldShowDangerBackground: Bool {
        hasWeekStarted && !choppedSummary.criticalTeams.isEmpty
    }
    
    /// Determines if elimination ceremony button should be shown
    var shouldShowEliminationCeremonyButton: Bool {
        choppedSummary.isComplete && choppedSummary.eliminatedTeam != nil
    }
    
    /// Format elimination line score for display (only if week started)
    var eliminationLineDisplay: String {
        guard hasWeekStarted else { return "--" }
        return String(format: "%.1f", choppedSummary.cutoffScore)
    }
    
    /// Format average score for display (only if week started)
    var averageScoreDisplay: String {
        guard hasWeekStarted else { return "--" }
        return String(format: "%.1f", choppedSummary.averageScore)
    }
    
    /// Format top score for display (only if week started)
    var topScoreDisplay: String {
        guard hasWeekStarted else { return "--" }
        return String(format: "%.1f", choppedSummary.highestScore)
    }
    
    /// Get week status display
    var weekStatusDisplay: String {
        if hasWeekStarted {
            return "ELIMINATION ROUND"
        } else {
            return "WAITING FOR GAMES"
        }
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
//        if let lamarRanking = choppedSummary.rankings.first(where: { 
//            $0.team.ownerName.lowercased().contains("lamar") ||
//            $0.team.ownerName.lowercased().contains("king")
//        }) {
//            return lamarRanking
//        }
        
        // Fallback: Return first team
        return choppedSummary.rankings.first
    }
    
    /// Your rank display (e.g., "1ST", "2ND", "3RD")
    var myRankDisplay: String {
        guard let myTeam = myTeamRanking else { return "?" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        
        // Ensure rank is treated as NSNumber for the formatter
        let rankNumber = NSNumber(value: myTeam.rank)
        
        // Format and make uppercase to match the UI style
        if let formattedRank = formatter.string(from: rankNumber) {
            return formattedRank.uppercased()
        }
        
        // Fallback for safety, though it should never be needed
        return "\(myTeam.rank)TH"
    }

    /// Your score display with formatting (handle pre-game state)
    var myScoreDisplay: String {
        guard let myTeam = myTeamRanking else { return "--" }
        guard hasWeekStarted else { return "--" }
        return String(format: "%.1f", myTeam.weeklyPoints)
    }
    
    /// Your status color based on elimination status (gray if week hasn't started)
    var myStatusColor: Color {
        guard let myTeam = myTeamRanking else { return .gray }
        guard hasWeekStarted else { return .gray }
        
        switch myTeam.eliminationStatus {
        case .champion:
            return .gpYellow
        case .safe:
            return .gpGreen
        case .warning:
            return .gpBlue
        case .danger:
            return .gpOrange
        case .critical:
            return .gpRedPink
        case .eliminated:
            return .gray
        }
    }

   var myForeColor: Color {
        guard let myTeam = myTeamRanking else { return .gray }
        guard hasWeekStarted else { return .gray }
        
        switch myTeam.eliminationStatus {
		   case .champion, .safe:
			  return .black
		   case .warning, .danger, .critical, .eliminated:
			  return .gpWhite
        }
    }
    
    /// Your status emoji based on elimination status (waiting if week hasn't started)
    var myStatusEmoji: String {
        guard let myTeam = myTeamRanking else { return "❓" }
        guard hasWeekStarted else { return "⏰" }
        
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
    
    /// Your status text based on elimination status (waiting if week hasn't started)
    var myStatusText: String {
        guard let myTeam = myTeamRanking else { return "UNKNOWN" }
        guard hasWeekStarted else { return "WAITING" }
        
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
    
    /// Check if your team is in danger (for pulsing animation) - only if week started
    var isMyTeamInDanger: Bool {
        guard let myTeam = myTeamRanking else { return false }
        guard hasWeekStarted else { return false }
        return myTeam.eliminationStatus == .critical || myTeam.eliminationStatus == .danger
    }
    
    /// Your elimination delta (points from elimination line)
    var myEliminationDelta: String? {
        guard let myTeam = myTeamRanking else { return nil }
        guard hasWeekStarted else { return nil }
        return myTeam.safetyMarginDisplay
    }
    
    /// Your elimination delta color (green if safe, red if in danger)
    var myEliminationDeltaColor: Color {
        guard let myTeam = myTeamRanking else { return .gray }
        guard hasWeekStarted else { return .gray }
        return myTeam.pointsFromSafety >= 0 ? .green : .red
    }
    
    // MARK: - Section Visibility Logic
    
    var hasChampion: Bool {
        hasWeekStarted && choppedSummary.champion != nil
    }
    
    var hasSafeTeams: Bool {
        hasWeekStarted && !choppedSummary.safeTeams.isEmpty
    }
    
    var hasWarningTeams: Bool {
        hasWeekStarted && !choppedSummary.warningTeams.isEmpty
    }
    
    var hasDangerZoneTeams: Bool {
        hasWeekStarted && !choppedSummary.dangerZoneTeams.isEmpty
    }
    
    var hasCriticalTeams: Bool {
        hasWeekStarted && !choppedSummary.criticalTeams.isEmpty
    }
    
    var hasEliminationHistory: Bool {
        !choppedSummary.eliminationHistory.isEmpty
    }
}