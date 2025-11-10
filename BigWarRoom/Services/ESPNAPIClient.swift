//
//  ESPNAPIClient.swift
//  BigWarRoom
//
//  ESPN Fantasy Football API networking client
//
// MARK: -> ESPN API Client

import Foundation

final class ESPNAPIClient: DraftAPIClient {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: ESPNAPIClient?
    
    static var shared: ESPNAPIClient {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance with default credentials
        let credentialsManager = ESPNCredentialsManager()
        let instance = ESPNAPIClient(credentialsManager: credentialsManager)
        credentialsManager.setAPIClient(instance) // Complete the circular dependency
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: ESPNAPIClient) {
        _shared = instance
    }
    
    // Updated to use working API subdomain from SleepThis
    private let baseURL = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons"
    private let session = URLSession.shared
    
    // 🔥 PHASE 2: Inject credentials manager instead of using .shared
    private let credentialsManager: ESPNCredentialsManager
    
    // 🔥 PHASE 2: Make initializer public and require dependency injection
    init(credentialsManager: ESPNCredentialsManager) {
        self.credentialsManager = credentialsManager
    }
    
    // MARK: -> Authentication Headers
    private func authHeaders() -> [String: String] {
        // Use dynamic credentials instead of hardcoded ones
        guard let headers = credentialsManager.generateAuthHeaders() else {
            return [:]
        }
        
        return headers
    }
    
    // MARK: -> DraftAPIClient Protocol Implementation
    
    /// Fetch user by username (ESPN doesn't have direct username lookup)
    func fetchUser(username: String) async throws -> SleeperUser {
        throw ESPNAPIError.unsupportedOperation("ESPN doesn't support username lookup")
    }
    
    /// Fetch user by ID (ESPN uses member lookup within leagues)
    func fetchUserByID(userID: String) async throws -> SleeperUser {
        throw ESPNAPIError.unsupportedOperation("ESPN doesn't support direct user lookup")
    }
    
    /// Fetch leagues for a user (ESPN requires knowing league IDs)
    func fetchLeagues(userID: String, season: String) async throws -> [SleeperLeague] {
        let currentSeason = season.isEmpty ? AppConstants.currentSeasonYear : season
        
        // Use dynamic league IDs from credentials manager instead of hardcoded ones
        guard !credentialsManager.leagueIDs.isEmpty else {
            throw ESPNAPIError.unsupportedOperation("No ESPN league IDs configured. Please add your league IDs in ESPN Setup.")
        }

        var leagues: [SleeperLeague] = []
        
        for leagueID in credentialsManager.leagueIDs {
            do {
                let league = try await fetchLeague(leagueID: leagueID)
                leagues.append(league)
            } catch {
                // Continue with other leagues even if one fails
            }
        }
        
        return leagues
    }
    
    /// Fetch a specific league by ID
    func fetchLeague(leagueID: String) async throws -> SleeperLeague {
        // Try with the best token for this league first
        let primaryToken = AppConstants.getESPNTokenForLeague(leagueID, year: AppConstants.currentSeasonYear)
        
        do {
            return try await fetchLeagueWithToken(leagueID: leagueID, token: primaryToken)
        } catch ESPNAPIError.authenticationFailed {            
            // Try with the alternate token
            let alternateToken = leagueID == "1241361400" ? 
                AppConstants.getPrimaryESPNToken(for: AppConstants.currentSeasonYear) : 
                AppConstants.getAlternateESPNToken(for: AppConstants.currentSeasonYear)
            
            return try await fetchLeagueWithToken(leagueID: leagueID, token: alternateToken)
        }
    }
    
