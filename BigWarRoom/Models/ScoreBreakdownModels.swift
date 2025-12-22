//
//  ScoreBreakdownModels.swift
//  BigWarRoom
//
//  Models for player fantasy score breakdown display
//

import Foundation

/// Model representing a single scoring stat line in the breakdown
struct ScoreBreakdownItem: Identifiable {
    let id = UUID()
    let statName: String
    let statValue: Double
    let pointsEarned: Double
    let description: String
    
    // Legacy: Keep old properties for backward compatibility
    var pointsPerStat: Double { pointsEarned != 0.0 ? pointsEarned / statValue : 0.0 }
    var totalPoints: Double { pointsEarned }
    
    /// Initialize with new structure
    init(statName: String, statValue: Double, pointsEarned: Double, description: String) {
        self.statName = statName
        self.statValue = statValue
        self.pointsEarned = pointsEarned
        self.description = description
    }
    
    /// Legacy initializer for backward compatibility
    init(statName: String, statValue: Double, pointsPerStat: Double, totalPoints: Double) {
        self.statName = statName
        self.statValue = statValue
        self.pointsEarned = totalPoints
        self.description = ""
    }
    
    /// Formatted stat value (e.g., "1", "76.5", "4")
    var statValueString: String {
        // Show fractional values when they're not whole numbers
        return statValue.truncatingRemainder(dividingBy: 1) == 0 ? 
            String(format: "%.0f", statValue) : 
            String(format: "%.1f", statValue)
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
    let hasRealScoringData: Bool
    let leagueContext: LeagueContext?
    let leagueName: String?
    
    init(player: FantasyPlayer, week: Int, items: [ScoreBreakdownItem], totalScore: Double, isChoppedLeague: Bool, hasRealScoringData: Bool = false, leagueContext: LeagueContext? = nil, leagueName: String? = nil) {
        self.player = player
        self.week = week
        self.items = items
        self.totalScore = totalScore
        self.isChoppedLeague = isChoppedLeague
        self.hasRealScoringData = hasRealScoringData
        self.leagueContext = leagueContext
        self.leagueName = leagueName
    }
    
    /// Helper to add league name after creation
    func withLeagueName(_ name: String) -> PlayerScoreBreakdown {
        return PlayerScoreBreakdown(
            player: self.player,
            week: self.week,
            items: self.items,
            totalScore: self.totalScore,
            isChoppedLeague: self.isChoppedLeague,
            hasRealScoringData: self.hasRealScoringData,
            leagueContext: self.leagueContext,
            leagueName: name
        )
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
    
    // MARK: - Standardized Interface
    
    /// **STANDARDIZED METHOD** - Use this for all new code
    /// Creates a score breakdown with automatic stats lookup and league scoring detection
    static func createBreakdown(
        for player: FantasyPlayer,
        week: Int? = nil,
        localStatsProvider: LocalStatsProvider? = nil,
        leagueContext: LeagueContext? = nil,
        allLivePlayersViewModel: AllLivePlayersViewModel? = nil
    ) -> PlayerScoreBreakdown {
        
        // Get the week, defaulting to current selected week
        let effectiveWeek = week ?? WeekSelectionManager.shared.selectedWeek
        
        DebugPrint(mode: .scoring, "🔍 ScoreBreakdown: Creating breakdown for \(player.fullName) (ESPN ID: \(player.id)), week \(effectiveWeek)")
        
        // 🎯 NEW: Use canonical ESPN→Sleeper ID mapping
        let canonicalSleeperID = ESPNSleeperIDCanonicalizer.shared.getCanonicalSleeperID(forESPNID: player.id)
        DebugPrint(mode: .scoring, "🔍 ScoreBreakdown: Canonical Sleeper ID: \(canonicalSleeperID)")
        
        // 🔥 NEW: Try direct lookup first using the player.sleeperID if available
        var sleeperPlayer: SleeperPlayer? = PlayerDirectoryStore.shared.player(for: canonicalSleeperID)
        
        // 🔥 FALLBACK: If canonical mapping didn't work, try searching by name
        if sleeperPlayer == nil {
            DebugPrint(mode: .scoring, "⚠️ ScoreBreakdown: No mapping found, searching by name: \(player.fullName)")
            let normalizedSearchName = player.fullName.lowercased()
            sleeperPlayer = PlayerDirectoryStore.shared.players.values.first { sleeperPlayer in
                sleeperPlayer.fullName.lowercased() == normalizedSearchName
            }
            
            if let foundPlayer = sleeperPlayer {
                DebugPrint(mode: .scoring, "✅ ScoreBreakdown: Found player by name search: \(foundPlayer.fullName), ID: \(foundPlayer.playerID)")
            }
        }
        
        guard let sleeperPlayer = sleeperPlayer else {
            DebugPrint(mode: .scoring, "❌ ScoreBreakdown: Could not find SleeperPlayer for ID \(canonicalSleeperID) or name '\(player.fullName)'")
            return createEmptyBreakdown(player: player, week: effectiveWeek)
        }
        
        DebugPrint(mode: .scoring, "✅ ScoreBreakdown: Found SleeperPlayer: \(sleeperPlayer.fullName), playerID: \(sleeperPlayer.playerID)")
        
        // 🔥 FIX: Pass PlayerStatsCache to StatsFacade so it can check cache
        guard let stats = StatsFacade.getPlayerStats(
            playerID: sleeperPlayer.playerID,
            week: effectiveWeek,
            localStatsProvider: localStatsProvider,
            allLivePlayersViewModel: allLivePlayersViewModel,
            playerStatsCache: PlayerStatsCache.shared
        ) else {
            DebugPrint(mode: .scoring, "❌ ScoreBreakdown: No stats found for playerID \(sleeperPlayer.playerID), week \(effectiveWeek)")
            return createEmptyBreakdown(player: player, week: effectiveWeek)
        }
        
        DebugPrint(mode: .scoring, "✅ ScoreBreakdown: Found stats (\(stats.count) items): \(stats)")
        
        // Always create consistent breakdown using player's authoritative total
        return createConsistentBreakdown(
            player: player,
            stats: stats,
            week: effectiveWeek,
            leagueContext: leagueContext
        )
    }
    
    // MARK: - Legacy Interface (For Backward Compatibility)
    
    /// **LEGACY METHOD** - Kept for backward compatibility, but prefer the standardized method above
    static func createBreakdown(
        for player: FantasyPlayer,
        stats: [String: Double],
        week: Int,
        scoringSystem: ScoringSystem = .ppr,
        isChoppedLeague: Bool = false,
        leagueScoringSettings: [String: Double]? = nil,
        espnScoringSettings: [String: Double]? = nil,  // Deprecated
        leagueID: String? = nil,
        leagueSource: LeagueSource? = nil
    ) -> PlayerScoreBreakdown {
        
        // Convert to new interface
        var leagueContext: LeagueContext? = nil
        
        if let leagueID = leagueID, let leagueSource = leagueSource {
            leagueContext = LeagueContext(
                leagueID: leagueID,
                source: leagueSource,
                isChopped: isChoppedLeague,
                customScoringSettings: leagueScoringSettings ?? espnScoringSettings
            )
        } else if isChoppedLeague {
            leagueContext = LeagueContext(
                leagueID: "chopped",
                source: .sleeper,
                isChopped: true,
                customScoringSettings: leagueScoringSettings
            )
        }
        
        // Use the unified scoring approach
        return createWithProvidedStats(
            player: player,
            stats: stats,
            week: week,
            leagueContext: leagueContext
        )
    }
    
    // MARK: - Internal Implementation Methods
    
    private static func createWithUnifiedScoring(
        player: FantasyPlayer,
        stats: [String: Double],
        week: Int,
        leagueID: String,
        leagueSource: LeagueSource,
        isChoppedLeague: Bool,
        customScoringSettings: [String: Double]?
    ) -> PlayerScoreBreakdown {
        
        var items: [ScoreBreakdownItem] = []
        var scoringSettings: [String: Double]?
        var hasRealScoringData = false
        
        // Priority 1: Use custom scoring settings (for chopped leagues)
        if isChoppedLeague, let customScoring = customScoringSettings {
            scoringSettings = customScoring
            hasRealScoringData = true
            print("Using custom chopped league scoring (\(customScoring.count) rules)")
        }
        // Priority 2: Use unified scoring manager
        else if let unifiedScoring = ScoringSettingsManager.shared.getScoringSettings(for: leagueID, source: leagueSource) {
            scoringSettings = unifiedScoring
            hasRealScoringData = true
            print("Using unified \(leagueSource) scoring (\(unifiedScoring.count) rules)")
        }
        // Priority 3: Fallback to estimates
        else {
            scoringSettings = getEstimatedSleeperScoring()
            hasRealScoringData = false
            print("Using estimated scoring (no league rules found)")
        }
        
        // Calculate breakdown using the selected scoring with proper position handling
        if let settings = scoringSettings {
            for (statKey, statValue) in stats {
                guard statValue != 0 else { continue }
                
                // Use enhanced calculation that considers player position
                let totalPoints = calculateAdvancedStatPoints(
                    player: player,
                    statKey: statKey,
                    statValue: statValue,
                    scoringSettings: settings
                )
                
                // Only create breakdown items for stats that actually score points
                if totalPoints != 0 {
                    let pointsPerStat = totalPoints / statValue // Calculate effective rate
                    let statDisplayName = getStatDisplayName(for: statKey)
                    
                    items.append(ScoreBreakdownItem(
                        statName: statDisplayName,
                        statValue: statValue,
                        pointsPerStat: pointsPerStat,
                        totalPoints: totalPoints
                    ))
                }
            }
        }
        
        items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
        let calculatedTotal = items.reduce(0) { $0 + $1.totalPoints }
        
        return PlayerScoreBreakdown(
            player: player,
            week: week,
            items: items,
            totalScore: hasRealScoringData ? calculatedTotal : (player.currentPoints ?? calculatedTotal),
            isChoppedLeague: isChoppedLeague,
            hasRealScoringData: hasRealScoringData
        )
    }
    
    private static func createWithProvidedStats(
        player: FantasyPlayer,
        stats: [String: Double],
        week: Int,
        leagueContext: LeagueContext?
    ) -> PlayerScoreBreakdown {
        
        if let context = leagueContext {
            return createWithUnifiedScoring(
                player: player,
                stats: stats,
                week: week,
                leagueID: context.leagueID,
                leagueSource: context.source,
                isChoppedLeague: context.isChopped,
                customScoringSettings: context.customScoringSettings
            )
        } else {
            return createWithEstimatedScoring(player: player, stats: stats, week: week)
        }
    }
    
    private static func createWithEstimatedScoring(
        player: FantasyPlayer,
        stats: [String: Double],
        week: Int
    ) -> PlayerScoreBreakdown {
        
        var items: [ScoreBreakdownItem] = []
        let estimatedScoring = getEstimatedSleeperScoring()
        
        for (statKey, statValue) in stats {
            guard statValue != 0, let pointsPerStat = estimatedScoring[statKey] else { continue }
            
            let totalPoints = calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat)
            let statDisplayName = getStatDisplayName(for: statKey)
            
            items.append(ScoreBreakdownItem(
                statName: statDisplayName,
                statValue: statValue,
                pointsPerStat: pointsPerStat,
                totalPoints: totalPoints
            ))
        }
        
        items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
        
        return PlayerScoreBreakdown(
            player: player,
            week: week,
            items: items,
            totalScore: player.currentPoints ?? 0.0,
            isChoppedLeague: false,
            hasRealScoringData: false
        )
    }
    
    private static func createEmptyBreakdown(player: FantasyPlayer, week: Int) -> PlayerScoreBreakdown {
        return PlayerScoreBreakdown(
            player: player,
            week: week,
            items: [],
            totalScore: player.currentPoints ?? 0.0,
            isChoppedLeague: false,
            hasRealScoringData: false
        )
    }
    
    /// Calculate points for a specific stat using proper fantasy football math
    /// This handles the difference between yard-based stats and event-based stats
    private static func calculateStatPoints(statKey: String, statValue: Double, pointsPerStat: Double) -> Double {
        // CORRECT MATH: Direct fractional multiplication
        // Example: 211 pass yards × 0.04 = 8.44 points (not 8.0 points)
        
        if isYardStat(statKey) {
            // Direct fractional multiplication  
            return statValue * pointsPerStat
        }
        
        // Event-based stats (TDs, INTs, etc.) use direct multiplication
        return statValue * pointsPerStat
    }
    
    /// Enhanced calculation that handles advanced ESPN scoring rules
    /// - Parameters:
    ///   - player: The fantasy player (for position-specific rules)
    ///   - statKey: The stat key (e.g., "fgm", "rec")
    ///   - statValue: The stat value
    ///   - scoringSettings: All available scoring settings including advanced rules
    /// - Returns: Points earned for this stat
    private static func calculateAdvancedStatPoints(
        player: FantasyPlayer,
        statKey: String,
        statValue: Double,
        scoringSettings: [String: Double]
    ) -> Double {
        
        // First check for standard scoring rule
        if let standardPoints = scoringSettings[statKey], standardPoints != 0.0 {
            return calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: standardPoints)
        }
        
        // Handle advanced field goal distance scoring
        if statKey == "fgm" && statValue > 0 {
            return calculateFieldGoalPoints(makes: Int(statValue), scoringSettings: scoringSettings)
        }
        
        // Handle position-specific reception scoring (TE premium, etc.)
        if statKey == "rec" && statValue > 0 {
            return calculatePositionSpecificReceptionPoints(
                player: player,
                receptions: statValue,
                scoringSettings: scoringSettings
            )
        }
        
        // For stats with no base scoring, return 0 (don't apply incorrect rules)
        return 0.0
    }
    
