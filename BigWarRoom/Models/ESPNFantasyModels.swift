//
//  ESPNFantasyModels.swift
//  BigWarRoom
//
//  ESPN Fantasy models from working SleepThis implementation
//

import Foundation

// MARK: - ESPN Fantasy Models (from SleepThis - WORKING)

/// Main ESPN Fantasy response structure
struct ESPNFantasyLeagueModel: Codable {
    let teams: [ESPNFantasyTeamModel]
    let schedule: [ESPNFantasyMatchupModel]
}

/// ESPN Fantasy Team
struct ESPNFantasyTeamModel: Codable {
    let id: Int
    let name: String?
    let roster: ESPNFantasyRosterModel?
    let record: ESPNTeamRecordModel?
}

/// ESPN Fantasy Roster
struct ESPNFantasyRosterModel: Codable {
    let entries: [ESPNPlayerEntryModel]
}

/// ESPN Player Entry
struct ESPNPlayerEntryModel: Codable {
    let playerPoolEntry: ESPNPlayerPoolModel
    let lineupSlotId: Int
}

/// ESPN Player Pool Entry  
struct ESPNPlayerPoolModel: Codable {
    let player: ESPNPlayerModel
}

/// ESPN Player
struct ESPNPlayerModel: Codable {
    let id: Int
    let fullName: String
    let proTeamId: Int?
    let stats: [ESPNPlayerStatModel]
    
    /// Convert ESPN proTeamId to NFL team abbreviation
    var nflTeamAbbreviation: String? {
        guard let proTeamId = proTeamId else { return nil }
        
        // ESPN NFL team ID mapping to abbreviations
        let teamMapping: [Int: String] = [
            1: "ATL", 2: "BUF", 3: "CHI", 4: "CIN", 5: "CLE", 6: "DAL",
            7: "DEN", 8: "DET", 9: "GB", 10: "TEN", 11: "IND", 12: "KC",
            13: "LV", 14: "LAR", 15: "MIA", 16: "MIN", 17: "NE", 18: "NO",
            19: "NYG", 20: "NYJ", 21: "PHI", 22: "ARI", 23: "PIT", 24: "LAC",
            25: "SF", 26: "SEA", 27: "TB", 28: "WSH", 29: "CAR", 30: "JAX",
            33: "BAL", 34: "HOU"
        ]
        
        return teamMapping[proTeamId]
    }
}

/// ESPN Player Stat
struct ESPNPlayerStatModel: Codable {
    let scoringPeriodId: Int
    let statSourceId: Int
    let appliedTotal: Double?
}

/// ESPN Team Record
struct ESPNTeamRecordModel: Codable {
    let overall: ESPNOverallRecordModel
}

/// ESPN Overall Record
struct ESPNOverallRecordModel: Codable {
    let wins: Int
    let losses: Int
    let ties: Int?
}

/// ESPN Fantasy Matchup - FIXED: Make 'away' optional to handle bye weeks
struct ESPNFantasyMatchupModel: Codable {
    let id: Int
    let away: ESPNTeamMatchupModel?  // FIXED: Optional for bye weeks
    let home: ESPNTeamMatchupModel
    let winner: String?
    let matchupPeriodId: Int
    let playoffTierType: String?  // NEW: Identifies playoff bracket (WINNERS_BRACKET, LOSERS_BRACKET, etc.)
}

/// ESPN Team Matchup
struct ESPNTeamMatchupModel: Codable {
    let teamId: Int
    let roster: ESPNFantasyRosterModel?
}

// MARK: - ESPN Position Utilities (SleepThis logic)

extension ESPNPlayerEntryModel {
    
    /// Convert ESPN lineup slot ID to position string (from SleepThis)
    var positionString: String {
        switch lineupSlotId {
        case 0: return "QB"
        case 2, 3: return "RB" 
        case 4, 5: return "WR"
        case 6: return "TE"
        case 16: return "D/ST"
        case 17: return "K"
        case 23: return "FLEX"
        default: return "BN"
        }
    }
    
    /// Check if this player is in an active lineup slot (SleepThis logic)
    var isActiveLineup: Bool {
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17]
        return activeSlotsOrder.contains(lineupSlotId)
    }
    
    /// Get player score for a specific week (SleepThis method)
    func getScore(for week: Int) -> Double {
        return playerPoolEntry.player.stats.first { 
            $0.scoringPeriodId == week && $0.statSourceId == 0 
        }?.appliedTotal ?? 0.0
    }
}

// MARK: - ESPN Team Utilities (from SleepThis)

extension ESPNFantasyTeamModel {
    
    /// Calculate active roster score for a specific week (SleepThis logic)
    func activeRosterScore(for week: Int) -> Double {
        guard let roster = roster else { return 0.0 }
        
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17]
        
        return roster.entries
            .filter { activeSlotsOrder.contains($0.lineupSlotId) }
            .reduce(0.0) { sum, entry in
                sum + entry.getScore(for: week)
            }
    }
    
    /// Get bench players for a specific week
    func benchPlayers(for week: Int) -> [ESPNPlayerEntryModel] {
        guard let roster = roster else { return [] }
        
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17]
        
        return roster.entries.filter { !activeSlotsOrder.contains($0.lineupSlotId) }
    }
    
    /// Get active players for a specific week, sorted by position (SleepThis)
    func activePlayers(for week: Int) -> [ESPNPlayerEntryModel] {
        guard let roster = roster else { return [] }
        
        let activeSlotsOrder: [Int] = [0, 2, 3, 4, 5, 6, 23, 16, 17]
        
        return roster.entries
            .filter { activeSlotsOrder.contains($0.lineupSlotId) }
            .sorted { sortOrder($0.lineupSlotId) < sortOrder($1.lineupSlotId) }
    }
    
    private func sortOrder(_ lineupSlotId: Int) -> Int {
        switch lineupSlotId {
        case 0: return 0 // QB
        case 2, 3: return 1 // RB
        case 4, 5: return 2 // WR
        case 6: return 3 // TE
        case 23: return 4 // FLEX
        case 16: return 5 // D/ST
        case 17: return 6 // K
        default: return 7 // Others
        }
    }
}