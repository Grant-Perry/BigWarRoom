//
//  ScoreBreakdownModels.swift
//  BigWarRoom
//
//  Models for player fantasy score breakdown display
//

import SwiftUI

/// Model representing a single scoring stat line in the breakdown
struct ScoreBreakdownItem: Identifiable {
    let id = UUID()
    let statName: String
    let statValue: Int
    let pointsPerStat: Double // REVERT: Back to Double for actual calculations
    let totalPoints: Double // REVERT: Back to Double for actual calculations
    
    /// Formatted stat value (e.g., "1", "76", "4")
    var statValueString: String {
        return "\(statValue)"
    }
    
    /// Formatted points per stat (e.g., "10.00", "0.10", "1.00")
    var pointsPerStatString: String {
        return String(format: "%.2f", pointsPerStat)
    }
    
    /// Formatted total points (e.g., "10.00", "7.60", "4.00")
    var totalPointsString: String {
        return String(format: "%.2f", totalPoints)
    }
}

/// Model representing the complete score breakdown for a player
struct PlayerScoreBreakdown {
    let player: FantasyPlayer
    let week: Int
    let items: [ScoreBreakdownItem]
    let totalScore: Double
    let isChoppedLeague: Bool
    let hasRealScoringData: Bool // 🔥 NEW: Track if we have real scoring calculations
    
    init(player: FantasyPlayer, week: Int, items: [ScoreBreakdownItem], totalScore: Double, isChoppedLeague: Bool, hasRealScoringData: Bool = false) {
        self.player = player
        self.week = week
        self.items = items
        self.totalScore = totalScore
        self.isChoppedLeague = isChoppedLeague
        self.hasRealScoringData = hasRealScoringData
    }
    
    /// Formatted total score
    var totalScoreString: String {
        return String(format: "%.2f", totalScore)
    }
    
    /// Player display name for header
    var playerDisplayName: String {
        return player.fullName
    }
    
    /// Week display string
    var weekDisplayString: String {
        return "WEEK \(week)"
    }
    
    /// Check if player has any scoring stats
    var hasStats: Bool {
        return !items.isEmpty
    }
}

/// Factory for creating score breakdowns from player stats
struct ScoreBreakdownFactory {
    
