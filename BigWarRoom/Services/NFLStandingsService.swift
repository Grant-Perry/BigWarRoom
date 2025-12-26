//
//  NFLStandingsService.swift
//  BigWarRoom
//
//  Real NFL team standings and records service using ESPN API
//

import Foundation
import SwiftUI
import Observation

// MARK: -> Playoff Status Enum
enum PlayoffStatus: String, Codable {
    case eliminated = "eliminated"
    case alive = "alive"
    case bubble = "bubble"
    case clinched = "clinched"
    case unknown = "unknown"
    
    var displayText: String {
        switch self {
        case .eliminated: return "ELIMINATED"
        case .alive: return "IN CONTENTION"
        case .bubble: return "ON THE BUBBLE"
        case .clinched: return "CLINCHED"
        case .unknown: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .eliminated: return .gray
        case .alive: return .green
        case .bubble: return .orange
        case .clinched: return .blue
        case .unknown: return .clear
        }
    }
}

// MARK: -> ESPN NFL Team Record API Response Models
struct NFLTeamRecordResponse: Codable {
    let team: NFLTeamWithRecord
}

struct NFLTeamWithRecord: Codable {
    let id: String
    let abbreviation: String
    let displayName: String
    let name: String
    let record: NFLTeamRecordData
}

struct NFLTeamRecordData: Codable {
    let items: [NFLRecordItem]
}

struct NFLRecordItem: Codable {
    let type: String
    let summary: String
    let stats: [NFLRecordStat]
}

struct NFLRecordStat: Codable {
    let name: String
    let value: Double
}

// MARK: -> ESPN Standings API Response (for playoff status)
struct ESPNStandingsResponse: Codable {
    let standings: [ESPNStandingsGroup]
}

struct ESPNStandingsGroup: Codable {
    let teams: [ESPNStandingsTeamEntry]
}

struct ESPNStandingsTeamEntry: Codable {
    let team: ESPNStandingsTeamInfo
    let eliminated: Bool?           // 🔥 FIXED: At team entry level, not team info level
    let clinched: Bool?             // 🔥 FIXED: At team entry level
    let seed: Int?                  // 🔥 FIXED: At team entry level
}

struct ESPNStandingsTeamInfo: Codable {
    let id: String
    let abbreviation: String
    let displayName: String
}

// MARK: -> Processed Team Record
struct NFLTeamRecord {
    let teamCode: String
    let teamName: String
    let wins: Int
    let losses: Int
    let ties: Int
    let playoffStatus: PlayoffStatus
    
    /// Record display string (e.g., "10-4", "7-7-1")
    var displayRecord: String {
        if ties > 0 {
            return "\(wins)-\(losses)-\(ties)"
        } else {
            return "\(wins)-\(losses)"
        }
    }
    
    /// Winning percentage
    var winningPercentage: Double {
        let totalGames = wins + losses + ties
        guard totalGames > 0 else { return 0.0 }
        return Double(wins) / Double(totalGames)
    }
}

// MARK: -> NFL Standings Service
@Observable
@MainActor
final class NFLStandingsService {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: NFLStandingsService?
    
    static var shared: NFLStandingsService {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = NFLStandingsService()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: NFLStandingsService) {
        _shared = instance
    }
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    var teamRecords: [String: NFLTeamRecord] = [:]
    var isLoading = false
    var errorMessage: String?
    
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var cacheTimestamp: Date?
    @ObservationIgnored private let cacheExpiration: TimeInterval = 3600 // 1 hour - standings don't change as often
    
    // Team ID mapping for ESPN API
    @ObservationIgnored private let teamIdMap: [String: String] = [
        "ARI": "22", "ATL": "1", "BAL": "33", "BUF": "2", "CAR": "29", "CHI": "3",
        "CIN": "4", "CLE": "5", "DAL": "6", "DEN": "7", "DET": "8", "GB": "9",
        "HOU": "34", "IND": "11", "JAX": "30", "KC": "12", "LV": "13", "LAC": "24",
        "LAR": "14", "MIA": "15", "MIN": "16", "NE": "17", "NO": "18", "NYG": "19",
        "NYJ": "20", "PHI": "21", "PIT": "23", "SF": "25", "SEA": "26", "TB": "27",
        "TEN": "10", "WSH": "28", "WAS": "28" // Handle both Washington codes
    ]
    
