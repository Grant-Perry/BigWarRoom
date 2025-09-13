//
//  ChoppedTeamRosterViewModel.swift
//  BigWarRoom
//
//  🏈 CHOPPED TEAM ROSTER VIEW MODEL 🏈
//  Handles all business logic for the Chopped team roster view
//

import SwiftUI
import Foundation
import Combine

/// **ChoppedTeamRosterViewModel**
/// 
/// MVVM ViewModel containing all business logic for Chopped roster display:
/// - API calls for roster and stats data
/// - Data processing and transformation
/// - Week validation and points calculation
/// - Player stats formatting and lookup
@MainActor
class ChoppedTeamRosterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var rosterData: ChoppedTeamRoster?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var opponentInfo: OpponentInfo?
    @Published var gameDataLoaded = false
    
    // MARK: - Private Properties
    
    private var playerStats: [String: [String: Double]] = [:]
    private let teamRanking: FantasyTeamRanking
    private let leagueID: String
    private let week: Int
    
    // MARK: - Initialization
    
    init(teamRanking: FantasyTeamRanking, leagueID: String, week: Int) {
        self.teamRanking = teamRanking
        self.leagueID = leagueID
        self.week = week
    }
    
    // MARK: - Public Interface
    
    /// Load the team roster and all associated data
    func loadTeamRoster() async {
        isLoading = true
        errorMessage = nil
        
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
        
        // Also load stats for breakdown display
        await loadPlayerStats()
    }
    
    /// Load NFL game data for real game times
    func loadNFLGameData() async {
        guard !gameDataLoaded else { return }
        
        NFLGameDataService.shared.fetchGameData(forWeek: week, year: AppConstants.currentSeasonYearInt)
        gameDataLoaded = true
    }
    
    /// Check if the current week has actually started (games have been played)
    func hasWeekStarted() -> Bool {
        if playerStats.isEmpty {
            return false
        }
        
        // Check if any players have actual points for this week
        let hasAnyPoints = playerStats.values.contains { stats in
            if let pprPoints = stats["pts_ppr"], pprPoints > 0 { return true }
            if let halfPprPoints = stats["pts_half_ppr"], halfPprPoints > 0 { return true }
            if let stdPoints = stats["pts_std"], stdPoints > 0 { return true }
            return false
        }
        
        return hasAnyPoints
    }
    
    /// Get actual player points ONLY if week has started
    func getActualPlayerPoints(for player: FantasyPlayer) -> Double? {
        guard hasWeekStarted() else { return nil }
        
        guard let sleeperPlayer = findSleeperPlayer(for: player) else { return nil }
        
        // First try to get from loaded playerStats FOR THIS SPECIFIC WEEK
        if let stats = playerStats[sleeperPlayer.playerID] {
            if let pprPoints = stats["pts_ppr"], pprPoints > 0 { return pprPoints }
            if let halfPprPoints = stats["pts_half_ppr"], halfPprPoints > 0 { return halfPprPoints }
            if let stdPoints = stats["pts_std"], stdPoints > 0 { return stdPoints }
        }
        
        // Fallback to cache - BUT ONLY FOR THE CURRENT WEEK
        if let cachedStats = PlayerStatsCache.shared.getPlayerStats(playerID: sleeperPlayer.playerID, week: week) {
            if let pprPoints = cachedStats["pts_ppr"], pprPoints > 0 { return pprPoints }
            if let halfPprPoints = cachedStats["pts_half_ppr"], halfPprPoints > 0 { return halfPprPoints }
            if let stdPoints = cachedStats["pts_std"], stdPoints > 0 { return stdPoints }
        }
        
        return nil
    }
    
    /// Format player stat breakdown based on position
    func formatPlayerStatBreakdown(_ player: FantasyPlayer) -> String? {
        guard let sleeperPlayer = findSleeperPlayer(for: player) else {
            return nil
        }
        
        guard let stats = playerStats[sleeperPlayer.playerID] else {
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
            }
        )
    }
    
    /// Find Sleeper player for given fantasy player
    func findSleeperPlayer(for player: FantasyPlayer) -> SleeperPlayer? {
        if let sleeperID = player.sleeperID {
            let sleeperPlayer = PlayerDirectoryStore.shared.player(for: sleeperID)
            if sleeperPlayer == nil {
                print("⚠️ No SleeperPlayer found for \(player.fullName) with ID: \(sleeperID)")
            } else if sleeperPlayer?.number == nil {
                print("⚠️ SleeperPlayer \(player.fullName) found but has no jersey number")
            }
            return sleeperPlayer
        } else {
            print("⚠️ No sleeperID found for player: \(player.fullName)")
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
                
                // Create opponent info
                let opponent = OpponentInfo(
                    ownerName: ownerName,
                    score: points,
                    rankDisplay: "Opp",
                    teamColor: Color.blue,
                    teamInitials: String(ownerName.prefix(2)).uppercased(),
                    avatarURL: users.first(where: { $0.userID == opponentRoster.ownerID })?.avatar.flatMap { URL(string: "https://sleepercdn.com/avatars/\($0)") }
                )
                
                self.opponentInfo = opponent
            }
        } catch {
            print("❌ Failed to load opponent info: \(error)")
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
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: calculatePlayerPoints(playerID: playerID),
                        projectedPoints: nil,
                        gameStatus: createMockGameStatus(),
                        isStarter: true,
                        lineupSlot: sleeperPlayer.position
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
                    let fantasyPlayer = FantasyPlayer(
                        id: playerID,
                        sleeperID: playerID,
                        espnID: sleeperPlayer.espnID,
                        firstName: sleeperPlayer.firstName,
                        lastName: sleeperPlayer.lastName,
                        position: sleeperPlayer.position ?? "FLEX",
                        team: sleeperPlayer.team,
                        jerseyNumber: sleeperPlayer.number?.description,
                        currentPoints: calculatePlayerPoints(playerID: playerID),
                        projectedPoints: nil,
                        gameStatus: createMockGameStatus(),
                        isStarter: false,
                        lineupSlot: sleeperPlayer.position
                    )
                    bench.append(fantasyPlayer)
                }
            }
        }
        
        return ChoppedTeamRoster(starters: starters, bench: bench)
    }
    
    /// Load weekly player stats for detailed breakdown display
    private func loadPlayerStats() async {
        guard playerStats.isEmpty else { return }
        
        let currentYear = AppConstants.currentSeasonYearInt
        
        guard let url = URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(currentYear)/\(week)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let statsData = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            
            self.playerStats = statsData
            
            // Debug: Check if this week actually has data
            let totalPointsThisWeek = statsData.values.reduce(0) { total, stats in
                let playerPoints = stats["pts_ppr"] ?? stats["pts_half_ppr"] ?? stats["pts_std"] ?? 0
                return total + playerPoints
            }
            
            print("🔥 Week \(week) Stats Summary (Year \(currentYear) via SSOT): \(statsData.count) players, Total Points: \(totalPointsThisWeek)")
            
            if totalPointsThisWeek == 0 {
                print("⚠️ Week \(week) has no scoring data yet - games haven't started!")
            }
            
        } catch {
            print("❌ Failed to load player stats for week \(week), year \(currentYear): \(error)")
        }
    }
    
    /// Calculate player points for a given player ID
    private func calculatePlayerPoints(playerID: String) -> Double? {
        guard hasWeekStarted() else { return nil }
        
        // Use cached stats if available FOR THIS SPECIFIC WEEK
        if let stats = PlayerStatsCache.shared.getPlayerStats(playerID: playerID, week: week) {
            // Use PPR points from Sleeper
            if let pprPoints = stats["pts_ppr"] {
                return pprPoints
            } else if let halfPprPoints = stats["pts_half_ppr"] {
                return halfPprPoints
            } else if let stdPoints = stats["pts_std"] {
                return stdPoints
            }
        }
        
        return nil
    }
    
    /// Create mock game status
    private func createMockGameStatus() -> GameStatus {
        return GameStatus(status: "live")
    }
}