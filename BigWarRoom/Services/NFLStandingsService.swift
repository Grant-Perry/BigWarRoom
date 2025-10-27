//
//  NFLStandingsService.swift
//  BigWarRoom
//
//  Real NFL team standings and records service using ESPN API
//

import Foundation
import SwiftUI
import Observation

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

// MARK: -> Processed Team Record
struct NFLTeamRecord {
    let teamCode: String
    let teamName: String
    let wins: Int
    let losses: Int
    let ties: Int
    
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
    
    // MARK: - Initialization
    
    // 🔥 PHASE 2.5: Make init public for dependency injection
    init() {
        // Auto-fetch on init
        fetchStandings()
    }
    
    /// Fetch real NFL standings from ESPN team record APIs
    func fetchStandings(forceRefresh: Bool = false) {
        // Check cache first
        if !forceRefresh,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiration,
           !teamRecords.isEmpty {
            print("🏈 Using cached team records")
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
            
            print("🏈 Fetching NFL team records from ESPN API...")
            
            // Fetch records for all teams simultaneously using async/await
            await withTaskGroup(of: (String, NFLTeamRecord?).self) { group in
                for (teamCode, teamId) in teamIdMap {
                    group.addTask {
                        await self.fetchSingleTeamRecord(teamCode: teamCode, teamId: teamId)
                    }
                }
                
                var newTeamRecords: [String: NFLTeamRecord] = [:]
                
                for await (teamCode, record) in group {
                    if let record = record {
                        newTeamRecords[teamCode] = record
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.teamRecords = newTeamRecords
                    self.cacheTimestamp = Date()
                    
                    print("🏈 Successfully fetched \(newTeamRecords.count) team records")
                    for record in newTeamRecords.values.sorted(by: { $0.teamCode < $1.teamCode }) {
                        print("🏈 \(record.teamCode): \(record.displayRecord)")
                    }
                }
            }
        }
    }
    
    /// Fetch single team record
    private func fetchSingleTeamRecord(teamCode: String, teamId: String) async -> (String, NFLTeamRecord?) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(teamId)?enable=record") else {
            return (teamCode, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NFLTeamRecordResponse.self, from: data)
            let record = processTeamRecord(response, teamCode: teamCode)
            return (teamCode, record)
        } catch {
            print("🏈 Error fetching record for \(teamCode): \(error)")
            return (teamCode, nil)
        }
    }
    
    /// Process ESPN team record API response
    private func processTeamRecord(_ response: NFLTeamRecordResponse, teamCode: String) -> NFLTeamRecord? {
        // Find the "total" record type
        guard let totalRecord = response.team.record.items.first(where: { $0.type == "total" }) else {
            print("🏈 No total record found for \(teamCode)")
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
        
        return NFLTeamRecord(
            teamCode: teamCode,
            teamName: response.team.name,
            wins: wins,
            losses: losses,
            ties: ties
        )
    }
    
    /// Get team record for display
    func getTeamRecord(for teamCode: String) -> String {
        let normalizedCode = normalizeTeamCode(teamCode)
        return teamRecords[normalizedCode]?.displayRecord ?? "0-0"
    }
    
    /// Get full team record object
    func getFullTeamRecord(for teamCode: String) -> NFLTeamRecord? {
        let normalizedCode = normalizeTeamCode(teamCode)
        return teamRecords[normalizedCode]
    }
    
    /// Normalize team codes for consistency (handle Washington/etc.)
    private func normalizeTeamCode(_ code: String) -> String {
        switch code.uppercased() {
        case "WSH":
            return "WSH" // ESPN uses WSH, we'll use WSH
        case "WAS":
            return "WSH" // Convert WAS to WSH
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