    // MARK: - ESPN Standings (Playoff clincher / seed / eliminated)
    //
    // We use ESPN's standings endpoint to avoid trying to re-implement NFL elimination math.
    // This brings our Schedule tab badges (CLINCH / HUNT / BUBBLE / OUT) back in line with
    // the source-of-truth flags (clincher + playoffSeed).
    private struct ESPNStandingsV2Response: Decodable {
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
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Make init public for dependency injection
    init() {
        // Auto-fetch on init
        fetchStandings()
    }
    
    /// Fetch real NFL standings from ESPN APIs (records + calculated playoff status)
    func fetchStandings(forceRefresh: Bool = false) {
        // Check cache first
        if !forceRefresh,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration,
           !teamRecords.isEmpty {
            DebugPrint(mode: .espnAPI, "🏈 Using cached team records")
            return
        }
        
        // Cancel any existing fetch task
        fetchTask?.cancel()
        
        fetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            DebugPrint(mode: .espnAPI, "🏈 Fetching NFL team records from ESPN API...")
            
            // Prefer ESPN standings flags (clincher/eliminated + playoff seed) for playoff status.
            // Fallback to our calculation only if the standings endpoint fails.
            let selectedYear = Int(SeasonYearManager.shared.selectedYear) ?? Calendar.current.component(.year, from: Date())
            let espnStatusMap = await self.fetchPlayoffStatusMapFromESPNStandings(season: selectedYear)
            
            // Fetch individual team records
            await withTaskGroup(of: (String, NFLTeamRecord?).self) { group in
                for (teamCode, teamId) in self.teamIdMap {
                    group.addTask {
                        await self.fetchSingleTeamRecord(teamCode: teamCode, teamId: teamId, playoffStatusMap: espnStatusMap)
                    }
                }
                
                var newTeamRecords: [String: NFLTeamRecord] = [:]
                
                for await (teamCode, record) in group {
                    if let record = record {
                        newTeamRecords[teamCode] = record
                    }
                }
                
                await MainActor.run {
                    self.teamRecords = newTeamRecords
                    
                    // 🔥 DEBUG: Log all team codes we have
                    DebugPrint(mode: .contention, "🏈 Team records loaded: \(Array(newTeamRecords.keys).sorted().joined(separator: ", "))")
                    
                    // 🔥 FIX: Ensure WSH and WAS are synced before calculating statuses
                    if let wasRecord = newTeamRecords["WAS"], newTeamRecords["WSH"] == nil {
                        newTeamRecords["WSH"] = wasRecord
                        DebugPrint(mode: .contention, "🔄 Synced WAS -> WSH")
                    } else if let wshRecord = newTeamRecords["WSH"], newTeamRecords["WAS"] == nil {
                        newTeamRecords["WAS"] = wshRecord
                        DebugPrint(mode: .contention, "🔄 Synced WSH -> WAS")
                    }
                    
                    // If ESPN standings didn't provide statuses, compute a fallback.
                    if espnStatusMap.isEmpty {
                        DebugPrint(mode: .espnAPI, "🏈 ESPN standings status map empty; falling back to local playoff-status calculation")
                        let playoffStatuses = self.calculatePlayoffStatuses()
                        for (teamCode, status) in playoffStatuses {
                            if let record = newTeamRecords[teamCode] {
                                newTeamRecords[teamCode] = NFLTeamRecord(
                                    teamCode: record.teamCode,
                                    teamName: record.teamName,
                                    wins: record.wins,
                                    losses: record.losses,
                                    ties: record.ties,
                                    playoffStatus: status
                                )
                            }
                        }
                    }
                    
                    self.teamRecords = newTeamRecords
                    
                    self.isLoading = false
                    self.cacheTimestamp = Date()
                    
                    DebugPrint(mode: .espnAPI, "🏈 Successfully fetched \(self.teamRecords.count) team records")
                    for record in self.teamRecords.values.sorted(by: { $0.teamCode < $1.teamCode }) {
                        let statusEmoji = record.playoffStatus == .eliminated ? "💀" : record.playoffStatus == .clinched ? "🎉" : record.playoffStatus == .bubble ? "⚠️" : "⚡️"
                        DebugPrint(mode: .espnAPI, "🏈 \(record.teamCode): \(record.displayRecord) \(statusEmoji) \(record.playoffStatus.displayText)")
                    }
                }
            }
        }
    }
    