    /// Calculate field goal points using distance-based scoring if available
    private static func calculateFieldGoalPoints(makes: Int, scoringSettings: [String: Double]) -> Double {
        // Check if we have distance-specific FG scoring rules
        let distanceRules = [
            "fgm_0_19": scoringSettings["fgm_0_19"],
            "fgm_20_29": scoringSettings["fgm_20_29"],
            "fgm_30_39": scoringSettings["fgm_30_39"],
            "fgm_40_49": scoringSettings["fgm_40_49"],
            "fgm_50p": scoringSettings["fgm_50p"]
        ].compactMapValues { $0 }
        
        if !distanceRules.isEmpty {
            // For now, use the most common range (30-39) as default
            // This could be enhanced with actual game data to determine distances
            let defaultPoints = distanceRules["fgm_30_39"] ?? distanceRules.values.first ?? 3.0
            return Double(makes) * defaultPoints
        }
        
        // Fallback to standard FG scoring
        let standardPoints = scoringSettings["fgm"] ?? 3.0
        return Double(makes) * standardPoints
    }
    
    /// Calculate reception points using position-specific scoring if available
    private static func calculatePositionSpecificReceptionPoints(
        player: FantasyPlayer,
        receptions: Double,
        scoringSettings: [String: Double]
    ) -> Double {
        
        let position = player.position.uppercased()
        
        // Check for position-specific reception scoring
        let positionSpecificKey = "rec_\(position.lowercased())"
        if let positionPoints = scoringSettings[positionSpecificKey] {
            return receptions * positionPoints
        }
        
        // Fallback to standard reception scoring
        let standardPoints = scoringSettings["rec"] ?? 1.0
        return receptions * standardPoints
    }
    
