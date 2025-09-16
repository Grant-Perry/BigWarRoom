//
//  MyRosterViewModel.swift
//  BigWarRoom
//
//  ViewModel for MyRosterView - handles all business logic and computed properties
//

import SwiftUI
import Foundation
import Combine

/// ViewModel responsible for MyRosterView business logic and data transformation
@MainActor
final class MyRosterViewModel: ObservableObject {
    @Published var selectedPlayer: SleeperPlayer?
    @Published var showStats = false
    @Published var showStartingLineup = true
    @Published var showBench = true
    
    private let draftRoomViewModel: DraftRoomViewModel
    
    init(draftRoomViewModel: DraftRoomViewModel) {
        self.draftRoomViewModel = draftRoomViewModel
    }
    
    // MARK: - Roster Title & Subtitle
    
    var rosterTitle: String {
        if draftRoomViewModel.selectedDraft != nil && draftRoomViewModel.isLiveMode {
            return "My \(draftRoomViewModel.selectedDraft?.name ?? "Draft") Roster"
        } else {
            return "My Roster"
        }
    }
    
    var rosterSubtitle: String {
        if draftRoomViewModel.selectedDraft != nil && draftRoomViewModel.isLiveMode {
            return "Live roster from \(draftRoomViewModel.sleeperDisplayName)'s draft"
        } else {
            return "Build your roster or connect to a live draft • Tap players for stats"
        }
    }
    
    // MARK: - Draft Status Properties
    
    var isLiveMode: Bool { draftRoomViewModel.isLiveMode }
    var isMyTurn: Bool { draftRoomViewModel.isMyTurn }
    var selectedDraft: SleeperLeague? { draftRoomViewModel.selectedDraft }
    
    // MARK: - Roster Statistics
    
    var filledSlots: Int {
        let roster = draftRoomViewModel.roster
        return [roster.qb, roster.rb1, roster.rb2, roster.wr1, roster.wr2, roster.wr3, 
                roster.te, roster.flex, roster.k, roster.dst].compactMap { $0 }.count
    }
    
    var benchCount: Int {
        draftRoomViewModel.roster.bench.count
    }
    
    var totalPlayers: Int {
        filledSlots + benchCount
    }
    
    var pickDisplayText: String {
        if let draftSlot = draftRoomViewModel.myRosterID, draftRoomViewModel.isUsingPositionalLogic {
            return "\(draftSlot)"
        } else if let rosterID = draftRoomViewModel.myRosterID {
            return "\(rosterID)"
        } else {
            return "—"
        }
    }
    
    // MARK: - Roster Data Access
    
    var roster: Roster {
        draftRoomViewModel.roster
    }
    
    var startingLineupSlots: [(label: String, player: Player?)] {
        [
            ("QB", roster.qb),
            ("RB1", roster.rb1),
            ("RB2", roster.rb2),
            ("WR1", roster.wr1),
            ("WR2", roster.wr2),
            ("WR3", roster.wr3),
            ("TE", roster.te),
            ("FLEX", roster.flex),
            ("K", roster.k),
            ("DST", roster.dst)
        ]
    }
    
    var benchPlayers: [Player] {
        roster.bench
    }
    
    // MARK: - Player Matching Logic
    
    /// Attempts to match the internal Player to a SleeperPlayer for richer display
    func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        let directory = PlayerDirectoryStore.shared
        let allPlayers = directory.players.values
        
        // Direct ID match
        if let directMatch = directory.players[player.id] {
            return directMatch
        }
        
        // Exact name + position + team match
        if let exactMatch = allPlayers.first(where: { sp in
            let nameMatches = sp.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sp.position?.uppercased() == player.position.rawValue
            let teamMatches = sp.team?.uppercased() == player.team.uppercased()
            return nameMatches && positionMatches && teamMatches
        }) {
            return exactMatch
        }
        
        // Fuzzy name matching with team verification
        if let fuzzyMatch = allPlayers.first(where: { sp in
            guard let spFirst = sp.firstName, let spLast = sp.lastName else { return false }
            let firstInitialMatches = spFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = spLast.lowercased().contains(player.lastName.lowercased()) ||
                                  player.lastName.lowercased().contains(spLast.lowercased())
            let teamMatches = sp.team?.uppercased() == player.team.uppercased()
            return firstInitialMatches && lastNameMatches && teamMatches
        }) {
            return fuzzyMatch
        }
        
        return nil
    }
    
    // MARK: - Actions
    
    func toggleStartingLineup() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showStartingLineup.toggle()
        }
    }
    
    func toggleBench() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showBench.toggle()
        }
    }
    
    func presentPlayerStats(for player: Player) {
        guard let sleeperPlayer = findSleeperPlayer(for: player) else { return }
        selectedPlayer = sleeperPlayer
        showStats = true
    }
    
    func dismissStats() {
        selectedPlayer = nil
        showStats = false
    }
}