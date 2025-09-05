//
//  SleeperModels.swift
//  BigWarRoom
//
//  Codable models for Sleeper API responses
//
// MARK: -> Sleeper API Models

import Foundation

// MARK: -> User
struct SleeperUser: Codable, Identifiable {
    let userID: String
    let username: String?  // 🔥 FIX: Make username optional since not all users have it
    let displayName: String?
    let avatar: String?
    
    var id: String { userID }
    
    /// Avatar URL (full size)
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
    }
    
    /// Avatar thumbnail URL
    var avatarThumbnailURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/thumbs/\(avatar)")
    }
    
    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatar
    }
}

// MARK: -> League
struct SleeperLeague: Codable, Identifiable {
    let leagueID: String
    let name: String
    let status: SleeperLeagueStatus
    let sport: String
    let season: String
    let seasonType: String
    let totalRosters: Int
    let draftID: String?
    let avatar: String?
    let settings: SleeperLeagueSettings?
    let scoringSettings: [String: Double]?
    let rosterPositions: [String]?
    
    var id: String { leagueID }
    
    /// League avatar URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
    }
    
    private enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case name
        case status
        case sport
        case season
        case seasonType = "season_type"
        case totalRosters = "total_rosters"
        case draftID = "draft_id"
        case avatar
        case settings
        case scoringSettings = "scoring_settings"
        case rosterPositions = "roster_positions"
    }
}

// MARK: -> League Status
enum SleeperLeagueStatus: String, Codable, CaseIterable {
    case preDraft = "pre_draft"
    case drafting = "drafting"
    case inSeason = "in_season"
    case complete = "complete"
    
    var isActive: Bool {
        self == .drafting
    }
    
    var displayName: String {
        switch self {
        case .preDraft: return "Pre-Draft"
        case .drafting: return "Drafting"
        case .inSeason: return "In Season"
        case .complete: return "Complete"
        }
    }
}

// MARK: -> League Settings
struct SleeperLeagueSettings: Codable {
    let teams: Int?
    let playoffTeams: Int?
    let playoffWeekStart: Int?
    let leagueAverageMatch: Int?
    let maxKeepers: Int?
    let tradeDeadline: Int?
    let reserveSlots: Int?
    let taxiSlots: Int?
    let leagueType: String?
    let isChopped: Bool?
    let type: Int?  // 🔥 THE KEY FIELD: 0=Redraft, 1=Keeper, 2=Dynasty, 3=Guillotine/Chopped
    
    /// Detect if this is a Chopped/elimination league - CENTRALIZED METHOD
    var isChoppedLeague: Bool {
        // PRIMARY: Check if type is 3 (Guillotine/Chopped) - THE OFFICIAL WAY
        if let type = type, type == 3 {
            return true
        }
        
        // FALLBACK: Check explicit Chopped flag for older leagues
        if let isChopped = isChopped, isChopped {
            return true
        }
        
        return false
    }
    
    /// STATIC helper method for checking any Sleeper league - CENTRALIZED FOR ENTIRE APP
    static func isChoppedLeague(_ league: SleeperLeague?) -> Bool {
        return league?.settings?.isChoppedLeague ?? false
    }
    
    private enum CodingKeys: String, CodingKey {
        case teams
        case playoffTeams = "playoff_teams"
        case playoffWeekStart = "playoff_week_start"
        case leagueAverageMatch = "league_average_match"
        case maxKeepers = "max_keepers"
        case tradeDeadline = "trade_deadline"
        case reserveSlots = "reserve_slots"
        case taxiSlots = "taxi_slots"
        case leagueType = "league_type"
        case isChopped = "is_chopped"
        case type = "type"  // 🔥 Add the type field
    }
}

// MARK: -> Draft
struct SleeperDraft: Codable, Identifiable {
    let draftID: String
    let leagueID: String?  // Changed from String to String? to handle mock drafts
    let status: SleeperDraftStatus
    let type: SleeperDraftType
    let sport: String
    let season: String
    let seasonType: String
    let startTime: TimeInterval?
    let lastPicked: TimeInterval?
    let settings: SleeperDraftSettings?
    let metadata: SleeperDraftMetadata?
    let draftOrder: [String: Int]? // user_id -> draft slot
    let slotToRosterID: [String: Int]? // draft slot -> roster_id
    
