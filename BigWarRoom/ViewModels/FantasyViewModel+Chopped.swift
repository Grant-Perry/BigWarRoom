//
//  FantasyViewModel+Chopped.swift
//  BigWarRoom
//
//  Chopped League functionality for FantasyViewModel
//

import Foundation

// MARK: -> Chopped League Extension
extension FantasyViewModel {
    
    /// Check if a league is a Chopped format - NOW USES CENTRALIZED DETECTION
    func isChoppedLeague(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper?) -> Bool {
        guard let leagueWrapper = leagueWrapper else {
            // x Print("❌ CHOPPED CHECK: Nil league wrapper")
            return false
        }
        
        // x Print("🔍 CHOPPED CHECK: Checking league \(leagueWrapper.league.leagueID)")
        // x Print("   - League name: '\(leagueWrapper.league.name)'")
        
        // USE THE CENTRALIZED DETECTION METHOD - DRY PRINCIPLE
        let isChopped = leagueWrapper.isChoppedLeague
        
        if isChopped {
            // x Print("🔥 CHOPPED CHECK: ✅ Detected via centralized method (settings.type == 3)")
        } else {
            // x Print("❌ CHOPPED CHECK: NOT detected as Chopped league")
        }
        
        return isChopped
    }

    /// Create a ChoppedWeekSummary from real Sleeper data
    func createRealChoppedSummary(leagueID: String, week: Int) async -> ChoppedWeekSummary? {
        return await createRealChoppedSummaryWithHistory(leagueID: leagueID, week: week)
    }
    
    /// Enhanced Chopped summary with elimination tracking
    func createRealChoppedSummaryWithHistory(leagueID: String, week: Int) async -> ChoppedWeekSummary? {
        // Get all team data including eliminated teams
        let allTeamData = await fetchAllChoppedTeamData(leagueID: leagueID, week: week)
        
        guard !allTeamData.activeRankings.isEmpty else {
            print("❌ CHOPPED: No active rankings found")
            return nil
        }
        
        print("🔥 CHOPPED: Active teams: \(allTeamData.activeRankings.count)")
        print("💀 CHOPPED: Eliminated teams: \(allTeamData.eliminatedTeams.count)")

        let activeRankings = allTeamData.activeRankings
        let eliminatedTeams = allTeamData.eliminatedTeams

        let hasAnyScoring = activeRankings.contains { $0.weeklyPoints > 0 }
        let isScheduled = !hasAnyScoring
        
        let adjustedRankings = activeRankings.map { ranking -> FantasyTeamRanking in
            if isScheduled {
                return FantasyTeamRanking(
                    id: ranking.id,
                    team: ranking.team,
                    weeklyPoints: ranking.weeklyPoints,
                    rank: ranking.rank,
                    eliminationStatus: .safe,
                    isEliminated: false,
                    survivalProbability: 1.0,
                    pointsFromSafety: 0.0,
                    weeksAlive: ranking.weeksAlive
                )
            } else {
                return ranking
            }
        }
        
        let eliminatedTeam = isScheduled ? nil : activeRankings.last
        let cutoffScore = eliminatedTeam?.weeklyPoints ?? 0.0
        let allScores = activeRankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        // Convert eliminated teams to EliminationEvents for the graveyard
        let graveyardEvents = eliminatedTeams.enumerated().map { index, team in
            let eliminatedRanking = FantasyTeamRanking(
                id: team.id,
                team: team,
                weeklyPoints: team.currentScore ?? 0.0,
                rank: allTeamData.activeRankings.count + index + 1,
                eliminationStatus: .eliminated,
                isEliminated: true,
                survivalProbability: 0.0,
                pointsFromSafety: 0.0,
                weeksAlive: week - 1 // Assume eliminated last week
            )
            
            return EliminationEvent(
                id: "eliminated_\(team.id)",
                week: week - 1, // Assume eliminated last week
                eliminatedTeam: eliminatedRanking,
                eliminationScore: team.currentScore ?? 0.0,
                margin: 0.0,
                dramaMeter: 0.5,
                lastWords: "Left with no players to field...",
                timestamp: Date()
            )
        }
        
        let summary = ChoppedWeekSummary(
            id: "chopped_with_graveyard_\(leagueID)_\(week)",
            week: week,
            rankings: adjustedRankings,
            eliminatedTeam: eliminatedTeam,
            cutoffScore: cutoffScore,
            isComplete: !isScheduled && !hasLiveGames(),
            totalSurvivors: adjustedRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: graveyardEvents // Now includes teams with no players
        )
        
        if !graveyardEvents.isEmpty {
            print("💀 GRAVEYARD POPULATED:")
            for event in graveyardEvents {
                print("   \(event.eliminatedTeam.team.ownerName) - no players")
            }
        }
        
        return summary
    }