    /// Fetch league with a specific token
    private func fetchLeagueWithToken(leagueID: String, token: String) async throws -> SleeperLeague {
        // Include comprehensive view parameters to get scoring settings
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam&view=mSettings&view=mScoringDetail&view=mPositionalRatings&view=mStats&view=mMatchup"
    
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
    
        var request = URLRequest(url: url)
    
        // Use the specific token instead of credentials manager
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SWID=\(AppConstants.SWID); espn_s2=\(token)", forHTTPHeaderField: "Cookie")
    
        do {
            let (data, response) = try await session.data(for: request)
    
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ESPNAPIError.invalidResponse
            }
    
            if httpResponse.statusCode == 401 {
                throw ESPNAPIError.authenticationFailed
            }
    
            if httpResponse.statusCode == 403 {
                throw ESPNAPIError.authenticationFailed
            }
    
            guard httpResponse.statusCode == 200 else {
                throw ESPNAPIError.invalidResponse
            }
    
            // Check if response looks like JSON
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.starts(with: "<") {
                    throw ESPNAPIError.invalidResponse
                }
            }
            
            // 🔍 DEBUG: Log top-level JSON keys to see if positionAgainstOpponent exists
            if AppConstants.debug, let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 ESPN API Response Top-Level Keys: \(jsonObject.keys.sorted())")
                if let positionData = jsonObject["positionAgainstOpponent"] {
                    print("✅ positionAgainstOpponent key EXISTS in response")
                    print("🔍 positionAgainstOpponent type: \(type(of: positionData))")
                    if let dict = positionData as? [String: Any] {
                        print("🔍 positionAgainstOpponent keys: \(dict.keys.sorted())")
                        if let innerRatings = dict["positionalRatings"] as? [String: Any] {
                            print("🔍 positionalRatings has \(innerRatings.keys.count) position entries")
                            print("🔍 Position IDs: \(Array(innerRatings.keys.sorted()))")
                            // Check one position to see team structure
                            if let firstKey = innerRatings.keys.first,
                               let positionData = innerRatings[firstKey] as? [String: Any],
                               let ratingsByOpp = positionData["ratingsByOpponent"] as? [String: Any],
                               let firstTeamKey = ratingsByOpp.keys.first,
                               let teamRating = ratingsByOpp[firstTeamKey] as? [String: Any] {
                                print("🔍 Sample team rating keys: \(teamRating.keys.sorted())")
                                print("🔍 Sample team rating values: \(teamRating)")
                            }
                        }
                    }
                } else {
                    print("❌ positionAgainstOpponent key NOT FOUND in response")
                }
            }
    
            let decoder = JSONDecoder()
            
            // Try to decode and catch any errors related to positionAgainstOpponent
            do {
                let espnLeague = try decoder.decode(ESPNLeague.self, from: data)
                if AppConstants.debug {
                    print("🔍 After decoding: positionAgainstOpponent is nil? \(espnLeague.positionAgainstOpponent == nil)")
                    
                    // If nil, try to decode just that field manually to see the error
                    if espnLeague.positionAgainstOpponent == nil {
                        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let posData = jsonObject["positionAgainstOpponent"] {
                            print("⚠️ positionAgainstOpponent exists in JSON but failed to decode")
                            print("⚠️ Attempting manual decode to see error...")
                            
                            let posDataJson = try JSONSerialization.data(withJSONObject: ["positionAgainstOpponent": posData])
                            struct Wrapper: Codable {
                                let positionAgainstOpponent: ESPNPositionalRatingsResponse?
                            }
                            do {
                                let wrapper = try decoder.decode(Wrapper.self, from: posDataJson)
                                print("✅ Manual decode successful: \(wrapper.positionAgainstOpponent != nil)")
                            } catch {
                                print("❌ Manual decode error: \(error)")
                            }
                        }
                    }
                }
                
                // Register scoring settings with ScoringSettingsManager
                ScoringSettingsManager.shared.registerESPNScoringSettings(from: espnLeague, leagueID: leagueID)
                
                // 🔥 NEW: Update OPRK data from ESPN positional ratings
                OPRKService.shared.updateOPRKData(from: espnLeague)
                
                return espnLeague.toSleeperLeague()
            } catch {
                if AppConstants.debug {
                    print("❌ ESPNLeague decode error: \(error)")
                }
                throw error
            }
    
        } catch DecodingError.keyNotFound(let key, let context) {
            throw ESPNAPIError.decodingError(DecodingError.keyNotFound(key, context))
        } catch DecodingError.typeMismatch(let type, let context) {
            throw ESPNAPIError.decodingError(DecodingError.typeMismatch(type, context))
        } catch {
            throw ESPNAPIError.networkError(error)
        }
    }
    
    /// Fetch draft information
    func fetchDraft(draftID: String) async throws -> SleeperDraft {
        // For ESPN, draft info is part of the league data
        guard let leagueID = findLeagueIDForDraft(draftID: draftID) else {
            throw ESPNAPIError.draftNotFound
        }
        
        // Updated with working view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mDraftDetail&view=mSettings&view=mTeam"
        
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ESPNAPIError.invalidResponse
        }
        
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
        
        guard let draftDetail = espnLeague.draftDetail else {
            throw ESPNAPIError.draftNotFound
        }
        
        return draftDetail.toSleeperDraft(leagueID: leagueID)
    }
    
    /// Fetch draft picks
    func fetchDraftPicks(draftID: String) async throws -> [SleeperPick] {
        // For ESPN, draft picks are fetched using the league ID
        // draftID might be the same as leagueID for completed drafts
        let leagueID = draftID // ESPN uses league ID for draft data
        
        // Use comprehensive view parameters to get draft data and picks
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mDraftDetail&view=mTeam&view=mRoster&view=mMatchup&view=mSettings"
        
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ESPNAPIError.invalidResponse
        }
        
        do {
            // First try to decode as a complete league response with draft data
            let leagueResponse = try JSONDecoder().decode(ESPNLeague.self, from: data)
            
            // Try actual draft picks first
            if let draftDetail = leagueResponse.draftDetail,
               let espnPicks = draftDetail.picks {
                
                // Build player directory from teams for conversion
                var playerDirectory: [Int: ESPNPlayer] = [:]
                if let teams = leagueResponse.teams {
                    for team in teams {
                        if let roster = team.roster?.entries {
                            for entry in roster {
                                if let player = entry.player {
                                    playerDirectory[player.id] = player
                                }
                            }
                        }
                    }
                }
                
                // Convert ESPN picks to Sleeper picks with embedded ESPN data
                let sleeperPicks = espnPicks.compactMap { espnPick -> SleeperPick? in
                    guard let player = playerDirectory[espnPick.playerId] else { 
                        return nil
                    }
                    
                    let espnPlayerInfo = ESPNPlayerInfo(
                        espnPlayerID: player.id,
                        fullName: player.fullName ?? "Unknown Player",
                        firstName: player.firstName,
                        lastName: player.lastName,
                        position: ESPNPositionMap.positionIdToSleeperPosition[player.defaultPositionId ?? 0],
                        team: ESPNTeamMap.teamIdToAbbreviation[player.proTeamId ?? 0],
                        jerseyNumber: player.jersey
                    )
                    
                    // Calculate proper draft slot instead of using teamId directly
                    let pickNumber = espnPick.overallPickNumber ?? espnPick.id
                    let teamCount = leagueResponse.totalRosters
                    let calculatedDraftSlot = calculateDraftSlot(pickNumber: pickNumber, teamCount: teamCount)
                    
                    // Get the manager name for this team
                    let managerName = leagueResponse.getManagerName(for: leagueResponse.teams?.first { $0.id == espnPick.teamId }?.owners)
                    
                    return SleeperPick(
                        draftID: draftID,
                        pickNo: pickNumber,
                        round: espnPick.roundId ?? calculateRound(pickNumber: pickNumber, teamCount: teamCount),
                        draftSlot: calculatedDraftSlot, // USE CALCULATED DRAFT SLOT, NOT teamId
                        rosterID: espnPick.teamId, // Keep rosterID as teamId for roster correlation
                        pickedBy: managerName, // USE ACTUAL MANAGER NAME instead of team ID
                        playerID: "espn_\(espnPick.playerId)", // Use prefixed ESPN ID
                        metadata: SleeperPickMetadata(
                            firstName: player.firstName,
                            lastName: player.lastName,
                            position: ESPNPositionMap.positionIdToSleeperPosition[player.defaultPositionId ?? 0],
                            team: ESPNTeamMap.teamIdToAbbreviation[player.proTeamId ?? 0],
                            number: player.jersey,
                            status: "Active",
                            sport: "nfl",
                            injuryStatus: nil,
                            newsUpdated: nil
                        ),
                        isKeeper: espnPick.keeper ?? false,
                        timestamp: nil,
                        espnPlayerInfo: espnPlayerInfo // EMBED the ESPN data
                    )
                }
                
                // Sort picks by pick number to maintain order
                let sortedPicks = sleeperPicks.sorted { $0.pickNo < $1.pickNo }
                
                return sortedPicks
            } else {
                // No actual draft picks found
                return []
            }
            
            // FALLBACK: If no actual draft picks, reconstruct from rosters (only as last resort)
            
            // Extract draft picks from the teams' rosters
            var draftPicks: [SleeperPick] = []
            
            if let teams = leagueResponse.teams {
                let teamCount = teams.count
                
                // For completed drafts, we need to reconstruct picks from rosters using PROPER snake draft logic
                // Create a map of team ID to roster position (1-based)
                let sortedTeams = teams.sorted { $0.id < $1.id }
                
                for (teamIndex, team) in sortedTeams.enumerated() {
                    if let roster = team.roster?.entries {
                        
                        // Calculate this team's pick numbers using snake draft logic
                        let draftPosition = teamIndex + 1 // 1-based position (1, 2, 3, etc.)
                        
                        for (playerIndex, entry) in roster.enumerated() {
                            guard let player = entry.player else { continue }
                            
                            // Calculate the correct pick number for this player using snake draft logic
                            let round = playerIndex + 1 // 1-based round
                            let pickNumber = calculateSnakeDraftPickNumber(
                                draftPosition: draftPosition,
                                round: round,
                                teamCount: teamCount
                            )
                            
                            let espnPlayerInfo = ESPNPlayerInfo(
                                espnPlayerID: player.id,
                                fullName: player.fullName ?? "Unknown Player",
                                firstName: player.firstName,
                                lastName: player.lastName,
                                position: ESPNPositionMap.positionIdToSleeperPosition[player.defaultPositionId ?? 0],
                                team: ESPNTeamMap.teamIdToAbbreviation[player.proTeamId ?? 0],
                                jerseyNumber: player.jersey
                            )
                            
                            // Create a draft pick entry with ESPN data embedded
                            let pick = SleeperPick(
                                draftID: draftID,
                                pickNo: pickNumber,
                                round: round,
                                draftSlot: draftPosition,
                                rosterID: team.id,
                                pickedBy: leagueResponse.getManagerName(for: team.owners), // USE MANAGER NAME
                                playerID: "espn_\(player.id)", // Use a prefixed ESPN ID as playerID
                                metadata: SleeperPickMetadata(
                                    firstName: player.firstName,
                                    lastName: player.lastName,
                                    position: ESPNPositionMap.positionIdToSleeperPosition[player.defaultPositionId ?? 0],
                                    team: ESPNTeamMap.teamIdToAbbreviation[player.proTeamId ?? 0],
                                    number: player.jersey,
                                    status: "Active",
                                    sport: "nfl",
                                    injuryStatus: nil,
                                    newsUpdated: nil
                                ),
                                isKeeper: false,
                                timestamp: nil,
                                espnPlayerInfo: espnPlayerInfo // EMBED the ESPN data
                            )
                            
                            draftPicks.append(pick)
                        }
                    }
                }
            }
            
            // Sort picks by pick number to maintain order
            draftPicks.sort { $0.pickNo < $1.pickNo }
            
            return draftPicks
            
        } catch {
            throw ESPNAPIError.decodingError(error)
        }
    }
    
    /// Fetch rosters for a league
    func fetchRosters(leagueID: String) async throws -> [SleeperRoster] {
        // ENHANCED: Fetch both team and member data with comprehensive view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mRoster&view=mSettings"
    
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
    
        var request = URLRequest(url: url)
    
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
    
        let (data, response) = try await session.data(for: request)
    
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ESPNAPIError.invalidResponse
        }
        
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
    
        guard let teams = espnLeague.teams else {
            return []
        }
        
        // Build member lookup dictionary
        var memberLookup: [String: ESPNMember] = [:]
        if let members = espnLeague.members {
            for member in members {
                memberLookup[member.id] = member
            }
        }
        
        // Convert teams to rosters with proper owner name mapping
        let rosters = teams.map { team in
            return team.toSleeperRoster(leagueID: leagueID, league: espnLeague)
        }
    
        return rosters
    }
    
    /// Fetch all players (ESPN doesn't have a global player endpoint like Sleeper)
    func fetchAllPlayers() async throws -> [String: SleeperPlayer] {
        throw ESPNAPIError.unsupportedOperation("ESPN doesn't provide a global player directory")
    }
    
    /// Fetch NFL state (ESPN doesn't provide this)
    func fetchNFLState() async throws -> SleeperNFLState {
        throw ESPNAPIError.unsupportedOperation("ESPN doesn't provide NFL state info")
    }
    
    /// Fetch users in a league (ESPN equivalent using members data)
    func fetchUsers(leagueID: String) async throws -> [SleeperLeagueUser] {
        let members = try await fetchLeagueMembers(leagueID: leagueID)
        
        // Convert ESPN members to Sleeper league users format
        let users = members.map { member in
            SleeperLeagueUser(
                userID: member.id,
                username: member.displayName ?? "User \(member.id)",
                displayName: member.displayName,
                avatar: nil, // ESPN doesn't provide avatar URLs
                metadata: SleeperUserMetadata(teamName: nil),
                isOwner: false // Would need additional logic to determine ownership
            )
        }
        
        return users
    }
    
    /// Fetch matchups for a league week (ESPN format)
    func fetchMatchups(leagueID: String, week: Int) async throws -> [SleeperMatchupResponse] {
        // ESPN doesn't have the same matchup structure as Sleeper
        // This would require fetching schedule data and converting it
        throw ESPNAPIError.unsupportedOperation("ESPN matchup fetching with projected points not yet implemented. Use Sleeper API for Chopped league features.")
    }
    
    // MARK: -> ESPN Specific Methods
    
    /// Find league ID that contains a specific draft ID
    private func findLeagueIDForDraft(draftID: String) -> String? {
        // For ESPN, draft ID is typically the same as league ID
        // or we can check our known league IDs
        return AppConstants.ESPNLeagueID.first { $0 == draftID } ?? draftID
    }
    
    /// Fetch league members for user lookup
    func fetchLeagueMembers(leagueID: String) async throws -> [ESPNMember] {
        // Updated with working view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mSettings"
    
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
    
        var request = URLRequest(url: url)
    
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
    
        let (data, response) = try await session.data(for: request)
    
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ESPNAPIError.invalidResponse
        }
    
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
        return espnLeague.members ?? []
    }
    
    /// Get current user's member ID in a specific league
    func getCurrentUserMemberID(leagueID: String) async throws -> String? {
        let members = try await fetchLeagueMembers(leagueID: leagueID)
        
        // Use dynamic SWID instead of hardcoded one
        guard let currentSWID = credentialsManager.getSWID() else {
            throw ESPNAPIError.authenticationFailed
        }
        
        let cleanSWID = currentSWID.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        
        return members.first { member in
            member.id == currentSWID || member.id == cleanSWID
        }?.id
    }
    
    /// Fetch ESPN league data for team ownership information
    func fetchESPNLeagueData(leagueID: String) async throws -> ESPNLeague {
        // Try with the best token for this league first
        let primaryToken = AppConstants.getESPNTokenForLeague(leagueID, year: AppConstants.currentSeasonYear)
        
        do {
            return try await fetchESPNLeagueDataWithToken(leagueID: leagueID, token: primaryToken)
        } catch ESPNAPIError.authenticationFailed {
            // Try with the alternate token
            let alternateToken = leagueID == "1241361400" ? 
                AppConstants.getPrimaryESPNToken(for: AppConstants.currentSeasonYear) : 
                AppConstants.getAlternateESPNToken(for: AppConstants.currentSeasonYear)
            
            return try await fetchESPNLeagueDataWithToken(leagueID: leagueID, token: alternateToken)
        }
    }
    
    /// Fetch ESPN league data with a specific token
    private func fetchESPNLeagueDataWithToken(leagueID: String, token: String) async throws -> ESPNLeague {
        // Use minimal view parameters to just get team and member data
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mSettings"
        
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SWID=\(AppConstants.SWID); espn_s2=\(token)", forHTTPHeaderField: "Cookie")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESPNAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw ESPNAPIError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ESPNAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode(ESPNLeague.self, from: data)
    }

    /// Fetch ESPN league standings data (contains team records)
    func fetchESPNStandings(leagueID: String) async throws -> ESPNLeague {
        // Try with the best token for this league first
        let primaryToken = AppConstants.getESPNTokenForLeague(leagueID, year: AppConstants.currentSeasonYear)

        do {
            return try await fetchESPNStandingsWithToken(leagueID: leagueID, token: primaryToken)
        } catch ESPNAPIError.authenticationFailed {
            // Try with the alternate token
            let alternateToken = leagueID == "1241361400" ?
                AppConstants.getPrimaryESPNToken(for: AppConstants.currentSeasonYear) :
                AppConstants.getAlternateESPNToken(for: AppConstants.currentSeasonYear)

            return try await fetchESPNStandingsWithToken(leagueID: leagueID, token: alternateToken)
        }
    }

    /// Fetch ESPN standings data with a specific token
    private func fetchESPNStandingsWithToken(leagueID: String, token: String) async throws -> ESPNLeague {
        // Try multiple view combinations to find team records
        let viewCombinations = [
            "?view=mStandings&view=mTeam",  // Both standings and team data
            "?view=mTeam&view=mStandings",  // Reverse order
            "?view=mTeam",                  // Just team data (might include records)
            "?view=mStandings"              // Original standings view
        ]

        var lastError: Error?

        for viewParams in viewCombinations {
            let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)\(viewParams)"

            guard let url = URL(string: urlString) else {
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("SWID=\(AppConstants.SWID); espn_s2=\(token)", forHTTPHeaderField: "Cookie")

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ESPNAPIError.invalidResponse
                }

                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw ESPNAPIError.authenticationFailed
                }

                guard httpResponse.statusCode == 200 else {
                    throw ESPNAPIError.invalidResponse
                }

                let league = try JSONDecoder().decode(ESPNLeague.self, from: data)

                // Check if this view combination has records
                let teamsWithRecords = league.teams?.filter { $0.record != nil } ?? []