    /// Calculate points for other advanced scoring rules
    private static func calculateOtherAdvancedPoints(
        statKey: String,
        statValue: Double,
        scoringSettings: [String: Double]
    ) -> Double? {
        
        // Look for advanced scoring rules related to this stat
        let advancedRules = scoringSettings.filter { key, _ in
            key.hasPrefix(statKey + "_")
        }
        
        if !advancedRules.isEmpty {
            // For now, just sum all the advanced rule points
            // This could be made more sophisticated based on specific rule types
            let totalAdvancedPoints = advancedRules.values.reduce(0, +)
            return statValue * (totalAdvancedPoints / Double(advancedRules.count))
        }
        
        return nil
    }
    
    /// Check if a stat is yard-based and needs increment calculation
    private static func isYardStat(_ statKey: String) -> Bool {
        let yardStats = [
            "pass_yd", "rush_yd", "rec_yd", 
            "def_int_yd", "def_fum_rec_yd", 
            "kick_ret_yd", "punt_ret_yd"
        ]
        return yardStats.contains(statKey)
    }
    
    /// Find matching stat value in player stats by attempting multiple name variations
    private static func findMatchingStatValue(statName: String, in stats: [String: Double]) -> Double? {
        // Try exact match first
        if let value = stats[statName] {
            return value
        }
        
        // Try mapping stat display name to sleeper key
        let lowerStatName = statName.lowercased()
        
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
            if let value = stats[sleeperKey] {
                return value
            }
        }
        
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
        case "pass_2pt": return "2-Point Conversion Pass"
        case "pass_rz_att": return "Red Zone Pass Attempt"
        
