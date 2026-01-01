//
//  ChoppedTeamRosterViewModel.swift
//  BigWarRoom
//
//  🏈 CHOPPED TEAM ROSTER VIEW MODEL 🏈
//  Handles all business logic for the Chopped team roster view
//

import SwiftUI
import Foundation
import Observation

/// **ChoppedTeamRosterViewModel**
/// 
/// MVVM ViewModel containing all business logic for Chopped roster display:
/// - API calls for roster and stats data
/// - Data processing and transformation
/// - Week validation and points calculation
/// - Player stats formatting and lookup
@Observable
@MainActor
final class ChoppedTeamRosterViewModel {
    
    // MARK: - Observable Properties (No @Published needed with @Observable)
    
    var rosterData: ChoppedTeamRoster?
    var isLoading = true
    var errorMessage: String?
    var opponentInfo: OpponentInfo?
    var gameDataLoaded = false
    
    // MARK: - Private Properties
    
    private let teamRanking: FantasyTeamRanking
    private let leagueID: String
    private let week: Int
    
    private let gameDataService: NFLGameDataService
    private let scoringService: ScoringCalculationService  // 🔥 NEW: DRY scoring service
    private let sharedStatsService: SharedStatsService  // 🔥 NEW: DRY stats service
    
    // MARK: - Initialization
    
    init(
        teamRanking: FantasyTeamRanking,
        leagueID: String,
        week: Int,
        gameDataService: NFLGameDataService,
        scoringService: ScoringCalculationService = .shared,  // 🔥 NEW: Inject scoring service
        sharedStatsService: SharedStatsService  // 🔥 NEW: Inject stats service (no default)
    ) {
        self.teamRanking = teamRanking
        self.leagueID = leagueID
        self.week = week
        self.gameDataService = gameDataService
        self.scoringService = scoringService  // 🔥 NEW: Store scoring service
        self.sharedStatsService = sharedStatsService  // 🔥 NEW: Store stats service
    }
    
    // MARK: - Public Interface
    
