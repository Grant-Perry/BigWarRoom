//
//  RosterViewModel.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//  🔥 REFACTORED: Now uses ColorThemeService for DRY compliance
//

import SwiftUI
import Foundation
import Observation

/// ViewModel for RosterView with business logic
@Observable
@MainActor
final class RosterViewModel {
    
    // MARK: - Dependencies
    private let draftRoomViewModel: DraftRoomViewModel
    
    // 🔥 DRY: Use centralized ColorThemeService
    private let colorService = ColorThemeService.shared
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var expandedTeam: Int? = nil
    var selectedPlayerForStats: SleeperPlayer?
    var showingPlayerStats = false
    
    // MARK: - Styling Properties
    var boxGradient = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color.gpBlueDarkL, location: 0.0),
            .init(color: Color.clear, location: 1.0)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    var boxForeColor = Color.gpYellow
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
    }
    
    // MARK: - Computed Properties
    
    var uniqueTeamCount: Int {
        Set(draftRoomViewModel.allDraftPicks.map { $0.draftSlot }).count
    }
    
    var picksByTeam: [Int: [EnhancedPick]] {
        Dictionary(grouping: draftRoomViewModel.allDraftPicks) { $0.draftSlot }
    }
    
    var sortedTeamSlots: [Int] {
        picksByTeam.keys.sorted()
    }
    
    // MARK: - Team Management
    
    func expandAllTeams() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // For expand all, we'll just expand the first team
            let allTeamSlots = Set(draftRoomViewModel.allDraftPicks.map { $0.draftSlot })
            expandedTeam = allTeamSlots.sorted().first
        }
    }
    
    func collapseAllTeams() {
        withAnimation(.easeInOut(duration: 0.3)) {
            expandedTeam = nil
        }
    }
    
    func toggleTeamExpansion(teamSlot: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if expandedTeam == teamSlot {
                // If this team is already expanded, collapse it
                expandedTeam = nil
            } else {
                // Expand this team (automatically collapses any other)
                expandedTeam = teamSlot
            }
        }
    }
    
    // MARK: - Team Display Logic
    
    /// Get team/manager display name using ViewModel's public method - show first names only
    func teamDisplayName(for teamSlot: Int, from picks: [EnhancedPick]) -> String {
        let fullName = draftRoomViewModel.teamDisplayName(for: teamSlot)
        
        // Extract first name from the full manager name
        let components = fullName.components(separatedBy: " ")
        if let firstName = components.first, !firstName.isEmpty {
            // Check if it's a meaningful first name (not generic like "Team" or "Manager")
            if !firstName.lowercased().hasPrefix("team") && 
               !firstName.lowercased().hasPrefix("manager") && 
               firstName.count > 1 {
                return firstName
            }
        }
        
        // Fallback to full name if we can't extract a meaningful first name
        return fullName
    }
    
    // MARK: - Position Management
    
    /// Organize picks by fantasy position
    func organizeRosterByPosition(_ picks: [EnhancedPick]) -> [String: [EnhancedPick]] {
        return Dictionary(grouping: picks) { pick in
            pick.position.uppercased()
        }
    }
    
    /// Standard fantasy roster position order
    var rosterPositionOrder: [String] {
        return ["QB", "RB", "WR", "TE", "K", "DEF", "DST"]
    }
    
    func positionColor(_ position: String) -> Color {
        // 🔥 DRY: Delegate to ColorThemeService
        return colorService.positionColor(for: position)
    }
    
    // MARK: - Player Stats
    
    func showPlayerStats(for player: SleeperPlayer) {
        selectedPlayerForStats = player
        showingPlayerStats = true
    }
}