        // Rushing
        case "rush_yd": return "Rushing Yards"
        case "rush_td": return "Rushing TD"
        case "rush_fd": return "Rushing 1st Down"
        case "rush_40": return "40+ Yard Rush Bonus"
        case "rush_2pt": return "2-Point Conversion Rush"
        case "rush_rz_att": return "Red Zone Rush Attempt"
        case "rush_att": return "Rushing Attempts"
        
        // Receiving
        case "rec": return "Reception"
        case "rec_yd": return "Receiving Yards"
        case "rec_td": return "Receiving TD"
        case "rec_fd": return "Receiving 1st Down"
        case "rec_40": return "40+ Yard Reception Bonus"
        case "rec_2pt": return "2-Point Conversion Reception"
        case "rec_tgt": return "Target"
        case "rec_rz_tgt": return "Red Zone Target"
        
        // Fumbles
        case "fum": return "Fumble"
        case "fum_lost": return "Fumble Lost"
        case "fum_rec": return "Fumble Recovery"
        case "fum_rec_td": return "Fumble Recovery TD"
        case "int_td": return "Interception Return TD"
        
        // Kicking
        case "fgm": return "Field Goal Made"
        case "fgmiss": return "Field Goal Missed"
        case "xpm": return "Extra Point Made"
        case "xpmiss": return "Extra Point Missed"
        case "fga_0_19": return "FG Attempt 0-19"
        case "fga_20_29": return "FG Attempt 20-29"
        case "fga_30_39": return "FG Attempt 30-39"
        case "fga_40_49": return "FG Attempt 40-49"
        case "fga_50p": return "FG Attempt 50+"
        case "fga": return "Field Goal Attempts"
        
