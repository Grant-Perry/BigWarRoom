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
    
    private init() {}
    
    // MARK: -> Authentication Headers
    private func authHeaders(use2025Token: Bool = false) -> [String: String] {
        // Choose the appropriate ESPN_S2 token based on the flag
        let espnS2Token = use2025Token ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        let cookieValue = "SWID=\(AppConstants.SWID); espn_s2=\(espnS2Token)"
        
        let tokenType = use2025Token ? "2025 token" : "default token"
        print("🔐 ESPN Auth Cookie (\(tokenType)): \(String(cookieValue.prefix(50)))...")
        
        return [
            "Cookie": cookieValue,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "BigWarRoom/3.12 (iOS)"
        ]
    }
    
    // MARK: -> Authentication Retry Helper
    private func makeAuthenticatedRequest(url: URL, use2025Token: Bool = false) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders(use2025Token: use2025Token) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESPNAPIError.invalidResponse
        }
        
        print("📡 ESPN Response Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            let tokenType = use2025Token ? "2025 token" : "default token"
            print("❌ ESPN Authentication failed with \(tokenType) - status: \(httpResponse.statusCode)")
            throw ESPNAPIError.authenticationFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ ESPN API returned status: \(httpResponse.statusCode)")
            
            // Try to log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 ESPN Response: \(String(responseString.prefix(500)))...")
            }
            
            throw ESPNAPIError.invalidResponse
        }
        
        return (data, response)
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
    func fetchLeagues(userID: String, season: String = "2024") async throws -> [SleeperLeague] {
        // ESPN requires knowing specific league IDs, so we'll fetch the ones from AppConstants
        var leagues: [SleeperLeague] = []
        
        for leagueID in AppConstants.ESPNLeagueID {
            do {
                let league = try await fetchLeague(leagueID: leagueID)
                leagues.append(league)
            } catch {
                print("❌ Failed to fetch ESPN league \(leagueID): \(error)")
                // Continue with other leagues even if one fails
            }
        }
        
        return leagues
    }
    
    /// Fetch a specific league by ID
    func fetchLeague(leagueID: String) async throws -> SleeperLeague {
        // Updated view parameters to include members data for manager name mapping
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam&view=mSettings"
        print("🌐 ESPN API Request: \(urlString)")
        print("🗓️ Using ESPN Year: \(AppConstants.ESPNLeagueYear)")
    
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        // Try with default token first, then with 2025 token if it fails
        do {
            let (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: false)
            return try await processLeagueResponse(data: data, leagueID: leagueID)
        } catch ESPNAPIError.authenticationFailed {
            print("🔄 Retrying ESPN league \(leagueID) with 2025 token...")
            
            do {
                let (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: true)
                print("✅ ESPN league \(leagueID) succeeded with 2025 token!")
                return try await processLeagueResponse(data: data, leagueID: leagueID)
            } catch {
                print("❌ ESPN league \(leagueID) failed even with 2025 token: \(error)")
                throw error
            }
        }
    }
    
    // MARK: -> League Response Processing Helper
    private func processLeagueResponse(data: Data, leagueID: String) async throws -> SleeperLeague {
        // Log successful response
        print("✅ ESPN API Success - received \(data.count) bytes")

        // Check if response looks like JSON
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.starts(with: "<") {
                print("❌ ESPN returned HTML instead of JSON")
                print("📄 HTML Response: \(String(responseString.prefix(300)))...")
                throw ESPNAPIError.invalidResponse
            }
            
            // Log first bit of JSON for debugging
            print("📄 JSON Response: \(String(responseString.prefix(500)))...")
        }

        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
        print("✅ Fetched ESPN league: \(espnLeague.displayName)")
        print("🔍 Debug - Root name: \(espnLeague.name ?? "nil"), Settings name: \(espnLeague.settings?.name ?? "nil")")
        print("🗓️ Debug - League season from API: \(espnLeague.seasonId ?? -1)")
        
        // NEW: Log members data for debugging
        if let members = espnLeague.members {
            print("👥 Found \(members.count) league members:")
            for member in members {
                let displayName = member.displayName ?? "No Display Name"
                let firstName = member.firstName ?? ""
                let lastName = member.lastName ?? ""
                let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                print("   ID: \(member.id) - Display: \(displayName) - Full: \(fullName)")
            }
        } else {
            print("⚠️ No members data found in league response")
        }
        
        // NEW: Log team owners for debugging
        if let teams = espnLeague.teams {
            print("🏈 Team owner mapping:")
            for team in teams {
                let owners = team.owners ?? []
                let managerName = espnLeague.getManagerName(for: team.owners)
                print("   Team \(team.id) (\(team.displayName)): Owners=\(owners) -> Manager: \(managerName)")
            }
        }
        
        print("🔢 ESPN League Team Count Debug:")
        print("   Raw size field: \(espnLeague.size ?? -1)")
        print("   Teams array count: \(espnLeague.teams?.count ?? -1)")
        print("   Calculated totalRosters: \(espnLeague.totalRosters)")

        return espnLeague.toSleeperLeague()
    }
    
    /// Fetch draft information
    func fetchDraft(draftID: String) async throws -> SleeperDraft {
        // For ESPN, draft info is part of the league data
        guard let leagueID = findLeagueIDForDraft(draftID: draftID) else {
            throw ESPNAPIError.draftNotFound
        }
        
        // Updated with working view parameters
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mDraftDetail&view=mSettings&view=mTeam"
        print("🌐 ESPN Draft API Request: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        // Try with default token first, then with 2025 token if it fails
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: false)
        } catch ESPNAPIError.authenticationFailed {
            print("🔄 Retrying ESPN draft \(draftID) with 2025 token...")
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: true)
            print("✅ ESPN draft \(draftID) succeeded with 2025 token!")
        }
        
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
        
        guard let draftDetail = espnLeague.draftDetail else {
            throw ESPNAPIError.draftNotFound
        }
        
        // DEBUG: Log draft completion information
        print("🗓️ ESPN Draft Detail Info:")
        print("   Draft ID: \(draftDetail.id ?? -1)")
        print("   In Progress: \(draftDetail.inProgress ?? false)")
        print("   Complete Date (raw): \(draftDetail.completeDate ?? 0)")
        if let completionDate = draftDetail.completionDate {
            print("   Complete Date (formatted): \(completionDate)")
        }
        if let completionString = draftDetail.completionDateString {
            print("   Complete Date (string): \(completionString)")
        }
        print("   Order Type: \(draftDetail.orderType ?? "unknown")")
        
        return draftDetail.toSleeperDraft(leagueID: leagueID)
    }
    
    /// Fetch draft picks
    func fetchDraftPicks(draftID: String) async throws -> [SleeperPick] {
        // For ESPN, draft picks are fetched using the league ID
        // draftID might be the same as leagueID for completed drafts
        let leagueID = draftID // ESPN uses league ID for draft data
        
        // Use comprehensive view parameters to get draft data and picks
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mDraftDetail&view=mTeam&view=mRoster&view=mMatchup&view=mSettings"
        print("🌐 ESPN Draft Picks API Request: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        // Try with default token first, then with 2025 token if it fails
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: false)
        } catch ESPNAPIError.authenticationFailed {
            print("🔄 Retrying ESPN draft picks \(draftID) with 2025 token...")
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: true)
            print("✅ ESPN draft picks \(draftID) succeeded with 2025 token!")
        }
        
        print("✅ ESPN Draft Picks API Success - received \(data.count) bytes")
        
        do {
            // First try to decode as a complete league response with draft data
            let leagueResponse = try JSONDecoder().decode(ESPNLeague.self, from: data)
            
            // DEBUG: Log draft information if available
            if let draftDetail = leagueResponse.draftDetail {
                print("🗓️ ESPN Draft Information:")
                print("   Draft Complete: \(draftDetail.completeDate != nil)")
                if let completionString = draftDetail.completionDateString {
                    print("   Completion Date: \(completionString)")
                }
                print("   In Progress: \(draftDetail.inProgress ?? false)")
                print("   Draft Type: \(draftDetail.orderType ?? "unknown")")
                
                // PRIORITY: Use actual draft picks if available
                if let espnPicks = draftDetail.picks {
                    print("🎯 Found \(espnPicks.count) actual ESPN draft picks! Using real draft data.")
                    
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
                            print("⚠️ No player data for pick \(espnPick.overallPickNumber ?? espnPick.id): ESPN ID \(espnPick.playerId)")
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
                        
                        print("🔧 ESPN Pick \(pickNumber): TeamId=\(espnPick.teamId), CalculatedSlot=\(calculatedDraftSlot), Manager=\(managerName)")
                        
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
                    
                    print("✅ Using \(sortedPicks.count) ACTUAL ESPN draft picks with CALCULATED draft slots")
                    return sortedPicks
                }
            }
            
            // FALLBACK: If no actual draft picks, reconstruct from rosters (only as last resort)
            print("⚠️ No actual ESPN draft picks found, falling back to roster reconstruction...")
            
            // Extract draft picks from the teams' rosters
            var draftPicks: [SleeperPick] = []
            
            if let teams = leagueResponse.teams {
                let teamCount = teams.count
                print("🔍 Processing \(teamCount) teams for draft reconstruction")
                
                // For completed drafts, we need to reconstruct picks from rosters using PROPER snake draft logic
                // Create a map of team ID to roster position (1-based)
                let sortedTeams = teams.sorted { $0.id < $1.id }
                
                for (teamIndex, team) in sortedTeams.enumerated() {
                    if let roster = team.roster?.entries {
                        print("🔍 Team \(team.id) has \(roster.count) roster entries")
                        
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
                            
                            print("✅ Created pick \(pickNumber): \(player.fullName ?? "Unknown") (ESPN ID: \(player.id)) - Round \(round), Pos \(draftPosition), Manager: \(leagueResponse.getManagerName(for: team.owners))")
                        }
                    }
                }
            }
            
            // Sort picks by pick number to maintain order
            draftPicks.sort { $0.pickNo < $1.pickNo }
            
            print("✅ Reconstructed \(draftPicks.count) draft picks from ESPN rosters with embedded ESPN data")
            return draftPicks
            
        } catch {
            print("❌ Failed to decode ESPN draft picks response: \(error)")
            throw ESPNAPIError.decodingError(error)
        }
    }
    
    /// Fetch rosters for a league
    func fetchRosters(leagueID: String) async throws -> [SleeperRoster] {
        // ENHANCED: Fetch both team and member data with comprehensive view parameters
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mRoster&view=mSettings"
        print("🌐 ESPN Rosters API Request: \(urlString)")
    
        guard let url = URL(string: urlString) else {
            throw ESPNAPIError.invalidResponse
        }
        
        // Try with default token first, then with 2025 token if it fails
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: false)
        } catch ESPNAPIError.authenticationFailed {
            print("🔄 Retrying ESPN rosters \(leagueID) with 2025 token...")
            (data, _) = try await makeAuthenticatedRequest(url: url, use2025Token: true)
            print("✅ ESPN rosters \(leagueID) succeeded with 2025 token!")
        }
        
        // COMPLETE JSON DUMP for debugging - this will be HUGE
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔍 COMPLETE ESPN JSON RESPONSE:")
            print("=====================================")
            print(responseString)
            print("=====================================")
        }
    
        let espnLeague = try JSONDecoder().decode(ESPNLeague.self, from: data)
    
        guard let teams = espnLeague.teams else {
            return []
        }
        
        // CRITICAL: Build member lookup dictionary and log everything
        print("🔍 ESPN League Members Mapping:")
        var memberLookup: [String: ESPNMember] = [:]
        if let members = espnLeague.members {
            print("   Found \(members.count) league members:")
            for member in members {
                memberLookup[member.id] = member
                let displayName = member.displayName ?? "No Display Name"
                let firstName = member.firstName ?? ""
                let lastName = member.lastName ?? ""
                let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                print("   👤 Member \(member.id): Display=\"\(displayName)\", First=\"\(firstName)\", Last=\"\(lastName)\", Full=\"\(fullName)\"")
            }
        } else {
            print("   ⚠️ No members array found in ESPN response - this is the problem!")
        }
        
        // ENHANCED: Convert teams to rosters with proper owner name mapping
        print("🔍 ESPN Team to Roster Mapping:")
        let rosters = teams.map { team in
            print("   Team \(team.id): '\(team.displayName)'")
            print("     Owners: \(team.owners ?? [])")
            
            let managerName = espnLeague.getManagerName(for: team.owners)
            print("     ✅ Final Manager Name: '\(managerName)'")
            
            return team.toSleeperRoster(leagueID: leagueID, league: espnLeague)
        }
    
        print("✅ Fetched \(rosters.count) ESPN rosters for league \(leagueID) with enhanced owner mapping")
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
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mTeam&view=mSettings"
        print("🌐 ESPN Members API Request: \(urlString)")
    
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
        
        // In ESPN, you can identify yourself by the SWID
        // The SWID in the cookie should match a member's ID
        let cleanSWID = AppConstants.SWID.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
        
        return members.first { member in
            member.id == AppConstants.SWID || member.id == cleanSWID
        }?.id
    }
    
    // MARK: -> ESPN Debug Methods
    
    /// Debug method to test ESPN API connection and log response
    func debugESPNConnection(leagueID: String) async {
        // Updated with working API URL and view parameters
        let urlString = "\(baseURL)/\(AppConstants.ESPNLeagueYear)/segments/0/leagues/\(leagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&view=mTeam"
        print("🔧 DEBUG ESPN API Request: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        
        // Add authentication headers
        for (key, value) in authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Log all headers
        print("🔐 Request Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key == "Cookie" {
                    print("  \(key): \(String(value.prefix(100)))...")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response Status: \(httpResponse.statusCode)")
                print("📡 Response Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("  \(String(describing: key)): \(String(describing: value))")
                }
            }
            
            // Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw Response (\(data.count) bytes):")
                print(String(responseString.prefix(1000)))
                
                if responseString.starts(with: "{") {
                    print("✅ Response looks like JSON!")
                } else {
                    print("❌ Response is NOT JSON - likely HTML error page")
                }
            }
            
        } catch {
            print("❌ Network Error: \(error)")
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