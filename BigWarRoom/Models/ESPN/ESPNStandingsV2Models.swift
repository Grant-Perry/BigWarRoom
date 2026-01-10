//
//  ESPNStandingsV2Models.swift
//  BigWarRoom
//
//  ESPN Standings V2 API response models
//  Used by NFLStandingsService and NFLPlayoffBracketService
//

import Foundation

/// ESPN Standings V2 API response structure
///
/// Used to fetch playoff clincher status and seed information.
/// Avoids re-implementing complex NFL elimination math by trusting ESPN's calculations.
struct ESPNStandingsV2Response: Decodable {
    let children: [Child]?
    
    struct Child: Decodable {
        let standings: Standings?
    }
    
    struct Standings: Decodable {
        let entries: [Entry]?
    }
    
    struct Entry: Decodable {
        let team: Team
        let stats: [Stat]?
    }
    
    struct Team: Decodable {
        let abbreviation: String
    }
    
    struct Stat: Decodable {
        let name: String?
        let type: String?
        let value: Double?
        let displayValue: String?
    }
}