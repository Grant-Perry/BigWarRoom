//
//  PlayerStatsViewModel.swift
//  BigWarRoom
//
//  ViewModel for PlayerStatsCardView - handles all business logic and data processing
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class PlayerStatsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoadingStats = false
    @Published var playerStatsData: PlayerStatsData?
    @Published var depthChartData: [String: DepthChartData] = [:]
    @Published var fantasyAnalysisData: FantasyAnalysisData?
    
    // MARK: - Dependencies
    
    private let livePlayersViewModel = AllLivePlayersViewModel.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    
    // MARK: - Current Player
    
    private var currentPlayer: SleeperPlayer?
    
    // MARK: - Public Methods
    
    /// Initialize the view model with player data
    func setupPlayer(_ player: SleeperPlayer) {
        currentPlayer = player
        loadPlayerData()
    }
    
    /// Load all player-related data
    private func loadPlayerData() {
        guard let player = currentPlayer else { return }
        
        Task {
            await loadStatsIfNeeded()
            generatePlayerStatsData(for: player)
            generateDepthChartData(for: player)
            generateFantasyAnalysisData(for: player)
        }
    }
    
    /// Load stats from live players ViewModel if needed
    private func loadStatsIfNeeded() async {
        if !livePlayersViewModel.statsLoaded {
            isLoadingStats = true
            await livePlayersViewModel.loadAllPlayers()
            isLoadingStats = false
        }
    }
    
    // MARK: - Business Logic (Moved from View)
    
    /// Generate player stats data
    private func generatePlayerStatsData(for player: SleeperPlayer) {
        guard let stats = getPlayerStats(for: player) else {
            playerStatsData = nil
            return
        }
        
        playerStatsData = PlayerStatsData(
            playerID: player.playerID,
            stats: stats,
            position: player.position?.uppercased() ?? ""
        )
    }
    
    /// Generate team depth chart data
    private func generateDepthChartData(for player: SleeperPlayer) {
        let teamPlayers = getTeamPlayers(for: player)
        var depthData: [String: DepthChartData] = [:]
        
        for (position, players) in teamPlayers {
            let depthPlayers = players.enumerated().map { index, p in
                DepthChartPlayer(
                    player: p,
                    depth: index + 1,
                    isCurrentPlayer: p.playerID == player.playerID
                )
            }
            
            depthData[position] = DepthChartData(
                position: position,
                players: depthPlayers
            )
        }
        
        depthChartData = depthData
    }
    
    /// Generate fantasy analysis data
    private func generateFantasyAnalysisData(for player: SleeperPlayer) {
        guard let searchRank = player.searchRank else {
            fantasyAnalysisData = nil
            return
        }
        
        let position = player.position ?? ""
        let tier = calculateFantasyTier(searchRank: searchRank, position: position)
        
        fantasyAnalysisData = FantasyAnalysisData(
            searchRank: searchRank,
            position: position,
            tier: tier,
            tierDescription: getTierDescription(tier: tier, position: position),
            positionAnalysis: getPositionAnalysis(searchRank: searchRank, position: position)
        )
    }
    
    // MARK: - Private Business Logic Methods
    
    /// Get player stats from live data (moved from View)
    private func getPlayerStats(for player: SleeperPlayer) -> [String: Double]? {
        let playerName = player.fullName.lowercased()
        
        // Find all potential matches
        let potentialMatches = playerDirectory.players.values.filter { sleeperPlayer in
            sleeperPlayer.fullName.lowercased() == playerName ||
            (sleeperPlayer.shortName.lowercased() == player.shortName.lowercased() &&
             sleeperPlayer.team?.lowercased() == player.team?.lowercased())
        }
        
        // Find the one with stats
        for match in potentialMatches {
            if let stats = livePlayersViewModel.playerStats[match.playerID] {
                return stats
            }
        }
        
        return nil
    }
    
    /// Get team players organized by position (moved from View)
    private func getTeamPlayers(for player: SleeperPlayer) -> [String: [SleeperPlayer]] {
        guard let playerTeam = player.team else { return [:] }
        
        // Get all players from the same team
        let teamPlayers = playerDirectory.players.values.filter { p in
            p.team?.uppercased() == playerTeam.uppercased() &&
            p.status == "Active" &&
            p.position != nil
        }
        
        // Group by position
        let playersByPosition = Dictionary(grouping: teamPlayers) { p in
            p.position?.uppercased() ?? "UNKNOWN"
        }
        
        // Sort each position group by depth chart order
        var sortedByPosition: [String: [SleeperPlayer]] = [:]
        
        for (position, players) in playersByPosition {
            guard position != "UNKNOWN" else { continue }
            
            let sortedPlayers = players.sorted { p1, p2 in
                let order1 = p1.depthChartOrder ?? 99
                let order2 = p2.depthChartOrder ?? 99
                
                // If depth chart orders are the same, use searchRank as tiebreaker
                if order1 == order2 {
                    let rank1 = p1.searchRank ?? 999
                    let rank2 = p2.searchRank ?? 999
                    return rank1 < rank2
                }
                
                return order1 < order2
            }
            
            sortedByPosition[position] = sortedPlayers
        }
        
        return sortedByPosition
    }
    
    /// Calculate fantasy tier based on search rank and position (moved from View)
    private func calculateFantasyTier(searchRank: Int, position: String) -> Int {
        switch position.uppercased() {
        case "QB":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        case "RB":
            if searchRank <= 24 { return 1 }
            if searchRank <= 48 { return 2 }
            if searchRank <= 84 { return 3 }
            return 4
        case "WR":
            if searchRank <= 36 { return 1 }
            if searchRank <= 72 { return 2 }
            if searchRank <= 120 { return 3 }
            return 4
        case "TE":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        default:
            return 4
        }
    }
    
    /// Get tier description (moved from View)
    private func getTierDescription(tier: Int, position: String) -> String {
        switch (tier, position.uppercased()) {
        case (1, "QB"): return "Elite QB1 - Weekly starter"
        case (2, "QB"): return "Solid QB1 - Reliable starter"
        case (3, "QB"): return "Streaming QB - Matchup dependent"
        case (1, "RB"): return "Elite RB1/2 - Every week starter"
        case (2, "RB"): return "Solid RB2/3 - Good starter"
        case (3, "RB"): return "Flex RB - Spot starter"
        case (1, "WR"): return "Elite WR1/2 - Must start"
        case (2, "WR"): return "Solid WR2/3 - Good starter"
        case (3, "WR"): return "Flex WR - Depth play"
        case (1, "TE"): return "Elite TE - Set and forget"
        case (2, "TE"): return "Solid TE - Weekly starter"
        case (3, "TE"): return "Streaming TE - Matchup play"
        default: return "Deep bench / waiver wire"
        }
    }
    
    /// Get position analysis (moved from View)
    private func getPositionAnalysis(searchRank: Int, position: String) -> String {
        let pos = position.uppercased()
        
        switch pos {
        case "QB":
            return "QB\(searchRank <= 12 ? "1" : searchRank <= 24 ? "2" : "3+") - Target in rounds \(searchRank <= 12 ? "6-8" : searchRank <= 24 ? "9-12" : "13+")"
        case "RB":
            return "RB\(searchRank <= 12 ? "1" : searchRank <= 36 ? "2" : "3+") - Target in rounds \(searchRank <= 24 ? "1-3" : searchRank <= 48 ? "4-6" : "7+")"
        case "WR":
            return "WR\(searchRank <= 18 ? "1" : searchRank <= 48 ? "2" : "3+") - Target in rounds \(searchRank <= 36 ? "1-4" : searchRank <= 72 ? "5-8" : "9+")"
        case "TE":
            return "TE\(searchRank <= 6 ? "1" : searchRank <= 18 ? "2" : "3+") - Target in rounds \(searchRank <= 12 ? "4-6" : searchRank <= 24 ? "7-10" : "11+")"
        default:
            return "Draft in later rounds based on team needs"
        }
    }
}