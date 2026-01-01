//
//  PlayerStatisticsService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Pure business logic for player statistics
//  Extracted from AllLivePlayersViewModel to follow MVVM pattern
//

import Foundation

/// Service responsible for statistical calculations on player data
/// - Pure business logic, no UI state
/// - Stateless and testable
/// - Single Responsibility: Calculate quartiles, percentages, performance tiers
final class PlayerStatisticsService {
    
    // MARK: - Singleton (stateless service)
    static let shared = PlayerStatisticsService()
    private init() {}
    
    // MARK: - Statistical Calculations
    
    /// Calculate quartiles from sorted scores (Q1, Q2/median, Q3)
    func calculateQuartiles(from sortedScores: [Double]) -> (q1: Double, q2: Double, q3: Double) {
        guard !sortedScores.isEmpty else { return (0, 0, 0) }
        
        let count = sortedScores.count
        let q1Index = count / 4
        let q2Index = count / 2
        let q3Index = (3 * count) / 4
        
        let q1 = q1Index < count ? sortedScores[q1Index] : sortedScores.last!
        let q2 = q2Index < count ? sortedScores[q2Index] : sortedScores.last!
        let q3 = q3Index < count ? sortedScores[q3Index] : sortedScores.last!
        
        return (q1, q2, q3)
    }
    
    /// Calculate scaled percentage for progress bars
    /// - Uses adaptive (logarithmic) scaling for extreme score distributions
    /// - Uses linear scaling for normal distributions
    func calculateScaledPercentage(
        score: Double,
        topScore: Double,
        useAdaptiveScaling: Bool
    ) -> Double {
        guard topScore > 0 else { return 0.0 }
        
        if useAdaptiveScaling {
            // Logarithmic scaling for extreme distributions
            let logTop = log(max(topScore, 1.0))
            let logScore = log(max(score, 1.0))
            return logScore / logTop
        } else {
            // Standard linear scaling
            return score / topScore
        }
    }
    
    /// Determine performance tier based on quartile position
    func determinePerformanceTier(
        score: Double,
        quartiles: (q1: Double, q2: Double, q3: Double)
    ) -> AllLivePlayersViewModel.PerformanceTier {
        if score >= quartiles.q3 {
            return .elite
        } else if score >= quartiles.q2 {
            return .good
        } else if score >= quartiles.q1 {
            return .average
        } else {
            return .struggling
        }
    }
    
    /// Calculate median from sorted scores
    func calculateMedian(from sortedScores: [Double]) -> Double {
        guard !sortedScores.isEmpty else { return 0.0 }
        
        let mid = sortedScores.count / 2
        return sortedScores.count % 2 == 0 ?
            (sortedScores[mid - 1] + sortedScores[mid]) / 2 :
            sortedScores[mid]
    }
    
    /// Determine if adaptive scaling should be used
    /// - Returns true if top score is more than 3x the median (extreme outliers)
    func shouldUseAdaptiveScaling(topScore: Double, medianScore: Double) -> Bool {
        return topScore > (medianScore * 3)
    }
}