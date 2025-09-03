//
//  ESPNModels.swift
//  BigWarRoom
//
//  Codable models for ESPN Fantasy Football API responses
//
// MARK: -> ESPN API Models

import Foundation

// NOTE: ESPN Fantasy League models are in ESPNFantasyModels.swift
// This file contains other ESPN-related models for general league management

// MARK: -> ESPN League
struct ESPNLeague: Codable, Identifiable {
    let id: Int
    let name: String?  // Made optional to handle missing field
    let status: ESPNLeagueStatus?
    let size: Int?     // Made optional as well for safety
    let seasonId: Int? // Add seasonId to read from API
    let draftDetail: ESPNDraftDetail?
    let teams: [ESPNTeam]?
    let members: [ESPNMember]?
    let settings: ESPNLeagueSettings?
    let scoringSettings: ESPNScoringSettings?
    
    // Computed properties for Sleeper compatibility
    var leagueID: String { String(id) }
    var totalRosters: Int { size ?? teams?.count ?? 12 } // Fallback logic
    
    // Dynamic season based on API response or AppConstants
    var season: String { 
        if let seasonId = seasonId {
            return String(seasonId)
        }
        return AppConstants.ESPNLeagueYear // Use the dynamic year from AppConstants
    }
    
    // Updated displayName to check both root name and settings.name
    var displayName: String { 
        // First try root level name
        if let name = name, !name.isEmpty {
            return name
        }
        
        // Then try settings name
        if let settingsName = settings?.name, !settingsName.isEmpty {
            return settingsName
        }
        
        // Fallback to default name with ID
        return "ESPN League \(id)"
    }
    
    /// Get manager name for a team's owners array - THE KEY MISSING PIECE!
    func getManagerName(for owners: [String]?) -> String {
        guard let owners = owners, let firstOwnerID = owners.first else {
            return "Unknown Manager"
        }
        
        // Look up the member by ID
        if let member = members?.first(where: { $0.id == firstOwnerID }) {
            // Priority 1: Build name from first/last name if available and meaningful
            let firstName = member.firstName ?? ""
            let lastName = member.lastName ?? ""
            let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            
            if !firstName.isEmpty && !lastName.isEmpty && fullName != " " {
                print("     🎯 Using firstName + lastName: '\(fullName)'")
                return fullName
            }
            
            // Priority 2: Use displayName if it's not generic ESPN crap
            if let displayName = member.displayName, 
               !displayName.isEmpty,
               !displayName.lowercased().hasPrefix("espnfan"),
               !displayName.lowercased().hasPrefix("team "),
               displayName.count > 3 {
                print("     🎯 Using meaningful displayName: '\(displayName)'")
                return displayName
            }
            
            // Priority 3: Fall back to displayName even if generic (better than nothing)
            if let displayName = member.displayName, !displayName.isEmpty {
                print("     ⚠️ Using generic displayName: '\(displayName)'")
                return displayName
            }
        }
        
        // Final fallback
        print("     ❌ No member found, using fallback")
        return "Manager \(firstOwnerID.suffix(8))"
    }
    
    /// Convert to SleeperLeague for UI compatibility
    func toSleeperLeague() -> SleeperLeague {
        // For ESPN leagues, use leagueID as draftID when no separate draft ID exists
        let draftIDString: String? = {
            // If there's a specific draft detail ID, use it
            if let draftDetail = draftDetail, let draftID = draftDetail.id {
                return String(draftID)
            }
            // For completed ESPN drafts, use the league ID as draft ID
            return leagueID
        }()
        
        return SleeperLeague(
            leagueID: leagueID,
            name: displayName, // Use displayName which has fallback logic
            status: status?.toSleeperStatus(draftDetail: draftDetail) ?? .drafting, // Pass draftDetail for smarter status detection
            sport: "nfl",
            season: season, // Use dynamic season
            seasonType: "regular",
            totalRosters: totalRosters,
            draftID: draftIDString, // Always provide a draft ID, even if it's the same as league ID
            avatar: nil, // ESPN doesn't provide league avatars
            settings: SleeperLeagueSettings(
                teams: totalRosters,
                playoffTeams: settings?.playoffTeamCount,
                playoffWeekStart: settings?.playoffWeekStart,
                leagueAverageMatch: nil,
                maxKeepers: nil,
                tradeDeadline: settings?.tradeDeadline,
                reserveSlots: nil,
                taxiSlots: nil
            ),
            scoringSettings: nil, // Could be converted if needed
            rosterPositions: settings?.rosterSettings?.lineupSlots?.compactMap { slot in
                ESPNPositionMap.slotToPosition[slot.slotCategoryId]
            }
        )
    }
}

