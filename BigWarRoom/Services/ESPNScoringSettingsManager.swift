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
    
    /// 🔥 NEW: Validated scoring settings using differential analysis
    private var validatedESPNScoringSettings: [String: [String: Double]] = [:]
    
    /// Debug info for each league's scoring basis
    private var leagueScoringBasis: [String: String] = [:]
    
    // MARK: - Initialization
    private init() {}
    
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
    
    /// Aggressive filtering based on real ESPN league analysis
    /// Removes template noise that never appears in actual leagues
    private func performSmartFiltering(rawSettings: [String: Double], leagueID: String) -> [String: Double] {
        print("🎯 SMART FILTERING: League \(leagueID)")
        print("   Input: \(rawSettings.count) raw ESPN rules")
        
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
                print("   🚫 TEMPLATE NOISE: \(statKey) = \(points) (never used in real leagues)")
                continue
            }
            
            // RULE 2: Zero points - Explicitly disabled, don't include
            if points == 0.0 {
                print("   ⭕ DISABLED: \(statKey) = \(points) (explicitly set to 0)")
                continue
            }
            
            // RULE 3: Rarely used stats with tiny values - Filter out
            if rarelyUsed.contains(statKey) && abs(points) < 0.1 {
                print("   🔍 LOW VALUE RARE: \(statKey) = \(points) (likely template)")
                continue
            }
            
            // RULE 4: Negative scoring with tiny values - Filter out (except fumbles/INTs)
            if points < 0 && abs(points) < 0.5 && !statKey.contains("fum") && !statKey.contains("int") {
                print("   ➖ TINY NEGATIVE: \(statKey) = \(points) (likely template)")
                continue
            }
            
            // RULE 5: Very small positive values that don't make fantasy sense
            if points > 0 && points < 0.01 {
                print("   🔬 MICROSCOPIC: \(statKey) = \(points) (too small to matter)")
                continue
            }
            
            // RULE 6: Include everything else that passes the filters
            filteredRules[statKey] = points
            print("   ✅ KEPT: \(statKey) = \(points)")
        }
        
        print("   OUTPUT: \(filteredRules.count) filtered rules (removed \(rawSettings.count - filteredRules.count) template noise)")
        
        return filteredRules
    }
    
    /// Extract ESPN scoring settings from existing ESPNLeague data
    func registerESPNScoringSettings(from espnLeague: ESPNLeague, leagueID: String) {
        print("🎯 ScoringManager: Extracting ESPN scoring for league \(leagueID)")
        
        // Try to extract from scoringSettings first
        if let scoringSettings = espnLeague.scoringSettings,
           let scoringItems = scoringSettings.scoringItems {
            
            let rawSettings = convertESPNScoringItems(scoringItems)
            espnScoringSettings[leagueID] = rawSettings
            
            // 🔥 NEW: Apply smart filtering instead of complex differential analysis
            let filteredSettings = performSmartFiltering(rawSettings: rawSettings, leagueID: leagueID)
            validatedESPNScoringSettings[leagueID] = filteredSettings
            
            leagueScoringBasis[leagueID] = "ESPN API - Smart Filtered (\(scoringItems.count) raw → \(filteredSettings.count) active)"
            
            print("✅ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
            return
        }
        
        // Try to extract from nested settings.scoringSettings
        if let settings = espnLeague.settings,
           let nestedScoring = settings.scoringSettings,
           let scoringItems = nestedScoring.scoringItems {
            
            let rawSettings = convertESPNScoringItems(scoringItems)
            espnScoringSettings[leagueID] = rawSettings
            
            // 🔥 NEW: Apply smart filtering
            let filteredSettings = performSmartFiltering(rawSettings: rawSettings, leagueID: leagueID)
            validatedESPNScoringSettings[leagueID] = filteredSettings
            
            leagueScoringBasis[leagueID] = "ESPN API - Smart Filtered (\(scoringItems.count) raw → \(filteredSettings.count) active)"
            
            print("✅ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
            return
        }
        
        // No scoring settings found
        leagueScoringBasis[leagueID] = "ESPN API - No scoring settings found"
        print("❌ BASIS: League \(leagueID) - \(leagueScoringBasis[leagueID]!)")
    }
    
    // MARK: - 🔥 NEW: Differential Analysis System
    
    /// Perform differential analysis to determine active scoring rules
    private func performDifferentialAnalysis(rawSettings: [String: Double], leagueID: String) -> [String: Double] {
        print("🔬 DIFFERENTIAL ANALYSIS: League \(leagueID)")
        print("   Input: \(rawSettings.count) raw ESPN rules")
        
        // Step 1: Detect league type (PPR, Half-PPR, Standard)
        let leagueType = detectLeagueType(from: rawSettings)
        let baseline = getBaseline(for: leagueType)
        
        print("   Detected Type: \(leagueType)")
        print("   Baseline: \(baseline.count) rules")
        
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
                print("   ✅ ACTIVE: \(statKey) = \(rawPoints) (\(analysis.reason))")
            } else {
                print("   ❌ FILTERED: \(statKey) = \(rawPoints) (\(analysis.reason))")
            }
        }
        
        // Step 3: Add missing core stats if league has them at 0 but baseline doesn't
        let missingCoreStats = addMissingCoreStats(validatedRules: &validatedRules, baseline: baseline, rawSettings: rawSettings)
        if !missingCoreStats.isEmpty {
            print("   🔧 ADDED MISSING: \(missingCoreStats)")
        }
        
        print("   OUTPUT: \(validatedRules.count) validated rules")
        print("   CONFIDENCE: \(calculateConfidence(validatedRules: validatedRules, baseline: baseline))")
        
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
        
        print("🔬 VALIDATION: \(player.fullName)")
        print("   Our Calc: \(String(format: "%.2f", ourCalculation))")
        print("   ESPN Total: \(String(format: "%.2f", espnAppliedTotal))")
        print("   Discrepancy: \(String(format: "%.2f", discrepancy))")
        print("   Confidence: \(confidence)")
        
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
        
        print("🔄 Converting \(scoringItems.count) ESPN scoring items:")
        
        for item in scoringItems {
            guard let statId = item.statId,
                  let points = item.points else { continue }
            
            if let sleeperKey = ESPNStatIDMapper.statIdToSleeperKey[statId] {
                
                // 🔥 REMOVED: Old filtering logic - let differential analysis handle this
                // if shouldFilterOutStat(...) { continue }
                
                // Include ALL rules for differential analysis (let the algorithm decide)
                convertedSettings[sleeperKey] = points
                print("   → ESPN \(statId) -> \(sleeperKey) = \(points) pts")
                
                // Handle pointsOverrides
                if let overrides = item.pointsOverrides, !overrides.isEmpty {
                    print("   🔧 ESPN \(statId) has pointsOverrides: \(overrides)")
                    
                    // Check if this is position-specific scoring
                    let isPositionSpecific = overrides.keys.allSatisfy { key in
                        if let positionId = Int(key) {
                            return positionId >= 1 && positionId <= 20
                        }
                        return false
                    }
                    
                    if isPositionSpecific {
                        print("      🎯 Position-specific rule detected - skipping general application")
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
            } else {
                let statName = ESPNStatIDMapper.getStatDisplayName(for: statId)
                print("   ⚠️ ESPN \(statId) (\(statName)) = \(points) pts - NO MAPPING")
            }
        }
        
        print("🔄 Raw conversion complete: \(convertedSettings.count) mapped rules (before differential analysis)")
        return convertedSettings
    }
    
    // MARK: - Advanced Scoring Override Handlers
    
    /// Handle field goal distance-based scoring overrides
    private func handleFieldGoalDistanceOverrides(overrides: [String: Double], convertedSettings: inout [String: Double]) {
        print("      🎯 Processing FG distance overrides:")
        
        // ESPN typically uses distance ranges as keys in pointsOverrides
        // Example: {"0-19": 3.0, "20-29": 3.0, "30-39": 3.0, "40-49": 4.0, "50+": 5.0}
        
        for (distanceKey, points) in overrides {
            let normalizedKey = distanceKey.lowercased().replacingOccurrences(of: " ", with: "")
            
            switch normalizedKey {
            case "0-19", "0_19":
                convertedSettings["fgm_0_19"] = points
                print("        0-19 yards: \(points) pts")
            case "20-29", "20_29":
                convertedSettings["fgm_20_29"] = points
                print("        20-29 yards: \(points) pts")
            case "30-39", "30_39":
                convertedSettings["fgm_30_39"] = points
                print("        30-39 yards: \(points) pts")
            case "40-49", "40_49":
                convertedSettings["fgm_40_49"] = points
                print("        40-49 yards: \(points) pts")
            case "50+", "50_plus", "50":
                convertedSettings["fgm_50p"] = points
                print("        50+ yards: \(points) pts")
            default:
                print("        Unknown FG distance key: \(distanceKey) = \(points) pts")
            }
        }
    }
    
    /// Handle position-specific scoring overrides (e.g., TE premium)
    private func handlePositionSpecificOverrides(statId: Int, overrides: [String: Double], convertedSettings: inout [String: Double]) {
        print("      🎯 Processing position-specific overrides:")
        
        // ESPN uses position IDs or abbreviations as keys in pointsOverrides
        // Example for receptions: {"TE": 1.5, "RB": 0.5, "WR": 1.0}
        
        for (positionKey, points) in overrides {
            let normalizedPosition = positionKey.uppercased()
            
            switch normalizedPosition {
            case "TE":
                convertedSettings["rec_te"] = points
                print("        TE receptions: \(points) pts")
            case "RB":
                convertedSettings["rec_rb"] = points
                print("        RB receptions: \(points) pts")
            case "WR":
                convertedSettings["rec_wr"] = points
                print("        WR receptions: \(points) pts")
            case "QB":
                convertedSettings["rec_qb"] = points
                print("        QB receptions: \(points) pts (rare)")
            default:
                print("        Unknown position key: \(positionKey) = \(points) pts")
            }
        }
    }
    
    /// Handle other general overrides - but filter out position-specific ones
    private func handleGeneralOverrides(statId: Int, sleeperKey: String, overrides: [String: Double], convertedSettings: inout [String: Double]) {
        print("      🔧 Processing general overrides for \(sleeperKey):")
        
        for (key, points) in overrides {
            // 🔥 FIXED: Skip position-specific overrides (numeric keys 1-20 are positions)
            if let positionId = Int(key), positionId >= 1 && positionId <= 20 {
                print("        ⏭️ Skipping position-specific override: \(key) (position ID)")
                continue
            }
            
            print("        \(key): \(points) pts")
            
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
        
        // 🔥 OLD PROBLEMATIC CODE (REMOVED):
        // This was zeroing out legitimate league settings like return yards, QB hits, etc.
        // If a commissioner actually enabled these stats, we should respect their league config
        
        /* REMOVED - TRUST LEAGUE SETTINGS:
        switch statId {
        case 206: // pass_air_yd 
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 209: // pass_yac
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 198: // qb_hit
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 201: // pass_drop
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 63: // punt_yd
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 37: // kick_ret_yd
            return 0.0  // 🚨 BAD: What if league actually uses this?
        case 38: // punt_ret_yd
            return 0.0  // 🚨 BAD: What if league actually uses this?
        default:
            break
        }
        */
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
            
            // 🔥 NEW: Apply proper fantasy football scoring math
            let points = calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat)
            totalPoints += points
        }
        
        return totalPoints
    }
    
    /// Calculate points for a specific stat using proper fantasy football math
    private func calculateStatPoints(statKey: String, statValue: Double, pointsPerStat: Double) -> Double {
        // 🔥 GUMBY'S CRITICAL FIX: YARDAGE MATH WAS SYSTEMATICALLY WRONG!
        // OLD BROKEN: floor(statValue / increment) - this undercounted every player
        // NEW CORRECT: Pure fractional multiplication - exact points like ESPN/Sleeper actually do
        
        if isYardStat(statKey) {
            // 🔥 NEW CORRECT MATH: Direct fractional multiplication  
            // Example: 211 pass yards × 0.04 = 8.44 points (not 8.0 points)
            return statValue * pointsPerStat
        }
        
        // Event-based stats (TDs, INTs, etc.) use direct multiplication
        return statValue * pointsPerStat
        
        // 🔥 OLD BROKEN MATH (REMOVED):
        // This was systematically undercounting every player with yards
        /* REMOVED - WRONG MATH:
        if isYardStat(statKey) {
            if pointsPerStat > 0 {
                let increment = 1.0 / pointsPerStat  // 25 yards per point
                let points = floor(statValue / increment) * 1.0  // 🚨 WRONG: floor() loses 0.44 points on 211 yards
                return points
            }
        }
        */
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
        print("📊 ALL SCORING BASES:")
        
        // ESPN leagues
        print("   ESPN Leagues:")
        for (leagueID, basis) in leagueScoringBasis.filter({ espnScoringSettings[$0.key] != nil }) {
            let rawCount = espnScoringSettings[leagueID]?.count ?? 0
            let validatedCount = validatedESPNScoringSettings[leagueID]?.count ?? 0
            print("     \(leagueID): \(basis)")
            print("       Raw: \(rawCount) → Validated: \(validatedCount)")
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
    
    /// 🔥 NEW: Print detailed differential analysis results
    func printDifferentialAnalysisDetails(for leagueID: String) {
        guard let rawSettings = espnScoringSettings[leagueID],
              let validatedSettings = validatedESPNScoringSettings[leagueID] else {
            print("❌ No data for league \(leagueID)")
            return
        }
        
        print("🔬 DIFFERENTIAL ANALYSIS DETAILS: League \(leagueID)")
        print("   Raw Rules: \(rawSettings.count)")
        print("   Validated Rules: \(validatedSettings.count)")
        print("   Filtered Out: \(rawSettings.count - validatedSettings.count)")
        
        print("\n✅ VALIDATED RULES:")
        for (statKey, points) in validatedSettings.sorted(by: { $0.key < $1.key }) {
            let isCore = ESPNScoringBaselines.coreStats.contains(statKey) ? " (CORE)" : ""
            print("     \(statKey): \(points)\(isCore)")
        }
        
        print("\n❌ FILTERED OUT:")
        let filteredOut = rawSettings.filter { validatedSettings[$0.key] == nil }
        for (statKey, points) in filteredOut.sorted(by: { $0.key < $1.key }) {
            print("     \(statKey): \(points)")
        }
        
        print("\n🎯 LEAGUE TYPE ANALYSIS:")
        let leagueType = detectLeagueType(from: rawSettings)
        print("     Detected: \(leagueType)")
        let receptionPoints = rawSettings["rec"] ?? 0.0
        print("     Reception Points: \(receptionPoints)")
    }
    
    /// 🔥 NEW: Test differential analysis against known players
    func testDifferentialAnalysis(for leagueID: String) {
        print("🧪 TESTING DIFFERENTIAL ANALYSIS: League \(leagueID)")
        
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
            print("❌ No validated settings for league \(leagueID)")
            return
        }
        
        for scenario in testScenarios {
            let calculatedPoints = calculatePoints(stats: scenario.stats, scoringSettings: validatedSettings)
            let inRange = calculatedPoints >= scenario.expectedRange.0 && calculatedPoints <= scenario.expectedRange.1
            let status = inRange ? "✅ PASS" : "❌ FAIL"
            
            print("   \(status) \(scenario.name): \(String(format: "%.2f", calculatedPoints)) pts (expected: \(scenario.expectedRange.0)-\(scenario.expectedRange.1))")
            
            // Show breakdown
            for (statKey, statValue) in scenario.stats {
                if let pointsPerStat = validatedSettings[statKey] {
                    let points = calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat)
                    print("     \(statKey): \(statValue) × \(pointsPerStat) = \(String(format: "%.2f", points))")
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
        print("🧹 ScoringManager: All scoring settings cleared")
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