    /// Fetch all team data separated into active and eliminated
    private func fetchAllChoppedTeamData(leagueID: String, week: Int) async -> (activeRankings: [FantasyTeamRanking], eliminatedTeams: [FantasyTeam]) {
        // Use the existing method but modify it to return both active and eliminated data
        await fetchSleeperLeagueUsersAndRosters(leagueID: leagueID)
        await fetchSleeperScoringSettings(leagueID: leagueID)
        await fetchSleeperWeeklyStats()
        
        do {
            let sleeperMatchups = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID, 
                week: week
            )
            
            print("🔍 CHOPPED DEBUG: Analyzing \(sleeperMatchups.count) teams for active vs eliminated status")
            
            var allTeams: [FantasyTeam] = []
            var activeTeams: [FantasyTeam] = []
            var eliminatedTeams: [FantasyTeam] = []
            
            for matchup in sleeperMatchups {
                let teamScore = matchup.points ?? 0.0
                let teamProjected = matchup.projectedPoints ?? (teamScore * 1.05)
                let managerID = rosterIDToManagerID[matchup.rosterID] ?? ""
                
                // 🔥 THE ONLY THING THAT MATTERS: Do they have players?
                let starterCount = matchup.starters?.count ?? 0
                let playerCount = matchup.players?.count ?? 0
                let hasAnyPlayers = starterCount > 0 || playerCount > 0
                
                // IMPROVED: Better manager name resolution
                var finalManagerName = "Manager \(matchup.rosterID)"
                
                if !managerID.isEmpty {
                    if let displayName = userIDs[managerID], !displayName.isEmpty {
                        finalManagerName = displayName
                    }
                }
                
                let avatarURL = userAvatars[managerID]
                
                let fantasyTeam = FantasyTeam(
                    id: String(matchup.rosterID),
                    name: finalManagerName,
                    ownerName: finalManagerName,
                    record: nil,
                    avatar: avatarURL?.absoluteString,
                    currentScore: teamScore,
                    projectedScore: teamProjected,
                    roster: [],
                    rosterID: matchup.rosterID
                )
                
                // 🔥 DEBUG: Log each team's status
                print("   Team: \(finalManagerName)")
                print("     - Points: \(teamScore)")
                print("     - Starters: \(starterCount)")
                print("     - Players: \(playerCount)")
                print("     - Has Players: \(hasAnyPlayers)")
                print("     - Status: \(hasAnyPlayers ? "ACTIVE" : "ELIMINATED")")
                
                if hasAnyPlayers {
                    activeTeams.append(fantasyTeam)
                } else {
                    eliminatedTeams.append(fantasyTeam)
                    print("     ☠️ GRAVEYARD: \(finalManagerName) - NO PLAYERS")
                }
                
                allTeams.append(fantasyTeam)
            }
            
            print("🔥 CHOPPED SEPARATION RESULTS:")
            print("   - Total teams: \(allTeams.count)")
            print("   - Active teams (have players): \(activeTeams.count)")
            print("   - Eliminated teams (no players): \(eliminatedTeams.count)")
            
            if !eliminatedTeams.isEmpty {
                print("💀 ELIMINATED TEAMS:")
                for team in eliminatedTeams {
                    print("   - \(team.ownerName)")
                }
            }
            
            // Create rankings for active teams only - IGNORE POINTS FOR ELIMINATION STATUS
            let sortedActiveTeams = activeTeams.sorted { team1, team2 in
                let score1 = (team1.currentScore ?? 0.0) > 0 ? (team1.currentScore ?? 0.0) : (team1.projectedScore ?? 0.0)
                let score2 = (team2.currentScore ?? 0.0) > 0 ? (team2.currentScore ?? 0.0) : (team2.projectedScore ?? 0.0)
                return score1 > score2
            }
            
            let totalActiveTeams = sortedActiveTeams.count
            let allProjectedScores = sortedActiveTeams.compactMap { $0.projectedScore }
            let averageProjected = allProjectedScores.reduce(0, +) / Double(max(1, allProjectedScores.count))
            let weeksRemaining = max(0, 18 - week)
            
            let activeRankings = sortedActiveTeams.enumerated().map { index, team -> FantasyTeamRanking in
                let rank = index + 1
                let teamScore = team.currentScore ?? 0.0
                let teamProjected = team.projectedScore ?? 0.0
                
                let safetyPercentage = EliminationProbabilityCalculator.calculateSafetyPercentage(
                    currentRank: rank,
                    totalTeams: totalActiveTeams,
                    projectedPoints: teamProjected,
                    averageProjected: averageProjected,
                    weeklyVariance: 10.0,
                    weeksRemaining: weeksRemaining,
                    historicalPerformance: []
                )
                
                let status = EliminationProbabilityCalculator.determineEliminationStatus(
                    safetyPercentage: safetyPercentage,
                    rank: rank,
                    totalTeams: totalActiveTeams
                )
                
                print("   Active Team \(rank): \(team.ownerName) - \(teamScore) pts - \(status.displayName)")
                
                return FantasyTeamRanking(
                    id: team.id,
                    team: team,
                    weeklyPoints: teamScore > 0 ? teamScore : teamProjected,
                    rank: rank,
                    eliminationStatus: status,
                    isEliminated: false, // Active teams are never eliminated
                    survivalProbability: safetyPercentage,
                    pointsFromSafety: 0.0,
                    weeksAlive: week
                )
            }
            
            return (activeRankings: activeRankings, eliminatedTeams: eliminatedTeams)
            
        } catch {
            print("❌ Failed to fetch chopped team data: \(error)")
            return (activeRankings: [], eliminatedTeams: [])
        }
    }
    
    /// Check if there are currently live NFL games
    private func hasLiveGames() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        
        if weekday == 1 && hour >= 13 && hour <= 23 { return true }
        if weekday == 2 && hour >= 20 && hour <= 23 { return true }
        if weekday == 5 && hour >= 20 && hour <= 23 { return true }
        
        return false
    }
}