    /// Fetch playoff statuses from ESPN standings (`clincher` + `playoffSeed`).
    /// Returns an empty map if anything fails (callers should fallback).
    private func fetchPlayoffStatusMapFromESPNStandings(season: Int) async -> [String: PlayoffStatus] {
        guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/football/nfl/standings?season=\(season)") else {
            return [:]
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ESPNStandingsV2Response.self, from: data)
            
            var statusMap: [String: PlayoffStatus] = [:]
            
            let children = response.children ?? []
            for child in children {
                let entries = child.standings?.entries ?? []
                for entry in entries {
                    let rawCode = entry.team.abbreviation.uppercased()
                    let normalizedCode = normalizeTeamCode(rawCode)
                    
                    let clincher = entry.stats?.first(where: { ($0.name ?? $0.type) == "clincher" })?.displayValue?.lowercased()
                    let seedValue = entry.stats?.first(where: { ($0.name ?? $0.type) == "playoffSeed" })?.value
                    
                    // ESPN: clincher 'e' => eliminated, 'x/y/z' => clinched (various clinch types)
                    if clincher == "e" {
                        statusMap[normalizedCode] = .eliminated
                        continue
                    }
                    
                    if clincher == "x" || clincher == "y" || clincher == "z" {
                        statusMap[normalizedCode] = .clinched
                        continue
                    }
                    
                    if let seed = seedValue {
                        statusMap[normalizedCode] = (seed <= 7) ? .alive : .bubble
                    }
                }
            }
            
            // Keep both Washington codes in-sync
            if let wsh = statusMap["WSH"] {
                statusMap["WAS"] = wsh
            } else if let was = statusMap["WAS"] {
                statusMap["WSH"] = was
            }
            