    var id: String { draftID }
    
    /// Start time as Date
    var startDate: Date? {
        guard let startTime = startTime else { return nil }
        return Date(timeIntervalSince1970: startTime / 1000) // Sleeper uses milliseconds
    }
    
    /// Last pick time as Date
    var lastPickDate: Date? {
        guard let lastPicked = lastPicked else { return nil }
        return Date(timeIntervalSince1970: lastPicked / 1000)
    }
    
    private enum CodingKeys: String, CodingKey {
        case draftID = "draft_id"
        case leagueID = "league_id"
        case status
        case type
        case sport
        case season
        case seasonType = "season_type"
        case startTime = "start_time"
        case lastPicked = "last_picked"
        case settings
        case metadata
        case draftOrder = "draft_order"
        case slotToRosterID = "slot_to_roster_id"
    }
}

// MARK: -> Draft Status
enum SleeperDraftStatus: String, Codable {
    case preDraft = "pre_draft"
    case drafting = "drafting"
    case paused = "paused"
    case complete = "complete"
    
    var isActive: Bool {
        self == .drafting
    }
    
    /// Is this draft active, upcoming, or worth monitoring?
    var isActiveOrUpcoming: Bool {
        self == .drafting || self == .preDraft || self == .paused
    }
    
    var displayName: String {
        switch self {
        case .preDraft: return "Pre-Draft"
        case .drafting: return "Live"
        case .paused: return "Paused"
        case .complete: return "Complete"
        }
    }
    
    var emoji: String {
        switch self {
        case .preDraft: return "⏰"
        case .drafting: return "🔴"
        case .paused: return "⏸️"
        case .complete: return "✅"
        }
    }
}

// MARK: -> Draft Type
enum SleeperDraftType: String, Codable {
    case snake = "snake"
    case linear = "linear"
    case auction = "auction"
    
    var displayName: String {
        switch self {
        case .snake: return "Snake"
        case .linear: return "Linear"
        case .auction: return "Auction"
        }
    }
}

// MARK: -> Draft Settings
struct SleeperDraftSettings: Codable {
    let teams: Int?
    let rounds: Int?
    let pickTimer: Int? // seconds
    let slotsQB: Int?
    let slotsRB: Int?
    let slotsWR: Int?
    let slotsTE: Int?
    let slotsFlex: Int?
    let slotsK: Int?
    let slotsDEF: Int?
    let slotsBN: Int? // bench
    
    private enum CodingKeys: String, CodingKey {
        case teams
        case rounds
        case pickTimer = "pick_timer"
        case slotsQB = "slots_qb"
        case slotsRB = "slots_rb"
        case slotsWR = "slots_wr"
        case slotsTE = "slots_te"
        case slotsFlex = "slots_flex"
        case slotsK = "slots_k"
        case slotsDEF = "slots_def"
        case slotsBN = "slots_bn"
    }
}

// MARK: -> Draft Metadata
struct SleeperDraftMetadata: Codable {
    let name: String?
    let description: String?
    let scoringType: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case scoringType = "scoring_type"
    }
}

// MARK: -> Draft Pick
struct SleeperPick: Codable, Identifiable {
    let draftID: String
    let pickNo: Int
    let round: Int
    let draftSlot: Int
    let rosterID: Int?
    let pickedBy: String?
    let playerID: String?
    let metadata: SleeperPickMetadata?
    let isKeeper: Bool?
    let timestamp: TimeInterval?
    
    let espnPlayerInfo: ESPNPlayerInfo?
    
    var id: String { "\(draftID)_\(pickNo)" }
    
    enum CodingKeys: String, CodingKey {
        case draftID = "draft_id"
        case pickNo = "pick_no"
        case round
        case draftSlot = "draft_slot"
        case rosterID = "roster_id"
        case pickedBy = "picked_by"
        case playerID = "player_id"
        case metadata
        case isKeeper = "is_keeper"
        case timestamp
        // Don't include espnPlayerInfo in CodingKeys - it's not from API
    }
    
