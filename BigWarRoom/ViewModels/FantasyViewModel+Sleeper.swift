//
//  FantasyViewModel+Sleeper.swift
//  BigWarRoom
//
//  Sleeper Fantasy League functionality for FantasyViewModel
//

import Foundation
import Combine

// MARK: -> Sleeper Fantasy Data Extension
extension FantasyViewModel {
    
    /// Fetch Sleeper league scoring settings
    func fetchSleeperScoringSettings(leagueID: String) async {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 🔥 UPDATED: Decode the full SleeperLeague to get proper scoring settings
            let sleeperLeague = try JSONDecoder().decode(SleeperLeague.self, from: data)
            
            // Store in local property for backward compatibility
            if let scoringSettings = sleeperLeague.scoringSettings {
                var convertedSettings: [String: Any] = [:]
                for (key, value) in scoringSettings {
                    convertedSettings[key] = value
                }
                sleeperLeagueSettings = convertedSettings
                
                DebugLogger.scoring("Loaded \(scoringSettings.count) rules for league \(leagueID)")
                
                // 🔥 FIX: Register the scoring settings with ScoringSettingsManager
                ScoringSettingsManager.shared.registerSleeperScoringSettings(
                    from: sleeperLeague, 
                    leagueID: leagueID
                )
                
                DebugLogger.scoring("Registered with ScoringSettingsManager for league \(leagueID)", level: .info)
            } else {
                DebugLogger.warning("No scoring settings found for league \(leagueID)", category: .scoring)
            }
            
        } catch {
            DebugLogger.error("Error fetching Sleeper league \(leagueID): \(error)", category: .api)
        }
    }
    
    /// Fetch Sleeper weekly player stats
    func fetchSleeperWeeklyStats() async {
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(selectedYear)/\(selectedWeek)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            playerStats = statsData
        } catch {
            // Silent error handling
        }
    }
    
    /// Fetch Sleeper league users and rosters
    func fetchSleeperLeagueUsersAndRosters(leagueID: String) async {
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else { 
            DebugLogger.error("Invalid URL for Sleeper rosters league \(leagueID)", category: .api)
            return 
        }
        
        DebugLogger.api("Fetching Sleeper roster data for league \(leagueID)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: rostersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                DebugLogger.api("Sleeper rosters HTTP Status \(httpResponse.statusCode)")
            }
            
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            DebugLogger.api("Decoded \(rosters.count) Sleeper rosters")
            
            // 🔥 NEW: Store rosters in main FantasyViewModel for record lookup
            sleeperRosters = rosters
            
            var newRosterMapping: [Int: String] = [:]
            
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    newRosterMapping[roster.rosterID] = ownerID
                } else {
                    DebugLogger.warning("Sleeper roster \(roster.rosterID) has no owner!", category: .fantasy)
                }
            }
            
            rosterIDToManagerID = newRosterMapping
            DebugLogger.fantasy("Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
            
            // Now fetch the user display names
            await fetchSleeperUsers(leagueID: leagueID)
            
        } catch {
            DebugLogger.error("Sleeper rosters fetch error: \(error)", category: .api)
        }
    }
    
    /// Fetch Sleeper users
    private func fetchSleeperUsers(leagueID: String) async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else { 
            DebugLogger.error("Invalid URL for Sleeper users league \(leagueID)", category: .api)
            return 
        }
        
        DebugLogger.api("Fetching Sleeper user data for league \(leagueID)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: usersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                DebugLogger.api("Sleeper users HTTP Status \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    DebugLogger.error("Bad HTTP status \(httpResponse.statusCode) for Sleeper users", category: .api)
                    return
                }
            }
            
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            DebugLogger.api("Decoded \(users.count) Sleeper users")
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for user in users {
                newUserIDs[user.userID] = user.displayName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    newUserAvatars[user.userID] = avatarURL
                }
            }
            
            // Update the dictionaries
            userIDs = newUserIDs
            userAvatars = newUserAvatars
            
            DebugLogger.fantasy("Successfully populated userIDs with \(userIDs.count) entries")
            
        } catch {
            DebugLogger.error("Sleeper users decoding error: \(error)", category: .api)
        }
    }
    
    /// Fetch real Sleeper matchups
    func fetchSleeperMatchups(leagueID: String, week: Int) async {
        DebugLogger.fantasy("Fetching Sleeper matchups for league \(leagueID) week \(week)")
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            DebugLogger.error("Invalid URL for Sleeper matchups", category: .api)
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                DebugLogger.api("Sleeper matchups HTTP Status \(httpResponse.statusCode)")
            }
            
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            DebugLogger.fantasy("Received \(sleeperMatchups.count) Sleeper matchups")
            
            if sleeperMatchups.isEmpty {
                DebugLogger.fantasy("No matchups found for week \(week) - checking if this is a chopped league", level: .info)
                
                detectedAsChoppedLeague = true
                hasActiveRosters = true
                
                await MainActor.run {
                    self.objectWillChange.send()
                }
                
                Task {
                    await validateChoppedLeagueDetection(leagueID: leagueID, week: week)
                }
                
                return
            }
            
            DebugLogger.fantasy("Processing \(sleeperMatchups.count) regular Sleeper matchups")
            await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
            
        } catch {
            DebugLogger.error("Sleeper matchups API Error: \(error.localizedDescription)", category: .api)
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }
    
    /// Process real Sleeper matchups with projected points
    func processSleeperMatchupsWithProjections(_ sleeperMatchups: [SleeperMatchupResponse], leagueID: String) async {
        DebugLogger.fantasy("Processing \(sleeperMatchups.count) REAL Sleeper matchups with projections")
        
        let groupedMatchups = Dictionary(grouping: sleeperMatchups, by: { $0.matchupID ?? 0 })
        var processedMatchups: [FantasyMatchup] = []
        
        for (_, matchups) in groupedMatchups where matchups.count == 2 {
            let team1 = matchups[0]
            let team2 = matchups[1]
            
            let awayManagerID = rosterIDToManagerID[team1.rosterID] ?? ""
            let homeManagerID = rosterIDToManagerID[team2.rosterID] ?? ""
            
            let awayManagerName = userIDs[awayManagerID] ?? "Manager \(team1.rosterID)"
            let homeManagerName = userIDs[homeManagerID] ?? "Manager \(team2.rosterID)"
            
            let awayAvatarURL = userAvatars[awayManagerID]
            let homeAvatarURL = userAvatars[homeManagerID]
            
            let awayScore = team1.points ?? 0.0
            let homeScore = team2.points ?? 0.0
            
            let awayProjected = team1.projectedPoints ?? 0.0
            let homeProjected = team2.projectedPoints ?? 0.0
            
            let awayTeam = createSleeperFantasyTeam(
                matchupResponse: team1,
                managerName: awayManagerName,
                avatarURL: awayAvatarURL
            )
            
            let homeTeam = createSleeperFantasyTeam(
                matchupResponse: team2,
                managerName: homeManagerName,
                avatarURL: homeAvatarURL
            )
            
            let fantasyMatchup = FantasyMatchup(
                id: "\(leagueID)_\(selectedWeek)_\(team1.rosterID)_\(team2.rosterID)",
                leagueID: leagueID,
                week: selectedWeek,
                year: selectedYear,
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                status: .live,
                winProbability: calculateWinProbability(homeScore: homeScore, awayScore: awayScore),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                sleeperMatchups: nil
            )
            
            processedMatchups.append(fantasyMatchup)
        }
        
        if !processedMatchups.isEmpty {
            matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
            DebugLogger.fantasy("Processed \(processedMatchups.count) REAL Sleeper matchups with accurate projections", level: .info)
        }
    }
    
    /// Create Sleeper fantasy team with real projected points from API AND ROSTER RECORD
    func createSleeperFantasyTeam(
        matchupResponse: SleeperMatchupResponse,
        managerName: String,
        avatarURL: URL?
    ) -> FantasyTeam {
        
        var fantasyPlayers: [FantasyPlayer] = []
        
        if let allPlayers = matchupResponse.players {
            for playerID in allPlayers {
                if let sleeperPlayer = playerDirectoryStore.player(for: playerID) {
                    let isStarter = matchupResponse.starters?.contains(playerID) ?? false
                    let playerScore = calculateSleeperPlayerScore(playerId: playerID)
                    let playerProjected = playerScore * 1.1
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: playerScore,
                        projectedPoints: playerProjected,
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: sleeperPlayer.team),
                        isStarter: isStarter,
                        lineupSlot: sleeperPlayer.position
                    )
                    
                    fantasyPlayers.append(fantasyPlayer)
                }
            }
        }
        
        let avatarString = avatarURL?.absoluteString
        
        var finalManagerName = managerName
        
        if let sharedDraftRoom = sharedDraftRoomViewModel {
            let allPicks = sharedDraftRoom.allDraftPicks
            if let correspondingPick = allPicks.first(where: { $0.rosterInfo?.rosterID == matchupResponse.rosterID }) {
                let draftSlotBasedName = sharedDraftRoom.teamDisplayName(for: correspondingPick.draftSlot)
                
                if !draftSlotBasedName.isEmpty,
                   !draftSlotBasedName.lowercased().hasPrefix("team "),
                   !draftSlotBasedName.lowercased().hasPrefix("manager "),
                   draftSlotBasedName.count > 4 {
                    finalManagerName = draftSlotBasedName
                }
            }
        }
        
        // 🔥 NEW: Get roster record data
        let rosterRecord: TeamRecord? = {
            if let roster = sleeperRosters.first(where: { $0.rosterID == matchupResponse.rosterID }) {
                // 🔥 FIX: Use roster.settings for wins/losses/ties, not root level properties
                let wins = roster.settings?.wins ?? roster.wins ?? 0
                let losses = roster.settings?.losses ?? roster.losses ?? 0
                let ties = roster.settings?.ties ?? roster.ties ?? 0
                
                DebugLogger.fantasy("Sleeper record: Roster \(roster.rosterID) -> \(wins)-\(losses)-\(ties)")
                
                return TeamRecord(
                    wins: wins,
                    losses: losses,
                    ties: ties
                )
            }
            
            DebugLogger.warning("No roster found for rosterID \(matchupResponse.rosterID)", category: .fantasy)
            return nil
        }()
        
        return FantasyTeam(
            id: String(matchupResponse.rosterID),
            name: finalManagerName,
            ownerName: finalManagerName,
            record: rosterRecord,
            avatar: avatarString,
            currentScore: matchupResponse.points,
            projectedScore: matchupResponse.projectedPoints,
            roster: fantasyPlayers,
            rosterID: matchupResponse.rosterID
        )
    }
    
    /// Calculate Sleeper player score using league settings
    func calculateSleeperPlayerScore(playerId: String) -> Double {
        guard let playerStats = playerStats[playerId],
              let scoringSettings = sleeperLeagueSettings else {
            return 0.0
        }
        
        var totalScore = 0.0
        for (statKey, statValue) in playerStats {
            if let scoring = scoringSettings[statKey] as? Double {
                let points = statValue * scoring
                totalScore += points
            }
        }
        return totalScore
    }
    
    /// Validate Chopped league detection in background
    func validateChoppedLeagueDetection(leagueID: String, week: Int) async {
        DebugLogger.fantasy("Validating chopped league detection - checking rosters for league \(leagueID)")
        
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else {
            DebugLogger.error("Invalid rosters URL for chopped validation", category: .api)
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            DebugLogger.fantasy("Found \(rosters.count) rosters for chopped validation")
            
            if !rosters.isEmpty {
                DebugLogger.fantasy("\(rosters.count) active rosters confirmed - this is definitely a Chopped league!", level: .info)
                
                await MainActor.run {
                    hasActiveRosters = true
                }
                
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: leagueID, 
                    week: week
                )
                isLoadingChoppedData = false
            } else {
                DebugLogger.warning("Chopped detection failed: No rosters found - reverting detection", category: .fantasy)
                await MainActor.run {
                    detectedAsChoppedLeague = false
                    hasActiveRosters = false
                    errorMessage = "No matchups or active rosters found for week \(week)"
                }
            }
            
        } catch {
            DebugLogger.warning("Chopped validation error: \(error) - keeping detection as is", category: .fantasy)
        }
    }
}