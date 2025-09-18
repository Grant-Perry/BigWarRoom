//
//  ScoringSettingsManager.swift
//  BigWarRoom
//
//  Unified manager for ESPN and Sleeper league scoring settings - extracts from existing API calls
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ScoringSettingsManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ScoringSettingsManager()
    
    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    /// Current scoring settings: [leagueID: [sleeperStatKey: points]]
    private var espnScoringSettings: [String: [String: Double]] = [:]
    private var sleeperScoringSettings: [String: [String: Double]] = [:]
    
    /// Debug info for each league's scoring basis
    private var leagueScoringBasis: [String: String] = [:]
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Interface
    
    /// Get scoring settings for any league (ESPN or Sleeper)
    func getScoringSettings(for leagueID: String, source: LeagueSource) -> [String: Double]? {
        switch source {
        case .espn:
            return espnScoringSettings[leagueID]
        case .sleeper:
            return sleeperScoringSettings[leagueID]
        }
    }
    
    /// Check if scoring settings are available for a league
    func hasScoringSettings(for leagueID: String, source: LeagueSource) -> Bool {
        return getScoringSettings(for: leagueID, source: source) != nil
    }
    
    /// Get the basis (data source) for a league's scoring settings
    func getScoringBasis(for leagueID: String) -> String {
        return leagueScoringBasis[leagueID] ?? "Unknown"
    }
    
    // MARK: - ESPN Integration
    
    /// Extract ESPN scoring settings from existing ESPNLeague data
    func registerESPNScoringSettings(from espnLeague: ESPNLeague, leagueID: String) {
        print("🎯 ScoringManager: Extracting ESPN scoring for league \(leagueID)")
        
        // Try to extract from scoringSettings first
        if let scoringSettings = espnLeague.scoringSettings,
           let scoringItems = scoringSettings.scoringItems {
            
            let convertedSettings = convertESPNScoringItems(scoringItems)
            espnScoringSettings[leagueID] = convertedSettings
            leagueScoringBasis[leagueID] = "ESPN API - scoringSettings (\(scoringItems.count) rules)"
            
            print("✅ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
            print("   Converted to \(convertedSettings.count) Sleeper keys")
            return
        }
        
        // Try to extract from nested settings.scoringSettings
        if let settings = espnLeague.settings,
           let nestedScoring = settings.scoringSettings,
           let scoringItems = nestedScoring.scoringItems {
            
            let convertedSettings = convertESPNScoringItems(scoringItems)
            espnScoringSettings[leagueID] = convertedSettings
            leagueScoringBasis[leagueID] = "ESPN API - settings.scoringSettings (\(scoringItems.count) rules)"
            
            print("✅ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
            print("   Converted to \(convertedSettings.count) Sleeper keys")
            return
        }
        
        // No scoring settings found
        leagueScoringBasis[leagueID] = "ESPN API - No scoring settings found"
        print("❌ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
    }
    
    /// Convert ESPN scoring items to Sleeper stat keys
    private func convertESPNScoringItems(_ scoringItems: [ESPNScoringItem]) -> [String: Double] {
        var convertedSettings: [String: Double] = [:]
        
        print("🔄 Converting \(scoringItems.count) ESPN scoring items:")
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { continue }
            
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                // 🔥 APPLY ESPN SCORING CORRECTIONS for known problematic stats
                let correctedPoints = applyESPNScoringCorrections(statId: statId, originalPoints: points, sleeperKey: sleeperKey)
                convertedSettings[sleeperKey] = correctedPoints
                
                if correctedPoints != points {
                    print("   🔧 ESPN \(statId) -> \(sleeperKey) = \(points) pts CORRECTED TO \(correctedPoints) pts")
                } else {
                    print("   ✓ ESPN \(statId) -> \(sleeperKey) = \(points) pts")
                }
            } else {
                let statName = ESPNStatIDMapper.getStatDisplayName(for: statId)
                print("   ⚠️ ESPN \(statId) (\(statName)) = \(points) pts - NO MAPPING")
            }
        }
        
        // 🔥 FIX: Apply ESPN scoring rule completions to fix missing complementary rules
        let finalSettings = applyESPNScoringRuleCompletions(convertedSettings)
        
        print("🔄 Conversion complete: \(finalSettings.count) mapped rules")
        return finalSettings
    }
    
    // MARK: - ESPN Scoring Rule Completions
    
    /// Apply missing complementary scoring rules that ESPN often omits from their API
    /// But ONLY if we can validate they actually improve scoring accuracy
    private func applyESPNScoringRuleCompletions(_ settings: [String: Double]) -> [String: Double] {
        // 🔥 NEW APPROACH: Conservative, validation-based completion
        // Don't blindly add rules - only add if we have strong evidence they're needed
        
        var completedSettings = settings
        var addedRules: [String] = []
        
        // 🔥 CONSERVATIVE: Only add passing first downs in very specific cases
        // - Only if rushing first downs exist (indicating league scores first downs)
        // - Only use very conservative rates
        // - Don't add if there are already lots of scoring rules (indicates complete API response)
        
        let ruleCount = settings.count
        let hasRushFd = settings["rush_fd"] != nil && settings["rush_fd"]! > 0
        let hasPassFd = settings["pass_fd"] != nil && settings["pass_fd"]! > 0
        
        // Only apply completions to leagues with moderate rule counts (not too many, not too few)
        guard ruleCount > 30 && ruleCount < 70 else {
            if ruleCount <= 30 {
                print("🚫 COMPLETION SKIPPED: Too few rules (\(ruleCount)) - likely incomplete league data")
            } else {
                print("🚫 COMPLETION SKIPPED: Too many rules (\(ruleCount)) - likely complete API response")
            }
            return completedSettings
        }
        
        // VERY CONSERVATIVE: Only add passing first downs if rushing first downs exist
        // AND only use the most conservative rate possible
        if hasRushFd && !hasPassFd {
            let rushFdPoints = settings["rush_fd"]!
            
            // Only add for leagues with reasonable rushing first down scoring
            if rushFdPoints >= 1.0 && rushFdPoints <= 3.0 {
                let passFdPoints = 0.1 // Fixed conservative rate
                completedSettings["pass_fd"] = passFdPoints
                addedRules.append("pass_fd: \(passFdPoints) pts (conservative completion)")
            } else {
                print("🚫 COMPLETION SKIPPED: Unusual rush_fd value (\(rushFdPoints)) - not applying pass_fd")
            }
        }
        
        // 🔥 REMOVED: All other completion logic - too risky
        // Let's see if just the conservative passing first down fix helps
        
        // Print added rules for debugging
        if !addedRules.isEmpty {
            print("🔥 ESPN SCORING COMPLETIONS APPLIED (CONSERVATIVE):")
            for rule in addedRules {
                print("   + \(rule)")
            }
        } else {
            print("🔥 ESPN SCORING COMPLETIONS: None applied (league appears complete)")
        }
        
        return completedSettings
    }
    
    // MARK: - ESPN Scoring Corrections
    
    /// Apply corrections to ESPN scoring settings that are known to be incorrect
    /// ESPN's API sometimes returns wildly incorrect point values that don't match their actual scoring
    private func applyESPNScoringCorrections(statId: Int, originalPoints: Double, sleeperKey: String) -> Double {
        switch statId {
        case 206: // pass_air_yd - ESPN returns 2.0, but almost never used in real leagues
            if originalPoints > 0.5 {
                print("   🚨 DISABLING ESPN stat \(statId) (pass_air_yd): Not used for fantasy scoring")
                return 0.0
            }
        case 209: // pass_yac - not real stat in almost all leagues
            if originalPoints > 0.5 {
                print("   🚨 DISABLING ESPN stat \(statId) (pass_yac): Not used for fantasy scoring")
                return 0.0
            }
        // DO NOT disable pass_cmp, pass_rz_att, rush_rz_att, etc
        // Let API/custom league scoring be used for everything else, including completions, bonuses, etc.
        case 198: // qb_hit
            return 0.0
        case 201: // pass_drop
            return 0.0
        case 63: // punt_yd
            return 0.0
        case 37: // kick_ret_yd
            return 0.0
        case 38: // punt_ret_yd
            return 0.0
        default:
            break
        }
        return originalPoints
    }
    
    // MARK: - Sleeper Integration
    
    /// Register Sleeper scoring settings from existing SleeperLeague data
    func registerSleeperScoringSettings(from sleeperLeague: SleeperLeague, leagueID: String) {
        print("🎯 ScoringManager: Extracting Sleeper scoring for league \(leagueID)")
        
        if let scoringSettings = sleeperLeague.scoringSettings {
            sleeperScoringSettings[leagueID] = scoringSettings
            leagueScoringBasis[leagueID] = "Sleeper API - league data (\(scoringSettings.count) rules)"
            
            print("✅ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
            return
        }
        
        // No scoring settings found
        leagueScoringBasis[leagueID] = "Sleeper API - No scoring settings found"
        print("❌ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
    }
    
    // MARK: - Validation
    
    /// Validate player points against calculated points using league scoring
    func validatePlayerPoints(
        player: FantasyPlayer,
        stats: [String: Double],
        leagueID: String,
        source: LeagueSource
    ) -> PointsValidationResult? {
        // Get scoring settings for this league
        guard let scoringSettings = getScoringSettings(for: leagueID, source: source) else {
            let basis = getScoringBasis(for: leagueID)
            print("❌ VALIDATION: No scoring settings for \(source) league \(leagueID) - Basis: \(basis)")
            
            return PointsValidationResult(
                player: player,
                apiPoints: player.currentPoints ?? 0.0,
                calculatedPoints: 0.0,
                discrepancy: 0.0,
                hasDiscrepancy: false,
                validationStatus: .noScoringSettings
            )
        }
        
        // Calculate points using league scoring rules
        let calculatedPoints = calculatePoints(stats: stats, scoringSettings: scoringSettings)
        let apiPoints = player.currentPoints ?? 0.0
        let discrepancy = abs(calculatedPoints - apiPoints)
        
        // Consider it a discrepancy if difference is > 0.1 points
        let hasDiscrepancy = discrepancy > 0.1
        
        let status: ValidationStatus
        if hasDiscrepancy {
            status = discrepancy > 1.0 ? .significantDiscrepancy : .minorDiscrepancy
        } else {
            status = .validated
        }
        
        // Debug print for validation
        let basis = getScoringBasis(for: leagueID)
        print("🔍 VALIDATION: \(player.fullName) in \(source) league \(leagueID)")
        print("   Basis: \(basis)")
        print("   API: \(apiPoints), Calculated: \(calculatedPoints), Discrepancy: \(discrepancy)")
        
        return PointsValidationResult(
            player: player,
            apiPoints: apiPoints,
            calculatedPoints: calculatedPoints,
            discrepancy: discrepancy,
            hasDiscrepancy: hasDiscrepancy,
            validationStatus: status
        )
    }
    
    /// Calculate fantasy points using scoring settings
    private func calculatePoints(stats: [String: Double], scoringSettings: [String: Double]) -> Double {
        var totalPoints: Double = 0.0
        
        for (statKey, statValue) in stats {
            guard statValue != 0.0,
                  let pointsPerStat = scoringSettings[statKey] else { continue }
            
            totalPoints += statValue * pointsPerStat
        }
        
        return totalPoints
    }
    
    // MARK: - Debug Methods
    
    /// Print all registered scoring bases for debugging
    func printAllScoringBases() {
        print("📊 ALL SCORING BASES:")
        
        // ESPN leagues
        print("   ESPN Leagues:")
        for (leagueID, basis) in leagueScoringBasis.filter({ espnScoringSettings[$0.key] != nil }) {
            let ruleCount = espnScoringSettings[leagueID]?.count ?? 0
            print("     \(leagueID): \(basis) -> \(ruleCount) rules")
        }
        
        // Sleeper leagues  
        print("   Sleeper Leagues:")
        for (leagueID, basis) in leagueScoringBasis.filter({ sleeperScoringSettings[$0.key] != nil }) {
            let ruleCount = sleeperScoringSettings[leagueID]?.count ?? 0
            print("     \(leagueID): \(basis) -> \(ruleCount) rules")
        }
        
        // Failed leagues
        let failedLeagues = leagueScoringBasis.filter { (leagueID, _) in
            espnScoringSettings[leagueID] == nil && sleeperScoringSettings[leagueID] == nil
        }
        
        if !failedLeagues.isEmpty {
            print("   Failed Leagues:")
            for (leagueID, basis) in failedLeagues {
                print("     \(leagueID): \(basis)")
            }
        }
    }
    
    /// Clear all scoring settings (for testing/debugging)
    func clearAllSettings() {
        espnScoringSettings.removeAll()
        sleeperScoringSettings.removeAll()
        leagueScoringBasis.removeAll()
        print("🧹 ScoringManager: All scoring settings cleared")
    }
}

// MARK: - Supporting Models (unchanged)

enum LeagueSource {
    case espn
    case sleeper
}

struct PointsValidationResult {
    let player: FantasyPlayer
    let apiPoints: Double      // Points from ESPN/Sleeper API
    let calculatedPoints: Double // Points calculated using league rules
    let discrepancy: Double
    let hasDiscrepancy: Bool
    let validationStatus: ValidationStatus
    
    var discrepancyDescription: String {
        let difference = calculatedPoints - apiPoints
        let sign = difference > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", difference))"
    }
}

enum ValidationStatus {
    case validated
    case minorDiscrepancy
    case significantDiscrepancy
    case noScoringSettings
    
    var description: String {
        switch self {
        case .validated: return "✅ Validated"
        case .minorDiscrepancy: return "⚠️ Minor Difference"
        case .significantDiscrepancy: return "🚨 Significant Difference"
        case .noScoringSettings: return "❌ No Scoring Rules"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .validated: return .green
        case .minorDiscrepancy: return .orange
        case .significantDiscrepancy: return .red
        case .noScoringSettings: return .gray
        }
    }
}