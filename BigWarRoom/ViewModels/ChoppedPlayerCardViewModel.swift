//
//  ChoppedPlayerCardViewModel.swift
//  BigWarRoom
//
//  🏈 CHOPPED PLAYER CARD VIEW MODEL 🏈
//  Handles player-specific business logic for player cards
//

import SwiftUI
import Foundation
import Combine

/// **ChoppedPlayerCardViewModel**
/// 
/// MVVM ViewModel for individual player card logic:
/// - Player image handling
/// - Stats display formatting
/// - Team color and styling logic
/// - Positional rankings within team lineup
@MainActor
class ChoppedPlayerCardViewModel: ObservableObject {
    
    let player: FantasyPlayer
    let isStarter: Bool
    private let parentViewModel: ChoppedTeamRosterViewModel
    
    // MARK: - Initialization
    
    init(player: FantasyPlayer, isStarter: Bool, parentViewModel: ChoppedTeamRosterViewModel) {
        self.player = player
        self.isStarter = isStarter
        self.parentViewModel = parentViewModel
    }
    
    // MARK: - Computed Properties
    
    /// Get the NFL team for this player
    var nflTeam: NFLTeam? {
        return NFLTeam.team(for: player.team ?? "")
    }
    
    /// Get the team's primary color
    var teamPrimaryColor: Color {
        return nflTeam?.primaryColor ?? .purple
    }
    
    /// Get the team gradient
    var teamGradient: LinearGradient {
        return nflTeam?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom)
    }
    
    /// Get the jersey number for display
    var jerseyNumber: String {
        return player.jerseyNumber ?? parentViewModel.findSleeperPlayer(for: player)?.number?.description ?? ""
    }
    
    /// Get actual player points if available
    var actualPoints: Double? {
        return parentViewModel.getActualPlayerPoints(for: player)
    }
    
    /// Get formatted stat breakdown
    var statBreakdown: String? {
        return parentViewModel.formatPlayerStatBreakdown(player)
    }
    
    /// Check if we should show stats
    var shouldShowStats: Bool {
        return isStarter && parentViewModel.hasWeekStarted() && actualPoints != nil && actualPoints! > 0 && statBreakdown != nil
    }
    
    /// Get the Sleeper player for this fantasy player
    var sleeperPlayer: SleeperPlayer? {
        return parentViewModel.findSleeperPlayer(for: player)
    }
    
    /// Get the badge text - now returns positional rankings for starters (QB1, RB1, RB2, etc.)
    var badgeText: String {
        if isStarter {
            return getPositionalRanking()
        } else {
            return "BENCH"
        }
    }
    
    /// Get the badge color
    var badgeColor: Color {
        return isStarter ? Color.green : Color.gray
    }
    
    // MARK: - Private Methods
    
    /// Calculate positional ranking within the team's starting lineup (QB1, RB1, RB2, etc.)
    private func getPositionalRanking() -> String {
        guard isStarter,
              let rosterData = parentViewModel.rosterData else {
            return player.position.uppercased()
        }
        
        // Get all starters with the same position, sorted by points (descending)
        let samePositionStarters = rosterData.starters
            .filter { $0.position.uppercased() == player.position.uppercased() }
            .sorted { player1, player2 in
                let points1 = parentViewModel.getActualPlayerPoints(for: player1) ?? 0.0
                let points2 = parentViewModel.getActualPlayerPoints(for: player2) ?? 0.0
                return points1 > points2
            }
        
        // Find this player's rank within their position
        if let playerIndex = samePositionStarters.firstIndex(where: { $0.id == player.id }) {
            let rank = playerIndex + 1
            return "\(player.position.uppercased())\(rank)"
        }
        
        // Fallback to just the position
        return player.position.uppercased()
    }
}