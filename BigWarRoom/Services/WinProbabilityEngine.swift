//
//  WinProbabilityEngine.swift
//  BigWarRoom
//
//  🎯 SSOT: Single Source of Truth for win probability calculations
//  Used by: Matchup Detail, Matchup Cards, Live Players Cards, etc.
//

import Foundation
import SwiftUI

/// Centralized win probability calculation engine
/// Uses statistical model based on normal distribution
@MainActor
final class WinProbabilityEngine {
    
    // MARK: - Singleton
    static let shared = WinProbabilityEngine()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Standard deviation for win probability calculation
    /// Adjustable via Settings - lower = more aggressive (big leads = high %), higher = more conservative
    @AppStorage("WinProbabilitySD") private var winProbabilitySD: Double = 40.0
    
    // MARK: - Public API
    
    /// Calculate win probability based on score differential
    /// - Parameters:
    ///   - myScore: My team's score (current or projected)
    ///   - opponentScore: Opponent's score (current or projected)
    /// - Returns: Win probability as Double (0.0 to 1.0), clamped to 0.05-0.95
    func calculateWinProbability(myScore: Double, opponentScore: Double) -> Double {
        let total = myScore + opponentScore
        guard total > 0 else { return 0.5 }
        
        // Lead/deficit in points
        let lead = myScore - opponentScore
        
        // Statistical model: Combined SD for two teams
        let combinedSD = winProbabilitySD * sqrt(2.0)
        
        // Z-score: how many standard deviations is the lead?
        let zScore = lead / combinedSD
        
        // Convert Z-score to probability using normal CDF
        let winProbability = normalCDF(zScore)
        
        // Clamp to reasonable bounds (never show 0% or 100%)
        return min(max(winProbability, 0.05), 0.95)
    }
    
    /// Calculate win probability and return as percentage integer (0-100)
    func calculateWinPercentage(myScore: Double, opponentScore: Double) -> Int {
        return Int(calculateWinProbability(myScore: myScore, opponentScore: opponentScore) * 100)
    }
    
    /// Calculate win probability for a fantasy matchup
    /// 🔥 ENHANCED: Now handles deterministic outcomes (0 players left = 100%/0%)
    func calculateWinProbability(for matchup: FantasyMatchup, isHomeTeam: Bool, gameStatusService: GameStatusService) -> Double {
        let myTeam = isHomeTeam ? matchup.homeTeam : matchup.awayTeam
        let oppTeam = isHomeTeam ? matchup.awayTeam : matchup.homeTeam
        let myScore = myTeam.currentScore ?? 0
        let oppScore = oppTeam.currentScore ?? 0
        
        // 🔥 NEW: Check players yet to play using GameStatusService
        let myYetToPlay = myTeam.playersYetToPlay(gameStatusService: gameStatusService)
        let oppYetToPlay = oppTeam.playersYetToPlay(gameStatusService: gameStatusService)
        
        // CASE 1: Both teams done playing - DETERMINISTIC
        if myYetToPlay == 0 && oppYetToPlay == 0 {
            if myScore > oppScore {
                return 1.0  // 100% win
            } else if myScore < oppScore {
                return 0.0  // 0% win (100% loss)
            } else {
                return 0.5  // Tie
            }
        }
        
        // CASE 2: I'm done, opponent has players left
        if myYetToPlay == 0 && oppYetToPlay > 0 {
            // Calculate if opponent can catch up
            // Conservative estimate: 25 points per remaining player (reasonable max)
            let oppMaxPossible = oppScore + (Double(oppYetToPlay) * 25.0)
            if myScore >= oppMaxPossible {
                return 1.0  // I've already won (opponent mathematically eliminated)
            }
            // Otherwise calculate probability with opponent's upside
        }
        
        // CASE 3: Opponent done, I have players left
        if myYetToPlay > 0 && oppYetToPlay == 0 {
            if myScore > oppScore {
                return 1.0  // I've already won (ahead with no chance of opponent scoring)
            }
            // If behind, calculate comeback probability
            let myMaxPossible = myScore + (Double(myYetToPlay) * 25.0)
            if myMaxPossible < oppScore {
                return 0.0  // Mathematically eliminated
            }
        }
        
        // CASE 4: Both teams have players left - use statistical model
        return calculateWinProbability(myScore: myScore, opponentScore: oppScore)
    }
    
    /// 🔥 DEPRECATED: Old method without game status - kept for backward compatibility
    /// Use the version with gameStatusService parameter for accurate results
    func calculateWinProbability(for matchup: FantasyMatchup, isHomeTeam: Bool) -> Double {
        // Fallback to statistical calculation without deterministic check
        let myScore = isHomeTeam ? matchup.homeTeam.currentScore ?? 0 : matchup.awayTeam.currentScore ?? 0
        let oppScore = isHomeTeam ? matchup.awayTeam.currentScore ?? 0 : matchup.homeTeam.currentScore ?? 0
        return calculateWinProbability(myScore: myScore, opponentScore: oppScore)
    }
    
    /// Calculate win probability for a unified matchup
    func calculateWinProbability(for matchup: UnifiedMatchup) -> Double? {
        guard !matchup.isChoppedLeague,
              let myScore = matchup.myTeam?.currentScore,
              let oppScore = matchup.opponentTeam?.currentScore else {
            return nil
        }
        return calculateWinProbability(myScore: myScore, opponentScore: oppScore)
    }
    
    // MARK: - Statistical Functions
    
    /// Approximation of the standard normal cumulative distribution function
    /// Uses the Abramowitz and Stegun approximation (accurate to ~1.5×10⁻⁷)
    private func normalCDF(_ x: Double) -> Double {
        // Handle extreme values
        if x < -8.0 { return 0.0 }
        if x > 8.0 { return 1.0 }
        
        // Constants for Abramowitz and Stegun formula 7.1.26
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911
        
        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x)
        
        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX / 2.0)
        
        return 0.5 * (1.0 + sign * y)
    }
}