    /// Load the team roster and all associated data
    func loadTeamRoster() async {
        isLoading = true
        errorMessage = nil
        
        // 🔥 DRY: Load stats using SharedStatsService instead of duplicating fetch logic
        do {
            _ = try await sharedStatsService.loadWeekStats(
                week: week,
                year: String(AppConstants.currentSeasonYearInt)
            )
        } catch {
            // Non-fatal error, continue with roster loading
        }
        
        // 🔥 NEW: Preload league scoring settings for sync access later
        _ = await scoringService.getLeagueScoringSettings(leagueID: leagueID)
        
        do {
            // Fetch matchup data for this week to get roster info
            let matchupData = try await SleeperAPIClient.shared.fetchMatchups(
                leagueID: leagueID,
                week: week
            )
            
            // Find this team's matchup data
            guard let teamMatchup = matchupData.first(where: { $0.rosterID == teamRanking.team.rosterID }) else {
                throw ChoppedRosterError.teamNotFound
            }
            
            // Load opponent in the same matchup
            if let matchupID = teamMatchup.matchupID {
                let opponent = matchupData.first { matchup in
                    matchup.matchupID == matchupID && matchup.rosterID != teamRanking.team.rosterID
                }
                
                if let opponentMatchup = opponent {
                    await loadOpponentInfo(rosterID: opponentMatchup.rosterID, points: opponentMatchup.points ?? 0.0)
                }
            }
            
            // Create roster from matchup data
            let roster = try await createChoppedTeamRoster(from: teamMatchup)
            self.rosterData = roster
            self.isLoading = false
            
        } catch {
            self.errorMessage = "Failed to load roster: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    /// Load NFL game data for real game times
    func loadNFLGameData() async {
        guard !gameDataLoaded else { return }
        
        gameDataService.fetchGameData(forWeek: week, year: AppConstants.currentSeasonYearInt)
        gameDataLoaded = true
    }
    
    /// Check if the current week has actually started (games have been played)
    func hasWeekStarted() -> Bool {
        // Check if SharedStatsService has cached data for this week
        let cachedStats = sharedStatsService.getCachedWeekStats(
            week: week,
            year: String(AppConstants.currentSeasonYearInt)
        )
        
        guard let stats = cachedStats, !stats.isEmpty else {
            return false
        }
        
        // Check if any players have actual points for this week
        let hasAnyPoints = stats.values.contains { playerStats in
            if let pprPoints = playerStats["pts_ppr"], pprPoints > 0 { return true }
            if let halfPprPoints = playerStats["pts_half_ppr"], halfPprPoints > 0 { return true }
            if let stdPoints = playerStats["pts_std"], stdPoints > 0 { return true }
            return false
        }
        
        return hasAnyPoints
    }
    
    /// Get actual player points ONLY if week has started
    func getActualPlayerPoints(for player: FantasyPlayer) -> Double? {
        guard hasWeekStarted() else { return nil }
        
        guard let sleeperPlayer = findSleeperPlayer(for: player) else { return nil }
        
        // 🔥 DRY: Use cached stats with ScoringCalculationService
        if let cachedStats = sharedStatsService.getCachedPlayerStats(
            playerID: sleeperPlayer.playerID,
            week: week,
            year: String(AppConstants.currentSeasonYearInt)
        ) {
            // Get league scoring from cache (already loaded during loadTeamRoster)
            Task {
                let scoringSettings = await scoringService.getLeagueScoringSettings(leagueID: leagueID)
                return scoringService.calculateScore(stats: cachedStats, scoringSettings: scoringSettings)
            }
            
            // Synchronous fallback using default scoring
            let defaultScoring = scoringService.getDefaultSleeperScoring()
            return scoringService.calculateScore(stats: cachedStats, scoringSettings: defaultScoring)
        }
        
        return nil
    }
    
    /// Format player stat breakdown based on position
    func formatPlayerStatBreakdown(_ player: FantasyPlayer) -> String? {
        guard let sleeperPlayer = findSleeperPlayer(for: player) else {
            return nil
        }
        
        guard let stats = sharedStatsService.getCachedPlayerStats(
            playerID: sleeperPlayer.playerID,
            week: week,
            year: String(AppConstants.currentSeasonYearInt)
        ) else {
            return nil
        }
        
        let position = player.position
        var breakdown: [String] = []
        
        switch position {
        case "QB":
            // Passing stats: completions/attempts, yards, TDs
            if let attempts = stats["pass_att"], attempts > 0 {
                let completions = stats["pass_cmp"] ?? 0
                let yards = stats["pass_yd"] ?? 0
                let tds = stats["pass_td"] ?? 0
                breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
                
                // Add pass first downs and completions 40+
                if let passFd = stats["pass_fd"], passFd > 0 {
                    breakdown.append("\(Int(passFd)) PASS FD")
                }
                if let pass40 = stats["pass_40"], pass40 > 0 {
                    breakdown.append("\(Int(pass40)) CMP (40+)")
                }
            }
            
            // Rushing stats if significant for QBs
            if let carries = stats["rush_att"], carries > 0 {
                let rushYards = stats["rush_yd"] ?? 0
                let rushTds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if rushYards > 0 { breakdown.append("\(Int(rushYards)) RUSH YD") }
                if rushTds > 0 { breakdown.append("\(Int(rushTds)) RUSH TD") }
                
                // Add rush first downs for QBs
                if let rushFd = stats["rush_fd"], rushFd > 0 {
                    breakdown.append("\(Int(rushFd)) RUSH FD")
                }
            }
            
            // Sacks taken
            if let sacks = stats["pass_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            
        case "RB":
            // Rushing stats: carries, yards, TDs
            if let carries = stats["rush_att"], carries > 0 {
                let yards = stats["rush_yd"] ?? 0
                let tds = stats["rush_td"] ?? 0
                breakdown.append("\(Int(carries)) CAR")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
                
                // Add rush first downs
                if let rushFd = stats["rush_fd"], rushFd > 0 {
                    breakdown.append("\(Int(rushFd)) RUSH FD")
                }
            }
            // Receiving if significant
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) REC TD") }
            }
            
        case "WR", "TE":
            // Receiving stats: receptions/targets, yards, TDs
            if let receptions = stats["rec"], receptions > 0 {
                let targets = stats["rec_tgt"] ?? receptions
                let yards = stats["rec_yd"] ?? 0
                let tds = stats["rec_td"] ?? 0
                breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
                if yards > 0 { breakdown.append("\(Int(yards)) YD") }
                if tds > 0 { breakdown.append("\(Int(tds)) TD") }
            }
            // Rushing if significant for WRs
            if position == "WR", let rushYards = stats["rush_yd"], rushYards > 0 {
                breakdown.append("\(Int(rushYards)) RUSH YD")
            }
            
        case "K":
            // Field goals and extra points
            if let fgMade = stats["fgm"], fgMade > 0 {
                let fgAtt = stats["fga"] ?? fgMade
                breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
            }
            if let xpMade = stats["xpm"], xpMade > 0 {
                breakdown.append("\(Int(xpMade)) XP")
            }
            
        case "DEF", "DST":
            // Defense stats: sacks, interceptions, fumble recoveries
            if let sacks = stats["def_sack"], sacks > 0 {
                breakdown.append("\(Int(sacks)) SACK")
            }
            if let ints = stats["def_int"], ints > 0 {
                breakdown.append("\(Int(ints)) INT")
            }
            if let fumRec = stats["def_fum_rec"], fumRec > 0 {
                breakdown.append("\(Int(fumRec)) FUM REC")
            }
            
        default:
            return nil
        }
        
        return breakdown.isEmpty ? nil : breakdown.joined(separator: ", ")
    }
    
    /// Sort players using DRY logic
    func sortPlayers(_ players: [FantasyPlayer], by sortingMethod: MatchupSortingMethod, highToLow: Bool) -> [FantasyPlayer] {
        return PlayerSortingService.sortPlayers(
            players, 
            by: sortingMethod, 
            highToLow: highToLow,
            getPlayerPoints: { [weak self] player in
                return self?.getActualPlayerPoints(for: player)
            },
            gameDataService: gameDataService
        )
    }
    
    /// Find Sleeper player for given fantasy player
    func findSleeperPlayer(for player: FantasyPlayer) -> SleeperPlayer? {
        if let sleeperID = player.sleeperID {
            let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID)
            if sleeperPlayer == nil {
            } else if sleeperPlayer?.number == nil {
            }
            return sleeperPlayer
        } else {
            return nil
        }
    }
    
