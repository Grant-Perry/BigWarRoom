//
//  Models.swift
//  DraftWarRoom
//
//  Domain models for Draft War Room
//
// MARK: -> Domain Models

import Foundation

// MARK: -> Position
enum Position: String, Codable, CaseIterable, Hashable {
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case k = "K"
    case dst = "DST"
}

// MARK: -> Position Filter
enum PositionFilter: String, Codable, CaseIterable, Identifiable, Hashable {
    case all = "ALL"
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case k = "K"
    case dst = "DST"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .qb: return "QB"
        case .rb: return "RB"
        case .wr: return "WR"
        case .te: return "TE"
        case .k: return "K"
        case .dst: return "DST"
        }
    }
}

// MARK: -> Sort Method
enum SortMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case wizard = "WIZARD"
    case rankings = "RANKINGS"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .wizard: return "AI Wizard"
        case .rankings: return "Pure Ranks"
        }
    }
}

// MARK: -> Team
struct Team: Codable, Hashable {
    let code: String
    let name: String
}

// MARK: -> Player
struct Player: Identifiable, Codable, Hashable {
    let id: String
    let firstInitial: String
    let lastName: String
    let position: Position
    let team: String
    let tier: Int // 1 elite ... higher = lower priority

    var shortKey: String {
        return "\(firstInitial.uppercased()) \(lastName.capitalized)"
    }
}

// MARK: -> Pick
struct Pick: Codable, Hashable {
    let overall: Int
    let player: Player
    let timestamp: Date
}

// MARK: -> LeagueSettings
struct LeagueSettings: Codable, Hashable {
    var fullPPR: Bool = true
    var rosterSpots: Int = 15
}

// MARK: -> Roster
struct Roster: Codable, Hashable {
    var qb: Player?
    var rb1: Player?
    var rb2: Player?
    var wr1: Player?
    var wr2: Player?
    var wr3: Player?
    var te: Player?
    var flex: Player?
    var k: Player?
    var dst: Player?
    var bench: [Player] = []

    mutating func add(_ player: Player) {
        switch player.position {
        case .qb:
            if qb == nil { qb = player } else { bench.append(player) }
        case .rb:
            if rb1 == nil { rb1 = player }
            else if rb2 == nil { rb2 = player }
            else if flex == nil { flex = player }
            else { bench.append(player) }
        case .wr:
            if wr1 == nil { wr1 = player }
            else if wr2 == nil { wr2 = player }
            else if wr3 == nil { wr3 = player }
            else if flex == nil { flex = player }
            else { bench.append(player) }
        case .te:
            if te == nil { te = player }
            else if flex == nil { flex = player }
            else { bench.append(player) }
        case .k:
            if k == nil { k = player } else { bench.append(player) }
        case .dst:
            if dst == nil { dst = player } else { bench.append(player) }
        }
    }
}