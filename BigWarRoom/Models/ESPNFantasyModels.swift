//
//  ESPNFantasyModels.swift
//  BigWarRoom
//
//  ESPN Fantasy API models matching SleepThis implementation for real scoring
//
// MARK: -> ESPN Fantasy Models

import Foundation

// MARK: -> ESPN Fantasy League Model (Root)
struct ESPNFantasyLeagueResponse: Codable {
    let teams: [ESPNFantasyTeamResponse]
    let schedule: [ESPNScheduleEntryResponse]
    let status: ESPNFantasyLeagueStatusResponse?
}

// MARK: -> ESPN Fantasy Team
struct ESPNFantasyTeamResponse: Codable, Identifiable {
    let id: Int
    let name: String? // Team name like "DrLizard", "EnglishConnection"
    let record: ESPNFantasyTeamRecordResponse?
    let roster: ESPNFantasyTeamRosterResponse?
}

// MARK: -> ESPN Team Record
struct ESPNFantasyTeamRecordResponse: Codable {
    let overall: ESPNFantasyOverallRecordResponse?
}

struct ESPNFantasyOverallRecordResponse: Codable {
    let wins: Int
    let losses: Int
    let ties: Int?
}

// MARK: -> ESPN Team Roster
struct ESPNFantasyTeamRosterResponse: Codable {
    let entries: [ESPNFantasyPlayerEntryResponse]
}

// MARK: -> ESPN Player Entry
struct ESPNFantasyPlayerEntryResponse: Codable {
    let playerPoolEntry: ESPNFantasyPlayerPoolEntryResponse
    let lineupSlotId: Int
}

// MARK: -> ESPN Player Pool Entry
struct ESPNFantasyPlayerPoolEntryResponse: Codable {
    let player: ESPNFantasyPlayerResponse
}

// MARK: -> ESPN Fantasy Player
struct ESPNFantasyPlayerResponse: Codable {
    let id: Int
    let fullName: String?
    let stats: [ESPNFantasyPlayerStatResponse]
}

// MARK: -> ESPN Player Stat
struct ESPNFantasyPlayerStatResponse: Codable {
    let scoringPeriodId: Int?
    let statSourceId: Int?
    let appliedTotal: Double? // The actual fantasy points!
}

// MARK: -> ESPN Schedule Entry
struct ESPNScheduleEntryResponse: Codable {
    let matchupPeriodId: Int?
    let away: ESPNFantasyMatchupTeamResponse
    let home: ESPNFantasyMatchupTeamResponse
}

// MARK: -> ESPN Matchup Team
struct ESPNFantasyMatchupTeamResponse: Codable {
    let teamId: Int
}

// MARK: -> ESPN League Status
struct ESPNFantasyLeagueStatusResponse: Codable {
    let currentMatchupPeriod: Int?
    let isActive: Bool?
}

// MARK: -> Type Aliases for Compatibility (to avoid changing FantasyViewModel)
typealias ESPNFantasyLeagueModel = ESPNFantasyLeagueResponse
typealias ESPNFantasyTeamModel = ESPNFantasyTeamResponse
typealias ESPNFantasyPlayerEntry = ESPNFantasyPlayerEntryResponse
typealias ESPNFantasyPlayerPoolEntry = ESPNFantasyPlayerPoolEntryResponse
typealias ESPNFantasyPlayer = ESPNFantasyPlayerResponse
typealias ESPNFantasyPlayerStat = ESPNFantasyPlayerStatResponse
typealias ESPNScheduleEntryModel = ESPNScheduleEntryResponse
typealias ESPNFantasyMatchupTeam = ESPNFantasyMatchupTeamResponse
typealias ESPNFantasyTeamRecord = ESPNFantasyTeamRecordResponse
typealias ESPNFantasyOverallRecord = ESPNFantasyOverallRecordResponse