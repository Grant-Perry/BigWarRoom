//
//  NFLStandingsService.swift
//  BigWarRoom
//
//  Service for fetching and managing NFL team standings and records from ESPN API
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class NFLStandingsService {
    
    // MARK: - Observable Properties
    
    var teamRecords: [String: NFLTeamRecord] = [:]
    var isLoading = false
    var errorMessage: String?
    
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var cacheTimestamp: Date?
    @ObservationIgnored private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // MARK: - ESPN Team ID Mapping
    
    /// ESPN API Team ID Mapping
    ///
    /// ESPN's API uses numeric team IDs in their endpoints (e.g., `/teams/22` for Arizona).
    /// This map translates our standard NFL team abbreviations to ESPN's internal team IDs.
    ///
    /// **Why hardcoded?**
    /// - ESPN team IDs are stable and have not changed in 20+ years
    /// - No ESPN API endpoint exists to dynamically look up "ARI" → "22"
    /// - Avoids unnecessary API calls on every team record fetch
    /// - Performance: instant local lookup vs. network request
    ///
    /// **Maintenance:**
    /// - Only needs updating if NFL adds a new franchise (last: HOU in 2002)
    /// - Or if ESPN completely redesigns their ID system (extremely unlikely)
    ///
    /// **Source:**
    /// IDs derived from ESPN's public API structure:
    /// `https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/{ID}`
    ///
    /// **Note:**
    /// Both "WSH" and "WAS" map to ID "28" to handle Washington's naming variations
    /// across different data sources (Commanders branding transition).
    @ObservationIgnored private let teamIdMap: [String: String] = [
        "ARI": "22",  // Arizona Cardinals
        "ATL": "1",   // Atlanta Falcons
        "BAL": "33",  // Baltimore Ravens
        "BUF": "2",   // Buffalo Bills
        "CAR": "29",  // Carolina Panthers
        "CHI": "3",   // Chicago Bears
        "CIN": "4",   // Cincinnati Bengals
        "CLE": "5",   // Cleveland Browns
        "DAL": "6",   // Dallas Cowboys
        "DEN": "7",   // Denver Broncos
        "DET": "8",   // Detroit Lions
        "GB": "9",    // Green Bay Packers
        "HOU": "34",  // Houston Texans
        "IND": "11",  // Indianapolis Colts
        "JAX": "30",  // Jacksonville Jaguars
        "KC": "12",   // Kansas City Chiefs
        "LV": "13",   // Las Vegas Raiders
        "LAC": "24",  // Los Angeles Chargers
        "LAR": "14",  // Los Angeles Rams
        "MIA": "15",  // Miami Dolphins
        "MIN": "16",  // Minnesota Vikings
        "NE": "17",   // New England Patriots
        "NO": "18",   // New Orleans Saints
        "NYG": "19",  // New York Giants
        "NYJ": "20",  // New York Jets
        "PHI": "21",  // Philadelphia Eagles
        "PIT": "23",  // Pittsburgh Steelers
        "SF": "25",   // San Francisco 49ers
        "SEA": "26",  // Seattle Seahawks
        "TB": "27",   // Tampa Bay Buccaneers
        "TEN": "10",  // Tennessee Titans
        "WSH": "28",  // Washington Commanders (primary code)
        "WAS": "28"   // Washington Commanders (legacy code for compatibility)
    ]
    
    // MARK: - Initialization
    
    init() {
        fetchStandings()
    }
    
    // MARK: - Public Methods
    
    /// Fetch NFL standings from ESPN API
    ///
    /// - Parameters:
    ///   - forceRefresh: If true, bypasses cache and fetches fresh data
    ///   - season: Optional season year (defaults to current season from SeasonYearManager)
    func fetchStandings(forceRefresh: Bool = false, season: Int? = nil) {
        let targetSeason = season ?? (Int(SeasonYearManager.shared.selectedYear) ?? NFLWeekCalculator.getCurrentSeasonYear())
        
        // Check cache
        if !forceRefresh,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration,
           !teamRecords.isEmpty {
            DebugPrint(mode: .espnAPI, "🏈 Using cached team records for season \(targetSeason)")
            return
        }
        
        fetchTask?.cancel()
        
        fetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            DebugPrint(mode: .espnAPI, "🏈 Fetching NFL team records from ESPN API for season \(targetSeason)...")
            
            let espnStatusMap = await self.fetchPlayoffStatusMapFromESPNStandings(season: targetSeason)
            
            await withTaskGroup(of: (String, NFLTeamRecord?).self) { group in
                for (teamCode, teamId) in self.teamIdMap {
                    group.addTask {
                        await self.fetchSingleTeamRecord(
                            teamCode: teamCode,
                            teamId: teamId,
                            playoffStatusMap: espnStatusMap,
                            season: targetSeason
                        )
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
                    
                    DebugPrint(mode: .contention, "🏈 Team records loaded for \(targetSeason): \(Array(newTeamRecords.keys).sorted().joined(separator: ", "))")
                    
                    // Sync Washington codes
                    if let wasRecord = newTeamRecords["WAS"], newTeamRecords["WSH"] == nil {
                        newTeamRecords["WSH"] = wasRecord
                        DebugPrint(mode: .contention, "🔄 Synced WAS -> WSH")
                    } else if let wshRecord = newTeamRecords["WSH"], newTeamRecords["WAS"] == nil {
                        newTeamRecords["WAS"] = wshRecord
                        DebugPrint(mode: .contention, "🔄 Synced WSH -> WAS")
                    }
                    
                    // Fallback to local calculation if ESPN standings failed
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
                    
                    DebugPrint(mode: .espnAPI, "🏈 Successfully fetched \(self.teamRecords.count) team records for season \(targetSeason)")
                    for record in self.teamRecords.values.sorted(by: { $0.teamCode < $1.teamCode }) {
                        let statusEmoji = record.playoffStatus == .eliminated ? "💀" : record.playoffStatus == .clinched ? "🎉" : record.playoffStatus == .bubble ? "⚠️" : "⚡️"
                        DebugPrint(mode: .espnAPI, "🏈 \(record.teamCode): \(record.displayRecord) \(statusEmoji) \(record.playoffStatus.displayText)")
                    }
                }
            }
        }
    }
    
    /// Get team record for display (e.g., "10-4")
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
    
    /// Get playoff status for a team
    func getPlayoffStatus(for teamCode: String) -> PlayoffStatus {
        let normalizedCode = normalizeTeamCode(teamCode)
        let status = teamRecords[normalizedCode]?.playoffStatus ?? .unknown
        DebugPrint(mode: .contention, "🔍 getPlayoffStatus: '\(teamCode)' -> normalized to '\(normalizedCode)' -> status: '\(status.displayText)'")
        return status
    }
    
    /// Check if team is eliminated from playoff contention
    func isTeamEliminated(for teamCode: String) -> Bool {
        return getPlayoffStatus(for: teamCode) == .eliminated
    }
    
    /// Force refresh standings with optional season parameter
    func refreshStandings(season: Int? = nil) {
        fetchStandings(forceRefresh: true, season: season)
    }
    
    // MARK: - Private Methods
    
    /// Fetch playoff statuses from ESPN standings API
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
                    
                    // ESPN clincher codes: 'e' = eliminated, 'x'/'y'/'z' = various clinch types
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
            
            // Sync Washington codes
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
    
    /// Fetch single team record from ESPN API
    private func fetchSingleTeamRecord(
        teamCode: String,
        teamId: String,
        playoffStatusMap: [String: PlayoffStatus],
        season: Int
    ) async -> (String, NFLTeamRecord?) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(teamId)?season=\(season)&seasontype=2") else {
            return (teamCode, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Debug logging for specific teams
            if teamCode == "CHI" {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let team = json["team"] as? [String: Any],
                   let record = team["record"] as? [String: Any],
                   let items = record["items"] as? [[String: Any]] {
                    DebugPrint(mode: .espnAPI, "🏈 CHI has \(items.count) record items for season \(season):")
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
            DebugPrint(mode: .espnAPI, "🏈 Error fetching record for \(teamCode) in season \(season): \(error)")
            return (teamCode, nil)
        }
    }
    
    /// Process ESPN team record API response
    private func processTeamRecord(
        _ response: NFLTeamRecordResponse,
        teamCode: String,
        playoffStatusMap: [String: PlayoffStatus]
    ) -> NFLTeamRecord? {
        guard let totalRecord = response.team.record.items.first(where: { $0.type == "total" }) else {
            DebugPrint(mode: .espnAPI, "🏈 No total record found for \(teamCode)")
            return nil
        }
        
        var wins = 0
        var losses = 0
        var ties = 0
        
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
    
    /// Calculate playoff statuses using local math (fallback if ESPN fails)
    private func calculatePlayoffStatuses() -> [String: PlayoffStatus] {
        var statusMap: [String: PlayoffStatus] = [:]
        
        DebugPrint(mode: .espnAPI, "🏈 Starting playoff calculation for \(teamRecords.count) teams")
        
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
        
        let afcStatuses = calculateConferencePlayoffStatuses(teams: afcTeams, conference: "AFC")
        let nfcStatuses = calculateConferencePlayoffStatuses(teams: nfcTeams, conference: "NFC")
        
        DebugPrint(mode: .espnAPI, "🏈 AFC returned \(afcStatuses.count) statuses")
        DebugPrint(mode: .espnAPI, "🏈 NFC returned \(nfcStatuses.count) statuses")
        
        statusMap.merge(afcStatuses) { $1 }
        statusMap.merge(nfcStatuses) { $1 }
        
        return statusMap
    }
    
    /// Calculate playoff elimination per conference
    private func calculateConferencePlayoffStatuses(
        teams: [(code: String, record: NFLTeamRecord)],
        conference: String
    ) -> [String: PlayoffStatus] {
        var statusMap: [String: PlayoffStatus] = [:]
        
        let sortedTeams = teams.sorted { first, second in
            if first.record.wins != second.record.wins {
                return first.record.wins > second.record.wins
            }
            return first.record.winningPercentage > second.record.winningPercentage
        }
        
        var teamsWithMaxWins: [(code: String, record: NFLTeamRecord, maxWins: Int, currentSeed: Int)] = []
        for (index, team) in sortedTeams.enumerated() {
            let gamesPlayed = team.record.wins + team.record.losses + team.record.ties
            let remainingGames = 17 - gamesPlayed
            let maxPossibleWins = team.record.wins + remainingGames
            teamsWithMaxWins.append((team.code, team.record, maxPossibleWins, index + 1))
        }
        
        let seventhPlaceWins = sortedTeams.count >= 7 ? sortedTeams[6].record.wins : 0
        
        DebugPrint(mode: .contention, "🏈 \(conference) Conference Analysis:")
        DebugPrint(mode: .contention, "   7th seed has \(seventhPlaceWins) wins")
        DebugPrint(mode: .contention, "   Top 7: \(sortedTeams.prefix(7).map { "\($0.code) \($0.record.wins)W" }.joined(separator: ", "))")
        
        for teamData in teamsWithMaxWins {
            let seed = teamData.currentSeed
            let currentWins = teamData.record.wins
            let maxWins = teamData.maxWins
            let gamesPlayed = teamData.record.wins + teamData.record.losses + teamData.record.ties
            let remainingGames = 17 - gamesPlayed
            let winsNeeded = seventhPlaceWins - currentWins
            
            if maxWins < seventhPlaceWins {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (max \(maxWins)W < \(seventhPlaceWins)W)")
            } else if currentWins < (seventhPlaceWins - 2) && remainingGames <= 2 {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (too far back: \(currentWins)W vs \(seventhPlaceWins)W, only \(remainingGames) left)")
            } else if seed > 7 && winsNeeded > remainingGames {
                statusMap[teamData.code] = .eliminated
                DebugPrint(mode: .contention, "   💀 \(teamData.code): ELIMINATED (need \(winsNeeded)W in \(remainingGames) games, seed #\(seed))")
            } else if seed <= 7 {
                if seed <= 2 && currentWins >= (seventhPlaceWins + 4) {
                    statusMap[teamData.code] = .clinched
                    DebugPrint(mode: .contention, "   🎉 \(teamData.code): CLINCHED #\(seed) (\(currentWins)W, +\(currentWins - seventhPlaceWins) ahead)")
                } else {
                    statusMap[teamData.code] = .alive
                    DebugPrint(mode: .contention, "   ⚡️ \(teamData.code): IN HUNT #\(seed) (\(currentWins)W)")
                }
            } else {
                statusMap[teamData.code] = .bubble
                DebugPrint(mode: .contention, "   ⚠️  \(teamData.code): BUBBLE #\(seed) (\(currentWins)W, max \(maxWins)W, need +\(winsNeeded))")
            }
        }
        
        return statusMap
    }
    
    /// Normalize team codes for consistency
    private func normalizeTeamCode(_ code: String) -> String {
        switch code.uppercased() {
        case "WSH":
            return "WSH"
        case "WAS":
            return "WSH"
        case "JAC":
            return "JAX"
        default:
            return code.uppercased()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        fetchTask?.cancel()
    }
}