    init(draftID: String, pickNo: Int, round: Int, draftSlot: Int, rosterID: Int?, pickedBy: String?, playerID: String?, metadata: SleeperPickMetadata?, isKeeper: Bool?, timestamp: TimeInterval?, espnPlayerInfo: ESPNPlayerInfo? = nil) {
        self.draftID = draftID
        self.pickNo = pickNo
        self.round = round
        self.draftSlot = draftSlot
        self.rosterID = rosterID
        self.pickedBy = pickedBy
        self.playerID = playerID
        self.metadata = metadata
        self.isKeeper = isKeeper
        self.timestamp = timestamp
        self.espnPlayerInfo = espnPlayerInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        draftID = try container.decode(String.self, forKey: .draftID)
        pickNo = try container.decode(Int.self, forKey: .pickNo)
        round = try container.decode(Int.self, forKey: .round)
        draftSlot = try container.decode(Int.self, forKey: .draftSlot)
        rosterID = try container.decodeIfPresent(Int.self, forKey: .rosterID)
        pickedBy = try container.decodeIfPresent(String.self, forKey: .pickedBy)
        playerID = try container.decodeIfPresent(String.self, forKey: .playerID)
        metadata = try container.decodeIfPresent(SleeperPickMetadata.self, forKey: .metadata)
        isKeeper = try container.decodeIfPresent(Bool.self, forKey: .isKeeper)
        timestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .timestamp)
        // ESPN player info is not decoded from API - only set programmatically
        espnPlayerInfo = nil
    }
}

struct ESPNPlayerInfo: Codable {
    let espnPlayerID: Int
    let fullName: String
    let firstName: String?
    let lastName: String?
    let position: String?
    let team: String?
    let jerseyNumber: String?
}

// MARK: -> Pick Metadata (Rich Player Info)
struct SleeperPickMetadata: Codable {
    let firstName: String?
    let lastName: String?
    let position: String?
    let team: String?
    let number: String?
    let status: String?
    let sport: String?
    let injuryStatus: String?
    let newsUpdated: String?
    
    /// Full player name
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    /// Short display name (e.g., "J Chase")
    var shortName: String {
        let firstInitial = firstName?.prefix(1).uppercased() ?? ""
        let last = lastName ?? ""
        return "\(firstInitial) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    private enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case position
        case team
        case number
        case status
        case sport
        case injuryStatus = "injury_status"
        case newsUpdated = "news_updated"
    }
}

// MARK: -> Player (Master Directory)
struct SleeperPlayer: Codable, Identifiable {
    let playerID: String
    let firstName: String?
    let lastName: String?
    let position: String?
    let team: String?
    let number: Int?
    let status: String?
    let height: String?
    let weight: String?
    let age: Int?
    let college: String?
    let yearsExp: Int?
    let fantasyPositions: [String]?
    let injuryStatus: String?
    let depthChartOrder: Int?
    let depthChartPosition: Int?
    let searchRank: Int?
    let hashtag: String?
    let birthCountry: String?
    // External IDs for cross-reference - make these flexible
    let espnID: String?
    let yahooID: String?
    let rotowireID: String?
    let rotoworldID: String?
    let fantasyDataID: String?
    let sportradarID: String?
    let statsID: String?
    
    var id: String { playerID }
    