//                print("📊 Standings fetch with \(viewParams): \(teamsWithRecords.count)/\(league.teams?.count ?? 0) teams have records")

                // If we found records, return this data
                if !teamsWithRecords.isEmpty {
//                    print("✅ Found records using view: \(viewParams)")
                    return league
                }

                // If no records but successful response, try next combination
                lastError = nil

            } catch {
                lastError = error
//                print("❌ Failed with view \(viewParams): \(error)")
                continue
            }
        }

        // If we get here, none of the view combinations worked
        if let error = lastError {
            throw error
        } else {
            throw ESPNAPIError.invalidResponse
        }
    }

    /// Get ESPN league scoring settings for score breakdown calculation
    func fetchESPNLeagueScoring(leagueID: String) async throws -> [String: Double] {
        let espnLeague = try await fetchESPNLeagueDataWithToken(leagueID: leagueID, token: AppConstants.getESPNTokenForLeague(leagueID, year: AppConstants.currentSeasonYear))
        
        guard let scoringSettings = espnLeague.scoringSettings,
              let scoringItems = scoringSettings.scoringItems else {
            logWarning("ESPN: No scoring settings found for league \(leagueID)", category: "ESPN")
            return [:]
        }
        
        var scoringMap: [String: Double] = [:]
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { continue }
            
            // Convert ESPN stat ID to readable stat name
            if let statName = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                scoringMap[statName] = points
//                print("📊 ESPN Scoring: \(statName) = \(points) points")
            } else {
//                print("⚠️ ESPN: Unknown stat ID \(statId) with \(points) points")
            }
        }
        
        if scoringMap.isEmpty {
            logWarning("ESPN: No scoring settings found for league \(leagueID)", category: "ESPN")
        } else {
            logInfo("ESPN: Loaded \(scoringMap.count) scoring rules for league \(leagueID)", category: "ESPN")
        }
        return scoringMap
    }
    
    // MARK: -> ESPN Debug Methods
    
    /// Debug method to test ESPN API connection and log response
    func debugESPNConnection(leagueID: String) async {
        // Updated with working API URL and view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam"
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.starts(with: "{") {
                    // Response looks like JSON
                } else {
                    // Response is NOT JSON - likely HTML error page
                }
            }
            
        } catch {
            // Network error occurred
        }
    }
}

