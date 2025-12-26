//
//  BettingOddsModels.swift
//  BigWarRoom
//
//  Models for The Odds API betting odds data (player props)
//

import Foundation

// MARK: - The Odds API Response Models

/// Main response from The Odds API for NFL odds
struct TheOddsAPIResponse: Codable {
    let odds: [TheOddsGame]
}

/// Individual game with odds
struct TheOddsGame: Codable {
    let id: String
    let sportKey: String
    let sportTitle: String
    let commenceTime: String
    let homeTeam: String
    let awayTeam: String
    let bookmakers: [TheOddsBookmaker]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case sportKey = "sport_key"
        case sportTitle = "sport_title"
        case commenceTime = "commence_time"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case bookmakers
    }
}

/// Bookmaker (sportsbook) with markets
struct TheOddsBookmaker: Codable {
    let key: String
    let title: String
    let lastUpdate: String
    let markets: [TheOddsMarket]
    
    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case lastUpdate = "last_update"
        case markets
    }
}

/// Market (type of bet - e.g., player props)
struct TheOddsMarket: Codable {
    let key: String
    let lastUpdate: String
    let outcomes: [TheOddsOutcome]
    
    private enum CodingKeys: String, CodingKey {
        case key
        case lastUpdate = "last_update"
        case outcomes
    }
}

/// Individual betting outcome (e.g., "Josh Allen Anytime TD - Yes")
struct TheOddsOutcome: Codable {
    let name: String
    let price: Double
    let point: Double? // For over/under props
    
    /// Convert American odds to implied probability
    var impliedProbability: Double {
        if price > 0 {
            return 100.0 / (price + 100.0)
        } else {
            return abs(price) / (abs(price) + 100.0)
        }
    }
    
    /// Convert to American odds string (e.g., "+150", "-110")
    var americanOddsString: String {
        if price > 0 {
            return "+\(Int(price))"
        } else {
            return String(Int(price))
        }
    }
}

// MARK: - Processed Game Betting Odds (Spreads / Totals / Moneyline)

/// Processed game betting odds for display in the NFL Schedule.
struct GameBettingOdds: Hashable {
    let gameID: String
    let homeTeamCode: String
    let awayTeamCode: String
    
    /// Example: "BUF -3.5" or "KC +2.5"
    let spreadDisplay: String?
    
    /// Example: "O/U 46.5"
    let totalDisplay: String?

    /// Favorite moneyline formatted for Schedule (e.g. teamCode="JAX", odds="-150")
    let favoriteMoneylineTeamCode: String?
    let favoriteMoneylineOdds: String?

    /// Raw total points (e.g. "46.5") for Schedule display next to the up/down icon
    let totalPoints: String?
    
    /// Example: "ML: BUF -150 / NE +130" (optional; not currently displayed)
    let moneylineDisplay: String?
    
    let sportsbook: String?
    let lastUpdated: Date?
    
    /// Single-line summary for schedule cards
    var scheduleLine: String? {
        switch (spreadDisplay, totalDisplay) {
        case (nil, nil):
            return nil
        case let (s?, nil):
            return s
        case let (nil, t?):
            return t
        case let (s?, t?):
            return "\(t) · \(s)"
        }
    }
}

// MARK: - Processed Player Betting Odds

/// Processed player betting odds for a specific week
struct PlayerBettingOdds: Identifiable {
    let id: String // playerID_week
    let playerID: String
    let playerName: String
    let team: String
    let week: Int
    let lastUpdated: Date
    
    // Player props by type
    let anytimeTD: PropOdds?
    let rushingYards: PropOdds?
    let receivingYards: PropOdds?
    let passingYards: PropOdds?
    let passingTDs: PropOdds?
    let receptions: PropOdds?
    
    /// Most relevant prop based on position
    var primaryProp: PropOdds? {
        return anytimeTD ?? rushingYards ?? receivingYards ?? passingYards
    }
}

/// Processed prop odds for display
struct PropOdds: Identifiable {
    let id: String
    let marketType: PropMarketType
    let playerName: String
    let overUnder: String? // e.g., "125.5" for yards
    let yesOdds: Int? // American odds for "yes" (anytime TD)
    let noOdds: Int? // American odds for "no"
    let overOdds: Int? // American odds for "over"
    let underOdds: Int? // American odds for "under"
    let sportsbook: String
    
    /// Implied probability for "yes" or "over"
    var impliedProbability: Double {
        if let yes = yesOdds {
            return yes > 0 ? 100.0 / Double(yes + 100) : Double(abs(yes)) / Double(abs(yes) + 100)
        }
        if let over = overOdds {
            return over > 0 ? 100.0 / Double(over + 100) : Double(abs(over)) / Double(abs(over) + 100)
        }
        return 0.5 // Default 50/50
    }
    
    /// Formatted odds string
    var oddsString: String {
        if let yes = yesOdds {
            return yes > 0 ? "+\(yes)" : "\(yes)"
        }
        if let over = overOdds, let under = underOdds {
            return "O: \(over > 0 ? "+\(over)" : "\(over)"), U: \(under > 0 ? "+\(under)" : "\(under)")"
        }
        return "N/A"
    }
}

enum PropMarketType: String, Codable {
    case anytimeTD = "player_anytime_td"
    case rushingYards = "player_rushing_yards"
    case receivingYards = "player_receiving_yards"
    case passingYards = "player_passing_yards"
    case passingTDs = "player_passing_tds"
    case receptions = "player_receptions"
    
    var displayName: String {
        switch self {
        case .anytimeTD: return "Anytime TD"
        case .rushingYards: return "Rushing Yards"
        case .receivingYards: return "Receiving Yards"
        case .passingYards: return "Passing Yards"
        case .passingTDs: return "Passing TDs"
        case .receptions: return "Receptions"
        }
    }
}

// MARK: - API Error Types

enum BettingOddsError: LocalizedError {
    case invalidAPIKey
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case httpError(Int)
    case noDataAvailable
    case playerNotFound
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your Secrets.plist configuration."
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noDataAvailable:
            return "No betting odds data available for this player"
        case .playerNotFound:
            return "Player not found in odds data"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}


