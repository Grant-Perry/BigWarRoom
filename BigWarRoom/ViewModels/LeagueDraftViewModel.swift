//
//  LeagueDraftViewModel.swift
//  BigWarRoom
//
//  ViewModel for LeagueDraftView - handles all business logic and computations
//

import SwiftUI
import Foundation
import Combine

/// ViewModel responsible for LeagueDraftView business logic and data organization
@MainActor
final class LeagueDraftViewModel: ObservableObject {
    @Published var showingRosterView = false
    @Published var selectedPlayerForStats: SleeperPlayer?
    @Published var showingPlayerStats = false
    
    private let draftRoomViewModel: DraftRoomViewModel
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
    }
    
    // MARK: - Draft Properties
    
    var selectedDraft: SleeperLeague? {
        draftRoomViewModel.selectedDraft
    }
    
    var allDraftPicks: [EnhancedPick] {
        draftRoomViewModel.allDraftPicks
    }
    
    var myRosterID: Int? {
        draftRoomViewModel.myRosterID
    }
    
    var selectedLeagueWrapper: UnifiedLeagueManager.LeagueWrapper? {
        draftRoomViewModel.selectedLeagueWrapper
    }
    
    var currentDraftTeamCount: Int {
        draftRoomViewModel.currentDraftTeamCount
    }
    
    // MARK: - Draft Statistics
    
    var totalPicksCount: Int {
        allDraftPicks.count
    }
    
    var expectedTotalPicks: Int? {
        guard let league = selectedDraft else { return nil }
        // Estimate 15 rounds * number of teams (common draft format)
        return league.totalRosters * 15
    }
    
    var draftProgressPercentage: Double {
        guard let expected = expectedTotalPicks, expected > 0 else { return 0.0 }
        return min(max(Double(totalPicksCount), 0), Double(expected)) / Double(expected)
    }
    
    // MARK: - Draft Organization
    
    var picksByRound: [Int: [EnhancedPick]] {
        Dictionary(grouping: allDraftPicks) { $0.round }
    }
    
    var sortedRounds: [Int] {
        picksByRound.keys.sorted()
    }
    
    func picks(for round: Int) -> [EnhancedPick] {
        picksByRound[round] ?? []
    }
    
    func sortedPicks(for round: Int) -> [EnhancedPick] {
        picks(for: round).sorted { $0.pickNumber < $1.pickNumber }
    }
    
    // MARK: - Team Display
    
    func teamDisplayName(for draftSlot: Int) -> String {
        draftRoomViewModel.teamDisplayName(for: draftSlot)
    }
    
    // MARK: - Pick Analysis
    
    func isMyPick(_ pick: EnhancedPick) -> Bool {
        guard let myRosterID = myRosterID else { return false }
        
        // For ESPN leagues using positional logic, ONLY use positional matching
        if pick.rosterInfo == nil || selectedLeagueWrapper?.source == .espn {
            // Pure positional logic match (for ESPN leagues using positional logic)
            let teamCount = currentDraftTeamCount
            let draftSlot = myRosterID // For positional logic, myRosterID represents draft slot
            
            // Calculate if this pick number belongs to our draft position
            let round = ((pick.pickNumber - 1) / teamCount) + 1
            
            if round % 2 == 1 {
                // Odd rounds: normal order
                let expectedSlot = ((pick.pickNumber - 1) % teamCount) + 1
                return expectedSlot == draftSlot
            } else {
                // Even rounds: snake order
                let expectedSlot = teamCount - ((pick.pickNumber - 1) % teamCount)
                return expectedSlot == draftSlot
            }
        }
        
        // Strategy 1: Direct roster ID match (for Sleeper leagues with real roster correlation)
        if let rosterInfo = pick.rosterInfo {
            return rosterInfo.rosterID == myRosterID
        }
        
        return false
    }
    
    // MARK: - Player Matching Logic
    
    func findRealSleeperPlayer(for pick: EnhancedPick) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Strategy 1: Direct ID match (if it's already a real Sleeper player)
        if let directMatch = PlayerDirectoryStore.shared.players[pick.player.playerID] {
            return directMatch
        }
        
        // For ESPN/fake players, try to match by name and team
        if let firstName = pick.player.firstName,
           let lastName = pick.player.lastName,
           let team = pick.player.team,
           let position = pick.player.position {
            
            // Strategy 2: Exact name, team, and position match
            let exactMatch = allSleeperPlayers.first { sleeperPlayer in
                let firstNameMatches = sleeperPlayer.firstName?.lowercased() == firstName.lowercased()
                let lastNameMatches = sleeperPlayer.lastName?.lowercased() == lastName.lowercased()
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                let positionMatches = sleeperPlayer.position?.uppercased() == position.uppercased()
                
                return firstNameMatches && lastNameMatches && teamMatches && positionMatches
            }
            
            if let exactMatch = exactMatch {
                return exactMatch
            }
            
            // Strategy 3: Fuzzy name match with team (handles name variations)
            let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperFirst = sleeperPlayer.firstName,
                      let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == firstName.prefix(1).uppercased()
                let lastNameContains = sleeperLast.lowercased().contains(lastName.lowercased()) || 
                                       lastName.lowercased().contains(sleeperLast.lowercased())
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                
                return firstInitialMatches && lastNameContains && teamMatches
            }
            
            if let fuzzyMatch = fuzzyMatch {
                return fuzzyMatch
            }
            
            // Strategy 4: Team + position match for common names
            let teamPositionMatch = allSleeperPlayers.first { sleeperPlayer in
                guard let sleeperLast = sleeperPlayer.lastName else { return false }
                
                let lastNameMatches = sleeperLast.lowercased() == lastName.lowercased()
                let teamMatches = sleeperPlayer.team?.uppercased() == team.uppercased()
                let positionMatches = sleeperPlayer.position?.uppercased() == position.uppercased()
                
                return lastNameMatches && teamMatches && positionMatches
            }
            
            return teamPositionMatch
        }
        
        return nil
    }
    
    // MARK: - Actions
    
    func showRosterView() {
        showingRosterView = true
    }
    
    func hideRosterView() {
        showingRosterView = false
    }
    
    func presentPlayerStats(for player: SleeperPlayer) {
        selectedPlayerForStats = player
        showingPlayerStats = true
    }
    
    func dismissPlayerStats() {
        selectedPlayerForStats = nil
        showingPlayerStats = false
    }
}