// MARK: -> ESPN League Status
struct ESPNLeagueStatus: Codable {
    let currentMatchupPeriod: Int?
    let finalScoringPeriod: Int?
    let firstScoringPeriod: Int?
    let isActive: Bool?
    let latestScoringPeriod: Int?
    let previousSeasons: [Int]?
    let waiverLastExecutionDate: TimeInterval?
    
    func toSleeperStatus(draftDetail: ESPNDraftDetail? = nil) -> SleeperLeagueStatus {
        // PRIORITY 1: Check draft status first
        if let draftDetail = draftDetail {
            // If draft is in progress, override everything else
            if let inProgress = draftDetail.inProgress, inProgress {
                return .drafting
            }
            
            // If draft is complete but league hasn't started regular season yet
            if let completeDate = draftDetail.completeDate, completeDate > 0 {
                // Draft is complete - check if regular season has started
                if let current = currentMatchupPeriod, current > 0 {
                    return .inSeason // Regular season has started
                } else {
                    return .complete // Draft done, season not started yet (show as complete)
                }
            }
        }
        
        // PRIORITY 2: Check league activity status
        guard let isActive = isActive else { return .preDraft }
        
        if !isActive {
            return .complete
        }
        
        // PRIORITY 3: Check if we're in draft period vs regular season
        if let current = currentMatchupPeriod {
            if current == 0 {
                return .drafting // Matchup period 0 = draft time
            } else {
                return .inSeason // Matchup period > 0 = regular season
            }
        }
        
        return .inSeason // Default fallback for active leagues
    }
}

// MARK: -> ESPN Draft Detail
struct ESPNDraftDetail: Codable {
    let id: Int?  // Made optional to handle missing field
    let completeDate: TimeInterval?
    let inProgress: Bool?
    let orderType: String? // "SNAKE", "LINEAR"
    let picks: [ESPNDraftPick]?
    
    /// Draft completion date as Date
    var completionDate: Date? {
        guard let completeDate = completeDate, completeDate > 0 else { return nil }
        // ESPN timestamps are typically in milliseconds
        return Date(timeIntervalSince1970: completeDate / 1000)
    }
    
    /// User-friendly completion date string
    var completionDateString: String? {
        guard let date = completionDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Convert to SleeperDraft for compatibility
    func toSleeperDraft(leagueID: String) -> SleeperDraft {
        let status: SleeperDraftStatus
        if let inProgress = inProgress, inProgress {
            status = .drafting
        } else if completeDate != nil {
            status = .complete
        } else {
            status = .preDraft
        }
        
        let type: SleeperDraftType
        switch orderType?.uppercased() {
        case "SNAKE":
            type = .snake
        case "LINEAR":
            type = .linear
        default:
            type = .snake
        }
        
        return SleeperDraft(
            draftID: id != nil ? String(id!) : leagueID, // Use leagueID as fallback if draft ID missing
            leagueID: leagueID,
            status: status,
            type: type,
            sport: "nfl",
            season: AppConstants.ESPNLeagueYear, // Use dynamic season
            seasonType: "regular",
            startTime: nil, // ESPN doesn't always provide start time
            lastPicked: nil,
            settings: nil, // Could be enhanced if needed
            metadata: nil,
            draftOrder: nil,
            slotToRosterID: nil
        )
    }
}

// MARK: -> ESPN Team
struct ESPNTeam: Codable, Identifiable {
    let id: Int
    let abbrev: String?
    let location: String?
    let nickname: String?
    let owners: [String]? // Array of member IDs
    let playoffSeed: Int?
    let points: Double?
    let pointsAdjusted: Double?
    let record: ESPNRecord?
    let roster: ESPNRoster?
    let valuesByStat: [String: ESPNStatValue]?
    
