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
                
                print("🎯 SLEEPER SCORING: Loaded \(scoringSettings.count) rules for league \(leagueID)")
                
                // 🔥 FIX: Register the scoring settings with ScoringSettingsManager
                ScoringSettingsManager.shared.registerSleeperScoringSettings(
                    from: sleeperLeague, 
                    leagueID: leagueID
                )
                
                print("✅ SLEEPER SCORING: Registered with ScoringSettingsManager for league \(leagueID)")
            } else {
                print("⚠️ SLEEPER SCORING: No scoring settings found for league \(leagueID)")
            }
            
        } catch {
            print("❌ SLEEPER SCORING: Error fetching league \(leagueID): \(error)")
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
            // x Print("❌ SLEEPER ROSTERS: Invalid URL for league \(leagueID)")
            return 
        }
        
        // x Print("🌐 SLEEPER ROSTERS: Fetching roster data for league \(leagueID)")
        // x Print("🔗 SLEEPER ROSTERS: URL = \(rostersURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: rostersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                // x Print("📡 SLEEPER ROSTERS: HTTP Status \(httpResponse.statusCode)")
            }
            
            // x Print("📊 SLEEPER ROSTERS: Received \(data.count) bytes")
            
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            // x Print("📋 SLEEPER ROSTERS: Decoded \(rosters.count) rosters")
            
            // 🔥 NEW: Store rosters in main FantasyViewModel for record lookup
            sleeperRosters = rosters
            
            var newRosterMapping: [Int: String] = [:]
            
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    newRosterMapping[roster.rosterID] = ownerID
                    // x Print("🔗 SLEEPER ROSTER: Roster \(roster.rosterID) -> Owner \(ownerID)")
                } else {
                    // x Print("⚠️ SLEEPER ROSTER: Roster \(roster.rosterID) has no owner!")
                }
            }
            
            rosterIDToManagerID = newRosterMapping
            // x Print("✅ SLEEPER ROSTERS: Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
            
            // Now fetch the user display names
            await fetchSleeperUsers(leagueID: leagueID)
            
        } catch {
            // x Print("❌ SLEEPER ROSTERS: Error - \(error)")
        }
    }
    
    /// Fetch Sleeper users
    private func fetchSleeperUsers(leagueID: String) async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else { 
            // x Print("❌ SLEEPER USERS: Invalid URL for league \(leagueID)")
            return 
        }
        
        // x Print("🌐 SLEEPER USERS: Fetching user data for league \(leagueID)")
        // x Print("🔗 SLEEPER USERS: URL = \(usersURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: usersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                // x Print("📡 SLEEPER USERS: HTTP Status \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    // x Print("❌ SLEEPER USERS: Bad HTTP status \(httpResponse.statusCode)")
                    return
                }
            }
            
            // x Print("📊 SLEEPER USERS: Received \(data.count) bytes")
            
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            // x Print("👥 SLEEPER USERS: Decoded \(users.count) users")
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for (index, user) in users.enumerated() {
                // x Print("👤 SLEEPER USER \(index): ID=\(user.userID), Display='\(user.displayName)', Username='\(user.username ?? "nil")'")
                
                newUserIDs[user.userID] = user.displayName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    newUserAvatars[user.userID] = avatarURL
                    // x Print("🎭 SLEEPER AVATAR: User \(user.userID) has avatar \(avatar)")
                }
            }
            
            // Update the dictionaries
            userIDs = newUserIDs
            userAvatars = newUserAvatars
            
            // x Print("✅ SLEEPER USERS: Successfully populated userIDs with \(userIDs.count) entries")
            // x Print("📋 SLEEPER USERS: Final userIDs = \(userIDs)")
            
        } catch {
            // x Print("❌ SLEEPER USERS: Decoding error - \(error)")
            if let decodingError = error as? DecodingError {
                // x Print("🔍 SLEEPER USERS: Decoding details - \(decodingError)")
            }
        }
    }
    
    /// Fetch real Sleeper matchups
    func fetchSleeperMatchups(leagueID: String, week: Int) async {
        // x Print("🔍 SLEEPER MATCHUPS: Fetching for league \(leagueID) week \(week)")
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            // x Print("❌ SLEEPER MATCHUPS: Invalid URL")
            return
        }
        
        do {
            // x Print("📡 SLEEPER MATCHUPS: Making API call...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                // x Print("📡 SLEEPER MATCHUPS: HTTP Status \(httpResponse.statusCode)")
            }
            
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            // x Print("📊 SLEEPER MATCHUPS: Received \(sleeperMatchups.count) matchups")
            
            if sleeperMatchups.isEmpty {
                // x Print("🔥 CHOPPED DETECTION: No matchups found for week \(week) - checking if this is a chopped league")
                
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
            
            // x Print("🏈 SLEEPER MATCHUPS: Processing \(sleeperMatchups.count) regular matchups")
            await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
            
        } catch {
            // x Print("❌ SLEEPER MATCHUPS: API Error - \(error.localizedDescription)")
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }
    
    /// Process real Sleeper matchups with projected points
    func processSleeperMatchupsWithProjections(_ sleeperMatchups: [SleeperMatchupResponse], leagueID: String) async {
        // x Print("🏈 Processing \(sleeperMatchups.count) REAL Sleeper matchups with projections")
        
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
            
            // x Print("📊 REAL PROJECTIONS - Away: \(String(format: "%.2f", awayScore)) pts (\(String(format: "%.2f", awayProjected)) proj) | Home: \(String(format: "%.2f", homeScore)) pts (\(String(format: "%.2f", homeProjected)) proj)")
            
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
            
            // x Print("✅ Sleeper matchup: \(awayManagerName) (\(String(format: "%.2f", awayScore))) vs \(homeManagerName) (\(String(format: "%.2f", homeScore)))")
        }
        
        if !processedMatchups.isEmpty {
            matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
            // x Print("🎯 Processed \(processedMatchups.count) REAL Sleeper matchups with accurate projections")
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
                
                print("🎯 SLEEPER RECORD: Roster \(roster.rosterID) -> \(wins)-\(losses)-\(ties)")
                
                return TeamRecord(
                    wins: wins,
                    losses: losses,
                    ties: ties
                )
            }
            
            print("⚠️ SLEEPER RECORD: No roster found for rosterID \(matchupResponse.rosterID)")
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
        // x Print("🔍 CHOPPED VALIDATION: Checking rosters for league \(leagueID)")
        
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else {
            // x Print("❌ CHOPPED VALIDATION: Invalid rosters URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            // x Print("📊 CHOPPED VALIDATION: Found \(rosters.count) rosters")
            
            if !rosters.isEmpty {
                // x Print("🔥 CHOPPED VALIDATED: \(rosters.count) active rosters confirmed - this is definitely a Chopped league!")
                
                await MainActor.run {
                    hasActiveRosters = true
                    // x Print("🔥 CHOPPED: Updated hasActiveRosters = \(hasActiveRosters)")
                }
                
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: leagueID, 
                    week: week
                )
                isLoadingChoppedData = false
            } else {
                // x Print("❌ CHOPPED DETECTION FAILED: No rosters found - reverting detection")
                await MainActor.run {
                    detectedAsChoppedLeague = false
                    hasActiveRosters = false
                    errorMessage = "No matchups or active rosters found for week \(week)"
                }
            }
            
        } catch {
            // x Print("⚠️ CHOPPED VALIDATION ERROR: \(error) - keeping detection as is")
        }
    }
}