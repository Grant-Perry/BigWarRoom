//
//  TeamRostersViewModel.swift
//  BigWarRoom
//
//  ViewModel for Team Rosters - extends existing data services
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class TeamRostersViewModel {
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var isLoading = false
    var errorMessage: String?
    var teamRoster: [SleeperPlayer] = []
    var selectedTeam: String = "KC"
    
    // MARK: - Services (extending existing architecture)
    private let playerDirectoryStore = PlayerDirectoryStore.shared
    
    // MARK: - Public Methods
    
    /// Load complete roster for an NFL team
    func loadTeamRoster(for teamCode: String) async {
        isLoading = true
        errorMessage = nil
        selectedTeam = teamCode
        
        do {
            // TODO: Extend existing services to get full NFL team rosters
            // For now, we'll use placeholder logic that gets players from existing data
            let fullRoster = try await getFullTeamRoster(teamCode: teamCode)
            
            teamRoster = fullRoster.sorted(by: { player1, player2 in
                // Sort by position order: QB, RB, WR, TE, K, DST
                let position1Priority = getPositionPriority(player1.position ?? "")
                let position2Priority = getPositionPriority(player2.position ?? "")
                return position1Priority < position2Priority
            })
            
        } catch {
            errorMessage = "Failed to load roster: \(error.localizedDescription)"
            teamRoster = []
        }
        
        isLoading = false
    }
    
    /// Check if a player is owned in any of the user's leagues
    func isPlayerOwned(_ player: SleeperPlayer) -> Bool {
        // TODO: Implement ownership checking logic using existing services
        // This would check across all user's leagues to see if they own this player
        return false // Placeholder
    }
    
    /// Get the leagues where a player is owned
    func getOwnershipInfo(for player: SleeperPlayer) -> [String] {
        // TODO: Return list of league names where player is owned
        return [] // Placeholder
    }
    
    // MARK: - Private Methods
    
    /// Get full roster for an NFL team (extends existing data services)
    private func getFullTeamRoster(teamCode: String) async -> [SleeperPlayer] {
        // TODO: This is where we'd extend existing services
        // For now, return empty array - will implement in next phase
        return []
    }
    
    /// Get position priority for sorting (using existing LineupSlots logic)
    private func getPositionPriority(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 0
        case "RB": return 1
        case "WR": return 2
        case "TE": return 3
        case "K": return 4
        case "DST", "DEF", "D/ST": return 5
        default: return 6
        }
    }
}