    /// Full player name
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    /// Short display name (e.g., "J Chase")
    var shortName: String {
        let firstInitial = firstName?.prefix(1).uppercased() ?? ""
        let last = lastName ?? ""
        return "\(firstInitial) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    /// Player headshot URL (Sleeper CDN)
    var headshotURL: URL? {
        return URL(string: "https://sleepercdn.com/content/nfl/players/\(playerID).jpg")
    }
    
    /// Sleeper thumbnail version
    var headshotThumbnailURL: URL? {
        return URL(string: "https://sleepercdn.com/content/nfl/players/thumb/\(playerID).jpg")
    }
    
    /// All Sleeper headshot variations
    var sleeperHeadshotURLs: [URL] {
        return [
            URL(string: "https://sleepercdn.com/content/nfl/players/\(playerID).jpg"),
            URL(string: "https://sleepercdn.com/content/nfl/players/thumb/\(playerID).jpg"),
            URL(string: "https://sleepercdn.com/content/nfl/players/\(playerID).png")
        ].compactMap { $0 }
    }
    
    // MARK: -> Custom Decoding to Handle Mixed Types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        playerID = try container.decode(String.self, forKey: .playerID)
        
        // Optional basic fields
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        team = try container.decodeIfPresent(String.self, forKey: .team)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        height = try container.decodeIfPresent(String.self, forKey: .height)
        weight = try container.decodeIfPresent(String.self, forKey: .weight)
        college = try container.decodeIfPresent(String.self, forKey: .college)
        fantasyPositions = try container.decodeIfPresent([String].self, forKey: .fantasyPositions)
        injuryStatus = try container.decodeIfPresent(String.self, forKey: .injuryStatus)
        hashtag = try container.decodeIfPresent(String.self, forKey: .hashtag)
        birthCountry = try container.decodeIfPresent(String.self, forKey: .birthCountry)
        
        // Flexible Int fields that could be String or Int
        number = Self.decodeFlexibleInt(container, key: .number)
        age = Self.decodeFlexibleInt(container, key: .age)
        yearsExp = Self.decodeFlexibleInt(container, key: .yearsExp)
        depthChartOrder = Self.decodeFlexibleInt(container, key: .depthChartOrder)
        depthChartPosition = Self.decodeFlexibleInt(container, key: .depthChartPosition)
        searchRank = Self.decodeFlexibleInt(container, key: .searchRank)
        
        // External IDs - handle both String and Int types
        espnID = Self.decodeFlexibleString(container, key: .espnID)
        yahooID = Self.decodeFlexibleString(container, key: .yahooID)
        rotowireID = Self.decodeFlexibleString(container, key: .rotowireID)
        rotoworldID = Self.decodeFlexibleString(container, key: .rotoworldID)
        fantasyDataID = Self.decodeFlexibleString(container, key: .fantasyDataID)
        sportradarID = Self.decodeFlexibleString(container, key: .sportradarID)
        statsID = Self.decodeFlexibleString(container, key: .statsID)
    }
    
    // Helper function to decode values that could be String or Int
    private static func decodeFlexibleString(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        // Try String first
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        // Try Int and convert to String
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        // Try Double and convert to String (just in case)
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return String(Int(doubleValue))
        }
        return nil
    }
    
    // Helper function to decode Int values that could be String or Int
    private static func decodeFlexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        // Try Int first
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        // Try String and convert to Int
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
           let intValue = Int(stringValue) {
            return intValue
        }
        // Try Double and convert to Int
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case position
        case team
        case number
        case status
        case height
        case weight
        case age
        case college
        case yearsExp = "years_exp"
        case fantasyPositions = "fantasy_positions"
        case injuryStatus = "injury_status"
        case depthChartOrder = "depth_chart_order"
        case depthChartPosition = "depth_chart_position"
        case searchRank = "search_rank"
        case hashtag
        case birthCountry = "birth_country"
        case espnID = "espn_id"
        case yahooID = "yahoo_id"
        case rotowireID = "rotowire_id"
        case rotoworldID = "rotoworld_id"
        case fantasyDataID = "fantasy_data_id"
        case sportradarID = "sportradar_id"
        case statsID = "stats_id"
    }
}

// MARK: -> NFL State
struct SleeperNFLState: Codable {
    let season: String
    let seasonType: String
    let week: Int
    let leg: Int // week of regular season
    let seasonStartDate: String
    let leagueSeason: String
    let leagueCreateSeason: String
    let displayWeek: Int
    let previousSeason: String
    
    /// Season start as Date
    var seasonStart: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: seasonStartDate)
    }
    
    private enum CodingKeys: String, CodingKey {
        case season
        case seasonType = "season_type"
        case week
        case leg
        case seasonStartDate = "season_start_date"
        case leagueSeason = "league_season"
        case leagueCreateSeason = "league_create_season"
        case displayWeek = "display_week"
        case previousSeason = "previous_season"
    }
}

