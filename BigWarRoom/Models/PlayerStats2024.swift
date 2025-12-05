//
//  PlayerStats2024.swift
//  BigWarRoom
//
//  2024 NFL Fantasy Stats for comprehensive player analysis
//
// MARK: -> 2024 Player Stats

import Foundation
import Combine

// MARK: -> Player Stats Model
struct PlayerStats2024: Codable, Identifiable {
    let playerID: String
    let name: String
    let position: String
    let team: String
    
    // Passing Stats
    let passYards: Int?
    let passTDs: Int?
    let passAttempts: Int?
    let passCompletions: Int?
    let interceptions: Int?
    
    // Rushing Stats
    let rushYards: Int?
    let rushTDs: Int?
    let rushAttempts: Int?
    
    // Receiving Stats
    let receptions: Int?
    let recYards: Int?
    let recTDs: Int?
    let targets: Int?
    
    // Kicking Stats
    let fgMade: Int?
    let fgAttempts: Int?
    let extraPoints: Int?
    
    // Defense Stats
    let sacks: Double?
    let interceptionsDef: Int?
    let fumblesRecovered: Int?
    let safeties: Int?
    let touchdownsDef: Int?
    let pointsAllowed: Int?
    let yardsAllowed: Int?
    
    // Fantasy Points
    let standardPoints: Double?
    let pprPoints: Double?
    let halfPprPoints: Double?
    
    // Games played
    let gamesPlayed: Int?
    
    var id: String { playerID }
    
    // MARK: -> Calculated Properties
    
    /// PPR points per game
    var pprPointsPerGame: Double? {
        guard let ppr = pprPoints, let games = gamesPlayed, games > 0 else { return nil }
        return ppr / Double(games)
    }
    
    /// Completion percentage
    var completionPercentage: Double? {
        guard let attempts = passAttempts, let completions = passCompletions, attempts > 0 else { return nil }
        return (Double(completions) / Double(attempts)) * 100
    }
    
    /// Yards per carry
    var yardsPerCarry: Double? {
        guard let yards = rushYards, let attempts = rushAttempts, attempts > 0 else { return nil }
        return Double(yards) / Double(attempts)
    }
    
    /// Yards per reception
    var yardsPerReception: Double? {
        guard let yards = recYards, let recs = receptions, recs > 0 else { return nil }
        return Double(yards) / Double(recs)
    }
    
    /// Target share (approximation)
    var catchRate: Double? {
        guard let recs = receptions, let tgts = targets, tgts > 0 else { return nil }
        return (Double(recs) / Double(tgts)) * 100
    }
    
    /// Field goal percentage
    var fieldGoalPercentage: Double? {
        guard let made = fgMade, let attempts = fgAttempts, attempts > 0 else { return nil }
        return (Double(made) / Double(attempts)) * 100
    }
    
    // MARK: -> Display Helpers
    
    /// Primary fantasy stat line for position
    var primaryStatLine: String {
        switch position.uppercased() {
        case "QB":
            let yards = passYards ?? 0
            let tds = passTDs ?? 0
            let ints = interceptions ?? 0
            return "\(yards) YDS, \(tds) TD, \(ints) INT"
            
        case "RB":
            let rushYds = rushYards ?? 0
            let rushTds = rushTDs ?? 0
            let recTds = recTDs ?? 0
            return "\(rushYds) RUSH YDS, \(rushTds + recTds) TD"
            
        case "WR", "TE":
            let recs = receptions ?? 0
            let yards = recYards ?? 0
            let tds = recTDs ?? 0
            return "\(recs) REC, \(yards) YDS, \(tds) TD"
            
        case "K":
            let fg = fgMade ?? 0
            let xp = extraPoints ?? 0
            return "\(fg) FG, \(xp) XP"
            
        case "DEF":
            let sks = sacks ?? 0
            let ints = interceptionsDef ?? 0
            return "\(sks) SACKS, \(ints) INT"
            
        default:
            return ""
        }
    }
    
    /// Secondary stat line
    var secondaryStatLine: String {
        switch position.uppercased() {
        case "QB":
            if let comp = completionPercentage {
                return String(format: "%.1f%% COMP", comp)
            }
            return ""
            
        case "RB":
            if let ypc = yardsPerCarry {
                return String(format: "%.1f YPC", ypc)
            }
            return ""
            
        case "WR", "TE":
            if let ypr = yardsPerReception {
                return String(format: "%.1f YPR", ypr)
            }
            return ""
            
        case "K":
            if let fgPct = fieldGoalPercentage {
                return String(format: "%.1f%% FG", fgPct)
            }
            return ""
            
        default:
            return ""
        }
    }
    