        // Punting
        case "punt_in20": return "Punt Inside 20"
        case "punt_att": return "Punt Attempts"
        
        // Defense/Special Teams
        case "def_td": return "Defensive TD"
        case "def_int": return "Interception"
        case "def_fum_rec": return "Fumble Recovery"
        case "def_sack": return "Sack"
        case "def_safe": return "Safety"
        case "def_tkl": return "Tackle"
        case "def_ast": return "Assisted Tackle"
        case "def_solo": return "Solo Tackle"
        case "def_comb": return "Combined Tackles"
        case "def_stf": return "Defensive Stuff"
        case "def_pass_def": return "Pass Defended"
        case "def_int_yd": return "Interception Return Yards"
        case "def_fum_rec_yd": return "Fumble Recovery Yards"
        case "def_fum_force": return "Forced Fumble"
        case "def_tkl_loss": return "Tackle for Loss"
        case "st_td": return "Special Teams TD"
        case "st_fum_rec": return "Special Teams Fumble Recovery"
        case "st_ff": return "Special Teams Forced Fumble"
        case "blk_kick": return "Blocked Kick"
        case "blk_punt": return "Blocked Punt"
        case "punt_ret_td": return "Punt Return TD"
        case "kick_ret_td": return "Kick Return TD"
        case "kick_ret_att": return "Kick Return Attempts"
        case "punt_ret_att": return "Punt Return Attempts"
        
        // Add unknown stat 130
        case "unknown_130": return "Unknown Stat 130"
        
        // Default: Clean up the key name
        default:
            return statKey.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    /// Create transparent breakdown using authoritative total (Option 2 approach)
    /// Shows stats breakdown with point calculations for reference, but uses official total
    static func createTransparentBreakdown(
        for player: FantasyPlayer,
        week: Int,
        authoritativeTotal: Double,
        localStatsProvider: LocalStatsProvider? = nil,
        leagueContext: LeagueContext
    ) -> PlayerScoreBreakdown? {
        
        // Get player stats (for display calculation)
        var allStats: [String: Double] = [:]
        
        // Try local stats first via StatsFacade
        if let stats = StatsFacade.getPlayerStats(
            playerID: player.id, 
            week: week,
            localStatsProvider: localStatsProvider
        ) {
            allStats = stats
        }
        
        // Get smart filtered scoring settings for this league context
        var scoringSettings: [String: Double] = [:]
        
        if let customScoring = leagueContext.customScoringSettings {
            scoringSettings = customScoring
        } else if let leagueScoring = ScoringSettingsManager.shared.getScoringSettings(for: leagueContext.leagueID, source: leagueContext.source) {
            scoringSettings = leagueScoring
        } else {
            // Fallback to estimated scoring
            scoringSettings = getEstimatedSleeperScoring()
        }
        
        // Filter out zero/irrelevant stats for cleaner display
        let relevantStats = allStats.filter { key, value in
            value > 0.0 && isRelevantDisplayStat(key)
        }
        
        // Convert stats to breakdown items with point calculations for reference
        let breakdownItems = relevantStats.compactMap { statKey, statValue -> ScoreBreakdownItem? in
            let displayName = StatDisplayHelper.getDisplayName(for: statKey)
            
            // Calculate points for display (but won't be used for total)
            let pointsPerStat = scoringSettings[statKey] ?? 0.0
            let calculatedPoints = pointsPerStat > 0.0 ? 
                calculateStatPoints(statKey: statKey, statValue: statValue, pointsPerStat: pointsPerStat) : 0.0
            
            return ScoreBreakdownItem(
                statName: displayName,
                statValue: statValue,
                pointsPerStat: pointsPerStat,
                totalPoints: calculatedPoints
            )
        }
        .filter { $0.pointsPerStat > 0.0 } // Only show stats that have scoring rules
        .sorted { abs($0.totalPoints) > abs($1.totalPoints) } // Sort by points value
        
        return PlayerScoreBreakdown(
            player: player,
            week: week,
            items: breakdownItems,
            totalScore: authoritativeTotal, // USE AUTHORITATIVE TOTAL ONLY
            isChoppedLeague: leagueContext.isChopped,
            hasRealScoringData: false // Mark as reference only
        )
    }
    