    /// Create a score breakdown from raw player stats
    /// UPDATED: Now handles both Sleeper (with league scoring) and ESPN (with unified manager) properly
    static func createBreakdown(
        for player: FantasyPlayer,
        stats: [String: Double],
        week: Int,
        scoringSystem: ScoringSystem = .ppr,
        isChoppedLeague: Bool = false,
        leagueScoringSettings: [String: Double]? = nil,
        espnScoringSettings: [String: Double]? = nil,
        leagueID: String? = nil, // 🔥 NEW: Add league ID for unified scoring lookup
        leagueSource: LeagueSource? = nil // 🔥 NEW: Add league source for unified scoring lookup
    ) -> PlayerScoreBreakdown {
        
        var items: [ScoreBreakdownItem] = []
        
        // 🔥 PRIORITY 1: UNIFIED SCORING - Use ScoringSettingsManager for both platforms!
        if let leagueID = leagueID, let leagueSource = leagueSource {
            let scoringSettings = ScoringSettingsManager.shared.getScoringSettings(for: leagueID, source: leagueSource)
            
            if let settings = scoringSettings {
                print("🔥 BREAKDOWN: Using \(settings.count) actual \(leagueSource == .espn ? "ESPN" : "Sleeper") scoring settings from unified manager")
                
                // 🔥 DETAILED DEBUG: Print all available stats
                print("🔍 AVAILABLE STATS for \(player.fullName):")
                for (statKey, statValue) in stats.sorted(by: { $0.key < $1.key }) {
                    print("   \(statKey): \(statValue)")
                }
                
                print("🔍 AVAILABLE SCORING RULES:")
                for (statKey, pointsPerStat) in settings.sorted(by: { $0.key < $1.key }) {
                    print("   \(statKey): \(pointsPerStat) pts")
                }
                
                var calculationDetails: [(String, Double, Double, Double)] = []
                
                // Calculate points using league scoring rules
                for (sleeperKey, pointsPerStat) in settings {
                    let statValue = stats[sleeperKey] ?? 0.0
                    if statValue != 0 {
                        let totalPoints = statValue * pointsPerStat
                        let statDisplayName = getStatDisplayName(for: sleeperKey)
                        
                        calculationDetails.append((sleeperKey, statValue, pointsPerStat, totalPoints))
                        
                        print("🧮 CALC: \(statDisplayName) (\(sleeperKey)): \(statValue) × \(pointsPerStat) = \(totalPoints)")
                        
                        items.append(ScoreBreakdownItem(
                            statName: statDisplayName,
                            statValue: Int(statValue),
                            pointsPerStat: pointsPerStat,
                            totalPoints: totalPoints
                        ))
                    } else if pointsPerStat != 0 {
                        // For diagnostics: Warn if the scoring setting exists but the stat is missing/zero.
                        print("⚠️ ESPN: League scores '\(sleeperKey)' but stat value is missing or zero. Stat may not be tracked for this player/game.")
                    }
                }
                
                // Sort by point impact
                items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
                
                let calculatedTotal = items.reduce(0) { $0 + $1.totalPoints }
                
                // 🔥 DETAILED VALIDATION: Check for discrepancy
                let apiTotal = player.currentPoints ?? 0.0
                let discrepancy = calculatedTotal - apiTotal
                
                print("🧮 FINAL CALCULATION:")
                print("   Items total: \(calculatedTotal)")
                print("   API total: \(apiTotal)")
                print("   Discrepancy: \(discrepancy)")
                
                if abs(discrepancy) > 0.01 {
                    print("🚨 \(leagueSource == .espn ? "ESPN" : "SLEEPER") BREAKDOWN: DISCREPANCY DETECTED!")
                    print("   Player: \(player.fullName)")
                    print("   API Total: \(apiTotal)")
                    print("   Calculated: \(calculatedTotal)")  
                    print("   Difference: \(discrepancy)")
                    
                    // 🔥 NEW: Print all calculation details for debugging
                    print("📊 DETAILED CALCULATION:")
                    for (statKey, statValue, pointsPerStat, totalPoints) in calculationDetails.sorted(by: { abs($0.3) > abs($1.3) }) {
                        print("   \(statKey): \(statValue) × \(pointsPerStat) = \(totalPoints)")
                    }
                    
                    // 🔥 SHOW STATS THAT ESPN MIGHT HAVE BUT WE DON'T CALCULATE
                    print("🔍 UNUSED STATS (might be calculated by ESPN):")
                    for (statKey, statValue) in stats.sorted(by: { $0.key < $1.key }) {
                        if statValue != 0 && settings[statKey] == nil {
                            print("   \(statKey): \(statValue) (NO SCORING RULE)")
                        }
                    }
                    
                    // 🔥 SHOW SCORING RULES THAT WE HAVE BUT NO STATS FOR
                    print("🔍 UNUSED SCORING RULES (might have 0 stats):")
                    for (statKey, pointsPerStat) in settings.sorted(by: { $0.key < $1.key }) {
                        if stats[statKey] == nil || stats[statKey] == 0 {
                            print("   \(statKey): \(pointsPerStat) pts (NO STATS)")
                        }
                    }
                }
                
                return PlayerScoreBreakdown(
                    player: player,
                    week: week,
                    items: items,
                    totalScore: calculatedTotal, // 🔥 Use calculated total with REAL league scoring!
                    isChoppedLeague: false,
                    hasRealScoringData: true
                )
            }
        }
        
        // 🔥 PRIORITY 2: FOR CHOPPED LEAGUES - Use provided league scoring settings (UNCHANGED - keep working!)
        if isChoppedLeague {
            let scoringSettings = leagueScoringSettings ?? getEstimatedSleeperScoring()
            
            print("🔥 BREAKDOWN: Using \(scoringSettings.count) actual league scoring settings")
            
            // Show all available stats in breakdown (much more comprehensive)
            for (statKey, statValue) in stats {
                guard statValue != 0, let pointsPerStat = scoringSettings[statKey] else { continue }
                
                let totalPoints = statValue * pointsPerStat
                let statDisplayName = getStatDisplayName(for: statKey)
                
                items.append(ScoreBreakdownItem(
                    statName: statDisplayName,
                    statValue: Int(statValue),
                    pointsPerStat: pointsPerStat,
                    totalPoints: totalPoints
                ))
            }
            
            // Sort items by absolute point value (highest impact first)
            items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
            
            let calculatedTotal = items.reduce(0) { $0 + $1.totalPoints }
            
            return PlayerScoreBreakdown(
                player: player,
                week: week,
                items: items,
                totalScore: calculatedTotal, // ✅ Use calculated total with REAL league scoring!
                isChoppedLeague: true,
                hasRealScoringData: true // 🔥 NEW: Chopped leagues have real scoring data
            )
        }
        
        // 🔥 PRIORITY 3: LEGACY - FOR ESPN LEAGUES with provided scoring settings (fallback)
        else if let espnScoring = espnScoringSettings {
            print("🔥 BREAKDOWN: Using \(espnScoring.count) actual ESPN scoring settings (legacy)")
            
            // 🔥 FIX: ESPN scoring is now mapped to Sleeper keys, so match directly
            for (sleeperKey, pointsPerStat) in espnScoring {
                if let statValue = stats[sleeperKey], statValue != 0 {
                    let totalPoints = statValue * pointsPerStat
                    let statDisplayName = getStatDisplayName(for: sleeperKey)
                    
                    items.append(ScoreBreakdownItem(
                        statName: statDisplayName,
                        statValue: Int(statValue),
                        pointsPerStat: pointsPerStat,
                        totalPoints: totalPoints
                    ))
                }
            }
            
            // Sort by point impact
            items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
            
            let calculatedTotal = items.reduce(0) { $0 + $1.totalPoints }
            
            return PlayerScoreBreakdown(
                player: player,
                week: week,
                items: items,
                totalScore: player.currentPoints ?? calculatedTotal, // 🔥 FORCE: Use ESPN's API total as definitive for exact match
                isChoppedLeague: false,
                hasRealScoringData: true
            )
        }
        
        // 🔥 PRIORITY 4: FOR ESPN LEAGUES WITHOUT SCORING SETTINGS - Show simplified breakdown
        else if player.espnID != nil {
            print("🔥 BREAKDOWN: ESPN league without scoring settings - showing simplified breakdown")
            
            // Create a single summary item showing the total score
            if let totalScore = player.currentPoints, totalScore > 0 {
                items.append(ScoreBreakdownItem(
                    statName: "Fantasy Points Earned",
                    statValue: 1,
                    pointsPerStat: totalScore,
                    totalPoints: totalScore
                ))
            }
            
            return PlayerScoreBreakdown(
                player: player,
                week: week,
                items: items,
                totalScore: player.currentPoints ?? 0.0, // Use ESPN's calculated total
                isChoppedLeague: false,
                hasRealScoringData: false // No detailed scoring breakdown available
            )
        }
        
        // 🔥 PRIORITY 5: FOR OTHER LEAGUES - Show stat breakdown with estimates but use actual API score for total
        else {
            // Create breakdown items for display (with estimated standard scoring for reference)
            let estimatedScoring = getStandardScoringEstimates()
            
            // Only show meaningful stats (non-zero values)
            for (statKey, statValue) in stats {
                guard statValue != 0 else { continue }
                
                let statDisplayName = getStatDisplayName(for: statKey)
                let estimatedPointsPerStat = estimatedScoring[statKey] ?? 0.0
                let estimatedTotalPoints = statValue * estimatedPointsPerStat
                
                items.append(ScoreBreakdownItem(
                    statName: statDisplayName,
                    statValue: Int(statValue),
                    pointsPerStat: estimatedPointsPerStat,
                    totalPoints: estimatedTotalPoints
                ))
            }
            
            // Sort by estimated point impact
            items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
            
            // 🔥 FIXED: Use actual player score (from ESPN/Sleeper API) as the definitive total
            return PlayerScoreBreakdown(
                player: player,
                week: week,
                items: items,
                totalScore: player.currentPoints ?? 0.0, // ✅ Use the REAL score from API!
                isChoppedLeague: false,
                hasRealScoringData: false // 🔥 NEW: No real scoring calculation, just estimates
            )
        }
    }
    