    var displayName: String {
        if let location = location, let nickname = nickname {
            return "\(location) \(nickname)"
        }
        return nickname ?? location ?? "Team \(id)"
    }
    
    /// Convert to SleeperRoster for compatibility with league context for manager names
    func toSleeperRoster(leagueID: String, league: ESPNLeague? = nil) -> SleeperRoster {
        // Convert ESPN player IDs to Sleeper player IDs using espnID matching
        let sleeperPlayerIDs = roster?.entries?.compactMap { entry -> String? in
            let espnPlayerID = String(entry.playerId)
            // Find corresponding Sleeper player using ESPN ID
            if let sleeperPlayer = PlayerDirectoryStore.shared.playerByESPNID(espnPlayerID) {
                return sleeperPlayer.playerID
            }
            print("⚠️ Could not find Sleeper player for ESPN ID: \(espnPlayerID)")
            return nil
        } ?? []
        
        print("🔄 Converted ESPN roster: \(roster?.entries?.count ?? 0) ESPN players -> \(sleeperPlayerIDs.count) Sleeper players")
        
        let recordString = record?.overall.map { overall in
            "\(overall.wins)-\(overall.losses)-\(overall.ties)"
        }
        
        // Get the real manager name using league context
        let managerName = league?.getManagerName(for: owners) ?? "Unknown Manager"
        
        return SleeperRoster(
            rosterID: id,
            ownerID: owners?.first,
            leagueID: leagueID,
            playerIDs: sleeperPlayerIDs, // Use converted Sleeper player IDs
            draftSlot: id, // ESPN team ID maps to draft slot position
            wins: record?.overall?.wins,
            losses: record?.overall?.losses,
            ties: record?.overall?.ties,
            totalMoves: nil,
            totalMovesMade: nil,
            waiversBudgetUsed: nil,
            settings: nil,
            metadata: SleeperRosterMetadata(
                teamName: displayName,
                ownerName: managerName, // USE THE REAL MANAGER NAME FROM LEAGUE MEMBERS!
                avatar: nil,
                record: recordString
            )
        )
    }
}

// MARK: -> ESPN Record
struct ESPNRecord: Codable {
    let overall: ESPNRecordOverall?
}

struct ESPNRecordOverall: Codable {
    let wins: Int
    let losses: Int
    let ties: Int
    let percentage: Double?
    let pointsFor: Double?
    let pointsAgainst: Double?
    let streakLength: Int?
    let streakType: String?
}

// MARK: -> ESPN Member
struct ESPNMember: Codable, Identifiable {
    let id: String
    let displayName: String?
    let firstName: String?
    let lastName: String?
    let isLeagueManager: Bool?
    
    /// Convert to SleeperUser for compatibility
    func toSleeperUser() -> SleeperUser {
        return SleeperUser(
            userID: id,
            username: displayName ?? "\(firstName ?? "")\(lastName ?? "")",
            displayName: displayName,
            avatar: nil
        )
    }
}

// MARK: -> ESPN Roster
struct ESPNRoster: Codable {
    let entries: [ESPNRosterEntry]?
}

struct ESPNRosterEntry: Codable {
    let playerId: Int
    let lineupSlotId: Int?
    let playerPoolEntry: ESPNPlayerPoolEntry?
    
