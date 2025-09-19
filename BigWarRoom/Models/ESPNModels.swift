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
                // x// x Print("     🎯 Using firstName + lastName: '\(fullName)'")
                return fullName
            }
            
            // Priority 2: Use displayName if it's not generic ESPN crap
            if let displayName = member.displayName, 
               !displayName.isEmpty,
               !displayName.lowercased().hasPrefix("espnfan"),
               !displayName.lowercased().hasPrefix("team "),
               displayName.count > 3 {
                // x// x Print("     🎯 Using meaningful displayName: '\(displayName)'")
                return displayName
            }
            
            // Priority 3: Fall back to displayName even if generic (better than nothing)
            if let displayName = member.displayName, !displayName.isEmpty {
                // x// x Print("     ⚠️ Using generic displayName: '\(displayName)'")
                return displayName
            }
        }
        
        // Final fallback
        // x// x Print("     ❌ No member found, using fallback")
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
                type: nil  // Add the type field - ESPN leagues are regular (type 0)
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
            // x// x Print("⚠️ Could not find Sleeper player for ESPN ID: \(espnPlayerID)")
            return nil
        } ?? []
        
        // x// x Print("🔄 Converted ESPN roster: \(roster?.entries?.count ?? 0) ESPN players -> \(sleeperPlayerIDs.count) Sleeper players")
        
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
//            // x// x Print("⚠️ Could not find Sleeper player for ESPN draft pick ID: \(espnPlayerIDString)")
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
    static let statIdToSleeperKey: [Int: String] = [
        // Passing
        0: "pass_att",        // Passing Attempts
        1: "pass_cmp",        // Passing Completions  
        3: "pass_yd",         // Passing Yards
        4: "pass_td",         // Passing Touchdowns
        20: "pass_int",       // QB Interceptions
        21: "pass_sack",      // Sacks (against QB)
        68: "pass_fd",        // Passing 1st Downs (CORRECT stat ID)
        
        // Rushing
        23: "rush_att",       // Rushing Attempts  
        24: "rush_yd",        // 🔥 FIXED: Rushing Yards (keep consistent)
        25: "rush_td",        // Rushing Touchdowns
        26: "rush_fd",        // Rushing 1st Downs
        // 🔥 REMOVED: 35: "rush_att" - duplicate of 23, causes conflicts
        
        // Receiving
        41: "rec",            // Receptions
        42: "rec_yd",         // Receiving Yards
        43: "rec_td",         // Receiving Touchdowns
        44: "rec_tgt",        // Targets
        45: "rec_fd",         // Receiving 1st Downs
        
        // Fumbles
        72: "fum",            // Fumbles
        73: "fum_lost",       // Fumbles Lost
        
        // Kicking
        74: "xpm",            // Extra Points Made
        77: "fgm",            // Field Goals Made
        78: "xpmiss",         // Extra Point Missed
        80: "fgmiss",         // Field Goals Missed
        137: "fga",           // Field Goal Attempts (total)
        
        // Defense
        85: "def_tkl",        // Tackles
        86: "def_ast",        // Assisted Tackles
        87: "def_solo",       // Solo Tackles
        88: "def_comb",       // Combined Tackles
        89: "def_int",        // Defensive Interceptions
        90: "def_fum_rec",    // Fumble Recoveries
        91: "def_td",         // Defensive Touchdowns
        92: "def_sack",       // Sacks (by defense)
        93: "def_safe",       // Safeties
        94: "def_stf",        // Defensive Stuffs
        95: "def_pass_def",   // Passes Defended
        96: "def_int_yd",     // Interception Return Yards
        97: "def_fum_force",  // Forced Fumbles
        98: "def_fum_rec_yd", // Fumble Recovery Yards
        99: "def_tkl_loss",   // Tackles for Loss
        
        // Bonus/Special
        101: "pass_40",       // 40+ Yard Pass Completion
        102: "pass_td_40p",   // 40+ Yard Pass TD
        103: "pass_td_50p",   // 50+ Yard Pass TD
        104: "rush_40",       // 40+ Yard Rush
        105: "rec_40",        // 40+ Yard Reception
        
        // 2-Point Conversions
        15: "pass_2pt",       // 2-Point Conversion Pass
        16: "rush_2pt",       // 2-Point Conversion Rush  
        17: "rec_2pt",        // 2-Point Conversion Reception
        18: "fum_rec_td",     // Fumble Recovery TD
        19: "int_td",         // Interception Return TD
        
        // Special teams and returns
        37: "kick_ret_yd",    // Kick Return Yards
        38: "punt_ret_yd",    // Punt Return Yards
        46: "kick_ret_td",    // Kick Return TD
        50: "kick_ret_att",   // Kick Return Attempts
        51: "punt_ret_att",   // Punt Return Attempts  
        53: "punt_ret_td",    // Punt Return TD
        57: "punt_in20",      // Punts Inside 20
        63: "punt_yd",        // Punt Yards
        131: "punt_att",      // Punt Attempts
        
        // Special teams defense
        123: "st_td",         // Special Teams TD
        124: "st_fum_rec",    // Special Teams Fumble Recovery
        125: "st_ff",         // Special Teams Forced Fumble
        128: "blk_kick",      // Blocked Kick
        129: "blk_punt",      // Blocked Punt
        
        // Kicking distance ranges
        132: "fga_0_19",      // FG Attempted 0-19 yards
        133: "fga_20_29",     // FG Attempted 20-29 yards
        134: "fga_30_39",     // FG Attempted 30-39 yards
        135: "fga_40_49",     // FG Attempted 40-49 yards
        136: "fga_50p",       // FG Attempted 50+ yards
        
        // Unknown/Advanced stats
        130: "unknown_130",   // Unknown ESPN stat 130 - appears in league scoring but unmapped
        198: "qb_hit",        // QB Hits
        201: "pass_drop",     // Dropped Passes
        206: "pass_air_yd",   // Passing Air Yards
        209: "pass_yac",      // Yards After Catch
        211: "pass_rz_att",   // Red Zone Pass Attempts
        212: "rush_rz_att",   // Red Zone Rush Attempts
        213: "rec_rz_tgt",    // Red Zone Targets
    ]
}