    /// PPR fantasy rank indicator
    var fantasyTier: Int {
        guard let ppr = pprPoints else { return 4 }
        
        switch position.uppercased() {
        case "QB":
            if ppr >= 300 { return 1 }      // Elite QB1s
            if ppr >= 250 { return 2 }      // Solid QB1s
            if ppr >= 200 { return 3 }      // Streamable QBs
            return 4
            
        case "RB":
            if ppr >= 250 { return 1 }      // Elite RB1s
            if ppr >= 180 { return 2 }      // Solid RB1/2s
            if ppr >= 120 { return 3 }      // Flex RBs
            return 4
            
        case "WR":
            if ppr >= 220 { return 1 }      // Elite WR1s
            if ppr >= 160 { return 2 }      // Solid WR1/2s
            if ppr >= 100 { return 3 }      // Flex WRs
            return 4
            
        case "TE":
            if ppr >= 180 { return 1 }      // Elite TEs
            if ppr >= 120 { return 2 }      // Solid TEs
            if ppr >= 80 { return 3 }       // Streamable TEs
            return 4
            
        case "K":
            if ppr >= 140 { return 3 }      // Top kickers
            return 4
            
        case "DEF":
            if ppr >= 160 { return 3 }      // Top defenses
            return 4
            
        default:
            return 4
        }
    }
}

// MARK: -> Stats Store
@Observable
@MainActor
final class PlayerStatsStore {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: PlayerStatsStore?
    
    static var shared: PlayerStatsStore {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = PlayerStatsStore()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: PlayerStatsStore) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    @ObservationIgnored private var stats: [String: PlayerStats2024] = [:]
    @ObservationIgnored private var isLoading = false
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Make init public for dependency injection
    init() {
        Task {
            await loadRealStats()
        }
    }
    
    /// Get stats for player
    func stats(for playerID: String) -> PlayerStats2024? {
        return stats[playerID]
    }
    
    /// Get stats for player by name (fuzzy match)
    func stats(for playerName: String, position: String? = nil) -> PlayerStats2024? {
        let normalized = playerName.lowercased()
        
        return stats.values.first { stat in
            let nameMatch = stat.name.lowercased().contains(normalized) ||
                           normalized.contains(stat.name.lowercased())
            let posMatch = position == nil || stat.position.uppercased() == position?.uppercased()
            return nameMatch && posMatch
        }
    }
    
    /// Get top performers by position
    func topPerformers(position: String, limit: Int = 20) -> [PlayerStats2024] {
        return stats.values
            .filter { $0.position.uppercased() == position.uppercased() }
            .sorted { ($0.pprPoints ?? 0) > ($1.pprPoints ?? 0) }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: -> Real Data Loading
    
    private func loadRealStats() async {
        isLoading = true
        
        if let stats = await loadFromNFLAPI() {
            self.stats = stats
        } else if let stats = await loadFromESPNAPI() {
            self.stats = stats
        } else if let stats = await loadFromBundledRealData() {
            self.stats = stats
        } else {
            self.stats = [:]
        }
        
        isLoading = false
    }
    
    private func loadFromNFLAPI() async -> [String: PlayerStats2024]? {
        // NFL.com stats API (if available)
        guard let url = URL(string: "https://api.nfl.com/v1/current/season/stats") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            // Parse NFL API response and convert to PlayerStats2024
            return parseNFLAPIData(data)
        } catch {
            return nil
        }
    }
    
    private func loadFromESPNAPI() async -> [String: PlayerStats2024]? {
        // ESPN fantasy API endpoint
        let positions = ["QB", "RB", "WR", "TE", "K", "DST"]
        var allStats: [String: PlayerStats2024] = [:]
        
        for position in positions {
            if let positionStats = await loadESPNPosition(position) {
                allStats.merge(positionStats) { _, new in new }
            }
        }
        
        return allStats.isEmpty ? nil : allStats
    }
    
    private func loadESPNPosition(_ position: String) async -> [String: PlayerStats2024]? {
        // ESPN's hidden fantasy API endpoints - use SeasonYearManager as SOT
        let season = SeasonYearManager.shared.selectedYear
        let urlString = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(season)/segments/0/leaguedefaults/3?view=kona_player_info"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseESPNData(data, position: position)
        } catch {
            return nil
        }
    }
    
    private func loadFromBundledRealData() async -> [String: PlayerStats2024]? {
        // Load from bundled real 2024 stats JSON file
        guard let url = Bundle.main.url(forResource: "nfl_2024_stats", withExtension: "json") else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let statsArray = try decoder.decode([PlayerStats2024].self, from: data)
            return Dictionary(uniqueKeysWithValues: statsArray.map { ($0.playerID, $0) })
        } catch {
            return nil
        }
    }
    
    // MARK: -> Data Parsing
    
    private func parseNFLAPIData(_ data: Data) -> [String: PlayerStats2024]? {
        // Parse NFL.com API response format
        // This would need to be implemented based on actual NFL API structure
        return nil
    }
    
    private func parseESPNData(_ data: Data, position: String) -> [String: PlayerStats2024]? {
        // Parse ESPN fantasy API response
        // This would need to be implemented based on ESPN's API structure
        return nil
    }
}