    // Always create consistent breakdown format
    private static func createConsistentBreakdown(
        player: FantasyPlayer,
        stats: [String: Double],
        week: Int,
        leagueContext: LeagueContext?
    ) -> PlayerScoreBreakdown {
        
        var items: [ScoreBreakdownItem] = []
        var scoringSettings: [String: Double] = [:]
        // Note: confidenceLevel tracking removed - was never used
        
        // Try to get actual league scoring settings
        if let context = leagueContext {
            // Priority 1 - Use customScoringSettings if provided (regardless of league type)
            if let customScoring = context.customScoringSettings, !customScoring.isEmpty {
                scoringSettings = customScoring
            }
            // Priority 2 - Try ScoringSettingsManager as fallback
            else if let leagueScoring = ScoringSettingsManager.shared.getScoringSettings(
                for: context.leagueID, 
                source: context.source
            ) {
                scoringSettings = leagueScoring
            }
        }
        
        // Fallback to standard scoring if no league settings found
        if scoringSettings.isEmpty {
            scoringSettings = getEstimatedSleeperScoring()
        }
        
        // Create breakdown items for all relevant stats
        for (statKey, statValue) in stats {
            guard statValue != 0 else { continue }
            
            // Get points per stat (fallback to 0 if not found)
            let pointsPerStat = scoringSettings[statKey] ?? 0.0
            
            // Only include stats that have scoring rules OR are important display stats
            guard pointsPerStat != 0.0 || isImportantDisplayStat(statKey) else { continue }
            
            let totalPoints = calculateStatPoints(
                statKey: statKey, 
                statValue: statValue, 
                pointsPerStat: pointsPerStat
            )
            
            let statDisplayName = getStatDisplayName(for: statKey)
            
            items.append(ScoreBreakdownItem(
                statName: statDisplayName,
                statValue: statValue,
                pointsPerStat: pointsPerStat,
                totalPoints: totalPoints
            ))
        }
        
        // Sort by points value (highest first)
        items.sort { abs($0.totalPoints) > abs($1.totalPoints) }
        
        // Always use player's authoritative total, not our calculation
        let authoritativeTotal = player.currentPoints ?? 0.0
        
        return PlayerScoreBreakdown(
            player: player,
            week: week,
            items: items,
            totalScore: authoritativeTotal, // Always use API total
            isChoppedLeague: leagueContext?.isChopped ?? false,
            hasRealScoringData: true, // Always show full breakdown format
            leagueContext: leagueContext,
            leagueName: nil // Will be set by caller
        )
    }
    
    /// Check if stat should be shown even without scoring rules (for display purposes)
    private static func isImportantDisplayStat(_ statKey: String) -> Bool {
        let displayStats: Set<String> = [
            "pass_td", "pass_yd", "pass_cmp", "pass_int",
            "rush_td", "rush_yd", "rush_att",
            "rec_td", "rec_yd", "rec",
            "fgm", "xpm", "fum_lost"
        ]
        return displayStats.contains(statKey)
    }
    
