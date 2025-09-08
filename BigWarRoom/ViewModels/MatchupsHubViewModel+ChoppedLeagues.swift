//
//  MatchupsHubViewModel+ChoppedLeagues.swift
//  BigWarRoom
//
//  Chopped league specific logic for MatchupsHubViewModel
//

import Foundation

// MARK: - Chopped League Operations
extension MatchupsHubViewModel {
    
    /// Handle chopped league processing
    internal func handleChoppedLeague(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String) async -> UnifiedMatchup? {
        print("🔥 CHOPPED DETECTED: League \(league.league.name) has no matchups - processing as Chopped league")
        
        // Create chopped summary using proper Sleeper data
        if let choppedSummary = await createSleeperChoppedSummary(league: league, myTeamID: myTeamID, week: getCurrentWeek()) {
            if let myTeamRanking = await findMyTeamInChoppedLeaderboard(choppedSummary, leagueID: league.league.leagueID) {
                
                let unifiedMatchup = UnifiedMatchup(
                    id: "\(league.id)_chopped",
                    league: league,
                    fantasyMatchup: nil,
                    choppedSummary: choppedSummary,
                    lastUpdated: Date(),
                    myTeamRanking: myTeamRanking,
                    myIdentifiedTeamID: myTeamID
                )
                
                await updateLeagueLoadingState(league.id, status: .completed, progress: 1.0)
                print("✅ Created Chopped league entry for \(league.league.name): \(myTeamRanking.team.ownerName) ranked \(myTeamRanking.rank)")
                return unifiedMatchup
            }
        }
        
        print("❌ CHOPPED: Failed to create chopped summary for \(league.league.name)")
        await updateLeagueLoadingState(league.id, status: .failed, progress: 0.0)
        return nil
    }
    
