//
//  BettingOddsModels.swift
//  BigWarRoom
//
//  Models for The Odds API betting odds data (player props)
//

import Foundation
import SwiftUI

// MARK: - Sportsbook Enum

/// Supported sportsbooks with display abbreviations and brand colors
enum Sportsbook: String, CaseIterable, Codable, Identifiable {
    case draftkings = "draftkings"
    case fanduel = "fanduel"
    case betmgm = "betmgm"
    case caesars = "caesars"
    case pointsbet = "pointsbetus"
    case betrivers = "betrivers"
    case pinnacle = "pinnacle"
    case bestLine = "best" // Special case: show the most favorable line
    
    var id: String { rawValue }
    
    /// Short abbreviation for display on cards (e.g., "DK", "FD")
    var abbreviation: String {
        switch self {
        case .draftkings: return "DK"
        case .fanduel: return "FD"
        case .betmgm: return "MGM"
        case .caesars: return "CZR"
        case .pointsbet: return "PB"
        case .betrivers: return "BR"
        case .pinnacle: return "PIN"
        case .bestLine: return "★"
        }
    }
    
    /// Full display name for settings
    var displayName: String {
        switch self {
        case .draftkings: return "DraftKings"
        case .fanduel: return "FanDuel"
        case .betmgm: return "BetMGM"
        case .caesars: return "Caesars"
        case .pointsbet: return "PointsBet"
        case .betrivers: return "BetRivers"
        case .pinnacle: return "Pinnacle"
        case .bestLine: return "Best Available"
        }
    }
    
    /// Primary brand color
    var primaryColor: Color {
        switch self {
        case .draftkings: return Color(red: 0.0, green: 0.69, blue: 0.31)   // DK Green #00B050
        case .fanduel: return Color(red: 0.08, green: 0.46, blue: 0.82)     // FD Blue #1493FF
        case .betmgm: return Color(red: 0.77, green: 0.63, blue: 0.16)      // MGM Gold #C5A028
        case .caesars: return Color(red: 0.77, green: 0.07, blue: 0.19)     // Caesars Red #C41230
        case .pointsbet: return Color(red: 1.0, green: 0.27, blue: 0.22)    // PointsBet Red #FF4438
        case .betrivers: return Color(red: 0.0, green: 0.4, blue: 0.7)      // BetRivers Blue #0066B2
        case .pinnacle: return Color(red: 0.0, green: 0.2, blue: 0.4)       // Pinnacle Navy #003366
        case .bestLine: return Color(red: 1.0, green: 0.84, blue: 0.0)      // Gold star #FFD700
        }
    }
    
    /// Secondary/text color for contrast
    var textColor: Color {
        switch self {
        case .draftkings: return .white
        case .fanduel: return .white
        case .betmgm: return .black
        case .caesars: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold text
        case .pointsbet: return .white
        case .betrivers: return .white
        case .pinnacle: return .white
        case .bestLine: return .black
        }
    }
    
    /// Match API bookmaker key to our enum
    static func from(apiKey: String) -> Sportsbook? {
        let lowercased = apiKey.lowercased()
        return Sportsbook.allCases.first { $0 != .bestLine && lowercased.contains($0.rawValue) }
    }
}

// MARK: - Sportsbook Badge View

/// Compact branded badge for displaying sportsbook on cards
struct SportsbookBadge: View {
    let book: Sportsbook
    var size: CGFloat = 11
    
    var body: some View {
        // Try to load image from assets first, fall back to text badge
        if let image = UIImage(named: book.abbreviation) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: size * 1.5) // Slightly larger for logo visibility
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            // Fallback to text badge if image doesn't exist
            Text(book.abbreviation)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundColor(book.textColor)
                .padding(.horizontal, book == .bestLine ? 3 : 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(book.primaryColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(book.textColor.opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Preview
#Preview("Sportsbook Badges") {
    VStack(spacing: 12) {
        ForEach(Sportsbook.allCases) { book in
            HStack {
                SportsbookBadge(book: book)
                Text(book.displayName)
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
    .padding()
    .background(Color.black)
}

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

/// Individual book's odds for a game
struct BookOdds: Hashable {
    let book: Sportsbook
    let favoriteTeamCode: String?
    let favoriteMoneylineOdds: Int?      // Raw numeric value for comparison
    let favoriteMoneylineDisplay: String? // Formatted string like "-130"
    let underdogTeamCode: String?         // NEW: Underdog team
    let underdogMoneylineOdds: Int?       // NEW: Raw numeric for underdog
    let underdogMoneylineDisplay: String? // NEW: Formatted like "+425"
    let totalPoints: Double?
    let spreadPoints: Double?
    let spreadTeamCode: String?
}

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
    
    /// NEW: Underdog moneyline (e.g. teamCode="PIT", odds="+425")
    let underdogMoneylineTeamCode: String?
    let underdogMoneylineOdds: String?

    /// Raw total points (e.g. "46.5") for Schedule display next to the up/down icon
    let totalPoints: String?
    
    /// Example: "ML: BUF -150 / NE +130" (optional; not currently displayed)
    let moneylineDisplay: String?
    
    let sportsbook: String?
    let sportsbookEnum: Sportsbook?  // 🔥 NEW: Typed sportsbook
    let lastUpdated: Date?
    
    /// 🔥 NEW: All available book odds for this game (for best line comparison)
    let allBookOdds: [BookOdds]?
    
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
    
    /// 🔥 NEW: Get the best moneyline (most favorable for betting the favorite)
    /// Most favorable = closest to even (least negative)
    var bestMoneylineBook: BookOdds? {
        guard let allOdds = allBookOdds else { return nil }
        return allOdds
            .filter { $0.favoriteMoneylineOdds != nil }
            .max { ($0.favoriteMoneylineOdds ?? -9999) < ($1.favoriteMoneylineOdds ?? -9999) }
    }
    
    /// 🔥 NEW: Get odds for a specific book
    func odds(for book: Sportsbook) -> BookOdds? {
        return allBookOdds?.first { $0.book == book }
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