    /// Find matching stat value in player stats by attempting multiple name variations
    private static func findMatchingStatValue(statName: String, in stats: [String: Double]) -> Double? {
        print("🐛 DEBUG: findMatchingStatValue looking for '\(statName)' in stats with keys: \(Array(stats.keys))")
        
        // Try exact match first
        if let value = stats[statName] {
            print("🐛 DEBUG: Found exact match for '\(statName)' = \(value)")
            return value
        }
        
        // Try mapping stat display name to sleeper key
        let lowerStatName = statName.lowercased()
        print("🐛 DEBUG: Trying lowercase match for '\(lowerStatName)'")
        
        // Common mappings
        let mappings: [String: String] = [
            "passing td": "pass_td",
            "passing yards": "pass_yd", 
            "rushing yards": "rush_yd",
            "rushing td": "rush_td",
            "reception": "rec",
            "receiving yards": "rec_yd",
            "receiving td": "rec_td",
            "interception": "pass_int",
            "fumble lost": "fum_lost",
            "field goal made": "fgm",
            "extra point made": "xpm",
            "passing 1st down": "pass_fd",
            "rushing 1st down": "rush_fd",
            "receiving 1st down": "rec_fd"
        ]
        
        if let sleeperKey = mappings[lowerStatName] {
            print("🐛 DEBUG: Found mapping: '\(lowerStatName)' -> '\(sleeperKey)'")
            if let value = stats[sleeperKey] {
                print("🐛 DEBUG: Found stats value for '\(sleeperKey)' = \(value)")
                return value
            } else {
                print("🐛 DEBUG: No stats value found for mapped key '\(sleeperKey)'")
            }
        } else {
            print("🐛 DEBUG: No mapping found for '\(lowerStatName)'")
        }
        
        print("🐛 DEBUG: No match found for '\(statName)'")
        return nil
    }
    
