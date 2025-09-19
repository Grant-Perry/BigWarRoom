//
//  LeagueContext.swift
//  BigWarRoom
//
//  Context model for passing league information to scoring calculations
//

import Foundation

/// **LeagueContext**
/// 
/// Contains all the information needed to determine scoring rules for a player breakdown
struct LeagueContext {
    let leagueID: String
    let source: LeagueSource
    let isChopped: Bool
    let customScoringSettings: [String: Double]?
    
    init(
        leagueID: String,
        source: LeagueSource,
        isChopped: Bool = false,
        customScoringSettings: [String: Double]? = nil
    ) {
        self.leagueID = leagueID
        self.source = source
        self.isChopped = isChopped
        self.customScoringSettings = customScoringSettings
    }
    
    /// Create context for ESPN league
    static func espn(leagueID: String) -> LeagueContext {
        return LeagueContext(leagueID: leagueID, source: .espn)
    }
    
    /// Create context for Sleeper league
    static func sleeper(leagueID: String) -> LeagueContext {
        return LeagueContext(leagueID: leagueID, source: .sleeper)
    }
    
    /// Create context for chopped league with custom scoring
    static func chopped(scoringSettings: [String: Double]) -> LeagueContext {
        return LeagueContext(
            leagueID: "chopped",
            source: .sleeper,
            isChopped: true,
            customScoringSettings: scoringSettings
        )
    }
}