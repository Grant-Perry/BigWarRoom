//
//  LineupSlots.swift  
//  BigWarRoom
//
//  Centralized lineup slot constants and utilities
//

import Foundation

/// **LineupSlots**
/// 
/// Centralized constants for lineup slot management across ESPN and Sleeper
struct LineupSlots {
    
    // MARK: - Active Slot Lists
    
    /// Active starter lineup slots (not bench/IR)
    static let activeSlots: [Int] = [
        0,  // QB
        2,  // RB  
        4,  // WR
        6,  // TE
        16, // D/ST
        17, // K
        23, // FLEX (RB/WR/TE)
        7,  // OP (Offensive Player - some leagues)
        1,  // TQB (Team QB - rare)
        3,  // RB  (additional RB slot)
        5,  // WR  (additional WR slot)
        8,  // DT  (IDP)
        9,  // DE  (IDP)
        10, // LB  (IDP)
        11, // DL  (IDP)
        12, // CB  (IDP)
        13, // S   (IDP)
        14, // DB  (IDP)
        15, // DP  (IDP Flex)
        18, // HC  (Head Coach - rare)
        22  // SUPER_FLEX (QB/RB/WR/TE)
    ]
    
    /// Bench and IR slots (not counted as active starters)
    static let inactiveSlots: [Int] = [
        20, // BN (Bench)
        21, // IR (Injured Reserve)
        24  // COVID (COVID-19 Reserve - deprecated but may exist in old data)
    ]
    
    /// All valid lineup slots
    static let allSlots: [Int] = activeSlots + inactiveSlots
    
    // MARK: - Slot Categories
    
    /// Standard offensive position slots
    static let offensiveSlots: [Int] = [0, 2, 4, 6, 23, 7, 22]
    
    /// Kicker slot
    static let kickerSlots: [Int] = [17]
    
    /// Defense/Special Teams slots  
    static let defenseSlots: [Int] = [16]
    
    /// Individual Defensive Player (IDP) slots
    static let idpSlots: [Int] = [8, 9, 10, 11, 12, 13, 14, 15]
    
    /// Flex position slots (can hold multiple position types)
    static let flexSlots: [Int] = [23, 7, 22, 15]
    
    // MARK: - Position Mappings
    
    /// Map ESPN slot IDs to position strings
    static let slotToPosition: [Int: String] = [
        0: "QB",
        1: "TQB",     // Team QB
        2: "RB",
        3: "RB",      // Additional RB slot
        4: "WR", 
        5: "WR",      // Additional WR slot
        6: "TE",
        7: "OP",      // Offensive Player
        8: "DT",      // Defensive Tackle
        9: "DE",      // Defensive End
        10: "LB",     // Linebacker
        11: "DL",     // Defensive Line
        12: "CB",     // Cornerback
        13: "S",      // Safety
        14: "DB",     // Defensive Back
        15: "DP",     // Defensive Player (IDP Flex)
        16: "DST",    // Defense/Special Teams
        17: "K",      // Kicker
        18: "HC",     // Head Coach
        20: "BN",     // Bench
        21: "IR",     // Injured Reserve
        22: "SUPER_FLEX", // Superflex (QB/RB/WR/TE)
        23: "FLEX",   // Flex (RB/WR/TE)
        24: "COVID"   // COVID-19 Reserve (deprecated)
    ]
    
    /// Map position strings back to primary slot IDs
    static let positionToSlot: [String: Int] = [
        "QB": 0,
        "RB": 2,
        "WR": 4,
        "TE": 6,
        "K": 17,
        "DST": 16,
        "DEF": 16,    // Alias for DST
        "D/ST": 16,   // Another alias
        "FLEX": 23,
        "OP": 7,
        "SUPER_FLEX": 22,
        "BN": 20,
        "IR": 21
    ]
    
    // MARK: - Utility Functions
    
    /// Check if a slot ID represents an active starter position
    /// - Parameter slotId: ESPN slot ID
    /// - Returns: True if the slot is for an active starter
    static func isActiveSlot(_ slotId: Int) -> Bool {
        return activeSlots.contains(slotId)
    }
    
    /// Check if a slot ID represents a bench or IR position
    /// - Parameter slotId: ESPN slot ID  
    /// - Returns: True if the slot is bench/IR
    static func isInactiveSlot(_ slotId: Int) -> Bool {
        return inactiveSlots.contains(slotId)
    }
    
    /// Check if a slot ID represents a flex position
    /// - Parameter slotId: ESPN slot ID
    /// - Returns: True if the slot is a flex position
    static func isFlexSlot(_ slotId: Int) -> Bool {
        return flexSlots.contains(slotId)
    }
    
    /// Get the position string for a slot ID
    /// - Parameter slotId: ESPN slot ID
    /// - Returns: Position string or nil if not found
    static func position(for slotId: Int) -> String? {
        return slotToPosition[slotId]
    }
    
    /// Get the primary slot ID for a position
    /// - Parameter position: Position string
    /// - Returns: Primary slot ID or nil if not found
    static func slot(for position: String) -> Int? {
        return positionToSlot[position.uppercased()]
    }
    
    /// Get all eligible positions for a flex slot
    /// - Parameter slotId: Flex slot ID
    /// - Returns: Array of eligible position strings
    static func eligiblePositions(for slotId: Int) -> [String] {
        switch slotId {
        case 23: // FLEX (RB/WR/TE)
            return ["RB", "WR", "TE"]
        case 7:  // OP (Offensive Player)
            return ["QB", "RB", "WR", "TE"]
        case 22: // SUPER_FLEX (QB/RB/WR/TE)
            return ["QB", "RB", "WR", "TE"]
        case 15: // DP (IDP Flex)
            return ["DT", "DE", "LB", "DL", "CB", "S", "DB"]
        default:
            return []
        }
    }
    
    /// Count active roster spots in a lineup configuration
    /// - Parameter lineupSlots: Array of ESPN lineup slot configurations
    /// - Returns: Number of active starter spots
    static func countActiveSpots(in lineupSlots: [Any]) -> Int {
        // This would need to be implemented based on your specific lineup slot structure
        // For now, return a default count
        return lineupSlots.filter { slot in
            // Implementation depends on your slot structure
            return true
        }.count
    }
}

// MARK: - Extensions

extension Array where Element == Int {
    /// Filter to only include active lineup slots
    var activeSlots: [Int] {
        return self.filter { LineupSlots.isActiveSlot($0) }
    }
    
    /// Filter to only include inactive (bench/IR) slots
    var inactiveSlots: [Int] {
        return self.filter { LineupSlots.isInactiveSlot($0) }
    }
}