    /// Filter stats that are relevant for display purposes
    private static func isRelevantDisplayStat(_ statKey: String) -> Bool {
        // Only show stats that fantasy users care about seeing
        let relevantStats: Set<String> = [
            // Core offensive stats
            "pass_yd", "pass_td", "pass_int", "pass_cmp", "pass_att",
            "rush_yd", "rush_td", "rush_att", 
            "rec", "rec_yd", "rec_td", "rec_tgt",
            
            // Kicking
            "fgm", "fga", "xpm", "xpmiss",
            "fgm_0_19", "fgm_20_29", "fgm_30_39", "fgm_40_49", "fgm_50p",
            
            // Defense/ST 
            "def_int", "def_fum_rec", "def_sack", "def_td", "def_safe",
            "st_td", "blk_kick",
            
            // Fumbles
            "fum", "fum_lost",
            
            // Bonus categories
            "pass_2pt", "rush_2pt", "rec_2pt",
            "pass_40", "rush_40", "rec_40"
        ]
        
        return relevantStats.contains(statKey)
    }
    
    /// Get stat importance for sorting (lower = more important)
    private static func getStatImportance(_ statName: String) -> Int {
        switch statName.lowercased() {
        // Most important stats first
        case let name where name.contains("touchdown"): return 1
        case let name where name.contains("yards"): return 2  
        case let name where name.contains("reception"): return 3
        case let name where name.contains("attempt"): return 4
        case let name where name.contains("field goal"): return 5
        case let name where name.contains("interception"): return 6
        case let name where name.contains("fumble"): return 7
        default: return 8
        }
    }
}

/// Scoring system type
enum ScoringSystem {
    case standard
    case halfPPR
    case ppr
}

// MARK: - Stat Display Helper

/// Helper for formatting stat names and descriptions
struct StatDisplayHelper {
    
    /// Get human-readable display name for a stat key
    static func getDisplayName(for statKey: String) -> String {
        switch statKey {
        // Passing
        case "pass_yd": return "Passing Yards"
        case "pass_td": return "Passing Touchdowns"
        case "pass_int": return "Interceptions"
        case "pass_cmp": return "Pass Completions"
        case "pass_att": return "Pass Attempts"
        case "pass_2pt": return "2-Point Conversions"
        
        // Rushing
        case "rush_yd": return "Rushing Yards"
        case "rush_td": return "Rushing Touchdowns"
        case "rush_att": return "Rush Attempts"
        case "rush_2pt": return "2-Point Conversions"
        
        // Receiving
        case "rec": return "Receptions"
        case "rec_yd": return "Receiving Yards"
        case "rec_td": return "Receiving Touchdowns"
        case "rec_tgt": return "Targets"
        case "rec_2pt": return "2-Point Conversions"
        
        // Kicking
        case "fgm": return "Field Goals Made"
        case "fga": return "Field Goal Attempts"
        case "xpm": return "Extra Points Made"
        case "xpmiss": return "Extra Points Missed"
        case "fgm_0_19": return "FG Made (0-19 yds)"
        case "fgm_20_29": return "FG Made (20-29 yds)"
        case "fgm_30_39": return "FG Made (30-39 yds)"
        case "fgm_40_49": return "FG Made (40-49 yds)"
        case "fgm_50p": return "FG Made (50+ yds)"
        
        // Defense/ST
        case "def_int": return "Interceptions"
        case "def_fum_rec": return "Fumble Recoveries"
        case "def_sack": return "Sacks"
        case "def_td": return "Defensive Touchdowns"
        case "def_safe": return "Safeties"
        case "st_td": return "Special Teams TDs"
        case "blk_kick": return "Blocked Kicks"
        
        // Fumbles
        case "fum": return "Fumbles"
        case "fum_lost": return "Fumbles Lost"
        
        // Bonus
        case "pass_40": return "40+ Yard Pass"
        case "rush_40": return "40+ Yard Rush"
        case "rec_40": return "40+ Yard Reception"
        
        default:
            // Convert snake_case to Title Case
            return statKey.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    /// Format a stat description for display
    static func formatStatDescription(statKey: String, value: Double) -> String {
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? 
            String(format: "%.0f", value) : 
            String(format: "%.1f", value)
        
        let displayName = getDisplayName(for: statKey).lowercased()
        
        if value == 1.0 {
            // Singular form
            return "1 \(displayName.replacingOccurrences(of: "s$", with: "", options: .regularExpression))"
        } else {
            // Plural form  
            return "\(formattedValue) \(displayName)"
        }
    }
}