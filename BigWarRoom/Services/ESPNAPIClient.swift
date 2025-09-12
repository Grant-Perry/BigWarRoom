//
//  ESPNAPIClient.swift
//  BigWarRoom
//
//  ESPN Fantasy Football API networking client
//
// MARK: -> ESPN API Client

import Foundation

final class ESPNAPIClient: DraftAPIClient {
    static let shared = ESPNAPIClient()
    
    // Updated to use working API subdomain from SleepThis
    private let baseURL = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons"
    private let session = URLSession.shared
    private let credentialsManager = ESPNCredentialsManager.shared
    
    private init() {}
    
    // MARK: -> Authentication Headers
    private func authHeaders() -> [String: String] {
        // Use dynamic credentials instead of hardcoded ones
        guard let headers = credentialsManager.generateAuthHeaders() else {
            // x// x Print("❌ No ESPN credentials configured")
            return [:]
        }
        
        // x// x Print("🔐 ESPN Auth Cookie: \(String(headers["Cookie"]?.prefix(50) ?? ""))...")
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
                // x// x Print("❌ Failed to fetch ESPN league \(leagueID): \(error)")
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
            // x Print("🔄 ESPN: Primary token failed for league \(leagueID), trying alternate token...")
            
            // Try with the alternate token
            let alternateToken = leagueID == "1241361400" ? 
                AppConstants.getPrimaryESPNToken(for: AppConstants.currentSeasonYear) : 
                AppConstants.getAlternateESPNToken(for: AppConstants.currentSeasonYear)
            
            return try await fetchLeagueWithToken(leagueID: leagueID, token: alternateToken)
        }
    }
    
    /// Fetch league with a specific token
    private func fetchLeagueWithToken(leagueID: String, token: String) async throws -> SleeperLeague {
        // Updated view parameters to include members data for manager name mapping
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam&view=mSettings"
        // x Print("🌐 ESPN API Request: \(urlString)")
        // x Print("🔑 Using token: \(String(token.prefix(50)))...")
    
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
    
            // x Print("📡 ESPN Response Status: \(httpResponse.statusCode)")
    
            if httpResponse.statusCode == 401 {
                // x Print("❌ ESPN Authentication failed - check espn_s2 and SWID cookies")
                throw ESPNAPIError.authenticationFailed
            }
    
            if httpResponse.statusCode == 403 {
                // x Print("❌ ESPN Access forbidden - league may be private or cookies expired")
                throw ESPNAPIError.authenticationFailed
            }
    
            guard httpResponse.statusCode == 200 else {
                // x Print("❌ ESPN API returned status: \(httpResponse.statusCode)")
    
                // Try to log response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    // x Print("📄 ESPN Response: \(String(responseString.prefix(500)))...")
                }
    
                throw ESPNAPIError.invalidResponse
            }
    
            // Log successful response
            // x Print("✅ ESPN API Success - received \(data.count) bytes")
    
            // Check if response looks like JSON
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.starts(with: "<") {
                    // x Print("❌ ESPN returned HTML instead of JSON")
                    // x Print("📄 HTML Response: \(String(responseString.prefix(300)))...")
                    throw ESPNAPIError.invalidResponse
                }
                
                // Log first bit of JSON for debugging
                // x Print("📄 JSON Response: \(String(responseString.prefix(500)))...")
            }
    
            let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
            // x Print("✅ Fetched ESPN league: \(espnLeague.displayName)")
            // x Print("🔍 Debug - Root name: \(espnLeague.name ?? "nil"), Settings name: \(espnLeague.settings?.name ?? "nil")")
            // x Print("🗓️ Debug - League season from API: \(espnLeague.seasonId ?? -1)")
            
            // NEW: Log members data for debugging
            if let members = espnLeague.members {
                // x Print("👥 Found \(members.count) league members:")
                for member in members {
                    let displayName = member.displayName ?? "No Display Name"
                    let firstName = member.firstName ?? ""
                    let lastName = member.lastName ?? ""
                    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                    // x Print("   ID: \(member.id) - Display: \(displayName) - Full: \(fullName)")
                }
            } else {
                // x Print("⚠️ No members data found in league response")
            }
            
            // NEW: Log team owners for debugging
            if let teams = espnLeague.teams {
                // x Print("🏈 Team owner mapping:")
                for team in teams {
                    let owners = team.owners ?? []
                    let managerName = espnLeague.getManagerName(for: team.owners)
                    // x Print("   Team \(team.id) (\(team.displayName)): Owners=\(owners) -> Manager: \(managerName)")
                }
            }
            
            // x Print("🔢 ESPN League Team Count Debug:")
            // x Print("   Raw size field: \(espnLeague.size ?? -1)")
            // x Print("   Teams array count: \(espnLeague.teams?.count ?? -1)")
            // x Print("   Calculated totalRosters: \(espnLeague.totalRosters)")

            return espnLeague.toSleeperLeague()
    
        } catch DecodingError.keyNotFound(let key, let context) {
            // x Print("❌ ESPN JSON Decode Error - Missing key: \(key)")
            // x Print("📄 Context: \(context)")
            throw ESPNAPIError.decodingError(DecodingError.keyNotFound(key, context))
        } catch DecodingError.typeMismatch(let type, let context) {
            // x Print("❌ ESPN JSON Decode Error - Type mismatch: \(type)")
            // x Print("📄 Context: \(context)")
            throw ESPNAPIError.decodingError(DecodingError.typeMismatch(type, context))
        } catch {
            // x Print("❌ ESPN Network Error: \(error)")
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
        // x// x Print("🌐 ESPN Draft API Request: \(urlString)")
        
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
        
        // DEBUG: Log draft completion information
        // x// x Print("🗓️ ESPN Draft Detail Info:")
        // x// x Print("   Draft ID: \(draftDetail.id ?? -1)")
        // x// x Print("   In Progress: \(draftDetail.inProgress ?? false)")
        // x// x Print("   Complete Date (raw): \(draftDetail.completeDate ?? 0)")
        if let completionDate = draftDetail.completionDate {
            // x// x Print("   Complete Date (formatted): \(completionDate)")
        }
        if let completionString = draftDetail.completionDateString {
            // x// x Print("   Complete Date (string): \(completionString)")
        }
        // x// x Print("   Order Type: \(draftDetail.orderType ?? "unknown")")
        
        return draftDetail.toSleeperDraft(leagueID: leagueID)
    }
    
    /// Fetch draft picks
    func fetchDraftPicks(draftID: String) async throws -> [SleeperPick] {
        // For ESPN, draft picks are fetched using the league ID
        // draftID might be the same as leagueID for completed drafts
        let leagueID = draftID // ESPN uses league ID for draft data
        
        // Use comprehensive view parameters to get draft data and picks
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mDraftDetail&view=mTeam&view=mRoster&view=mMatchup&view=mSettings"
        // x// x Print("🌐 ESPN Draft Picks API Request: \(urlString)")
        
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
            // x// x Print("❌ ESPN Draft Picks API failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ESPNAPIError.invalidResponse
        }
        
        // x// x Print("✅ ESPN Draft Picks API Success - received \(data.count) bytes")
        
        do {
            // First try to decode as a complete league response with draft data
            let leagueResponse = try JSONDecoder().decode(ESPNLeague.self, from: data)
            
            // DEBUG: Log draft information if available
            if let draftDetail = leagueResponse.draftDetail {
                // x// x Print("🗓️ ESPN Draft Information:")
                // x// x Print("   Draft Complete: \(draftDetail.completeDate != nil)")
                if let completionString = draftDetail.completionDateString {
                    // x// x Print("   Completion Date: \(completionString)")
                }
                // x// x Print("   In Progress: \(draftDetail.inProgress ?? false)")
                // x// x Print("   Draft Type: \(draftDetail.orderType ?? "unknown")")
                
                // PRIORITY: Use actual draft picks if available
                if let espnPicks = draftDetail.picks {
                    // x// x Print("🎯 Found \(espnPicks.count) actual ESPN draft picks! Using real draft data.")
                    
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
                            // x// x Print("⚠️ No player data for pick \(espnPick.overallPickNumber ?? espnPick.id): ESPN ID \(espnPick.playerId)")
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
                        
                        // FIXED: Calculate proper draft slot instead of using teamId directly
                        let pickNumber = espnPick.overallPickNumber ?? espnPick.id
                        let teamCount = leagueResponse.totalRosters
                        let calculatedDraftSlot = calculateDraftSlot(pickNumber: pickNumber, teamCount: teamCount)
                        
                        // NEW: Get the manager name for this team
                        let managerName = leagueResponse.getManagerName(for: leagueResponse.teams?.first { $0.id == espnPick.teamId }?.owners)
                        
                        // x// x Print("🔧 ESPN Pick \(pickNumber): TeamId=\(espnPick.teamId), CalculatedSlot=\(calculatedDraftSlot), Manager=\(managerName)")
                        
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
                    
                    // x// x Print("✅ Using \(sortedPicks.count) ACTUAL ESPN draft picks with CALCULATED draft slots")
                    return sortedPicks
                } else {
                    // NO FALLBACK - If there are no actual draft picks, return empty array
                    // x// x Print("❌ No actual ESPN draft picks found and roster reconstruction is disabled")
                    // x// x Print("   This prevents incorrect pick order calculations from team roster data")
                    return []
                }
            }
            
            // FALLBACK: If no actual draft picks, reconstruct from rosters (only as last resort)
            // x// x Print("⚠️ No actual ESPN draft picks found, falling back to roster reconstruction...")
            
            // Extract draft picks from the teams' rosters
            var draftPicks: [SleeperPick] = []
            
            if let teams = leagueResponse.teams {
                let teamCount = teams.count
                // x// x Print("🔍 Processing \(teamCount) teams for draft reconstruction")
                
                // For completed drafts, we need to reconstruct picks from rosters using PROPER snake draft logic
                // Create a map of team ID to roster position (1-based)
                let sortedTeams = teams.sorted { $0.id < $1.id }
                
                for (teamIndex, team) in sortedTeams.enumerated() {
                    if let roster = team.roster?.entries {
                        // x// x Print("🔍 Team \(team.id) has \(roster.count) roster entries")
                        
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
                            
                            // x// x Print("✅ Created pick \(pickNumber): \(player.fullName ?? "Unknown") (ESPN ID: \(player.id)) - Round \(round), Pos \(draftPosition), Manager: \(leagueResponse.getManagerName(for: team.owners))")
                        }
                    }
                }
            }
            
            // Sort picks by pick number to maintain order
            draftPicks.sort { $0.pickNo < $1.pickNo }
            
            // x// x Print("✅ Reconstructed \(draftPicks.count) draft picks from ESPN rosters with embedded ESPN data")
            return draftPicks
            
        } catch {
            // x// x Print("❌ Failed to decode ESPN draft picks response: \(error)")
            throw ESPNAPIError.decodingError(error)
        }
    }
    
    /// Fetch rosters for a league
    func fetchRosters(leagueID: String) async throws -> [SleeperRoster] {
        // ENHANCED: Fetch both team and member data with comprehensive view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mRoster&view=mSettings"
        // x// x Print("🌐 ESPN Rosters API Request: \(urlString)")
    
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
        
        // COMPLETE JSON DUMP for debugging - this will be HUGE
        if let responseString = String(data: data, encoding: .utf8) {
            // x// x Print("🔍 COMPLETE ESPN JSON RESPONSE:")
            // x// x Print("=====================================")
            // x// x Print("=====================================")
        }
    
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
    
        guard let teams = espnLeague.teams else {
            return []
        }
        
        // CRITICAL: Build member lookup dictionary and log everything
        // x// x Print("🔍 ESPN League Members Mapping:")
        var memberLookup: [String: ESPNMember] = [:]
        if let members = espnLeague.members {
            // x// x Print("   Found \(members.count) league members:")
            for member in members {
                memberLookup[member.id] = member
                let displayName = member.displayName ?? "No Display Name"
                let firstName = member.firstName ?? ""
                let lastName = member.lastName ?? ""
                let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                // x// x Print("   👤 Member \(member.id): Display=\"\(displayName)\", First=\"\(firstName)\", Last=\"\(lastName)\", Full=\"\(fullName)\"")
            }
        } else {
            // x// x Print("   ⚠️ No members array found in ESPN response - this is the problem!")
        }
        
        // ENHANCED: Convert teams to rosters with proper owner name mapping
        // x// x Print("🔍 ESPN Team to Roster Mapping:")
        let rosters = teams.map { team in
            // x// x Print("   Team \(team.id): '\(team.displayName)'")
            // x// x Print("     Owners: \(team.owners ?? [])")
            
            let managerName = espnLeague.getManagerName(for: team.owners)
            // x// x Print("     ✅ Final Manager Name: '\(managerName)'")
            
            return team.toSleeperRoster(leagueID: leagueID, league: espnLeague)
        }
    
        // x// x Print("✅ Fetched \(rosters.count) ESPN rosters for league \(leagueID) with enhanced owner mapping")
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
        // x// x Print("🌐 ESPN Members API Request: \(urlString)")
    
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
            // x Print("🔄 ESPN: Primary token failed for league ownership \(leagueID), trying alternate token...")
            
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
    
    // MARK: -> ESPN Debug Methods
    
    /// Debug method to test ESPN API connection and log response
    func debugESPNConnection(leagueID: String) async {
        // Updated with working API URL and view parameters
        let urlString = "\(baseURL)/\(AppConstants.currentSeasonYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam"
        // x// x Print("🔧 DEBUG ESPN API Request: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            // x// x Print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Log all headers
        // x// x Print("🔐 Request Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key == "Cookie" {
                    // x// x Print("  \(key): \(String(value.prefix(100)))...")
                } else {
                    // x// x Print("  \(key): \(value)")
                }
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                // x// x Print("📡 Response Status: \(httpResponse.statusCode)")
                // x// x Print("📡 Response Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    // x// x Print("  \(String(describing: key)): \(String(describing: value))")
                }
            }
            
            // Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                // x// x Print("📄 Raw Response (\(data.count) bytes):")
                
                if responseString.starts(with: "{") {
                    // x// x Print("✅ Response looks like JSON!")
                } else {
                    // x// x Print("❌ Response is NOT JSON - likely HTML error page")
                }
            }
            
        } catch {
            // x// x Print("❌ Network Error: \(error)")
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