// MARK: -> Roster
struct SleeperRoster: Codable, Identifiable {
    let rosterID: Int
    let ownerID: String?
    let leagueID: String
    let playerIDs: [String]?
    let draftSlot: Int?
    let wins: Int?
    let losses: Int?
    let ties: Int?
    let totalMoves: Int?
    let totalMovesMade: Int?
    let waiversBudgetUsed: Int?
    let settings: SleeperRosterSettings?
    let metadata: SleeperRosterMetadata?
    
    var id: Int { rosterID }
    
    /// Get display name from owner or metadata
    var ownerDisplayName: String? {
        metadata?.ownerName ?? metadata?.teamName
    }
    
    private enum CodingKeys: String, CodingKey {
        case rosterID = "roster_id"
        case ownerID = "owner_id"
        case leagueID = "league_id"
        case playerIDs = "players"
        case draftSlot = "draft_slot"
        case wins
        case losses
        case ties
        case totalMoves = "total_moves"
        case totalMovesMade = "total_moves_made"
        case waiversBudgetUsed = "waiver_budget_used"
        case settings
        case metadata
    }
}

// MARK: -> Roster Settings
struct SleeperRosterSettings: Codable {
    let wins: Int?
    let waiver_position: Int?
    let waiver_budget_used: Int?
    let total_moves: Int?
    let ties: Int?
    let losses: Int?
    let fpts_decimal: Double?
    let fpts_against_decimal: Double?
    let fpts_against: Double?
    let fpts: Double?
}

// MARK: -> Roster Metadata
struct SleeperRosterMetadata: Codable {
    let teamName: String?
    let ownerName: String?
    let avatar: String?
    let record: String?
    
    private enum CodingKeys: String, CodingKey {
        case teamName = "team_name"
        case ownerName = "owner_name"
        case avatar
        case record
    }
}

// MARK: -> League Users (for team names and metadata)
struct SleeperLeagueUser: Codable, Identifiable {
    let userID: String
    let username: String?  // 🔥 FIX: Make username optional 
    let displayName: String?
    let avatar: String?
    let metadata: SleeperUserMetadata?
    let isOwner: Bool?
    
    var id: String { userID }
    
    /// Team name from metadata
    var teamName: String? {
        return metadata?.teamName ?? displayName
    }
    
    /// Avatar URL (full size)
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/\(avatar)")
    }
    
    /// Avatar thumbnail URL
    var avatarThumbnailURL: URL? {
        guard let avatar = avatar else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/thumbs/\(avatar)")
    }
    
    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatar
        case metadata
        case isOwner = "is_owner"
    }
}

// MARK: -> User Metadata (for team names)
struct SleeperUserMetadata: Codable {
    let teamName: String?
    
    private enum CodingKeys: String, CodingKey {
        case teamName = "team_name"
    }
}

// MARK: -> Matchup Response (THE KEY MODEL FOR PROJECTED POINTS)
struct SleeperMatchupResponse: Codable, Identifiable {
    let rosterID: Int
    let points: Double?
    let projectedPoints: Double?  // 🎯 THIS IS WHAT WE NEED!
    let matchupID: Int?
    let starters: [String]?
    let players: [String]?
    let customPoints: Double?  // If commissioner manually adjusts
    
    var id: String { 
        return "\(rosterID)_\(matchupID ?? 0)"
    }
    
    /// Current points formatted
    var pointsString: String {
        guard let points = points else { return "0.00" }
        return String(format: "%.2f", points)
    }
    
    /// Projected points formatted (KEY FOR CHOPPED PREDICTIONS)
    var projectedPointsString: String {
        guard let projectedPoints = projectedPoints else { return "0.00" }
        return String(format: "%.2f", projectedPoints)
    }
    
    private enum CodingKeys: String, CodingKey {
        case rosterID = "roster_id"
        case points
        case projectedPoints = "projected_points"  // 🔥 Real Sleeper projections
        case matchupID = "matchup_id"
        case starters
        case players
        case customPoints = "custom_points"
    }
}