    // MARK: - Public Methods for Score Breakdown
    
    /// Get player stats for score breakdown functionality
    func getPlayerStats(for playerID: String) -> [String: Double]? {
        return sharedStatsService.getCachedPlayerStats(
            playerID: playerID,
            week: week,
            year: String(AppConstants.currentSeasonYearInt)
        )
    }
    
    /// Get the specific week this roster is for (needed for score breakdown)
    func getCurrentWeek() -> Int {
        return week
    }
    
    /// Get the actual league scoring settings for score breakdown (synchronous with caching)
    func getLeagueScoringSettings() -> [String: Double]? {
        // 🔥 DRY: Try to get from ScoringCalculationService cache
        // This will work if loadTeamRoster() was already called (which loads scoring settings async)
        // For sync contexts, we'll return default scoring
        let defaults = scoringService.getDefaultSleeperScoring()
        
        return defaults.compactMapValues { value in
            if let doubleValue = value as? Double {
                return doubleValue
            } else if let intValue = value as? Int {
                return Double(intValue)
            }
            return nil
        }
    }

    // MARK: - Private Methods
    
    /// Load opponent information
    private func loadOpponentInfo(rosterID: Int, points: Double) async {
        do {
            // Fetch league rosters to get owner names
            let rosters = try await SleeperAPIClient.shared.fetchRosters(leagueID: leagueID)
            
            // Find the opponent roster
            if let opponentRoster = rosters.first(where: { $0.rosterID == rosterID }) {
                // Fetch users to get owner names
                let users = try await SleeperAPIClient.shared.fetchUsers(leagueID: leagueID)
                let ownerName = users.first(where: { $0.userID == opponentRoster.ownerID })?.displayName ?? "Unknown"
                
                // 🔥 DRY: Use APIEndpointService for avatar URL
                let avatarURL: URL? = {
                    if let avatar = users.first(where: { $0.userID == opponentRoster.ownerID })?.avatar {
                        return APIEndpointService.sleeperAvatar(avatarID: avatar)
                    }
                    return nil
                }()
                
                // Create opponent info
                let opponent = OpponentInfo(
                    ownerName: ownerName,
                    score: points,
                    rankDisplay: "Opp",
                    teamColor: Color.blue,
                    teamInitials: String(ownerName.prefix(2)).uppercased(),
                    avatarURL: avatarURL
                )
                
                self.opponentInfo = opponent
            }
        } catch {
        }
    }

    /// Create Chopped team roster from matchup data
    private func createChoppedTeamRoster(from matchup: SleeperMatchupResponse) async throws -> ChoppedTeamRoster {
        let playerDirectory = PlayerDirectoryStore.shared
        
        var starters: [FantasyPlayer] = []
        var bench: [FantasyPlayer] = []
        
        // Process starters
        if let starterIDs = matchup.starters {
            for playerID in starterIDs {
                if let sleeperPlayer = playerDirectory.player(for: playerID) {
                    // 🔥 DRY: Use ScoringCalculationService for player points
                    let actualPlayerScore = await scoringService.calculatePlayerScore(
                        playerID: playerID,
                        leagueID: leagueID,
                        week: week,
                        year: String(AppConstants.currentSeasonYearInt)
                    )
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: actualPlayerScore,
                        projectedPoints: nil,
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: sleeperPlayer.team),
                        isStarter: true,
                        lineupSlot: sleeperPlayer.position,
                        injuryStatus: sleeperPlayer.injuryStatus
                    )
                    starters.append(fantasyPlayer)
                }
            }
        }
        
        // Process bench (all players minus starters)
        if let allPlayers = matchup.players {
            let starterIDs = Set(matchup.starters ?? [])
            let benchIDs = allPlayers.filter { !starterIDs.contains($0) }
            
            for playerID in benchIDs {
                if let sleeperPlayer = playerDirectory.player(for: playerID) {
                    // 🔥 DRY: Use ScoringCalculationService for player points
                    let actualPlayerScore = await scoringService.calculatePlayerScore(
                        playerID: playerID,
                        leagueID: leagueID,
                        week: week,
                        year: String(AppConstants.currentSeasonYearInt)
                    )
                    
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: actualPlayerScore,
                        projectedPoints: nil,
                        gameStatus: GameStatusService.shared.getGameStatusWithFallback(for: sleeperPlayer.team),
                        isStarter: false,
                        lineupSlot: sleeperPlayer.position,
                        injuryStatus: sleeperPlayer.injuryStatus
                    )
                    bench.append(fantasyPlayer)
                }
            }
        }
        
        return ChoppedTeamRoster(starters: starters, bench: bench)
    }
}