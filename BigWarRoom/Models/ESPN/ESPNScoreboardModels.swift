//
//  ESPNScoreboardModels.swift
//  BigWarRoom
//
//  ESPN Scoreboard API response models
//  Used by NFLPlayoffBracketService for fetching playoff game data
//

import Foundation

/// ESPN Scoreboard API response structure
struct ESPNScoreboardResponse: Decodable {
    let events: [Event]?
    
    struct Event: Decodable {
        let id: String?
        let name: String?
        let date: String?
        let week: Week?
        let competitions: [Competition]?
        let venue: Venue?
        let broadcasts: [Broadcast]?
    }
    
    struct Week: Decodable {
        let number: Int?
    }
    
    struct Competition: Decodable {
        let competitors: [Competitor]?
        let status: Status?
        let venue: Venue?
        let broadcasts: [Broadcast]?
    }
    
    struct Note: Decodable {
        let headline: String?
    }
    
    struct Competitor: Decodable {
        let homeAway: String?
        let team: Team
        let score: String?
        let timeouts: Int?  // 🏈 NEW: Timeouts remaining (0-3)
    }
    
    struct Team: Decodable {
        let abbreviation: String
    }
    
    struct Status: Decodable {
        let type: StatusType?
        let period: Int?
        let displayClock: String?
    }
    
    struct StatusType: Decodable {
        let state: String?
        let completed: Bool?
    }
    
    struct Venue: Decodable {
        let fullName: String?
        let address: VenueAddress?
        
        struct VenueAddress: Decodable {
            let city: String?
            let state: String?
        }
    }
    
    struct Broadcast: Decodable {
        let market: String?
        let names: [String]?
    }
}