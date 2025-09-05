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
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["scoring_settings"] as? [String: Any] {
                sleeperLeagueSettings = settings
            }
        } catch {
            // Silent error handling
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
            print("❌ SLEEPER ROSTERS: Invalid URL for league \(leagueID)")
            return 
        }
        
        print("🌐 SLEEPER ROSTERS: Fetching roster data for league \(leagueID)")
        print("🔗 SLEEPER ROSTERS: URL = \(rostersURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: rostersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SLEEPER ROSTERS: HTTP Status \(httpResponse.statusCode)")
            }
            
            print("📊 SLEEPER ROSTERS: Received \(data.count) bytes")
            
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            print("📋 SLEEPER ROSTERS: Decoded \(rosters.count) rosters")
            
            var newRosterMapping: [Int: String] = [:]
            
            for roster in rosters {
                if let ownerID = roster.ownerID {
                    newRosterMapping[roster.rosterID] = ownerID
                    print("🔗 SLEEPER ROSTER: Roster \(roster.rosterID) -> Owner \(ownerID)")
                } else {
                    print("⚠️ SLEEPER ROSTER: Roster \(roster.rosterID) has no owner!")
                }
            }
            
            rosterIDToManagerID = newRosterMapping
            print("✅ SLEEPER ROSTERS: Populated rosterIDToManagerID with \(rosterIDToManagerID.count) entries")
            
            // Now fetch the user display names
            await fetchSleeperUsers(leagueID: leagueID)
            
        } catch {
            print("❌ SLEEPER ROSTERS: Error - \(error)")
        }
    }
    
    /// Fetch Sleeper users
    private func fetchSleeperUsers(leagueID: String) async {
        guard let usersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users") else { 
            print("❌ SLEEPER USERS: Invalid URL for league \(leagueID)")
            return 
        }
        
        print("🌐 SLEEPER USERS: Fetching user data for league \(leagueID)")
        print("🔗 SLEEPER USERS: URL = \(usersURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: usersURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SLEEPER USERS: HTTP Status \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ SLEEPER USERS: Bad HTTP status \(httpResponse.statusCode)")
                    return
                }
            }
            
            print("📊 SLEEPER USERS: Received \(data.count) bytes")
            
            let users = try JSONDecoder().decode([SleeperUser].self, from: data)
            print("👥 SLEEPER USERS: Decoded \(users.count) users")
            
            var newUserIDs: [String: String] = [:]
            var newUserAvatars: [String: URL] = [:]
            
            for (index, user) in users.enumerated() {
                print("👤 SLEEPER USER \(index): ID=\(user.userID), Display='\(user.displayName)', Username='\(user.username ?? "nil")'")
                
                newUserIDs[user.userID] = user.displayName
                
                if let avatar = user.avatar {
                    let avatarURL = URL(string: "https://sleepercdn.com/avatars/\(avatar)")
                    newUserAvatars[user.userID] = avatarURL
                    print("🎭 SLEEPER AVATAR: User \(user.userID) has avatar \(avatar)")
                }
            }
            
            // Update the dictionaries
            userIDs = newUserIDs
            userAvatars = newUserAvatars
            
            print("✅ SLEEPER USERS: Successfully populated userIDs with \(userIDs.count) entries")
            print("📋 SLEEPER USERS: Final userIDs = \(userIDs)")
            
        } catch {
            print("❌ SLEEPER USERS: Decoding error - \(error)")
            if let decodingError = error as? DecodingError {
                print("🔍 SLEEPER USERS: Decoding details - \(decodingError)")
            }
        }
    }
    
    /// Fetch real Sleeper matchups
    func fetchSleeperMatchups(leagueID: String, week: Int) async {
        print("🔍 SLEEPER MATCHUPS: Fetching for league \(leagueID) week \(week)")
        
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            print("❌ SLEEPER MATCHUPS: Invalid URL")
            return
        }
        
        do {
            print("📡 SLEEPER MATCHUPS: Making API call...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SLEEPER MATCHUPS: HTTP Status \(httpResponse.statusCode)")
            }
            
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchupResponse].self, from: data)
            print("📊 SLEEPER MATCHUPS: Received \(sleeperMatchups.count) matchups")
            
            if sleeperMatchups.isEmpty {
                print("🔥 CHOPPED DETECTION: No matchups found for week \(week) - checking if this is a chopped league")
                
                detectedAsChoppedLeague = true
                hasActiveRosters = true
                
                await MainActor.run {
                    print("🔥 CHOPPED: Forcing UI update with objectWillChange.send()")
                    self.objectWillChange.send()
                }
                
                Task {
                    await validateChoppedLeagueDetection(leagueID: leagueID, week: week)
                }
                
                return
            }
            
            print("🏈 SLEEPER MATCHUPS: Processing \(sleeperMatchups.count) regular matchups")
            await processSleeperMatchupsWithProjections(sleeperMatchups, leagueID: leagueID)
            
        } catch {
            print("❌ SLEEPER MATCHUPS: API Error - \(error.localizedDescription)")
            errorMessage = "Failed to fetch Sleeper matchups: \(error.localizedDescription)"
        }
    }
    
    /// Process real Sleeper matchups with projected points
    func processSleeperMatchupsWithProjections(_ sleeperMatchups: [SleeperMatchupResponse], leagueID: String) async {
        print("🏈 Processing \(sleeperMatchups.count) REAL Sleeper matchups with projections")
        
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
            
            print("📊 REAL PROJECTIONS - Away: \(String(format: "%.2f", awayScore)) pts (\(String(format: "%.2f", awayProjected)) proj) | Home: \(String(format: "%.2f", homeScore)) pts (\(String(format: "%.2f", homeProjected)) proj)")
            
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
            
            print("✅ Sleeper matchup: \(awayManagerName) (\(String(format: "%.2f", awayScore))) vs \(homeManagerName) (\(String(format: "%.2f", homeScore)))")
        }
        
        if !processedMatchups.isEmpty {
            matchups = processedMatchups.sorted { $0.homeTeam.ownerName < $1.homeTeam.ownerName }
            print("🎯 Processed \(processedMatchups.count) REAL Sleeper matchups with accurate projections")
        }
    }
    
    /// Create Sleeper fantasy team with real projected points from API
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
                        gameStatus: createMockGameStatus(),
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
        
        return FantasyTeam(
            id: String(matchupResponse.rosterID),
            name: finalManagerName,
            ownerName: finalManagerName,
            record: nil,
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
        print("🔍 CHOPPED VALIDATION: Checking rosters for league \(leagueID)")
        
        guard let rostersURL = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters") else {
            print("❌ CHOPPED VALIDATION: Invalid rosters URL")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: rostersURL)
            let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
            
            print("📊 CHOPPED VALIDATION: Found \(rosters.count) rosters")
            
            if !rosters.isEmpty {
                print("🔥 CHOPPED VALIDATED: \(rosters.count) active rosters confirmed - this is definitely a Chopped league!")
                
                await MainActor.run {
                    hasActiveRosters = true
                    print("🔥 CHOPPED: Updated hasActiveRosters = \(hasActiveRosters)")
                }
                
                isLoadingChoppedData = true
                currentChoppedSummary = await createRealChoppedSummaryWithHistory(
                    leagueID: leagueID, 
                    week: week
                )
                isLoadingChoppedData = false
            } else {
                print("❌ CHOPPED DETECTION FAILED: No rosters found - reverting detection")
                await MainActor.run {
                    detectedAsChoppedLeague = false
                    hasActiveRosters = false
                    errorMessage = "No matchups or active rosters found for week \(week)"
                }
            }
            
        } catch {
            print("⚠️ CHOPPED VALIDATION ERROR: \(error) - keeping detection as is")
        }
    }
}