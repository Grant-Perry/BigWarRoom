//
//  PlayerComparisonViewModel.swift
//  BigWarRoom
//
//  ViewModel for player comparison feature (MVP - without betting odds)
//

import Foundation
import Observation

@Observable
@MainActor
class PlayerComparisonViewModel {
    
    // MARK: - State
    var player1: SleeperPlayer?
    var player2: SleeperPlayer?
    
    var comparisonPlayer1: ComparisonPlayer?
    var comparisonPlayer2: ComparisonPlayer?
    var recommendation: ComparisonRecommendation?
    
    var isLoading = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    private let playerDirectory = PlayerDirectoryStore.shared
    private let statsService = SharedStatsService.shared
    private var nflGameService: NFLGameDataService
    
    init(nflGameService: NFLGameDataService) {
        self.nflGameService = nflGameService
    }
    
    // MARK: - Current Week
    var currentWeek: Int {
        WeekSelectionManager.shared.selectedWeek
    }
    
    var currentYear: String {
        AppConstants.currentSeasonYear
    }
    
    // MARK: - Persistence Keys
    private let lastPlayer1IDKey = "StartSit_LastPlayer1ID"
    private let lastPlayer2IDKey = "StartSit_LastPlayer2ID"
    
    // MARK: - Player Selection
    
    func selectPlayer1(_ player: SleeperPlayer) {
        player1 = player
        comparisonPlayer1 = nil
        recommendation = nil
        // Persist selection
        UserDefaults.standard.set(player.playerID, forKey: lastPlayer1IDKey)
    }
    
    func selectPlayer2(_ player: SleeperPlayer) {
        player2 = player
        comparisonPlayer2 = nil
        recommendation = nil
        // Persist selection
        UserDefaults.standard.set(player.playerID, forKey: lastPlayer2IDKey)
    }
    
    func clearPlayer1() {
        player1 = nil
        comparisonPlayer1 = nil
        // Don't clear recommendation - let player 2 stay if they exist
        UserDefaults.standard.removeObject(forKey: lastPlayer1IDKey)
    }
    
    func clearPlayer2() {
        player2 = nil
        comparisonPlayer2 = nil
        // Don't clear recommendation - let player 1 stay if they exist
        UserDefaults.standard.removeObject(forKey: lastPlayer2IDKey)
    }
    
