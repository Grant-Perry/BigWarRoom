//
//  ScoringSettingsManager.swift
//  BigWarRoom
//
//  Unified manager for ESPN and Sleeper league scoring settings - extracts from existing API calls
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class ScoringSettingsManager {
    
    // 🔥 PHASE 2 TEMPORARY: Bridge pattern - allow both .shared AND dependency injection
    private static var _shared: ScoringSettingsManager?
    
    static var shared: ScoringSettingsManager {
        if let existing = _shared {
            return existing
        }
        // Create temporary shared instance
        let instance = ScoringSettingsManager()
        _shared = instance
        return instance
    }
    
    // 🔥 PHASE 2: Allow setting the shared instance for proper DI
    static func setSharedInstance(_ instance: ScoringSettingsManager) {
        _shared = instance
    }
    
    // MARK: - Observable Properties
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Private Properties - Use @ObservationIgnored for internal caches
    /// Current scoring settings: [leagueID: [sleeperStatKey: points]]
    @ObservationIgnored private var espnScoringSettings: [String: [String: Double]] = [:]
    @ObservationIgnored private var sleeperScoringSettings: [String: [String: Double]] = [:]
    
    /// 🔥 NEW: Validated scoring settings using differential analysis
    @ObservationIgnored private var validatedESPNScoringSettings: [String: [String: Double]] = [:]
    
    /// Debug info for each league's scoring basis
    @ObservationIgnored private var leagueScoringBasis: [String: String] = [:]
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - 🔥 NEW: Fantasy Football Scoring Baselines
    
    /// Comprehensive scoring baselines for different league types
    struct ESPNScoringBaselines {
        
        /// Standard PPR League (most common fantasy setup)
        static let standardPPR: [String: Double] = [
            // Core Passing (99% of leagues use)
            "pass_yd": 0.04,        // 1 pt per 25 yards (25 × 0.04 = 1.0)
            "pass_td": 6.0,         // 6 pts per touchdown
            "pass_int": -2.0,       // -2 pts per interception
            "pass_2pt": 2.0,        // 2 pts per 2-point conversion
            
            // Core Rushing (99% of leagues use)
            "rush_yd": 0.1,         // 1 pt per 10 yards (10 × 0.1 = 1.0)
            "rush_td": 6.0,         // 6 pts per touchdown
            "rush_2pt": 2.0,        // 2 pts per 2-point conversion
            
            // Core Receiving (99% of PPR leagues use)
            "rec": 1.0,             // 1 pt per reception (PPR defining characteristic)
            "rec_yd": 0.1,          // 1 pt per 10 yards
            "rec_td": 6.0,          // 6 pts per touchdown
            "rec_2pt": 2.0,         // 2 pts per 2-point conversion
            
            // Core Kicking (95% of leagues use)
            "xpm": 1.0,             // 1 pt per extra point
            "fgm": 3.0,             // 3 pts per field goal (basic)
            
            // Core Fumbles (90% of leagues use)
            "fum_lost": -2.0,       // -2 pts per fumble lost
            
            // Core Defense/ST (85% of leagues use DST)
            "def_int": 2.0,         // 2 pts per defensive interception
            "def_fum_rec": 2.0,     // 2 pts per fumble recovery
            "def_sack": 1.0,        // 1 pt per sack
            "def_td": 6.0,          // 6 pts per defensive TD
            "def_safe": 2.0,        // 2 pts per safety
            "st_td": 6.0,           // 6 pts per special teams TD
            "blk_kick": 2.0,        // 2 pts per blocked kick
        ]
        
        /// Half-PPR League (same as PPR but 0.5 receptions)
        static let halfPPR: [String: Double] = {
            var settings = standardPPR
            settings["rec"] = 0.5   // 0.5 pts per reception
            return settings
        }()
        
        /// Standard (Non-PPR) League (same as PPR but 0 receptions)
        static let standard: [String: Double] = {
            var settings = standardPPR
            settings["rec"] = 0.0   // 0 pts per reception
            return settings
        }()
        
        /// Advanced PPR League (includes bonus categories ~60% use)
        static let advancedPPR: [String: Double] = {
            var settings = standardPPR
            // Bonus categories
            settings["pass_40"] = 1.0       // 40+ yard pass bonus
            settings["rush_40"] = 1.0       // 40+ yard rush bonus  
            settings["rec_40"] = 1.0        // 40+ yard reception bonus
            settings["pass_td_40p"] = 1.0   // 40+ yard pass TD bonus
            settings["rush_td_40p"] = 1.0   // 40+ yard rush TD bonus
            settings["rec_td_40p"] = 1.0    // 40+ yard rec TD bonus
            return settings
        }()
        
        /// Core stats that 90%+ of leagues use (high confidence these are active)
        static let coreStats: Set<String> = [
            "pass_yd", "pass_td", "pass_int",
            "rush_yd", "rush_td", 
            "rec", "rec_yd", "rec_td",
            "fgm", "xpm", "fum_lost"
        ]
        
        /// Advanced stats that some leagues use (medium confidence)
        static let commonAdvancedStats: Set<String> = [
            "pass_2pt", "rush_2pt", "rec_2pt",
            "def_int", "def_fum_rec", "def_sack", "def_td", "def_safe",
            "st_td", "blk_kick"
        ]
        
        /// Rare stats that few leagues use (low confidence)
        static let rareStats: Set<String> = [
            "kick_ret_yd", "punt_ret_yd", "qb_hit", "pass_air_yd",
            "pass_yac", "pass_drop", "punt_yd", "def_tkl", "def_ast"
        ]
    }
    
    // MARK: - Public Interface
    
    /// Get scoring settings for any league (ESPN or Sleeper) - 🔥 NEW: Returns validated settings
    func getScoringSettings(for leagueID: String, source: LeagueSource) -> [String: Double]? {
        switch source {
        case .espn:
            // 🔥 NEW: Return validated settings if available, fallback to raw settings
            return validatedESPNScoringSettings[leagueID] ?? espnScoringSettings[leagueID]
        case .sleeper:
            return sleeperScoringSettings[leagueID]
        }
    }
    
    /// 🔥 NEW: Get raw (unvalidated) ESPN scoring settings for debugging
    func getRawESPNScoringSettings(for leagueID: String) -> [String: Double]? {
        return espnScoringSettings[leagueID]
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
    
    // MARK: - 🔥 NEW: Smart Filtering Based on Real League Data
    
    /// Perform smart filtering based on real ESPN league analysis
    /// Removes template noise that never appears in actual leagues
    private func performSmartFiltering(rawSettings: [String: Double], leagueID: String) -> [String: Double] {
        var filteredRules: [String: Double] = [:]
        
        // Define template noise that never appears in real leagues
        let templateNoise: Set<String> = [
            "pass_air_yd",      // Pass Air Yards - NEVER in real leagues
            "pass_yac",         // Yards After Catch - NEVER in real leagues
            "qb_hit",           // QB Hits - NEVER in real leagues (defensive stat)
            "pass_drop",        // Dropped Passes - NEVER in real leagues
            "punt_yd",          // Punt Yards - Special teams, not fantasy scoring
            "pass_rz_att",      // Red Zone Pass Attempts - NEVER in real leagues
            "rush_rz_att",      // Red Zone Rush Attempts - NEVER in real leagues  
            "rec_rz_tgt",       // Red Zone Targets - NEVER in real leagues
            "kick_ret_att",     // Kick Return Attempts - NEVER for skill players
            "punt_ret_att",     // Punt Return Attempts - NEVER for skill players
        ]
        
        // Define stats that are almost never used (very low threshold)
        let rarelyUsed: Set<String> = [
            "kick_ret_yd",      // Kick Return Yards - only in very custom leagues
            "punt_ret_yd",      // Punt Return Yards - only in very custom leagues
            "def_tkl",          // Individual Tackles - usually only in IDP
            "def_ast",          // Assisted Tackles - usually only in IDP
            "def_solo",         // Solo Tackles - usually only in IDP
            "def_comb",         // Combined Tackles - usually only in IDP
            "def_stf",          // Defensive Stuffs - usually only in IDP
            "def_pass_def",     // Pass Deflections - usually only in IDP
        ]
        
        for (statKey, points) in rawSettings {
            
            // RULE 1: Hard filter - Never include template noise
            if templateNoise.contains(statKey) {
                continue
            }
            
            // RULE 2: Zero points - Explicitly disabled, don't include
            if points == 0.0 {
                continue
            }
            
            // RULE 3: Rarely used stats with tiny values - Filter out
            if rarelyUsed.contains(statKey) && abs(points) < 0.1 {
                continue
            }
            
            // RULE 4: Negative scoring with tiny values - Filter out (except fumbles/INTs)
            if points < 0 && abs(points) < 0.5 && !statKey.contains("fum") && !statKey.contains("int") {
                continue
            }
            
            // RULE 5: Very small positive values that don't make fantasy sense
            if points > 0 && points < 0.01 {
                continue
            }
            
            // RULE 6: Include everything else that passes the filters
            filteredRules[statKey] = points
        }
        
        return filteredRules
    }
    
    /// Extract ESPN scoring settings from existing ESPNLeague data
    func registerESPNScoringSettings(from espnLeague: ESPNLeague, leagueID: String) {
        // Directly use authoritative ESPN API scoringItems -- no overrides, no filtering, full trust
        if let scoringSettings = espnLeague.scoringSettings,
           let scoringItems = scoringSettings.scoringItems {

            var trustedSettings: [String: Double] = [:]

            for item in scoringItems {
                guard let statId = item.statId, let points = item.points else { continue }

                if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                    if points != 0.0 {
                        trustedSettings[sleeperKey] = points
                    }

                    // Handle position-specific overrides (like DST scoring)
                    if let overrides = item.pointsOverrides, !overrides.isEmpty {
                        for (positionKey, overridePoints) in overrides {
                            if positionKey == "16" { // DST
                                let dstKey = "\(sleeperKey)_dst"
                                trustedSettings[dstKey] = overridePoints
                            }
                        }
                    }
                }
            }

            espnScoringSettings[leagueID] = trustedSettings
            validatedESPNScoringSettings[leagueID] = trustedSettings
            leagueScoringBasis[leagueID] = "ESPN Silver Bullet (Authoritative JSON: \(scoringItems.count) raw → \(trustedSettings.count) mapped)"
            return
        }

        // Try nested settings as fallback
        if let settings = espnLeague.settings,
           let nestedScoring = settings.scoringSettings,
           let scoringItems = nestedScoring.scoringItems {

            var trustedSettings: [String: Double] = [:]

            for item in scoringItems {
                guard let statId = item.statId, let points = item.points else { continue }
                if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                    if points != 0.0 {
                        trustedSettings[sleeperKey] = points
                    }
                }
            }

            espnScoringSettings[leagueID] = trustedSettings
            validatedESPNScoringSettings[leagueID] = trustedSettings
            leagueScoringBasis[leagueID] = "ESPN Silver Bullet (Nested JSON: \(scoringItems.count) raw → \(trustedSettings.count) mapped)"
            return
        }

        // No scoring settings found
        leagueScoringBasis[leagueID] = "ESPN API - No scoring settings found"
    }
    
    // MARK: - 🔥 NEW: Differential Analysis System
    
    /// Perform differential analysis to determine active scoring rules
    private func performDifferentialAnalysis(rawSettings: [String: Double], leagueID: String) -> [String: Double] {
        // Step 1: Detect league type (PPR, Half-PPR, Standard)
        let leagueType = detectLeagueType(from: rawSettings)
        let baseline = getBaseline(for: leagueType)
        
        // Step 2: Apply differential logic
        var validatedRules: [String: Double] = [:]
        
        for (statKey, rawPoints) in rawSettings {
            let baselinePoints = baseline[statKey] ?? 0.0
            let analysis = analyzeStatRule(
                statKey: statKey, 
                rawPoints: rawPoints, 
                baselinePoints: baselinePoints
            )
            
            if analysis.isActive {
                validatedRules[statKey] = rawPoints
            }
        }
        
        // Step 3: Add missing core stats if league has them at 0 but baseline doesn't
        let _ = addMissingCoreStats(validatedRules: &validatedRules, baseline: baseline, rawSettings: rawSettings)
        
        return validatedRules
    }
    
    /// Detect league type based on reception scoring
    private func detectLeagueType(from rawSettings: [String: Double]) -> LeagueType {
        let receptionPoints = rawSettings["rec"] ?? 0.0
        
        if abs(receptionPoints - 1.0) < 0.01 {
            return .standardPPR
        } else if abs(receptionPoints - 0.5) < 0.01 {
            return .halfPPR
        } else if abs(receptionPoints - 0.0) < 0.01 {
            return .standard
        } else if receptionPoints > 1.0 {
            return .customPPR  // TE premium or other custom
        } else {
            return .standardPPR  // Default assumption
        }
    }
    
    /// Get baseline for league type
    private func getBaseline(for leagueType: LeagueType) -> [String: Double] {
        switch leagueType {
        case .standardPPR, .customPPR:
            return ESPNScoringBaselines.standardPPR
        case .halfPPR:
            return ESPNScoringBaselines.halfPPR
        case .standard:
            return ESPNScoringBaselines.standard
        }
    }
    
    /// Analyze individual stat rule to determine if it's active
    private func analyzeStatRule(statKey: String, rawPoints: Double, baselinePoints: Double) -> StatRuleAnalysis {
        
        // RULE 1: Core stats with non-zero points → ALWAYS ACTIVE
        if ESPNScoringBaselines.coreStats.contains(statKey) && rawPoints != 0.0 {
            if abs(rawPoints - baselinePoints) < 0.01 {
                return StatRuleAnalysis(isActive: true, reason: "Core stat matches baseline")
            } else {
                return StatRuleAnalysis(isActive: true, reason: "Core stat with custom points")
            }
        }
        
        // RULE 2: Core stats with zero points when baseline has points → EXPLICITLY DISABLED
        if ESPNScoringBaselines.coreStats.contains(statKey) && rawPoints == 0.0 && baselinePoints > 0.0 {
            return StatRuleAnalysis(isActive: false, reason: "Core stat explicitly disabled")
        }
        
        // RULE 3: Different from baseline → CUSTOM ACTIVE (high confidence)
        if abs(rawPoints - baselinePoints) > 0.01 && rawPoints != 0.0 {
            return StatRuleAnalysis(isActive: true, reason: "Custom rule (diff from baseline)")
        }
        
        // RULE 4: Advanced stats with significant points → PROBABLY ACTIVE
        if ESPNScoringBaselines.commonAdvancedStats.contains(statKey) && rawPoints >= 0.5 {
            return StatRuleAnalysis(isActive: true, reason: "Advanced stat with significant points")
        }
        
        // RULE 5: Rare stats with high points → CUSTOM LEAGUE FEATURE
        if ESPNScoringBaselines.rareStats.contains(statKey) && rawPoints >= 1.0 {
            return StatRuleAnalysis(isActive: true, reason: "Rare stat with high points (custom league)")
        }
        
        // RULE 6: Rare stats with low points → PROBABLY TEMPLATE NOISE
        if ESPNScoringBaselines.rareStats.contains(statKey) && rawPoints < 0.5 && rawPoints > 0.0 {
            return StatRuleAnalysis(isActive: false, reason: "Rare stat with low points (likely template)")
        }
        
        // RULE 7: Unknown stats with decent points → MAYBE ACTIVE (include for now)
        if !ESPNScoringBaselines.coreStats.contains(statKey) && 
           !ESPNScoringBaselines.commonAdvancedStats.contains(statKey) &&
           !ESPNScoringBaselines.rareStats.contains(statKey) &&
           rawPoints >= 0.5 {
            return StatRuleAnalysis(isActive: true, reason: "Unknown stat with decent points")
        }
        
        // RULE 8: Everything else → FILTER OUT
        return StatRuleAnalysis(isActive: false, reason: "Low confidence - filtered out")
    }
    
    /// Add missing core stats that should be included
    private func addMissingCoreStats(validatedRules: inout [String: Double], baseline: [String: Double], rawSettings: [String: Double]) -> [String] {
        var addedStats: [String] = []
        
        for (statKey, baselinePoints) in baseline {
            // If core stat is missing from validated rules but exists in baseline
            if ESPNScoringBaselines.coreStats.contains(statKey) && 
               validatedRules[statKey] == nil &&
               baselinePoints > 0.0 {
                
                // Check if it was in raw settings but filtered out  
                if let rawPoints = rawSettings[statKey], rawPoints == 0.0 {
                    // It was explicitly set to 0, respect that
                    continue
                }
                
                // Add missing core stat with baseline points
                validatedRules[statKey] = baselinePoints
                addedStats.append(statKey)
            }
        }
        
        return addedStats
    }
    
    /// Calculate confidence score for validated rules
    private func calculateConfidence(validatedRules: [String: Double], baseline: [String: Double]) -> String {
        let coreStatsFound = validatedRules.keys.filter { ESPNScoringBaselines.coreStats.contains($0) }.count
        let coreStatsExpected = ESPNScoringBaselines.coreStats.count
        let corePercentage = Double(coreStatsFound) / Double(coreStatsExpected) * 100
        
        if corePercentage >= 90 {
            return "HIGH (\(Int(corePercentage))% core stats)"
        } else if corePercentage >= 70 {
            return "MEDIUM (\(Int(corePercentage))% core stats)"
        } else {
            return "LOW (\(Int(corePercentage))% core stats)"
        }
    }
    
    // MARK: - Supporting Types
    
    enum LeagueType {
        case standardPPR
        case halfPPR
        case standard
        case customPPR
    }
    
    struct StatRuleAnalysis {
        let isActive: Bool
        let reason: String
    }
    
    // MARK: - 🔥 NEW: Validation Against ESPN appliedTotal
    
    /// Validate differential analysis results against ESPN's appliedTotal
    func validateDifferentialAnalysis(
        player: FantasyPlayer, 
        stats: [String: Double], 
        espnAppliedTotal: Double,
        leagueID: String
    ) -> DifferentialValidationResult {
        
        guard let validatedSettings = validatedESPNScoringSettings[leagueID] else {
            return DifferentialValidationResult(
                success: false,
                ourCalculation: 0.0,
                espnTotal: espnAppliedTotal,
                discrepancy: espnAppliedTotal,
                confidence: "NO_SETTINGS"
            )
        }
        
        // Calculate using our differential analysis results
        let ourCalculation = calculatePoints(stats: stats, scoringSettings: validatedSettings)
        let discrepancy = abs(ourCalculation - espnAppliedTotal)
        let success = discrepancy < 1.0  // Within 1 point is considered success
        
        let confidence: String
        if discrepancy < 0.1 {
            confidence = "PERFECT"
        } else if discrepancy < 0.5 {
            confidence = "EXCELLENT" 
        } else if discrepancy < 1.0 {
            confidence = "GOOD"
        } else if discrepancy < 2.0 {
            confidence = "FAIR"
        } else {
            confidence = "POOR"
        }
        
        return DifferentialValidationResult(
            success: success,
            ourCalculation: ourCalculation,
            espnTotal: espnAppliedTotal,
            discrepancy: discrepancy,
            confidence: confidence
        )
    }
    
    struct DifferentialValidationResult {
        let success: Bool
        let ourCalculation: Double
        let espnTotal: Double
        let discrepancy: Double
        let confidence: String
    }
    
    /// Convert ESPN scoring items to Sleeper stat keys
    private func convertESPNScoringItems(_ scoringItems: [ESPNScoringItem]) -> [String: Double] {
        var convertedSettings: [String: Double] = [:]
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { continue }
            
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                // Include ALL rules for differential analysis (let the algorithm decide)
                convertedSettings[sleeperKey] = points
                
                // Handle pointsOverrides
                if let overrides = item.pointsOverrides, !overrides.isEmpty {
                    // Check if this is position-specific scoring
                    let isPositionSpecific = overrides.keys.allSatisfy { key in
                        if let positionId = Int(key) {
                            return positionId >= 1 && positionId <= 20
                        }
                        return false
                    }
                    
                    if isPositionSpecific {
                        continue
                    }
                    
                    // Handle various override types
                    if sleeperKey == "fgm" {
                        handleFieldGoalDistanceOverrides(overrides: overrides, convertedSettings: &convertedSettings)
                    }
                    else if sleeperKey == "rec" {
                        handlePositionSpecificOverrides(statId: statId, overrides: overrides, convertedSettings: &convertedSettings)
                    }
                    else {
                        handleGeneralOverrides(statId: statId, sleeperKey: sleeperKey, overrides: overrides, convertedSettings: &convertedSettings)
                    }
                }
            }
        }
        
        return convertedSettings
    }
    
    // MARK: - Advanced Scoring Override Handlers
    
    /// Handle field goal distance-based scoring overrides
    private func handleFieldGoalDistanceOverrides(overrides: [String: Double], convertedSettings: inout [String: Double]) {
        // ESPN typically uses distance ranges as keys in pointsOverrides
        // Example: {"0-19": 3.0, "20-29": 3.0, "30-39": 3.0, "40-49": 4.0, "50+": 5.0}
        
        for (distanceKey, points) in overrides {
            let normalizedKey = distanceKey.lowercased().replacingOccurrences(of: " ", with: "")
            
            switch normalizedKey {
            case "0-19", "0_19":
                convertedSettings["fgm_0_19"] = points
            case "20-29", "20_29":
                convertedSettings["fgm_20_29"] = points
            case "30-39", "30_39":
                convertedSettings["fgm_30_39"] = points
            case "40-49", "40_49":
                convertedSettings["fgm_40_49"] = points
            case "50+", "50_plus", "50":
                convertedSettings["fgm_50p"] = points
            default:
                break // Unknown FG distance key
            }
        }
    }
    
    /// Handle position-specific scoring overrides (e.g., TE premium)
    private func handlePositionSpecificOverrides(statId: Int, overrides: [String: Double], convertedSettings: inout [String: Double]) {
        // ESPN uses position IDs or abbreviations as keys in pointsOverrides
        // Example for receptions: {"TE": 1.5, "RB": 0.5, "WR": 1.0}
        
        for (positionKey, points) in overrides {
            let normalizedPosition = positionKey.uppercased()
            
            switch normalizedPosition {
            case "TE":
                convertedSettings["rec_te"] = points
            case "RB":
                convertedSettings["rec_rb"] = points
            case "WR":
                convertedSettings["rec_wr"] = points
            case "QB":
                convertedSettings["rec_qb"] = points
            default:
                break // Unknown position key
            }
        }
    }
    
    /// Handle other general overrides - but filter out position-specific ones
    private func handleGeneralOverrides(statId: Int, sleeperKey: String, overrides: [String: Double], convertedSettings: inout [String: Double]) {
        for (key, points) in overrides {
            // Skip position-specific overrides (numeric keys 1-20 are positions)
            if let positionId = Int(key), positionId >= 1 && positionId <= 20 {
                continue
            }
            
            // Create a combined key for non-position-specific advanced rules
            let advancedKey = "\(sleeperKey)_\(key.lowercased())"
            convertedSettings[advancedKey] = points
        }
    }
    
    // MARK: - ESPN Scoring Rule Completions
    
    /// Apply missing complementary scoring rules that ESPN often omits from their API
    /// But ONLY if we can validate they actually improve scoring accuracy
    private func applyESPNScoringRuleCompletions(_ settings: [String: Double]) -> [String: Double] {
        // NO more add/complete/guess logic.
        // Just return the settings verbatim. Never invent a multiplier.
        return settings
    }
    
    // MARK: - ESPN Scoring Corrections
    
    /// Apply corrections to ESPN scoring settings that are known to be incorrect
    /// ESPN's API sometimes returns wildly incorrect point values that don't match their actual scoring
    private func applyESPNScoringCorrections(statId: Int, originalPoints: Double, sleeperKey: String) -> Double {
        // 🔥 GUMBY'S CRITICAL FIX: TRUST THE LEAGUE SETTINGS - DO NOT ZERO OUT LEGITIMATE RULES!
        // If a league actually configured these stats, we should honor their decision
        // Only apply corrections for truly broken/impossible values, not personal preferences
        
        // For now, return original points - trust the league configuration
        return originalPoints
        
    }
    
    // MARK: - Sleeper Integration
    
    /// Register Sleeper scoring settings from existing SleeperLeague data
    func registerSleeperScoringSettings(from sleeperLeague: SleeperLeague, leagueID: String) {
        if let scoringSettings = sleeperLeague.scoringSettings {
            sleeperScoringSettings[leagueID] = scoringSettings
            leagueScoringBasis[leagueID] = "Sleeper API - league data (\(scoringSettings.count) rules)"
            return
        }
        
        // No scoring settings found
        leagueScoringBasis[leagueID] = "Sleeper API - No scoring settings found"
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
            
            // 🔥 NEW: Apply proper fantasy football scoring math
            let points = calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat)
            totalPoints += points
        }
        
        return totalPoints
    }
    
    /// Calculate points for a specific stat using proper fantasy football math
    private func calculateStatPoints(statKey: String, statValue: Double, pointsPerStat: Double) -> Double {
        if isYardStat(statKey) {
            // 🔥 NEW CORRECT MATH: Direct fractional multiplication  
            return statValue * pointsPerStat
        }
        
        // Event-based stats (TDs, INTs, etc.) use direct multiplication
        return statValue * pointsPerStat
    }
    
    /// Check if a stat is yard-based and needs increment calculation
    private func isYardStat(_ statKey: String) -> Bool {
        let yardStats = [
            "pass_yd", "rush_yd", "rec_yd", 
            "def_int_yd", "def_fum_rec_yd", 
            "kick_ret_yd", "punt_ret_yd"
        ]
        return yardStats.contains(statKey)
    }
    
    // MARK: - Debug Methods
    
    /// Print all registered scoring bases for debugging
    func printAllScoringBases() {
        DebugLogger.scoring("ALL SCORING BASES:", level: .info)
        
        // ESPN leagues
        DebugLogger.scoring("ESPN Leagues:", level: .info)
        for (leagueID, basis) in leagueScoringBasis.filter({ espnScoringSettings[$0.key] != nil }) {
            let rawCount = espnScoringSettings[leagueID]?.count ?? 0
            let validatedCount = validatedESPNScoringSettings[leagueID]?.count ?? 0
            DebugLogger.scoring("  \(leagueID): \(basis)", level: .info)
            DebugLogger.scoring("    Raw: \(rawCount) → Validated: \(validatedCount)", level: .info)
        }
        
        // Sleeper leagues  
        DebugLogger.scoring("Sleeper Leagues:", level: .info)
        for (leagueID, basis) in leagueScoringBasis.filter({ sleeperScoringSettings[$0.key] != nil }) {
            let ruleCount = sleeperScoringSettings[leagueID]?.count ?? 0
            DebugLogger.scoring("  \(leagueID): \(basis) -> \(ruleCount) rules", level: .info)
        }
        
        // Failed leagues
        let failedLeagues = leagueScoringBasis.filter { (leagueID, _) in
            espnScoringSettings[leagueID] == nil && sleeperScoringSettings[leagueID] == nil
        }
        
        if !failedLeagues.isEmpty {
            DebugLogger.scoring("Failed Leagues:", level: .warning)
            for (leagueID, basis) in failedLeagues {
                DebugLogger.scoring("  \(leagueID): \(basis)", level: .warning)
            }
        }
    }
    
    /// 🔥 NEW: Print detailed differential analysis results
    func printDifferentialAnalysisDetails(for leagueID: String) {
        guard let rawSettings = espnScoringSettings[leagueID],
              let validatedSettings = validatedESPNScoringSettings[leagueID] else {
            DebugLogger.error("No data for league \(leagueID)", category: .scoring)
            return
        }
        
        DebugLogger.scoring("DIFFERENTIAL ANALYSIS DETAILS: League \(leagueID)", level: .info)
        DebugLogger.scoring("Raw Rules: \(rawSettings.count)", level: .info)
        DebugLogger.scoring("Validated Rules: \(validatedSettings.count)", level: .info)
        DebugLogger.scoring("Filtered Out: \(rawSettings.count - validatedSettings.count)", level: .info)
        
        DebugLogger.scoring("VALIDATED RULES:", level: .info)
        for (statKey, points) in validatedSettings.sorted(by: { $0.key < $1.key }) {
            let isCore = ESPNScoringBaselines.coreStats.contains(statKey) ? " (CORE)" : ""
            DebugLogger.scoring("  \(statKey): \(points)\(isCore)", level: .info)
        }
        
        DebugLogger.scoring("FILTERED OUT:", level: .info)
        let filteredOut = rawSettings.filter { validatedSettings[$0.key] == nil }
        for (statKey, points) in filteredOut.sorted(by: { $0.key < $1.key }) {
            DebugLogger.scoring("  \(statKey): \(points)", level: .info)
        }
        
        DebugLogger.scoring("LEAGUE TYPE ANALYSIS:", level: .info)
        let leagueType = detectLeagueType(from: rawSettings)
        DebugLogger.scoring("  Detected: \(leagueType)", level: .info)
        let receptionPoints = rawSettings["rec"] ?? 0.0
        DebugLogger.scoring("  Reception Points: \(receptionPoints)", level: .info)
    }
    
    /// 🔥 NEW: Test differential analysis against known players
    func testDifferentialAnalysis(for leagueID: String) {
        DebugLogger.scoring("TESTING DIFFERENTIAL ANALYSIS: League \(leagueID)", level: .info)
        
        // Create test players with known stats
        let testScenarios = [
            TestScenario(
                name: "Josh Allen", 
                stats: [
                    "pass_yd": 287.0,
                    "pass_td": 2.0,
                    "rush_yd": 45.0,
                    "rush_td": 1.0
                ],
                expectedRange: (20.0, 30.0)
            ),
            TestScenario(
                name: "Christian McCaffrey",
                stats: [
                    "rush_yd": 118.0,
                    "rush_td": 1.0,
                    "rec": 8.0,
                    "rec_yd": 72.0
                ],
                expectedRange: (25.0, 35.0)
            ),
            TestScenario(
                name: "Tyreek Hill",
                stats: [
                    "rec": 12.0,
                    "rec_yd": 143.0,
                    "rec_td": 1.0
                ],
                expectedRange: (25.0, 35.0)
            )
        ]
        
        guard let validatedSettings = validatedESPNScoringSettings[leagueID] else {
            DebugLogger.error("No validated settings for league \(leagueID)", category: .scoring)
            return
        }
        
        for scenario in testScenarios {
            let calculatedPoints = calculatePoints(stats: scenario.stats, scoringSettings: validatedSettings)
            let inRange = calculatedPoints >= scenario.expectedRange.0 && calculatedPoints <= scenario.expectedRange.1
            let status = inRange ? "✅ PASS" : "❌ FAIL"
            
            DebugLogger.scoring("\(status) \(scenario.name): \(String(format: "%.2f", calculatedPoints)) pts (expected: \(scenario.expectedRange.0)-\(scenario.expectedRange.1))", level: .info)
            
            // Show breakdown
            for (statKey, statValue) in scenario.stats {
                if let pointsPerStat = validatedSettings[statKey] {
                    let points = calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat)
                    DebugLogger.scoring("  \(statKey): \(statValue) × \(pointsPerStat) = \(String(format: "%.2f", points))", level: .info)
                }
            }
        }
    }
    
    struct TestScenario {
        let name: String
        let stats: [String: Double]
        let expectedRange: (Double, Double)
    }
    
    /// Clear all scoring settings (for testing/debugging)
    func clearAllSettings() {
        espnScoringSettings.removeAll()
        sleeperScoringSettings.removeAll()
        validatedESPNScoringSettings.removeAll()
        leagueScoringBasis.removeAll()
        DebugLogger.scoring("All scoring settings cleared", level: .info)
    }
}

// MARK: - Supporting Models (unchanged)

// Import the proper LeagueSource
typealias LeagueSource = UnifiedLeagueManager.LeagueWrapper.LeagueSource

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