    var player: ESPNPlayer? {
        return playerPoolEntry?.player
    }
}

// MARK: -> ESPN Player Pool Entry
struct ESPNPlayerPoolEntry: Codable {
    let id: Int
    let player: ESPNPlayer?
    let ratings: [String: ESPNRating]?
}

// MARK: -> ESPN Player
struct ESPNPlayer: Codable, Identifiable {
    let id: Int
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let jersey: String?
    let proTeamId: Int?
    let defaultPositionId: Int?
    let eligibleSlots: [Int]?
    let stats: [ESPNPlayerStats]?
    let ownership: ESPNOwnership?
    
    /// Convert to SleeperPlayer for compatibility
    func toSleeperPlayer() -> SleeperPlayer? {
        guard let firstName = firstName,
              let lastName = lastName,
              let positionId = defaultPositionId,
              let position = ESPNPositionMap.positionIdToSleeperPosition[positionId],
              let proTeamId = proTeamId,
              let team = ESPNTeamMap.teamIdToAbbreviation[proTeamId] else {
            return nil
        }
        
        // Create a SleeperPlayer using the custom decoder
        let playerData: [String: Any] = [
            "player_id": String(id),
            "first_name": firstName,
            "last_name": lastName,
            "position": position,
            "team": team,
            "number": jersey as Any,
            "status": "Active", // Default status
            "espn_id": String(id)
        ]
        
        // Convert to JSON Data and decode using SleeperPlayer's custom decoder
        guard let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
              let sleeperPlayer = try? JSONDecoder().decode(SleeperPlayer.self, from: jsonData) else {
            return nil
        }
        
        return sleeperPlayer
    }
}

// MARK: -> ESPN Player Stats
struct ESPNPlayerStats: Codable {
    let id: String?
    let proTeamId: Int?
    let scoringPeriodId: Int?
    let seasonId: Int?
    let statSourceId: Int?
    let statSplitTypeId: Int?
    let stats: [String: Double]?
}

// MARK: -> ESPN Ownership
struct ESPNOwnership: Codable {
    let percentOwned: Double?
    let percentChange: Double?
    let percentStarted: Double?
    let auctionValueAverage: Double?
}

// MARK: -> ESPN Rating
struct ESPNRating: Codable {
    let totalRating: Double?
    let totalRanking: Int?
    let positionalRanking: Int?
}

// MARK: -> ESPN Stat Value
struct ESPNStatValue: Codable {
    let value: Double?
    let result: String?

    // Custom decoder to handle both dictionary and direct number
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as a direct Double first
        if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
            self.result = nil
            return
        }
        
        // Fallback to decoding as a Dictionary
        let dictionaryContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try dictionaryContainer.decodeIfPresent(Double.self, forKey: .value)
        self.result = try dictionaryContainer.decodeIfPresent(String.self, forKey: .result)
    }

    // Custom encoder (optional but good practice)
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        // If it's a simple value, encode just the double
        if result == nil, let value = value {
            try container.encode(value)
        } else {
            // Encode as a dictionary if it has more properties
            var dictionaryContainer = encoder.container(keyedBy: CodingKeys.self)
            try dictionaryContainer.encodeIfPresent(value, forKey: .value)
            try dictionaryContainer.encodeIfPresent(result, forKey: .result)
        }
    }

    enum CodingKeys: String, CodingKey {
        case value, result
    }
}

// MARK: -> ESPN League Settings
struct ESPNLeagueSettings: Codable {
    let name: String?
    let playoffTeamCount: Int?
    let playoffWeekStart: Int?
    let tradeDeadline: Int?
    let rosterSettings: ESPNRosterSettings?
    let scoringSettings: ESPNScoringSettings?
}

// MARK: -> ESPN Roster Settings
struct ESPNRosterSettings: Codable {
    let lineupSlots: [ESPNLineupSlot]?
}

struct ESPNLineupSlot: Codable {
    let slotCategoryId: Int
    let slotCount: Int
}

// MARK: -> ESPN Scoring Settings
struct ESPNScoringSettings: Codable {
    let matchupPeriodCount: Int?
    let matchupPeriodLength: Int?
    let playoffMatchupPeriodLength: Int?
    let scoringItems: [ESPNScoringItem]?
}