    /// Create Chopped league summary for Sleeper leagues with no matchups
    internal func createSleeperChoppedSummary(league: UnifiedLeagueManager.LeagueWrapper, myTeamID: String, week: Int) async -> ChoppedWeekSummary? {
        print("🔥 CHOPPED: Creating REAL summary for \(league.league.name) week \(week)")
        
        do {
            // Step 1: Fetch REAL matchup data for this week to get actual starter scores
            let matchupData = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: league.league.leagueID, 
                week: week
            )
            print("📊 CHOPPED: Found \(matchupData.count) team scores in \(league.league.name)")
            
            // Step 2-3: Fetch rosters and users data
            let (rosters, users) = try await fetchRostersAndUsers(for: league.league.leagueID)
            
            // Step 4: Create team mapping and fantasy teams
            let (rosterToOwnerMap, userMap, avatarMap) = createTeamMappings(rosters: rosters, users: users)
            let choppedTeams = createChoppedFantasyTeams(matchupData: matchupData, rosterToOwnerMap: rosterToOwnerMap, userMap: userMap, avatarMap: avatarMap)
            
            // Step 5: Process and rank teams
            return await processChoppedTeamRankings(teams: choppedTeams, league: league, week: week)
            
        } catch {
            print("❌ CHOPPED: Failed to create REAL summary for \(league.league.name): \(error)")
            return nil
        }
    }
    
    /// Fetch rosters and users data in parallel
    private func fetchRostersAndUsers(for leagueID: String) async throws -> ([SleeperRoster], [SleeperLeagueUser]) {
        async let rosters = SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
        async let users = SleeperAPIClient.shared.fetchUsers(leagueID: leagueID)
        
        let rostersResult = try await rosters
        let usersResult = try await users
        
        print("📊 CHOPPED: Found \(rostersResult.count) rosters and \(usersResult.count) users")
        
        return (rostersResult, usersResult)
    }
    
    /// Create team mapping dictionaries
    private func createTeamMappings(rosters: [SleeperRoster], users: [SleeperLeagueUser]) -> ([Int: String], [String: String], [String: URL]) {
        let userMap = Dictionary(uniqueKeysWithValues: users.map { ($0.userID, $0.displayName ?? "Team \($0.userID)") })
        
        let avatarMap = Dictionary(uniqueKeysWithValues: users.compactMap { user -> (String, URL)? in
            guard let avatar = user.avatar,
                  let url = URL(string: "https://sleepercdn.com/avatars/\(avatar)") else { return nil }
            return (user.userID, url)
        })
        
        let rosterToOwnerMap = Dictionary(uniqueKeysWithValues: rosters.compactMap { roster -> (Int, String)? in
            guard let ownerID = roster.ownerID else { return nil }
            return (roster.rosterID, ownerID)
        })
        
        return (rosterToOwnerMap, userMap, avatarMap)
    }
    
    /// Create fantasy teams from matchup data
    private func createChoppedFantasyTeams(
        matchupData: [SleeperMatchupResponse], 
        rosterToOwnerMap: [Int: String], 
        userMap: [String: String], 
        avatarMap: [String: URL]
    ) -> [FantasyTeam] {
        var choppedTeams: [FantasyTeam] = []
        
        for matchup in matchupData {
            let rosterID = matchup.rosterID
            let ownerID = rosterToOwnerMap[rosterID] ?? ""
            let resolvedTeamName = userMap[ownerID] ?? "Team \(rosterID)"
            let avatarURL = avatarMap[ownerID]
            
            // 🔥 CRITICAL FIX: Use REAL points from the matchup data (starter-only scores)
            let realTeamScore = matchup.points ?? 0.0
            let projectedScore = matchup.projectedPoints ?? (realTeamScore * 1.05)
            
            print("🎯 CHOPPED TEAM: \(resolvedTeamName) = \(String(format: "%.2f", realTeamScore)) pts (Projected: \(String(format: "%.2f", projectedScore)))")
            
            let fantasyTeam = FantasyTeam(
                id: String(rosterID),
                name: resolvedTeamName,
                ownerName: resolvedTeamName,
                record: nil,
                avatar: avatarURL?.absoluteString,
                currentScore: realTeamScore,
                projectedScore: projectedScore,
                roster: [], // Empty for chopped leagues (we only care about total scores)
                rosterID: rosterID
            )
            
            choppedTeams.append(fantasyTeam)
        }
        
        return choppedTeams
    }
    
    /// Process team rankings and create final summary
    private func processChoppedTeamRankings(teams: [FantasyTeam], league: UnifiedLeagueManager.LeagueWrapper, week: Int) async -> ChoppedWeekSummary {
        // Sort teams by REAL scores (highest to lowest)
        let sortedTeams = teams.sorted { team1, team2 in
            let score1 = team1.currentScore ?? 0.0
            let score2 = team2.currentScore ?? 0.0
            return score1 > score2
        }
        
        // Dynamic elimination count based on league size
        let totalTeams = sortedTeams.count
        let eliminationCount = totalTeams >= 18 ? 2 : 1
        print("🔥 ELIMINATION LOGIC: \(totalTeams) teams = \(eliminationCount) eliminations per week")
        
        // Create team rankings with proper elimination zones
        let teamRankings = createTeamRankings(sortedTeams: sortedTeams, eliminationCount: eliminationCount, totalTeams: totalTeams, week: week)
        
        // Calculate summary stats
        let (avgScore, highScore, lowScore) = calculateSummaryStats(teamRankings: teamRankings)
        
        // Get eliminated teams (bottom N teams)
        let eliminatedTeams = Array(teamRankings.suffix(eliminationCount))
        
        logChoppedSummary(totalTeams: totalTeams, eliminationCount: eliminationCount, eliminatedTeams: eliminatedTeams, highScore: highScore, lowScore: lowScore, avgScore: avgScore, leagueName: league.league.name)
        
        return ChoppedWeekSummary(
            id: "chopped_real_\(league.league.leagueID)_\(week)",
            week: week,
            rankings: teamRankings,
            eliminatedTeam: eliminatedTeams.first, // Primary eliminated team for UI
            cutoffScore: lowScore,
            isComplete: true, // Real data means it's complete
            totalSurvivors: teamRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: [] // TODO: Could fetch this from previous weeks
        )
    }
    
    /// Create team rankings with elimination status
    private func createTeamRankings(sortedTeams: [FantasyTeam], eliminationCount: Int, totalTeams: Int, week: Int) -> [FantasyTeamRanking] {
        return sortedTeams.enumerated().map { (index, team) -> FantasyTeamRanking in
            let rank = index + 1
            let teamScore = team.currentScore ?? 0.0
            
            // 🔥 DEATH ROW CALCULATION: Bottom N teams based on elimination count
            let isInEliminationZone = rank > (totalTeams - eliminationCount)
            
            let status: EliminationStatus
            if rank == 1 {
                status = .champion
            } else if isInEliminationZone {
                status = .critical // 🔥 DEATH ROW
            } else if rank > (totalTeams * 3 / 4) {
                status = .danger
            } else if rank > (totalTeams / 2) {
                status = .warning
            } else {
                status = .safe
            }
            
            // Calculate safety margin from elimination cutoff
            let eliminationCutoffTeams = sortedTeams.suffix(eliminationCount)
            let cutoffScore = eliminationCutoffTeams.first?.currentScore ?? 0.0
            let safetyMargin = teamScore - cutoffScore
            
            print("🎯 RANKING: #\(rank) \(team.ownerName) - \(String(format: "%.2f", teamScore)) pts (\(status.displayName)) - Safety: +\(String(format: "%.2f", safetyMargin))")
            
            return FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: teamScore,
                rank: rank,
                eliminationStatus: status,
                isEliminated: false, // 🔥 FIX: Don't mark as eliminated yet - let Death Row show them first
                survivalProbability: isInEliminationZone ? 0.0 : max(0.0, min(1.0, Double(totalTeams - rank) / Double(totalTeams))),
                pointsFromSafety: safetyMargin,
                weeksAlive: week
            )
        }
    }
    
    /// Calculate summary statistics
    private func calculateSummaryStats(teamRankings: [FantasyTeamRanking]) -> (avgScore: Double, highScore: Double, lowScore: Double) {
        let allScores = teamRankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        return (avgScore, highScore, lowScore)
    }
    
    /// Log chopped summary details
    private func logChoppedSummary(totalTeams: Int, eliminationCount: Int, eliminatedTeams: [FantasyTeamRanking], highScore: Double, lowScore: Double, avgScore: Double, leagueName: String) {
        print("🔥 CHOPPED SUMMARY: \(totalTeams) teams, \(eliminationCount) eliminations")
        print("   💀 DEATH ROW: \(eliminatedTeams.map { $0.team.ownerName }.joined(separator: ", "))")
        print("   📊 Scores: High=\(String(format: "%.2f", highScore)), Low=\(String(format: "%.2f", lowScore)), Avg=\(String(format: "%.2f", avgScore))")
        print("🎯 CHOPPED: Created REAL summary with \(totalTeams) teams for \(leagueName)")
    }
    
    /// Find the authenticated user's team in the Chopped leaderboard using proper Sleeper user identification
    internal func findMyTeamInChoppedLeaderboard(_ choppedSummary: ChoppedWeekSummary, leagueID: String) async -> FantasyTeamRanking? {
        // Strategy 1: For Sleeper leagues, use roster ID matching
        if let userRosterID = await getCurrentUserRosterID(leagueID: leagueID) {
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.rosterID == userRosterID
            }
            
            if let myRanking = myRanking {
                print("🎯 CHOPPED: Found MY team by roster ID \(userRosterID): \(myRanking.team.ownerName) (\(myRanking.eliminationStatus.displayName))")
                return myRanking
            }
        }
        
        // Strategy 2: Fallback to username matching
        let authenticatedUsername = sleeperCredentials.currentUsername
        if !authenticatedUsername.isEmpty {
            let myRanking = choppedSummary.rankings.first { ranking in
                ranking.team.ownerName.lowercased() == authenticatedUsername.lowercased()
            }
            
            if let myRanking = myRanking {
                print("🎯 CHOPPED: Found MY team by username '\(authenticatedUsername)': \(myRanking.team.ownerName) (\(myRanking.eliminationStatus.displayName))")
                return myRanking
            }
        }
        
        // Strategy 3: Match by "Gp" (specific fallback)
        let gpRanking = choppedSummary.rankings.first { ranking in
            ranking.team.ownerName.lowercased().contains("gp")
        }
        
        if let gpRanking = gpRanking {
            print("🎯 CHOPPED: Found MY team by 'Gp' match: \(gpRanking.team.ownerName) (\(gpRanking.eliminationStatus.displayName))")
            return gpRanking
        }
        
        print("⚠️ CHOPPED: Could not identify user team in league \(leagueID)")
        print("   Available teams: \(choppedSummary.rankings.map { $0.team.ownerName }.joined(separator: ", "))")
        
        // Return first team as fallback
        return choppedSummary.rankings.first
    }
    
    /// Get the current user's roster ID in a Sleeper league (helper for Chopped leagues)
    private func getCurrentUserRosterID(leagueID: String) async -> Int? {
        guard !sleeperCredentials.currentUserID.isEmpty else {
            print("❌ SLEEPER: No user ID available for roster identification")
            return nil
        }
        
        do {
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            let userRoster = rosters.first { $0.ownerID == sleeperCredentials.currentUserID }
            
            if let userRoster = userRoster {
                print("🎯 SLEEPER: Found user roster ID \(userRoster.rosterID) for user \(sleeperCredentials.currentUserID)")
                return userRoster.rosterID
            } else {
                print("⚠️ SLEEPER: No roster found for user \(sleeperCredentials.currentUserID) in league \(leagueID)")
                return nil
            }
        } catch {
            print("❌ SLEEPER: Failed to fetch rosters for league \(leagueID): \(error)")
            return nil
        }
    }
}