//
//  ScoringCalculationService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized scoring calculation logic
//  Eliminates duplicate scoring methods across ChoppedLeagueService and ChoppedTeamRosterViewModel
//

import Foundation

/// Centralized service for calculating fantasy football scores
/// Supports both default Sleeper scoring and custom league scoring settings
@MainActor
final class ScoringCalculationService {
    
    // MARK: - Singleton (for backward compatibility, prefer DI)
    static let shared: ScoringCalculationService = {
        let service = ScoringCalculationService(
            sharedStatsService: SharedStatsService.shared,
            weekSelectionManager: WeekSelectionManager.shared,
            seasonYearManager: SeasonYearManager.shared
        )
        return service
    }()
    
    // MARK: - Dependencies
    private let sharedStatsService: SharedStatsService
    private let weekSelectionManager: WeekSelectionManager
    private let seasonYearManager: SeasonYearManager
    
    // MARK: - Cache
    private var leagueScoringCache: [String: [String: Any]] = [:]
    
    // MARK: - Initialization
    
    init(
        sharedStatsService: SharedStatsService,
        weekSelectionManager: WeekSelectionManager,
        seasonYearManager: SeasonYearManager
    ) {
        self.sharedStatsService = sharedStatsService
        self.weekSelectionManager = weekSelectionManager
        self.seasonYearManager = seasonYearManager
    }
    
    // MARK: - Public Interface
    
    /// Calculate player score using league-specific scoring settings
    func calculatePlayerScore(
        playerID: String,
        leagueID: String,
        week: Int? = nil,
        year: String? = nil
    ) async -> Double {
        let targetWeek = week ?? weekSelectionManager.selectedWeek
        let targetYear = year ?? String(seasonYearManager.selectedYear)
        
        // Get player stats
        guard let stats = sharedStatsService.getCachedPlayerStats(
            playerID: playerID,
            week: targetWeek,
            year: targetYear
        ), !stats.isEmpty else {
            return 0.0
        }
        
        // Get league scoring settings
        let scoringSettings = await getLeagueScoringSettings(leagueID: leagueID)
        
        // Calculate score
        return calculateScore(stats: stats, scoringSettings: scoringSettings)
    }
    
    /// Calculate player score with provided stats and scoring settings
    func calculateScore(
        stats: [String: Double],
        scoringSettings: [String: Any]
    ) -> Double {
        var totalScore = 0.0
        
        for (statKey, statValue) in stats {
            if let scoring = scoringSettings[statKey] as? Double {
                totalScore += statValue * scoring
            } else if let scoring = scoringSettings[statKey] as? Int {
                totalScore += statValue * Double(scoring)
            }
        }
        
        return totalScore
    }
    
    /// Get league scoring settings (with caching)
    func getLeagueScoringSettings(leagueID: String) async -> [String: Any] {
        // Check cache first
        if let cached = leagueScoringCache[leagueID] {
            return cached
        }
        
        // Fetch from Sleeper API
        do {
            let league = try await SleeperAPIClient.shared.fetchLeague(leagueID: leagueID)
            if let scoringSettings = league.scoringSettings {
                leagueScoringCache[leagueID] = scoringSettings
                return scoringSettings
            }
        } catch {
            // Fallback to defaults on error
        }
        
        // Return default settings
        let defaults = getDefaultSleeperScoring()
        leagueScoringCache[leagueID] = defaults
        return defaults
    }
    
    /// Get default Sleeper scoring settings (PPR)
    func getDefaultSleeperScoring() -> [String: Any] {
        return [
            // Passing
            "pass_yd": 0.04,      // 1 point per 25 passing yards
            "pass_td": 4.0,       // 4 points per passing TD
            "pass_int": -1.0,     // -1 point per interception
            "pass_fd": 1.0,       // 1 point per passing 1st down
            "pass_2pt": 2.0,      // 2 points per 2pt conversion
            "pass_cmp_40p": 1.0,  // 1 point per completion 40+ yards
            
            // Rushing
            "rush_yd": 0.1,       // 1 point per 10 rushing yards
            "rush_td": 6.0,       // 6 points per rushing TD
            "rush_fd": 1.0,       // 1 point per rushing 1st down
            "rush_2pt": 2.0,      // 2 points per 2pt conversion
            "rush_40p": 1.0,      // 1 point per rush 40+ yards
            
            // Receiving
            "rec": 1.0,           // 1 point per reception (PPR)
            "rec_yd": 0.1,        // 1 point per 10 receiving yards
            "rec_td": 6.0,        // 6 points per receiving TD
            "rec_fd": 1.0,        // 1 point per receiving 1st down
            "rec_2pt": 2.0,       // 2 points per 2pt conversion
            "rec_40p": 1.0,       // 1 point per reception 40+ yards
            
            // Fumbles
            "fum": -1.0,          // -1 point per fumble
            "fum_lost": -2.0,     // -2 points per fumble lost
            "fum_rec": 2.0,       // 2 points per fumble recovery
            "fum_rec_td": 6.0,    // 6 points per fumble recovery TD
            
            // Kicking
            "fgm": 3.0,           // 3 points per field goal made
            "fgm_0_19": 3.0,      // 3 points per FG 0-19 yards
            "fgm_20_29": 3.0,     // 3 points per FG 20-29 yards
            "fgm_30_39": 3.0,     // 3 points per FG 30-39 yards
            "fgm_40_49": 4.0,     // 4 points per FG 40-49 yards
            "fgm_50p": 5.0,       // 5 points per FG 50+ yards
            "fgmiss": -1.0,       // -1 point per field goal missed
            "xpm": 1.0,           // 1 point per extra point made
            "xpmiss": -1.0,       // -1 point per extra point missed
            
            // Defense/Special Teams
            "def_td": 6.0,        // 6 points per defensive TD
            "def_int": 2.0,       // 2 points per interception
            "def_fum_rec": 2.0,   // 2 points per fumble recovery
            "def_sack": 1.0,      // 1 point per sack
            "def_safe": 2.0,      // 2 points per safety
            "def_block_kick": 2.0,// 2 points per blocked kick
            "def_pass_def": 0.5,  // 0.5 points per pass defended
            "def_tkl_solo": 1.0,  // 1 point per solo tackle
            "def_tkl_ast": 0.5,   // 0.5 points per assisted tackle
            
            // Points allowed (DST)
            "def_pts_allowed_0": 10.0,
            "def_pts_allowed_1_6": 7.0,
            "def_pts_allowed_7_13": 4.0,
            "def_pts_allowed_14_20": 1.0,
            "def_pts_allowed_21_27": 0.0,
            "def_pts_allowed_28_34": -1.0,
            "def_pts_allowed_35p": -4.0,
            
            // Yards allowed (DST)
            "def_yds_allowed_0_100": 10.0,
            "def_yds_allowed_100_199": 5.0,
            "def_yds_allowed_200_299": 2.0,
            "def_yds_allowed_300_349": 0.0,
            "def_yds_allowed_350_399": -1.0,
            "def_yds_allowed_400_449": -3.0,
            "def_yds_allowed_450_499": -5.0,
            "def_yds_allowed_500_549": -6.0,
            "def_yds_allowed_550p": -7.0,
        ]
    }
    
    /// Clear scoring cache (useful when league settings change)
    func clearCache(leagueID: String? = nil) {
        if let leagueID = leagueID {
            leagueScoringCache.removeValue(forKey: leagueID)
        } else {
            leagueScoringCache.removeAll()
        }
    }
}