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
        let rankings = await fetchChoppedLeagueStandings(leagueID: leagueID, week: week)
        
        guard !rankings.isEmpty else {
            return nil
        }
        
        let eliminationHistory = await fetchChoppedEliminationHistory(leagueID: leagueID, currentWeek: week)
        
        let hasAnyScoring = rankings.contains { $0.weeklyPoints > 0 }
        let isScheduled = !hasAnyScoring
        
        let adjustedRankings = rankings.map { ranking -> FantasyTeamRanking in
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
        
        let eliminatedTeam = isScheduled ? nil : rankings.last
        let cutoffScore = eliminatedTeam?.weeklyPoints ?? 0.0
        let allScores = rankings.map { $0.weeklyPoints }
        let avgScore = allScores.reduce(0, +) / Double(allScores.count)
        let highScore = allScores.max() ?? 0.0
        let lowScore = allScores.min() ?? 0.0
        
        let summary = ChoppedWeekSummary(
            id: "chopped_with_history_\(leagueID)_\(week)",
            week: week,
            rankings: adjustedRankings,
            eliminatedTeam: eliminatedTeam,
            cutoffScore: cutoffScore,
            isComplete: !isScheduled && !hasLiveGames(),
            totalSurvivors: adjustedRankings.filter { !$0.isEliminated }.count,
            averageScore: avgScore,
            highestScore: highScore,
            lowestScore: lowScore,
            eliminationHistory: eliminationHistory
        )
        
        if !eliminationHistory.isEmpty {
            // x Print("💀 ELIMINATION HISTORY:")
            for elimination in eliminationHistory {
                // x Print("   Week \(elimination.week): \(elimination.eliminatedTeam.team.ownerName) - \(elimination.eliminationScore) pts (margin: \(elimination.margin))")
            }
        }
        
        return summary
    }
    
    /// Fetch Chopped league standings with real projected points and elimination probabilities
    func fetchChoppedLeagueStandings(leagueID: String, week: Int) async -> [FantasyTeamRanking] {
        // x Print("🔍 CHOPPED STANDINGS: Starting fetch for league \(leagueID)")
        
        // FIRST: Ensure all user data is loaded and populated
        await fetchSleeperLeagueUsersAndRosters(leagueID: leagueID)
        await fetchSleeperScoringSettings(leagueID: leagueID)
        await fetchSleeperWeeklyStats()
        
        // DEBUG: Check if user data was populated
        // x Print("📊 USER DATA CHECK:")
        // x Print("   - rosterIDToManagerID count: \(rosterIDToManagerID.count)")
        // x Print("   - userIDs count: \(userIDs.count)")
        // x Print("   - userAvatars count: \(userAvatars.count)")
        
        if !rosterIDToManagerID.isEmpty {
            // x Print("   - Sample roster mappings:")
            for (rosterID, managerID) in rosterIDToManagerID.prefix(3) {
                let displayName = userIDs[managerID] ?? "NO NAME"
                // x Print("     Roster \(rosterID) -> Manager \(managerID) -> '\(displayName)'")
            }
        }
        
        do {
            let sleeperMatchups = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID, 
                week: week
            )
            
            var allTeams: [FantasyTeam] = []
            
            for matchup in sleeperMatchups {
                let teamScore = matchup.points ?? 0.0
                let teamProjected = matchup.projectedPoints ?? (teamScore * 1.05)
                let managerID = rosterIDToManagerID[matchup.rosterID] ?? ""
                
                // x Print("🔍 PROCESSING: Roster \(matchup.rosterID)")
                // x Print("   - Found managerID: '\(managerID)'")
                
                // IMPROVED: Better manager name resolution with multiple fallbacks
                var finalManagerName = "Manager \(matchup.rosterID)" // fallback
                
                if !managerID.isEmpty {
                    if let displayName = userIDs[managerID], !displayName.isEmpty {
                        // Use actual display name if available
                        finalManagerName = displayName
                        // x Print("👤 MANAGER SUCCESS: Roster \(matchup.rosterID) -> '\(displayName)'")
                    } else {
                        // x Print("⚠️ NO DISPLAY NAME: Manager ID '\(managerID)' not found in userIDs")
                    }
                } else {
                    // x Print("❌ NO MANAGER ID: Roster \(matchup.rosterID) has no mapped manager ID")
                }
                
                // Try draft room data as additional fallback
                if finalManagerName.hasPrefix("Manager ") {
                    if let sharedDraftRoom = sharedDraftRoomViewModel {
                        let allPicks = sharedDraftRoom.allDraftPicks
                        if let correspondingPick = allPicks.first(where: { $0.rosterInfo?.rosterID == matchup.rosterID }) {
                            let draftSlotBasedName = sharedDraftRoom.teamDisplayName(for: correspondingPick.draftSlot)
                            
                            if !draftSlotBasedName.isEmpty,
                               !draftSlotBasedName.lowercased().hasPrefix("team "),
                               !draftSlotBasedName.lowercased().hasPrefix("manager "),
                               draftSlotBasedName.count > 4 {
                                finalManagerName = draftSlotBasedName
                                // x Print("🎯 DRAFT FALLBACK: Roster \(matchup.rosterID) -> '\(draftSlotBasedName)'")
                            }
                        }
                    }
                }
                
                if finalManagerName.hasPrefix("Manager ") {
                    // x Print("⚠️ FALLBACK: Roster \(matchup.rosterID) -> \(finalManagerName)")
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
                
                allTeams.append(fantasyTeam)
            }
            
            let sortedTeams = allTeams.sorted { team1, team2 in
                let score1 = (team1.currentScore ?? 0.0) > 0 ? (team1.currentScore ?? 0.0) : (team1.projectedScore ?? 0.0)
                let score2 = (team2.currentScore ?? 0.0) > 0 ? (team2.currentScore ?? 0.0) : (team2.projectedScore ?? 0.0)
                return score1 > score2
            }
            
            let totalTeams = sortedTeams.count
            let allCurrentScores = sortedTeams.compactMap { $0.currentScore }
            let allProjectedScores = sortedTeams.compactMap { $0.projectedScore }
            let averageProjected = allProjectedScores.reduce(0, +) / Double(allProjectedScores.count)
            let scoreVariance = calculateScoreVariance(allCurrentScores)
            let weeksRemaining = max(0, 18 - week)
            
            let rankings = sortedTeams.enumerated().map { index, team -> FantasyTeamRanking in
                let rank = index + 1
                let teamScore = team.currentScore ?? 0.0
                let teamProjected = team.projectedScore ?? 0.0
                
                let safetyPercentage = EliminationProbabilityCalculator.calculateSafetyPercentage(
                    currentRank: rank,
                    totalTeams: totalTeams,
                    projectedPoints: teamProjected,
                    averageProjected: averageProjected,
                    weeklyVariance: scoreVariance,
                    weeksRemaining: weeksRemaining,
                    historicalPerformance: []
                )
                
                let status = EliminationProbabilityCalculator.determineEliminationStatus(
                    safetyPercentage: safetyPercentage,
                    rank: rank,
                    totalTeams: totalTeams
                )
                
                let lastPlaceProjected = sortedTeams.last?.projectedScore ?? 0.0
                let safetyMargin = teamProjected - lastPlaceProjected
                
                return FantasyTeamRanking(
                    id: team.id,
                    team: team,
                    weeklyPoints: teamScore > 0 ? teamScore : teamProjected,
                    rank: rank,
                    eliminationStatus: status,
                    isEliminated: false,
                    survivalProbability: safetyPercentage,
                    pointsFromSafety: safetyMargin,
                    weeksAlive: week
                )
            }
            
            // x Print("🔥 CHOPPED: Created \(rankings.count) real team rankings with Sleeper-style safety percentages for league \(leagueID) week \(week)")
            return rankings
            
        } catch {
            // x Print("❌ CHOPPED: Failed to fetch league standings with projections: \(error)")
            return []
        }
    }
    
    /// Fetch complete elimination history for Chopped league
    func fetchChoppedEliminationHistory(leagueID: String, currentWeek: Int) async -> [EliminationEvent] {
        var eliminationHistory: [EliminationEvent] = []
        
        for week in 1..<currentWeek {
            if let elimination = await calculateWeeklyElimination(leagueID: leagueID, week: week) {
                eliminationHistory.append(elimination)
            }
        }
        
        // x Print("💀 ELIMINATION TRACKER: Found \(eliminationHistory.count) eliminations across \(currentWeek-1) weeks")
        return eliminationHistory.sorted { $0.week < $1.week }
    }

    /// Calculate who was eliminated in a specific week
    private func calculateWeeklyElimination(leagueID: String, week: Int) async -> EliminationEvent? {
        guard let url = URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let sleeperMatchups = try JSONDecoder().decode([SleeperMatchup].self, from: data)
            
            var teamScores: [(rosterID: Int, score: Double, managerName: String)] = []
            
            for matchup in sleeperMatchups {
                let teamScore = calculateSleeperTeamScore(matchup: matchup)
                let managerID = rosterIDToManagerID[matchup.roster_id] ?? ""
                let managerName = userIDs[managerID] ?? "Manager \(matchup.roster_id)"
                
                teamScores.append((
                    rosterID: matchup.roster_id,
                    score: teamScore,
                    managerName: managerName
                ))
            }
            
            guard let lowestScorer = teamScores.min(by: { $0.score < $1.score }) else {
                return nil
            }
            
            let tiedTeams = teamScores.filter { $0.score == lowestScorer.score }
            let dramaMeter = tiedTeams.count > 1 ? 1.0 : 0.6
            
            let eliminationTeam = FantasyTeam(
                id: String(lowestScorer.rosterID),
                name: lowestScorer.managerName,
                ownerName: lowestScorer.managerName,
                record: nil,
                avatar: nil,
                currentScore: lowestScorer.score,
                projectedScore: lowestScorer.score,
                roster: [],
                rosterID: lowestScorer.rosterID
            )
            
            let eliminationRanking = FantasyTeamRanking(
                id: String(lowestScorer.rosterID),
                team: eliminationTeam,
                weeklyPoints: lowestScorer.score,
                rank: teamScores.count,
                eliminationStatus: .eliminated,
                isEliminated: true,
                survivalProbability: 0.0,
                pointsFromSafety: 0.0,
                weeksAlive: week
            )
            
            let sortedScores = teamScores.map { $0.score }.sorted(by: >)
            let secondLowest = sortedScores.count > 1 ? sortedScores[sortedScores.count - 2] : lowestScorer.score
            let margin = secondLowest - lowestScorer.score
            
            return EliminationEvent(
                id: "elimination_\(leagueID)_week_\(week)",
                week: week,
                eliminatedTeam: eliminationRanking,
                eliminationScore: lowestScorer.score,
                margin: margin,
                dramaMeter: dramaMeter,
                lastWords: tiedTeams.count > 1 ? "Eliminated by tiebreaker" : "Couldn't score enough to survive",
                timestamp: Date()
            )
        
        } catch {
            // x Print("❌ ELIMINATION: Failed to fetch week \(week) data: \(error)")
            return nil
        }
    }
    
    /// Calculate Sleeper team score using real starter lineup (legacy format)
    private func calculateSleeperTeamScore(matchup: SleeperMatchup) -> Double {
        guard let starters = matchup.starters else { return 0.0 }
        
        return starters.reduce(0.0) { total, playerId in
            total + calculateSleeperPlayerScore(playerId: playerId)
        }
    }
    
    /// Calculate score variance for elimination probability calculation
    private func calculateScoreVariance(_ scores: [Double]) -> Double {
        guard scores.count > 1 else { return 10.0 }
        
        let mean = scores.reduce(0, +) / Double(scores.count)
        let squaredDifferences = scores.map { pow($0 - mean, 2) }
        return sqrt(squaredDifferences.reduce(0, +) / Double(scores.count - 1))
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