struct ESPNScoringItem: Codable {
    let statId: Int?
    let points: Double?
    let pointsOverrides: [String: Double]?
}

// MARK: -> ESPN Draft Pick (for draft results)
struct ESPNDraftPick: Codable, Identifiable {
    let id: Int
    let playerId: Int
    let teamId: Int
    let nominatingTeamId: Int?
    let bid: Double?
    let keeper: Bool?
    let overallPickNumber: Int?
    let roundId: Int?
    let roundPickNumber: Int?
    
    /// Convert to SleeperPick for compatibility
    func toSleeperPick(draftID: String, playerDirectory: [Int: ESPNPlayer]) -> SleeperPick? {
        guard playerDirectory[playerId] != nil else { return nil }
        
        // Convert ESPN player ID to Sleeper player ID using espnID matching
        let espnPlayerIDString = String(playerId)
        guard let sleeperPlayer = PlayerDirectoryStore.shared.playerByESPNID(espnPlayerIDString) else {
            print("⚠️ Could not find Sleeper player for ESPN draft pick ID: \(espnPlayerIDString)")
            return nil
        }
        
        return SleeperPick(
            draftID: draftID,
            pickNo: overallPickNumber ?? id,
            round: roundId ?? ((overallPickNumber ?? id) / 12) + 1, // Estimate round
            draftSlot: ((overallPickNumber ?? id) % 12) + 1, // Estimate slot
            rosterID: teamId,
            pickedBy: String(teamId), // Use team ID as picker
            playerID: sleeperPlayer.playerID, // Use Sleeper player ID instead of ESPN ID
            metadata: SleeperPickMetadata(
                firstName: sleeperPlayer.firstName,
                lastName: sleeperPlayer.lastName,
                position: sleeperPlayer.position,
                team: sleeperPlayer.team,
                number: sleeperPlayer.number?.description,
                status: sleeperPlayer.status ?? "Active",
                sport: "nfl",
                injuryStatus: sleeperPlayer.injuryStatus,
                newsUpdated: nil
            ),
            isKeeper: keeper,
            timestamp: nil // ESPN doesn't always provide timestamp
        )
    }
}

// MARK: -> Position Mapping
struct ESPNPositionMap {
    // ESPN position ID to Sleeper position string
    static let positionIdToSleeperPosition: [Int: String] = [
        1: "QB",
        2: "RB",
        3: "WR",
        4: "TE",
        5: "K",
        16: "DST",
        17: "K", // Place kicker
        20: "FLEX" // Flex position
    ]
    
    // ESPN slot category to Sleeper position
    static let slotToPosition: [Int: String] = [
        0: "QB",
        2: "RB",
        4: "WR",
        6: "TE",
        17: "K",
        16: "DST",
        23: "FLEX", // RB/WR/TE
        7: "OP", // Offensive Player
        20: "BN", // Bench
        21: "IR" // Injured Reserve
    ]
}

// MARK: -> Team Mapping
struct ESPNTeamMap {
    // ESPN team ID to NFL team abbreviation
    static let teamIdToAbbreviation: [Int: String] = [
        1: "ATL", 2: "BUF", 3: "CHI", 4: "CIN", 5: "CLE", 6: "DAL", 7: "DEN", 8: "DET",
        9: "GB", 10: "TEN", 11: "IND", 12: "KC", 13: "LV", 14: "LAR", 15: "MIA", 16: "MIN",
        17: "NE", 18: "NO", 19: "NYG", 20: "NYJ", 21: "PHI", 22: "ARI", 23: "PIT", 24: "LAC",
        25: "SF", 26: "SEA", 27: "TB", 28: "WSH", 29: "CAR", 30: "JAX", 33: "BAL", 34: "HOU"
    ]
}

// MARK: -> Draft Response Wrapper
struct ESPNDraftResponse: Codable {
    let draftDetail: ESPNDraftDetail?
    let picks: [ESPNDraftPick]?
    let teams: [ESPNTeam]?
}