// MARK: -> ESPN API Errors
enum ESPNAPIError: Error, LocalizedError {
    case invalidResponse
    case authenticationFailed
    case draftNotFound
    case unsupportedOperation(String)
    case networkError(Error)
    case decodingError(Error)
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid ESPN API response"
        case .authenticationFailed:
            return "ESPN authentication failed - check your espn_s2 and SWID cookies"
        case .draftNotFound:
            return "Draft not found"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimited:
            return "ESPN API rate limit exceeded"
        }
    }
}

// MARK: -> Draft Helper Functions

/// Calculate round number from pick number
private func calculateRound(pickNumber: Int, teamCount: Int) -> Int {
    return ((pickNumber - 1) / teamCount) + 1
}

/// Calculate draft slot from pick number  
private func calculateDraftSlot(pickNumber: Int, teamCount: Int) -> Int {
    let round = calculateRound(pickNumber: pickNumber, teamCount: teamCount)
    
    if round % 2 == 1 {
        // Odd rounds: normal order (1, 2, 3, ..., teamCount)
        return ((pickNumber - 1) % teamCount) + 1
    } else {
        // Even rounds: snake/reverse order (teamCount, ..., 3, 2, 1)  
        return teamCount - ((pickNumber - 1) % teamCount)
    }
}

/// Calculate the correct pick number for a snake draft
/// - Parameters:
///   - draftPosition: Team's draft position (1-10 for a 10-team league)
///   - round: Round number (1, 2, 3, etc.)
///   - teamCount: Total number of teams
/// - Returns: Overall pick number
private func calculateSnakeDraftPickNumber(draftPosition: Int, round: Int, teamCount: Int) -> Int {
    if round % 2 == 1 {
        // Odd rounds: normal order (1, 2, 3, ..., teamCount)
        return (round - 1) * teamCount + draftPosition
    } else {
        // Even rounds: snake/reverse order (teamCount, ..., 3, 2, 1)
        return (round - 1) * teamCount + (teamCount - draftPosition + 1)
    }
}