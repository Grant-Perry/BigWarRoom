//
//  NFLStandingsModels.swift
//  BigWarRoom
//
//  Data models for NFL team standings and records
//

import Foundation
import SwiftUI

// MARK: - Playoff Status Enum

/// Represents a team's current playoff contention status
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

// MARK: - ESPN NFL Team Record API Response Models

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

// MARK: - ESPN Standings API Response (for playoff status)

struct ESPNStandingsResponse: Codable {
    let standings: [ESPNStandingsGroup]
}

struct ESPNStandingsGroup: Codable {
    let teams: [ESPNStandingsTeamEntry]
}

struct ESPNStandingsTeamEntry: Codable {
    let team: ESPNStandingsTeamInfo
    let eliminated: Bool?
    let clinched: Bool?
    let seed: Int?
}

struct ESPNStandingsTeamInfo: Codable {
    let id: String
    let abbreviation: String
    let displayName: String
}

// MARK: - Processed Team Record

/// Processed NFL team record with wins, losses, and playoff status
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