    /// Get estimated standard scoring (for reference in regular leagues)
    private static func getStandardScoringEstimates() -> [String: Double] {
        return [
            // Passing
            "pass_yd": 0.04,      // 1 point per 25 passing yards
            "pass_td": 4.0,       // 4 points per passing TD (ESPN standard)
            "pass_int": -1.0,     // -1 point per interception
            "pass_fd": 1.0,       // 1 point per passing 1st down (bonus leagues)
            "pass_cmp": 0.0,      // Usually no points for completions in standard
            "pass_inc": 0.0,      // Usually no penalty for incompletions in standard
            
            // Rushing
            "rush_yd": 0.1,       // 1 point per 10 rushing yards
            "rush_td": 6.0,       // 6 points per rushing TD
            "rush_fd": 0.0,       // Usually no bonus for 1st downs in standard
            
            // Receiving
            "rec": 1.0,           // 1 point per reception (PPR)
            "rec_yd": 0.1,        // 1 point per 10 receiving yards
            "rec_td": 6.0,        // 6 points per receiving TD
            "rec_fd": 0.0,       // Usually no bonus for 1st downs in standard
            
            // Fumbles
            "fum": 0.0,           // Usually no penalty for fumbles in standard
            "fum_lost": -2.0,     // -2 points per fumble lost
            
            // Kicking
            "fgm": 3.0,           // 3 points per field goal made
            "fgmiss": 0.0,        // Usually no penalty for misses in standard
            "xpm": 1.0,           // 1 point per extra point made
            
            // Defense
            "def_td": 6.0,        // 6 points per defensive TD
            "def_int": 2.0,       // 2 points per interception
            "def_fum_rec": 2.0,   // 2 points per fumble recovery
            "def_sack": 1.0,      // 1 point per sack
            "def_safe": 2.0,      // 2 points per safety
        ]
    }
    
