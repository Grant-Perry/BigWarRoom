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
    private let nflGameService = NFLGameDataService.shared
    
    // MARK: - Current Week
    var currentWeek: Int {
        WeekSelectionManager.shared.selectedWeek
    }
    
    var currentYear: String {
        AppConstants.currentSeasonYear
    }
    
    // MARK: - Player Selection
    
    func selectPlayer1(_ player: SleeperPlayer) {
        player1 = player
        player2 = nil // Reset player 2 when player 1 changes
        comparisonPlayer1 = nil
        comparisonPlayer2 = nil
        recommendation = nil
    }
    
    func selectPlayer2(_ player: SleeperPlayer) {
        player2 = player
        comparisonPlayer2 = nil
        recommendation = nil
    }
    
    func clearPlayer1() {
        player1 = nil
        comparisonPlayer1 = nil
        // Don't clear recommendation - let player 2 stay if they exist
    }
    
    func clearPlayer2() {
        player2 = nil
        comparisonPlayer2 = nil
        // Don't clear recommendation - let player 1 stay if they exist
    }
    
    func clearBoth() {
        player1 = nil
        player2 = nil
        comparisonPlayer1 = nil
        comparisonPlayer2 = nil
        recommendation = nil
        errorMessage = nil
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
            print("❌ PlayerComparison: Error - \(error)")
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
        
        return ComparisonPlayer(
            id: player.playerID,
            sleeperPlayer: player,
            projectedPoints: projectedPoints,
            recentForm: recentForm,
            matchupInfo: matchupInfo,
            injuryStatus: injuryStatus
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
        
        // Factor 1: Projected Points (40% weight)
        let projWeight = 0.40
        let proj1 = (player1.projectedPoints ?? 0) * projWeight
        let proj2 = (player2.projectedPoints ?? 0) * projWeight
        player1Score += proj1
        player2Score += proj2
        
        if let p1 = player1.projectedPoints, let p2 = player2.projectedPoints {
            if abs(p1 - p2) > 2.0 {
                reasons.append(p1 > p2 ?
                    "\(player1.fullName) projects \(p1.fantasyPointsString) pts vs \(p2.fantasyPointsString) pts" :
                    "\(player2.fullName) projects \(p2.fantasyPointsString) pts vs \(p1.fantasyPointsString) pts")
            }
        }
        
        // Factor 2: Matchup Difficulty (25% weight) - simplified for MVP
        let matchupWeight = 0.25
        // TODO: Add actual defensive rankings lookup
        // For now, we'll give a neutral score
        player1Score += 10.0 * matchupWeight // Neutral
        player2Score += 10.0 * matchupWeight
        
        // Factor 3: Recent Form (20% weight)
        let formWeight = 0.20
        if let form1 = player1.recentForm {
            player1Score += form1.averagePoints * formWeight
            reasons.append("\(player1.fullName) averaging \(form1.averagePoints.fantasyPointsString) pts recently")
            if form1.trend == .trendingUp {
                reasons.append("\(player1.fullName) trending up")
            }
        }
        
        if let form2 = player2.recentForm {
            player2Score += form2.averagePoints * formWeight
            reasons.append("\(player2.fullName) averaging \(form2.averagePoints.fantasyPointsString) pts recently")
            if form2.trend == .trendingUp {
                reasons.append("\(player2.fullName) trending up")
            }
        }
        
        // Factor 4: Injury Status (10% weight)
        let injuryWeight = 0.10
        if player1.injuryStatus.isHealthy {
            player1Score += 15.0 * injuryWeight
        } else {
            player1Score += 5.0 * injuryWeight
            reasons.append("⚠️ \(player1.fullName) has injury status: \(player1.injuryStatus.description)")
        }
        
        if player2.injuryStatus.isHealthy {
            player2Score += 15.0 * injuryWeight
        } else {
            player2Score += 5.0 * injuryWeight
            reasons.append("⚠️ \(player2.fullName) has injury status: \(player2.injuryStatus.description)")
        }
        
        // Determine winner
        let (winner, loser) = player1Score >= player2Score ?
            (player1, player2) :
            (player2, player1)
        
        let projectedDiff = abs((player1.projectedPoints ?? 0) - (player2.projectedPoints ?? 0))
        
        // Calculate grades
        let winnerGrade = calculateGrade(score: player1Score >= player2Score ? player1Score : player2Score, projectedPoints: winner.projectedPoints)
        let loserGrade = calculateGrade(score: player1Score >= player2Score ? player2Score : player1Score, projectedPoints: loser.projectedPoints)
        
        // Determine confidence
        let scoreDiff = abs(player1Score - player2Score)
        let confidence: ComparisonRecommendation.ConfidenceLevel = {
            if scoreDiff > 5.0 || projectedDiff > 5.0 {
                return .high
            } else if scoreDiff > 2.0 || projectedDiff > 2.0 {
                return .medium
            } else {
                return .low
            }
        }()
        
        return ComparisonRecommendation(
            winner: winner,
            loser: loser,
            winnerGrade: winnerGrade,
            loserGrade: loserGrade,
            scoreDifference: projectedDiff,
            reasoning: reasons,
            confidence: confidence
        )
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
}