            DebugPrint(mode: .espnAPI, "🏈 ESPN standings status map loaded (\(statusMap.count) teams)")
            return statusMap
        } catch {
            DebugPrint(mode: .espnAPI, "🏈 ESPN standings status map fetch failed: \(error)")
            return [:]
        }
    }
    
    /// 🔥 FIXED: Calculate playoff statuses using proper NFL math with CORRECT records
    private func fetchPlayoffStatuses() async -> [String: PlayoffStatus] {
        // ESPN API doesn't expose playoff status, so we calculate it ourselves
        // This will be called AFTER records are fetched
        return [:]
    }
    
    /// 🔥 FIXED: Calculate playoff status using proper conference-based elimination logic
    private func calculatePlayoffStatuses() -> [String: PlayoffStatus] {
        var statusMap: [String: PlayoffStatus] = [:]
        
        DebugPrint(mode: .espnAPI, "🏈 Starting playoff calculation for \(teamRecords.count) teams")
        
        // Separate teams by conference
        var afcTeams: [(code: String, record: NFLTeamRecord)] = []
        var nfcTeams: [(code: String, record: NFLTeamRecord)] = []
        
        for (code, record) in teamRecords {
            if let team = NFLTeam.team(for: code) {
                if team.conference == .afc {
                    afcTeams.append((code, record))
                } else {
                    nfcTeams.append((code, record))
                }
            } else {
                DebugPrint(mode: .espnAPI, "🏈 WARNING: No NFLTeam found for code '\(code)'")
            }
        }
        
        DebugPrint(mode: .espnAPI, "🏈 Split into AFC: \(afcTeams.count) teams, NFC: \(nfcTeams.count) teams")
        
        // Calculate status for each conference
        let afcStatuses = calculateConferencePlayoffStatuses(teams: afcTeams, conference: "AFC")
        let nfcStatuses = calculateConferencePlayoffStatuses(teams: nfcTeams, conference: "NFC")
        
        DebugPrint(mode: .espnAPI, "🏈 AFC returned \(afcStatuses.count) statuses")
        DebugPrint(mode: .espnAPI, "🏈 NFC returned \(nfcStatuses.count) statuses")
        
        // Merge results
        statusMap.merge(afcStatuses) { $1 }
        statusMap.merge(nfcStatuses) { $1 }
        
        return statusMap
    }
    
    /// 🔥 FIXED: Proper playoff elimination calculation per conference
    private func calculateConferencePlayoffStatuses(teams: [(code: String, record: NFLTeamRecord)], conference: String) -> [String: PlayoffStatus] {
        var statusMap: [String: PlayoffStatus] = [:]
        
        // Sort teams by wins (descending), then by win percentage
        let sortedTeams = teams.sorted { first, second in
            if first.record.wins != second.record.wins {
                return first.record.wins > second.record.wins
            }
            return first.record.winningPercentage > second.record.winningPercentage
        }
        
        // Calculate max possible wins for each team
        var teamsWithMaxWins: [(code: String, record: NFLTeamRecord, maxWins: Int, currentSeed: Int)] = []
        for (index, team) in sortedTeams.enumerated() {
            let gamesPlayed = team.record.wins + team.record.losses + team.record.ties
            let remainingGames = 17 - gamesPlayed
            let maxPossibleWins = team.record.wins + remainingGames
            teamsWithMaxWins.append((team.code, team.record, maxPossibleWins, index + 1))
        }
        
        // 7th place team's current wins (last playoff spot)
        let seventhPlaceWins = sortedTeams.count >= 7 ? sortedTeams[6].record.wins : 0
        
        DebugPrint(mode: .contention, "🏈 \(conference) Conference Analysis:")
        DebugPrint(mode: .contention, "   7th seed has \(seventhPlaceWins) wins")
        DebugPrint(mode: .contention, "   Top 7: \(sortedTeams.prefix(7).map { "\($0.code) \($0.record.wins)W" }.joined(separator: ", "))")
        
        // Classify each team
        for teamData in teamsWithMaxWins {
            let seed = teamData.currentSeed
            let currentWins = teamData.record.wins
            let maxWins = teamData.maxWins
            let gamesPlayed = teamData.record.wins + teamData.record.losses + teamData.record.ties
            let remainingGames = 17 - gamesPlayed
            let winsNeeded = seventhPlaceWins - currentWins
            
            // ELIMINATED: Can't mathematically reach 7th place
            // 🔥 FIX: Changed <= to < - teams that can TIE are not eliminated
            if maxWins < seventhPlaceWins {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (max \(maxWins)W < \(seventhPlaceWins)W)")
            }
            // ELIMINATED: Too far back with too few games left
            // If you're 3+ wins behind 7th place with 2 or fewer games left, you're done
            else if currentWins < (seventhPlaceWins - 2) && remainingGames <= 2 {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (too far back: \(currentWins)W vs \(seventhPlaceWins)W, only \(remainingGames) left)")
            }
            // ELIMINATED: Outside playoffs and need 2+ wins with only 2 games left (very unlikely)
            // 🔥 FIX: Changed >= to > - teams that CAN win out are not eliminated
            else if seed > 7 && winsNeeded > remainingGames {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (need \(winsNeeded)W in \(remainingGames) games, seed #\(seed))")
            }
            // Currently in playoff spots (1-7)
            else if seed <= 7 {
                // CLINCHED: Top 2 seeds with commanding lead (4+ wins ahead of 7th)
                if seed <= 2 && currentWins >= (seventhPlaceWins + 4) {
                    statusMap[teamData.code] = .clinched
                    DebugPrint(mode: .contention, "   🎉 \(teamData.code): CLINCHED #\(seed) (\(currentWins)W, +\(currentWins - seventhPlaceWins) ahead)")
                } else {
                    statusMap[teamData.code] = .alive
                    DebugPrint(mode: .contention, "   ⚡️ \(teamData.code): IN HUNT #\(seed) (\(currentWins)W)")
                }
            }
            // BUBBLE: Outside playoffs but still mathematically alive
            else {
                statusMap[teamData.code] = .bubble
                DebugPrint(mode: .contention, "   ⚠️  \(teamData.code): BUBBLE #\(seed) (\(currentWins)W, max \(maxWins)W, need +\(winsNeeded))")
            }
        }
        
        return statusMap
    }
    
    /// Fetch single team record (now includes playoff status)
    private func fetchSingleTeamRecord(teamCode: String, teamId: String, playoffStatusMap: [String: PlayoffStatus]) async -> (String, NFLTeamRecord?) {
        let currentYear = Calendar.current.component(.year, from: Date())
        // 🔥 FIXED: Add season and seasontype parameters
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(teamId)?season=\(currentYear)&seasontype=2") else {
            return (teamCode, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 🔥 DEBUG: Log CHI's full record structure
            if teamCode == "CHI" {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let team = json["team"] as? [String: Any],
                   let record = team["record"] as? [String: Any],
                   let items = record["items"] as? [[String: Any]] {
                    DebugPrint(mode: .espnAPI, "🏈 CHI has \(items.count) record items:")
                    for (index, item) in items.enumerated() {
                        let type = item["type"] as? String ?? "unknown"
                        let summary = item["summary"] as? String ?? "unknown"
                        DebugPrint(mode: .espnAPI, "   Item \(index): type='\(type)', summary='\(summary)'")
                        
                        if let stats = item["stats"] as? [[String: Any]] {
                            for stat in stats {
                                let name = stat["name"] as? String ?? "unknown"
                                let value = stat["value"] as? Double ?? 0
                                DebugPrint(mode: .espnAPI, "     - \(name): \(value)")
                            }
                        }
                    }
                }
            }
            
            let response = try JSONDecoder().decode(NFLTeamRecordResponse.self, from: data)
            let record = processTeamRecord(response, teamCode: teamCode, playoffStatusMap: playoffStatusMap)
            
            return (teamCode, record)
        } catch {
            DebugPrint(mode: .espnAPI, "🏈 Error fetching record for \(teamCode): \(error)")
            return (teamCode, nil)
        }
    }
    
    /// Process ESPN team record API response (now uses playoff status from map)
    private func processTeamRecord(_ response: NFLTeamRecordResponse, teamCode: String, playoffStatusMap: [String: PlayoffStatus]) -> NFLTeamRecord? {
        // Find the "total" record type
        guard let totalRecord = response.team.record.items.first(where: { $0.type == "total" }) else {
            DebugPrint(mode: .espnAPI, "🏈 No total record found for \(teamCode)")
            return nil
        }
        
        var wins = 0
        var losses = 0
        var ties = 0
        
        // Extract wins, losses, ties from stats
        for stat in totalRecord.stats {
            switch stat.name.lowercased() {
            case "wins":
                wins = Int(stat.value)
            case "losses":
                losses = Int(stat.value)
            case "ties":
                ties = Int(stat.value)
            default:
                continue
            }
        }
        
        // 🔥 FIXED: Use playoff status from ESPN, fallback to unknown
        let playoffStatus = playoffStatusMap[teamCode] ?? .unknown
        
        return NFLTeamRecord(
            teamCode: teamCode,
            teamName: response.team.name,
            wins: wins,
            losses: losses,
            ties: ties,
            playoffStatus: playoffStatus
        )
    }
    
    /// Get team record for display
    func getTeamRecord(for teamCode: String) -> String {
        let normalizedCode = normalizeTeamCode(teamCode)
        let record = teamRecords[normalizedCode]?.displayRecord ?? "0-0"
        DebugPrint(mode: .contention, "🔍 getTeamRecord: '\(teamCode)' -> normalized to '\(normalizedCode)' -> record: '\(record)'")
        return record
    }
    
    /// Get full team record object
    func getFullTeamRecord(for teamCode: String) -> NFLTeamRecord? {
        let normalizedCode = normalizeTeamCode(teamCode)
        return teamRecords[normalizedCode]
    }
    
    /// 🔥 NEW: Get playoff status for a team
    func getPlayoffStatus(for teamCode: String) -> PlayoffStatus {
        let normalizedCode = normalizeTeamCode(teamCode)
        let status = teamRecords[normalizedCode]?.playoffStatus ?? .unknown
        DebugPrint(mode: .contention, "🔍 getPlayoffStatus: '\(teamCode)' -> normalized to '\(normalizedCode)' -> status: '\(status.displayText)'")
        return status
    }
    
    /// 🔥 NEW: Check if team is eliminated
    func isTeamEliminated(for teamCode: String) -> Bool {
        return getPlayoffStatus(for: teamCode) == .eliminated
    }
    
    /// Normalize team codes for consistency (handle Washington/etc.)
    private func normalizeTeamCode(_ code: String) -> String {
        switch code.uppercased() {
        case "WSH":
            return "WSH" // ESPN uses WSH, keep it consistent
        case "WAS":
            return "WSH" // Convert WAS to WSH for consistency
        case "JAC":
            return "JAX" // Some sources use JAC, we use JAX
        default:
            return code.uppercased()
        }
    }
    
    /// Force refresh standings
    func refreshStandings() {
        fetchStandings(forceRefresh: true)
    }
    
    // MARK: - Cleanup
    
    deinit {
        fetchTask?.cancel()
    }
}