    func clearBoth() {
        player1 = nil
        player2 = nil
        comparisonPlayer1 = nil
        comparisonPlayer2 = nil
        recommendation = nil
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: lastPlayer1IDKey)
        UserDefaults.standard.removeObject(forKey: lastPlayer2IDKey)
    }
    
    /// Restore last compared players from persisted IDs (if available)
    func restoreLastComparison() {
        let defaults = UserDefaults.standard
        guard let id1 = defaults.string(forKey: lastPlayer1IDKey),
              let id2 = defaults.string(forKey: lastPlayer2IDKey) else {
            return
        }
        
        let store = playerDirectory
        if let p1 = store.players[id1] {
            player1 = p1
        }
        if let p2 = store.players[id2] {
            player2 = p2
        }
    }
    
    // MARK: - Comparison Processing
    
    func performComparison() async {
        guard let p1 = player1, let p2 = player2 else {
            errorMessage = "Please select both players to compare"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Prepare both players
            async let prep1 = prepareComparisonPlayer(p1)
            async let prep2 = prepareComparisonPlayer(p2)
            
            let (comp1, comp2) = try await (prep1, prep2)
            
            comparisonPlayer1 = comp1
            comparisonPlayer2 = comp2
            
            // Generate recommendation
            recommendation = generateRecommendation(player1: comp1, player2: comp2)
            
        } catch {
            errorMessage = "Failed to prepare comparison: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Player Preparation
    
    private func prepareComparisonPlayer(_ player: SleeperPlayer) async throws -> ComparisonPlayer {
        // Get projected points from Sleeper matchups (if available)
        let projectedPoints = await getProjectedPoints(for: player)
        
        // Get recent form (last 3 games)
        let recentForm = await getRecentForm(for: player)
        
        // Get matchup info
        let matchupInfo = getMatchupInfo(for: player)
        
        // Get injury status
        let injuryStatus = InjuryStatus(from: player)
        
        // NEW: Get QB quality tier (for receivers and RBs)
        let (qbTier, qbStats, qbName) = getQBQualityTier(for: player)
        
        // NEW: Calculate TD scoring tier
        let tdTier = getTDScoringTier(for: player)
        
        // NEW: Get average TDs per game
        let avgTDsPerGame = getAverageTDsPerGame(for: player, projectedPoints: projectedPoints, recentStats: recentForm?.lastThreeGames)
        
        // NEW: Determine injury severity
        let injurySeverity = getInjurySeverity(from: player, injuryStatus: injuryStatus)
        
        // NEW: Determine depth chart tier
        let depthTier = getDepthChartTier(for: player)
        
        // NEW: Calculate efficiency trend
        let efficiencyTrend = getEfficiencyTrend(for: player, recentForm: recentForm)
        
        // NEW: Get catch rate and usage metrics
        let catchRate = getCatchRatePercentage(for: player)
        let yardsPerCarry = getYardsPerCarry(for: player)
        let usagePercentage = getUsagePercentage(for: player)
        
        return ComparisonPlayer(
            id: player.playerID,
            sleeperPlayer: player,
            projectedPoints: projectedPoints,
            recentForm: recentForm,
            matchupInfo: matchupInfo,
            injuryStatus: injuryStatus,
            qbQualityTier: qbTier,
            qbTeamStats: qbStats,
            qbPasserRating: qbStats?.passerRating,
            qbName: qbName,
            tdScoringTier: tdTier,
            avgTDsPerGame: avgTDsPerGame,
            injurySeverity: injurySeverity,
            depthChartTier: depthTier,
            depthChartPosition: player.depthChartOrder,
            efficiencyTrend: efficiencyTrend,
            catchRatePercentage: catchRate,
            yardsPerCarry: yardsPerCarry,
            usagePercentage: usagePercentage
        )
    }
    
    // MARK: - Data Fetching
    
    private func getProjectedPoints(for player: SleeperPlayer) async -> Double? {
        // Try to get projected points from user's matchups
        // This is a simplified approach - could be enhanced with league integration
        let _ = player.playerID // For future use when integrating with league matchups
        
        // For MVP, we'll use a simple heuristic:
        // If we have recent stats, use average + slight projection
        if let recentForm = await getRecentForm(for: player) {
            return recentForm.averagePoints * 1.05 // 5% boost for projection
        }
        
        // Fallback: Could query Sleeper matchups if we had league context
        // For now, return nil and let UI show "No projection available"
        return nil
    }
    
    private func getRecentForm(for player: SleeperPlayer) async -> RecentForm? {
        let playerID = player.playerID
        
        // Get last 3 weeks of stats
        var gameScores: [Double] = []
        let year = currentYear
        
        // Load stats for last 3 weeks
        for weekOffset in 1...3 {
            let week = max(1, currentWeek - weekOffset)
            
            // Try cache first
            if let cachedStats = PlayerStatsCache.shared.getPlayerStats(playerID: playerID, week: week) {
                if let points = extractPoints(from: cachedStats) {
                    gameScores.append(points)
                }
            } else {
                // Fetch from API
                do {
                    let stats = try await statsService.loadWeekStats(week: week, year: year)
                    if let playerStats = stats[playerID],
                       let points = extractPoints(from: playerStats) {
                        gameScores.append(points)
                    }
                } catch {
                    // Continue to next week if this one fails
                    continue
                }
            }
        }
        
        guard !gameScores.isEmpty else { return nil }
        
        // Reverse to get chronological order (oldest to newest)
        gameScores.reverse()
        
        let average = gameScores.reduce(0, +) / Double(gameScores.count)
        let trend = RecentForm.calculate(from: gameScores)
        
        return RecentForm(
            averagePoints: average,
            lastThreeGames: gameScores,
            trend: trend
        )
    }
    
    private func extractPoints(from stats: [String: Double]) -> Double? {
        // Priority: PPR > Half-PPR > Standard
        return stats["pts_ppr"] ?? stats["pts_half_ppr"] ?? stats["pts_std"]
    }
    
    private func getMatchupInfo(for player: SleeperPlayer) -> MatchupInfo? {
        guard let team = player.team else { return nil }
        
        // Get game info from NFLGameDataService
        if let gameInfo = nflGameService.getGameInfo(for: team) {
            // Derive opponent and home status from game info
            let opponent: String?
            let isHome: Bool
            
            if team == gameInfo.homeTeam {
                opponent = gameInfo.awayTeam
                isHome = true
            } else if team == gameInfo.awayTeam {
                opponent = gameInfo.homeTeam
                isHome = false
            } else {
                // Team not found in game - shouldn't happen but handle gracefully
                return nil
            }
            
            // Format game time
            let gameTime: String? = {
                if let time = gameInfo.startDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    return formatter.string(from: time)
                }
                return nil
            }()
            
            return MatchupInfo(
                opponent: opponent,
                isHome: isHome,
                gameTime: gameTime
            )
        }
        
        return nil
    }
    
    // MARK: - Recommendation Generation
    
    private func generateRecommendation(
        player1: ComparisonPlayer,
        player2: ComparisonPlayer
    ) -> ComparisonRecommendation {
        
        var reasons: [String] = []
        var player1Score = 0.0
        var player2Score = 0.0
        
        // ====== SCORING BREAKDOWN (out of 100) ======
        
        // Factor 1: Projected Points (40% weight - 40 pts) - INCREASED from 30%
        let projWeight = 0.40
        let proj1 = (player1.projectedPoints ?? 0) * projWeight
        let proj2 = (player2.projectedPoints ?? 0) * projWeight
        player1Score += proj1
        player2Score += proj2
        
        if let p1 = player1.projectedPoints, let p2 = player2.projectedPoints {
            if abs(p1 - p2) > 2.0 {
                let leader = p1 > p2 ? player1.fullName : player2.fullName
                let difference = abs(p1 - p2)
                reasons.append("📊 \(leader) projects \(difference.fantasyPointsString) pts higher")
            }
        }
        
        // Factor 2: Recent Form (25% weight - 25 pts) - INCREASED from 20%
        let formWeight = 0.25
        if let form1 = player1.recentForm {
            let formScore = form1.averagePoints * formWeight
            player1Score += formScore
            
            if form1.trend == .trendingUp {
                reasons.append("📈 \(player1.fullName) trending up (\(form1.averagePoints.fantasyPointsString) avg)")
                player1Score += 2.0  // Bonus for uptrend
            } else if form1.trend == .trendingDown {
                player2Score += 2.0  // Bonus to other player if this one trending down
                reasons.append("📉 \(player1.fullName) trending down")
            }
        }
        
        if let form2 = player2.recentForm {
            let formScore = form2.averagePoints * formWeight
            player2Score += formScore
            
            if form2.trend == .trendingUp {
                reasons.append("📈 \(player2.fullName) trending up (\(form2.averagePoints.fantasyPointsString) avg)")
                player2Score += 2.0
            } else if form2.trend == .trendingDown {
                player1Score += 2.0
                reasons.append("📉 \(player2.fullName) trending down")
            }
        }
        
        // Factor 3: TD Scoring Potential (12% weight - 12 pts) - DECREASED from 15%
        let tdWeight = 0.12
        let td1Score = scoreTDTier(player1.tdScoringTier) * tdWeight
        let td2Score = scoreTDTier(player2.tdScoringTier) * tdWeight
        player1Score += td1Score
        player2Score += td2Score
        
        if player1.tdScoringTier != player2.tdScoringTier {
            let td1emoji = player1.tdScoringTier == "High TD Potential" ? "🔥" : "⚡"
            let td2emoji = player2.tdScoringTier == "High TD Potential" ? "🔥" : "⚡"
            reasons.append("\(td1emoji) \(player1.fullName): \(player1.tdScoringTier) | \(td2emoji) \(player2.fullName): \(player2.tdScoringTier)")
        }
        
        // Factor 4: Depth Chart Position (5% weight - 5 pts) - DECREASED from 10%
        let depthWeight = 0.05
        let depth1Score = scoreDepthTier(player1.depthChartTier) * depthWeight
        let depth2Score = scoreDepthTier(player2.depthChartTier) * depthWeight
        player1Score += depth1Score
        player2Score += depth2Score
        
        if player1.depthChartTier != player2.depthChartTier {
            reasons.append("📋 Depth: \(player1.fullName) (\(player1.depthChartTier)) vs \(player2.fullName) (\(player2.depthChartTier))")
        }
        
        // Factor 5: QB Quality (for WR/TE/RB only - 10% weight)
        let qbWeight = 0.10
        if ["WR", "TE", "RB"].contains(player1.position.uppercased()) {
            let qb1Score = scoreQBTier(player1.qbQualityTier) * qbWeight
            let qb2Score = scoreQBTier(player2.qbQualityTier) * qbWeight
            player1Score += qb1Score
            player2Score += qb2Score
        }
        
        // Factor 6: Injury Status (12% weight - 12 pts)
        let injuryWeight = 0.12
        let injury1Penalty = getInjuryPenalty(player1.injurySeverity)
        let injury2Penalty = getInjuryPenalty(player2.injurySeverity)
        player1Score -= injury1Penalty * injuryWeight * 12.0
        player2Score -= injury2Penalty * injuryWeight * 12.0
        
        if player1.injurySeverity != "Healthy" {
            reasons.append("⚠️ \(player1.fullName): \(player1.injurySeverity)")
        }
        if player2.injurySeverity != "Healthy" {
            reasons.append("⚠️ \(player2.fullName): \(player2.injurySeverity)")
        }
        
        // Factor 7: OPRK / Matchup Advantage (8% weight - 8 pts) 🔥 NEW!
        let oprkWeight = 0.08
        let oprk1Score = getOPRKScore(for: player1) * oprkWeight
        let oprk2Score = getOPRKScore(for: player2) * oprkWeight
        player1Score += oprk1Score
        player2Score += oprk2Score
        
        // Add OPRK reasoning
        if let team1 = player1.sleeperPlayer.team,
           let matchup1 = player1.matchupInfo, let opp1 = matchup1.opponent {
            let pos1 = player1.position
            let advantage1 = OPRKService.shared.getMatchupAdvantage(forOpponent: opp1, position: pos1)
            let oprk1 = OPRKService.shared.getOPRK(forTeam: opp1, position: pos1)
            
            if let rank = oprk1 {
                let advantageEmoji = getOPRKEmoji(advantage1)
                let advantageText = getOPRKText(advantage1)
                reasons.append("\(advantageEmoji) \(player1.fullName) vs \(opp1): \(advantageText) (OPRK: \(rank))")
            }
        }
        
        if let team2 = player2.sleeperPlayer.team,
           let matchup2 = player2.matchupInfo, let opp2 = matchup2.opponent {
            let pos2 = player2.position
            let advantage2 = OPRKService.shared.getMatchupAdvantage(forOpponent: opp2, position: pos2)
            let oprk2 = OPRKService.shared.getOPRK(forTeam: opp2, position: pos2)
            
            if let rank = oprk2 {
                let advantageEmoji = getOPRKEmoji(advantage2)
                let advantageText = getOPRKText(advantage2)
                reasons.append("\(advantageEmoji) \(player2.fullName) vs \(opp2): \(advantageText) (OPRK: \(rank))")
            }
        }
        
        // Add QB information for non-QB players
        if !player1.position.uppercased().contains("QB") {
            let qb1Name = player1.qbName ?? "Unknown QB"
            let qb1Tier = player1.qbQualityTier ?? "Unknown"
            reasons.append("🏈 \(player1.fullName) QB: \(qb1Name) (\(qb1Tier))")
        }
        if !player2.position.uppercased().contains("QB") {
            let qb2Name = player2.qbName ?? "Unknown QB"
            let qb2Tier = player2.qbQualityTier ?? "Unknown"
            reasons.append("🏈 \(player2.fullName) QB: \(qb2Name) (\(qb2Tier))")
        }
        
        // Clamp scores to 0-100
        player1Score = max(0, min(100, player1Score))
        player2Score = max(0, min(100, player2Score))
        
        // Determine winner
        let (winner, loser) = player1Score >= player2Score ?
            (player1, player2) :
            (player2, player1)
        
        let projectedDiff = abs((player1.projectedPoints ?? 0) - (player2.projectedPoints ?? 0))
        
        // Calculate grades based on winner/loser scores
        let winnerFinalScore = player1Score >= player2Score ? player1Score : player2Score
        let loserFinalScore = player1Score >= player2Score ? player2Score : player1Score
        
        let winnerGrade = calculateGrade(score: winnerFinalScore, projectedPoints: winner.projectedPoints)
        let loserGrade = calculateGrade(score: loserFinalScore, projectedPoints: loser.projectedPoints)
        
        // Determine confidence
        let scoreDiff = abs(player1Score - player2Score)
        let confidence: ComparisonRecommendation.ConfidenceLevel = {
            if scoreDiff > 8.0 || projectedDiff > 5.0 {
                return .high
            } else if scoreDiff > 3.0 || projectedDiff > 2.0 {
                return .medium
            } else {
                return .low
            }
        }()
        
        // Add summary line
        if scoreDiff <= 2.0 {
            reasons.append("🤝 This is a close call - use your gut!")
        }
        
        return ComparisonRecommendation(
            winner: winner,
            loser: loser,
            winnerGrade: winnerGrade,
            loserGrade: loserGrade,
            scoreDifference: projectedDiff,
            winnerScore: player1Score >= player2Score ? player1Score : player2Score,
            loserScore: player1Score >= player2Score ? player2Score : player1Score,
            reasoning: reasons,
            confidence: confidence
        )
    }
    
    // MARK: - Scoring Helpers for Enhanced Metrics
    
    private func scoreTDTier(_ tier: String) -> Double {
        switch tier {
        case "High TD Potential": return 15.0
        case "Moderate": return 10.0
        case "Low TD Potential": return 5.0
        default: return 8.0
        }
    }
    
    private func scoreDepthTier(_ tier: String) -> Double {
        switch tier {
        case "Starter": return 10.0
        case "Backup": return 6.0
        default: return 2.0
        }
    }
    
    private func scoreQBTier(_ tier: String?) -> Double {
        guard let tier = tier else { return 5.0 }
        switch tier {
        case "Elite": return 10.0
        case "Solid": return 8.0
        case "Good": return 5.0
        case "Weak": return 2.0
        default: return 5.0
        }
    }
    
    private func getInjuryPenalty(_ severity: String) -> Double {
        switch severity {
        case "Healthy": return 0.0
        case "Minor Risk": return 0.5
        case "Moderate Risk": return 1.0
        case "High Risk": return 2.0
        default: return 0.5
        }
    }
    
    private func calculateGrade(
        score: Double,
        projectedPoints: Double?
    ) -> ComparisonRecommendation.LetterGrade {
        // Use projected points if available, otherwise use score
        let value = projectedPoints ?? score
        
        switch value {
        case 20...: return .aPlus
        case 18..<20: return .a
        case 16..<18: return .aMinus
        case 14..<16: return .bPlus
        case 12..<14: return .b
        case 10..<12: return .bMinus
        case 8..<10: return .cPlus
        case 6..<8: return .c
        case 4..<6: return .cMinus
        case 2..<4: return .d
        default: return .f
        }
    }
    
    // MARK: - NEW: Enhanced Metrics Helpers
    
    private func getQBQualityTier(for player: SleeperPlayer) -> (tier: String?, stats: (passTDs: Int?, passYards: Int?, passerRating: Double?)?, qbName: String?) {
        guard let position = player.position?.uppercased() else {
            return (nil, nil, nil)
        }
        
        
        // If this IS a QB, try to calculate their own passer rating
        if position == "QB" {
            // Try to get stats from store first
            if let stats = PlayerStatsStore.shared.stats(for: player.playerID) {
                let passTDs = stats.passTDs ?? 0
                let passYards = stats.passYards ?? 0
                let passAttempts = stats.passAttempts ?? 1
                let passCompletions = stats.passCompletions ?? 0
                let interceptions = stats.interceptions ?? 0
                
                let passerRating = calculatePasserRating(
                    completions: passCompletions,
                    attempts: passAttempts,
                    yards: passYards,
                    touchdowns: passTDs,
                    interceptions: interceptions
                )
                
                
                let tier: String
                switch passerRating {
                case 120...: tier = "Elite"
                case 105..<120: tier = "Solid"
                case 85..<105: tier = "Good"
                default: tier = "Weak"
                }
                
                return (tier, (passTDs: passTDs, passYards: passYards, passerRating: passerRating), player.fullName)
            } else {
                // Use tier map for QB without stats
            }
        }
        
        // For non-QBs, get their team's QB
        guard ["WR", "TE", "RB"].contains(position) else {
            return (nil, nil, nil)
        }
        
        // Get QB for this player's team
        guard let team = player.team else { return ("Good", nil, nil) }
        let roster = NFLTeamRosterService.shared.getTeamRoster(for: team)
        guard let qb = roster.quarterbacks.first else { 
            return ("Good", nil, nil) 
        }
        
        
        // Use tier map of known QBs to provide reasonable estimates
        let knownQBTiers: [String: String] = [
            // Elite QBs (30+ TDs, 120+ rating)
            "Josh Allen": "Elite", "Patrick Mahomes": "Elite", "Jared Goff": "Elite",
            "Lamar Jackson": "Elite", "Dak Prescott": "Elite", "Joe Burrow": "Elite",

            // Solid QBs (25-29 TDs, 105-119 rating)
            "Brock Purdy": "Solid", "Justin Herbert": "Solid", "Michael Penix": "Good",
             "Baker Mayfield": "Solid", "Daniel Jones": "Solid", "Drake Maye": "Solid",

            // Good QBs (20-24 TDs, 85-104 rating)
            "Will Levis": "Good", "Bryce Young": "Good", "Tua Tagovailoa": "Good",
            "Aaron Rodgers": "Solid", "Sam Darnold": "Good", "Anthony Richardson": "Good", "Kirk Cousins": "Bad"]

        let tier = knownQBTiers[qb.fullName] ?? "Good"
        
        // For non-QBs, return the tier and the QB's name
        return (tier, nil, qb.fullName)
    }
    
    private func calculatePasserRating(completions: Int, attempts: Int, yards: Int, touchdowns: Int, interceptions: Int) -> Double {
        guard attempts > 0 else { return 0.0 }
        
        let a = attempts
        let c = Double(completions)
        let y = Double(yards)
        let t = Double(touchdowns)
        let i = Double(interceptions)
        let att = Double(a)
        
        // NFL Passer Rating Formula:
        // ((C/A) * 100 - 30) * 0.05 + ((Y/A) - 3) * 0.25 + (T/A) * 20 + 2.375 - (I/A) * 25
        
        let comp = max(0, min(2.375, ((c / att) * 100 - 30) * 0.05))
        let yard = max(0, min(2.375, ((y / att) - 3) * 0.25))
        let td = max(0, min(2.375, (t / att) * 20))
        let inter = max(0, min(2.375, (i / att) * 25))
        
        let rating = ((comp + yard + td + 2.375 - inter) / 6.0) * 100.0
        return min(158.3, max(0, rating)) // Cap at 158.3 (perfect rating)
    }
    
    private func getTDScoringTier(for player: SleeperPlayer) -> String {
        guard let position = player.position?.uppercased() else { return "Moderate" }
        guard let stats = PlayerStatsStore.shared.stats(for: player.playerID) else {
            // Return default tier based on position instead of "Unknown"
            return "Moderate"
        }
        
        switch position {
        case "RB":
            let rushTDs = stats.rushTDs ?? 0
            let recTDs = stats.recTDs ?? 0
            let totalTDs = rushTDs + recTDs
            switch totalTDs {
            case 10...: return "High TD Potential"
            case 5..<10: return "Moderate"
            default: return "Low TD Potential"
            }
        case "WR", "TE":
            let recTDs = stats.recTDs ?? 0
            switch recTDs {
            case 8...: return "High TD Potential"
            case 4..<8: return "Moderate"
            default: return "Low TD Potential"
            }
        case "QB":
            let passTDs = stats.passTDs ?? 0
            switch passTDs {
            case 25...: return "High TD Potential"
            case 15..<25: return "Moderate"
            default: return "Low TD Potential"
            }
        default:
            return "Moderate"
        }
    }
    
    private func getAverageTDsPerGame(for player: SleeperPlayer, projectedPoints: Double?, recentStats: [Double]?) -> Double? {
        guard let stats = PlayerStatsStore.shared.stats(for: player.playerID),
              let gamesPlayed = stats.gamesPlayed, gamesPlayed > 0 else {
            // Fallback: Get actual TDs from last 3 weeks if available
            return getActualTDsFromRecentWeeks(for: player)
        }
        
        guard let position = player.position?.uppercased() else { return nil }
        
        let totalTDs: Int?
        switch position {
        case "RB":
            totalTDs = (stats.rushTDs ?? 0) + (stats.recTDs ?? 0)
        case "WR", "TE":
            totalTDs = stats.recTDs ?? 0
        case "QB":
            totalTDs = stats.passTDs ?? 0
        default:
            return nil
        }
        
        guard let tds = totalTDs else { return nil }
        return Double(tds) / Double(gamesPlayed)
    }
    
    private func getActualTDsFromRecentWeeks(for player: SleeperPlayer) -> Double? {
        // Extract TD data from the last 3 weeks if available
        var totalTDs = 0
        var gamesWithData = 0
        let position = player.position?.uppercased() ?? "UNK"
        
        // Load stats for last 3 weeks
        for weekOffset in 1...3 {
            let week = max(1, currentWeek - weekOffset)
            
            // Try cache first
            if let cachedStats = PlayerStatsCache.shared.getPlayerStats(playerID: player.playerID, week: week) {
                // Extract TDs based on position
                let weekTDs: Int
                switch position {
                case "RB":
                    let rushTDs = Int(cachedStats["rush_td"] ?? 0)
                    let recTDs = Int(cachedStats["rec_td"] ?? 0)
                    weekTDs = rushTDs + recTDs
                case "WR", "TE":
                    weekTDs = Int(cachedStats["rec_td"] ?? 0)
                case "QB":
                    weekTDs = Int(cachedStats["pass_td"] ?? 0)
                default:
                    weekTDs = 0
                }
                
                if weekTDs >= 0 {
                    totalTDs += weekTDs
                    gamesWithData += 1
                }
            }
        }
        
        guard gamesWithData > 0 else { return nil }
        return Double(totalTDs) / Double(gamesWithData)
    }
    
    private func getInjurySeverity(from player: SleeperPlayer, injuryStatus: InjuryStatus) -> String {
        guard !injuryStatus.isHealthy else { return "Healthy" }
        
        let status = (player.injuryStatus ?? "").lowercased()
        
        // If no injury status at all, return Low Risk
        if status.isEmpty {
            return "Low Risk"
        }
        
        if status.contains("out") {
            return "High Risk"
        } else if status.contains("doubtful") {
            return "Moderate Risk"
        } else if status.contains("questionable") {
            return "Minor Risk"
        } else if status.contains("probable") {
            return "Minor Risk"
        }
        
        return "Low Risk"
    }
    
    private func getDepthChartTier(for player: SleeperPlayer) -> String {
        guard let depthOrder = player.depthChartOrder else { return "Unknown" }
        
        switch depthOrder {
        case 1: return "Starter"
        case 2: return "Backup"
        default: return "Deep Bench"
        }
    }
    
    private func getEfficiencyTrend(for player: SleeperPlayer, recentForm: RecentForm?) -> String {
        guard let recentForm = recentForm else { return "Stable →" }
        
        switch recentForm.trend {
        case .trendingUp: return "Improving ↗️"
        case .trendingDown: return "Declining ↘️"
        case .stable: return "Stable →"
        }
    }
    
    private func getCatchRatePercentage(for player: SleeperPlayer) -> Double? {
        guard let stats = PlayerStatsStore.shared.stats(for: player.playerID) else { return nil }
        return stats.catchRate
    }
    
    private func getYardsPerCarry(for player: SleeperPlayer) -> Double? {
        guard let stats = PlayerStatsStore.shared.stats(for: player.playerID) else { return nil }
        return stats.yardsPerCarry
    }
    
    private func getUsagePercentage(for player: SleeperPlayer) -> Double? {
        // For now, use catch rate as proxy for usage
        // In future, could calculate actual target share from team context
        guard let stats = PlayerStatsStore.shared.stats(for: player.playerID),
              let targets = stats.targets, targets > 0 else {
            return nil
        }
        
        // Simple estimation: targets / season targets for that team
        // This would need team context to be precise
        return nil  // TODO: implement when we have team target context
    }
    
    // MARK: - OPRK Helpers
    
    private func getOPRKScore(for player: ComparisonPlayer) -> Double {
        guard let team = player.sleeperPlayer.team,
              let matchupInfo = player.matchupInfo,
              let opponent = matchupInfo.opponent else {
            return 5.0 // Neutral score
        }
        
        let position = player.position
        let advantage = OPRKService.shared.getMatchupAdvantage(forOpponent: opponent, position: position)
        
        switch advantage {
        case .elite:      return 10.0  // Best matchup (weakest defense)
        case .favorable:  return 7.5   // Good matchup
        case .neutral:    return 5.0   // Average matchup
        case .difficult:  return 2.5   // Tough matchup (strong defense)
        }
    }
    
    private func getOPRKEmoji(_ advantage: MatchupAdvantage) -> String {
        switch advantage {
        case .elite:      return "🟢"  // Green circle (best)
        case .favorable:  return "🟡"  // Yellow circle (good)
        case .neutral:    return "⚪"  // White circle (neutral)
        case .difficult:  return "🔴"  // Red circle (tough)
        }
    }
    
    private func getOPRKText(_ advantage: MatchupAdvantage) -> String {
        switch advantage {
        case .elite:      return "Elite Matchup"
        case .favorable:  return "Favorable"
        case .neutral:    return "Neutral"
        case .difficult:  return "Difficult"
        }
    }
}