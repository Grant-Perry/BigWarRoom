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
    let positionAgainstOpponent: ESPNPositionalRatingsResponse? // 🔥 OPRK data (ESPN calls it positionAgainstOpponent)
    
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
                return fullName
            }
            
            // Priority 2: Use displayName if it's not generic ESPN crap
            if let displayName = member.displayName, 
               !displayName.isEmpty,
               !displayName.lowercased().hasPrefix("espnfan"),
               !displayName.lowercased().hasPrefix("team "),
               displayName.count > 3 {
                return displayName
            }
            
            // Priority 3: Fall back to displayName even if generic (better than nothing)
            if let displayName = member.displayName, !displayName.isEmpty {
                return displayName
            }
        }
        
        // Final fallback
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
                taxiSlots: nil,
                leagueType: nil,
                isChopped: nil,
                type: nil,  // Add the type field - ESPN leagues are regular (type 0)
                waiverBudget: nil  // ESPN FAAB - not implemented yet, leave nil for now
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
        // 🎯 NEW: Convert ESPN player IDs to Sleeper IDs using canonical mapping
        let sleeperPlayerIDs = roster?.entries?.compactMap { entry -> String? in
            let espnPlayerID = String(entry.playerId)
            // Use canonical ESPN→Sleeper ID mapping instead of unreliable lookup
            let canonicalSleeperID = ESPNSleeperIDCanonicalizer.shared.getCanonicalSleeperID(forESPNID: espnPlayerID)
            return canonicalSleeperID
        } ?? []
        
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
        
        // 🎯 NEW: Convert ESPN player ID to Sleeper ID using canonical mapping
        let espnPlayerIDString = String(playerId)
        let canonicalSleeperID = ESPNSleeperIDCanonicalizer.shared.getCanonicalSleeperID(forESPNID: espnPlayerIDString)
        
        // Get player info from canonical Sleeper ID
        guard let sleeperPlayer = PlayerDirectoryStore.shared.player(for: canonicalSleeperID) else {
            return nil
        }
        
        return SleeperPick(
            draftID: draftID,
            pickNo: overallPickNumber ?? id,
            round: roundId ?? ((overallPickNumber ?? id) / 12) + 1, // Estimate round
            draftSlot: ((overallPickNumber ?? id) % 12) + 1, // Estimate slot
            rosterID: teamId,
            pickedBy: String(teamId), // Use team ID as picker
            playerID: canonicalSleeperID, // 🎯 Use canonical Sleeper ID
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

// MARK: -> ESPN Stat ID Mapping
struct ESPNStatIDMapper {
    /// Get human-readable stat display name from ESPN stat ID (for score breakdown)
    static func getStatDisplayName(for statId: Int) -> String {
        switch statId {
        // Passing
        case 0: return "Passing Attempts"
        case 1: return "Pass Completed"
        case 3: return "Passing Yards"
        case 4: return "Passing TD"
        case 20: return "QB Interception"  // 🔥 FIXED: Disambiguate from defensive INT
        case 21: return "Sacked"
        case 68: return "Passing 1st Down"  // 🔥 FIXED: Move from 24 to proper stat ID
        
        // Rushing
        case 23: return "Rushing Attempts"
        case 24: return "Rushing Yards"  // 🔥 FIXED: Keep consistent - 24 = rushing yards
        case 25: return "Rushing TD"
        case 26: return "Rushing 1st Down"
        
        // Receiving
        case 41: return "Reception"
        case 42: return "Receiving Yards"
        case 43: return "Receiving TD"
        case 44: return "Targets"
        case 45: return "Receiving 1st Down"
        
        // Fumbles
        case 72: return "Fumble"
        case 73: return "Fumble Lost"
        
        // Kicking
        case 74: return "Extra Point Made"
        case 77: return "Field Goal Made"
        case 78: return "Extra Point Missed"
        case 80: return "Field Goal Missed"
        
        // Defense
        case 87: return "Solo Tackles"
        case 88: return "Combined Tackles"
        case 89: return "Defensive Interception"  // 🔥 FIXED: Disambiguate from QB INT
        case 90: return "Fumble Recovery"
        case 91: return "Defensive TD"
        case 92: return "Sack"
        case 93: return "Safety"
        case 94: return "Defensive Stuffs"
        
        // Bonus scoring
        case 101: return "40+ Yard Completion Bonus"
        case 102: return "40+ Yard Pass TD Bonus"
        case 103: return "50+ Yard Pass TD Bonus"
        case 104: return "40+ Yard Rush Bonus"
        case 105: return "40+ Yard Reception Bonus"
        
        // Special teams and returns
        case 50: return "Kick Return Attempts"
        case 51: return "Punt Return Attempts"
        case 131: return "Punt Attempts"
        case 137: return "Field Goal Attempts"
        
        // Unknown/Advanced stats  
        case 130: return "Unknown Stat 130"
        
        // 🔥 REMOVE: Duplicate case 35 (was "Rushing Attempts") - handled by case 23
        
        default: return "Unknown Stat \(statId)"
        }
    }
    
    /// Map ESPN stat IDs to Sleeper stat keys for matching player stats
    /// 🔥 COMPLETELY REBUILT using official cwendt94/espn-api source
    static let statIdToSleeperKey: [Int: String] = [
        // 🔥 CORE PASSING STATS (verified against cwendt94/espn-api)
        0: "pass_att",        // passingAttempts
        1: "pass_cmp",        // passingCompletions  
        3: "pass_yd",         // passingYards
        4: "pass_td",         // passingTouchdowns
        15: "pass_td_40p",    // passing40PlusYardTD
        16: "pass_td_50p",    // passing50PlusYardTD
        19: "pass_2pt",       // passing2PtConversions
        20: "pass_int",       // passingInterceptions
        
        // 🔥 CORE RUSHING STATS (verified)
        23: "rush_att",       // rushingAttempts  
        24: "rush_yd",        // rushingYards
        25: "rush_td",        // rushingTouchdowns
        26: "rush_2pt",       // rushing2PtConversions
        35: "rush_td_40p",    // rushing40PlusYardTD
        36: "rush_td_50p",    // rushing50PlusYardTD
        
        // 🔥 CORE RECEIVING STATS (verified)
        41: "rec",            // receivingReceptions
        42: "rec_yd",         // receivingYards ✅ CONFIRMED CORRECT
        43: "rec_td",         // receivingTouchdowns
        44: "rec_2pt",        // receiving2PtConversions
        45: "rec_td_40p",     // receiving40PlusYardTD
        46: "rec_td_50p",     // receiving50PlusYardTD
        58: "rec_tgt",        // receivingTargets
        
        // 🔥 FUMBLES (verified)
        68: "fum",            // fumbles
        72: "fum_lost",       // lostFumbles
        
        // 🔥 KICKING STATS (verified - ESPN uses different ranges than Sleeper)
        74: "fgm_50p",        // madeFieldGoalsFrom50Plus (ESPN: 50+, not 60+)
        77: "fgm_40_49",      // madeFieldGoalsFrom40To49
        80: "fgm_0_39",       // madeFieldGoalsFromUnder40  
        83: "fgm",            // madeFieldGoals (total)
        86: "xpm",            // madeExtraPoints
        88: "xpmiss",         // missedExtraPoints
        
        // 🔥 DEFENSE/ST STATS (verified)
        95: "def_int",        // defensiveInterceptions
        96: "def_fum_rec",    // defensiveFumbles (fumble recoveries)
        97: "blk_kick",       // defensiveBlockedKicks
        98: "def_safe",       // defensiveSafeties
        99: "def_sack",       // defensiveSacks
        101: "kick_ret_td",   // kickoffReturnTouchdowns
        102: "punt_ret_td",   // puntReturnTouchdowns
        103: "int_td",        // interceptionReturnTouchdowns
        104: "fum_rec_td",    // fumbleReturnTouchdowns
        106: "def_fum_force", // defensiveForcedFumbles
        107: "def_ast",       // defensiveAssistedTackles
        108: "def_solo",      // defensiveSoloTackles
        109: "def_comb",      // defensiveTotalTackles
        113: "def_pass_def",  // defensivePassesDefensed
        114: "kick_ret_yd",   // kickoffReturnYards
        115: "punt_ret_yd",   // puntReturnYards
        
        // 🔥 ADVANCED KICKING (verified ranges)
        201: "fgm_60p",       // madeFieldGoalsFrom60Plus (ESPN specific)
        
        // 🔥 2-POINT RETURNS & SPECIAL (verified)
        205: "def_2pt_ret",   // defensive2PtReturns
        206: "def_2pt_ret",   // defensive2PtReturns (duplicate mapping, same stat)
        
        // 🔥 FIRST DOWNS (verified)
        211: "pass_fd",       // passingFirstDown  
        212: "rush_fd",       // rushingFirstDown
        213: "rec_fd",        // receivingFirstDown
        
        // 🔥 REMOVED ALL THE BULLSHIT MAPPINGS:
        // - pass_air_yd (NEVER EXISTED)
        // - pass_yac (not in core stats)  
        // - qb_hit (not in core stats)
        // - pass_drop (not in core stats)
        // - All the red zone attempt garbage (not in core ESPN stats)
    ]
}

// MARK: -> ESPN Positional Ratings (OPRK Data)

/// ESPN Positional Ratings response structure
/// This contains OPRK (Opponent Rank) data for defenses against each position
/// Structure: positionAgainstOpponent -> positionalRatings -> [PositionID: PositionRatings]
struct ESPNPositionalRatingsResponse: Codable {
    let positionalRatings: [String: ESPNPositionRatings]?
}

/// Ratings for a specific position (contains average and by-opponent data)
struct ESPNPositionRatings: Codable {
    let average: Double?  // Just a number, not an object
    let ratingsByOpponent: [String: ESPNPositionalRating]?  // [TeamID: Rating]
}

/// Individual team's defensive rating against this position
struct ESPNPositionalRating: Codable {
    let rank: Int           // This is OPRK! (1-32, lower = tougher defense)
    let average: Double?    // Average points allowed to this position
}