    /// Get estimated Sleeper scoring settings (fallback when league settings unavailable)
    private static func getEstimatedSleeperScoring() -> [String: Double] {
        return [
            // Passing
            "pass_yd": 0.04,      // 1 point per 25 passing yards
            "pass_td": 4.0,       // 4 points per passing TD
            "pass_int": -1.0,     // -1 point per interception
            "pass_fd": 1.0,       // 1 point per passing 1st down
            
            // Rushing
            "rush_yd": 0.1,       // 1 point per 10 rushing yards
            "rush_td": 6.0,       // 6 points per rushing TD
            "rush_fd": 1.0,       // 1 point per rushing 1st down
            
            // Receiving
            "rec": 1.0,           // 1 point per reception (PPR)
            "rec_yd": 0.1,        // 1 point per 10 receiving yards
            "rec_td": 6.0,        // 6 points per receiving TD
            "rec_fd": 1.0,        // 1 point per receiving 1st down
            
            // Fumbles
            "fum": -1.0,          // -1 point per fumble
            "fum_lost": -2.0,     // -2 points per fumble lost
            
            // Kicking
            "fgm": 3.0,           // 3 points per field goal made
            "fgmiss": -1.0,       // -1 point per field goal missed
            "xpm": 1.0,           // 1 point per extra point made
            
            // Defense
            "def_td": 6.0,        // 6 points per defensive TD
            "def_int": 2.0,       // 2 points per interception
            "def_fum_rec": 2.0,   // 2 points per fumble recovery
            "def_sack": 1.0,      // 1 point per sack
            "def_safe": 2.0,      // 2 points per safety
        ]
    }
    
    /// Get human-readable display name for stat key
    private static func getStatDisplayName(for statKey: String) -> String {
        switch statKey {
        // Passing
        case "pass_yd": return "Passing Yards"
        case "pass_td": return "Passing TD"
        case "pass_int": return "Interception"
        case "pass_fd": return "Passing 1st Down"
        case "pass_cmp": return "Pass Completed"
        case "pass_inc": return "Incomplete Pass"
        case "pass_40": return "40+ Yard Completion Bonus"
        case "pass_td_40p": return "40+ Yard Pass TD Bonus"
        case "pass_td_50p": return "50+ Yard Pass TD Bonus"
        
        // Rushing
        case "rush_yd": return "Rushing Yards"
        case "rush_td": return "Rushing TD"
        case "rush_fd": return "Rushing 1st Down"
        case "rush_40": return "40+ Yard Rush Bonus"
        
        // Receiving
        case "rec": return "Reception"
        case "rec_yd": return "Receiving Yards"
        case "rec_td": return "Receiving TD"
        case "rec_fd": return "Receiving 1st Down"
        case "rec_40": return "40+ Yard Reception Bonus"
        
        // Fumbles
        case "fum": return "Fumble"
        case "fum_lost": return "Fumble Lost"
        case "fum_rec": return "Fumble Recovery"
        
        // Kicking
        case "fgm": return "Field Goal Made"
        case "fgmiss": return "Field Goal Missed"
        case "xpm": return "Extra Point Made"
        case "xpmiss": return "Extra Point Missed"
        
        // Defense
        case "def_td": return "Defensive TD"
        case "def_int": return "Interception"
        case "def_fum_rec": return "Fumble Recovery"
        case "def_sack": return "Sack"
        case "def_safe": return "Safety"
        
        // Default: Clean up the key name
        default:
            return statKey.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// Scoring system type
enum ScoringSystem {
    case standard
    case halfPPR
    case ppr
}