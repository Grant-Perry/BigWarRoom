//
//  EnhancedPick.swift
//  BigWarRoom
//
//  UI-friendly draft pick model enriched with player and team context
//

import Foundation

struct EnhancedPick: Identifiable {
    let id: String
    let pickNumber: Int
    let round: Int
    let draftSlot: Int
    let position: String
    let teamCode: String
    let team: NFLTeam?
    let player: SleeperPlayer
    let displayName: String
    let rosterInfo: DraftRosterInfo?
    let pickInRound: Int
    
    var pickDescription: String {
        "Pick \(pickNumber)"
    }
}