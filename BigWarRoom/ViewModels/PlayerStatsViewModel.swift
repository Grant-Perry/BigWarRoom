//
//  PlayerStatsViewModel.swift
//  BigWarRoom
//
//  ViewModel for PlayerStatsCardView - handles all business logic and data processing
//  
//  🔧 BLANK SHEET FIX: Added comprehensive loading states and progressive loading messages
//  to eliminate the 4-6 second blank screen that occurred when opening player stats sheets.

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class PlayerStatsViewModel {
    // MARK: - Observable Properties (No @Published needed with @Observable)
    
    var isLoadingStats = false
    
    // 🔧 BLANK SHEET FIX: CRITICAL - Set isLoadingPlayerData to TRUE by default
    // BEFORE: Started as false, causing blank screen to show first
    // AFTER: Starts as true, showing loading view immediately when sheet opens
    var isLoadingPlayerData = true // FIXED: Changed from false to true
    var loadingMessage = "Loading player data..." // NEW: Progressive status messages for user feedback
    var hasLoadingError = false // NEW: Error state for timeout/failure handling
    
    var playerStatsData: PlayerStatsData?
    var depthChartData: [String: DepthChartData] = [:]
    var fantasyAnalysisData: FantasyAnalysisData?
    
    // MARK: - Dependencies
    
    private let livePlayersViewModel = AllLivePlayersViewModel.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    
    // MARK: - Current Player
    
    private var currentPlayer: SleeperPlayer?
    
    // 🔧 BLANK SHEET FIX: Added task management to properly handle cancellation
    // when user closes sheet before loading completes
    private var loadingTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Initialize the view model with player data
    func setupPlayer(_ player: SleeperPlayer) {
        currentPlayer = player
        
        // CRITICAL FIX: Reset loading state EVERY time setupPlayer is called
        // This ensures fresh state even if ViewModel instance is reused by SwiftUI
        isLoadingPlayerData = true
        hasLoadingError = false
        loadingMessage = "Loading player data..."
        
        loadPlayerData()
    }
    
    /// 🔧 BLANK SHEET FIX: Completely rewrote this method to provide loading state management
    /// BEFORE: Would silently load data in background while UI showed blank screen
    /// AFTER: Sets loading states immediately and provides progressive feedback
    private func loadPlayerData() {
        guard let player = currentPlayer else { 
            return 
        }
        
        // 🔧 BLANK SHEET FIX: Cancel any existing loading task to prevent race conditions
        loadingTask?.cancel()
        
        // 🔧 BLANK SHEET FIX: Set loading state IMMEDIATELY when method is called
        // This triggers the UI to show PlayerStatsLoadingView instead of blank screen
        isLoadingPlayerData = true
        hasLoadingError = false
        loadingMessage = "Loading player data..."
        
        // 🔧 BLANK SHEET FIX: Wrapped all loading logic in a Task with @MainActor
        // to ensure UI updates happen on main thread and provide progress updates
        loadingTask = Task { @MainActor in
            
            // 🔧 BLANK SHEET FIX: Step 1 - The SLOW part that was causing blank screens
            // This loadStatsIfNeeded() call can take 4-6 seconds but now user sees progress
            if !livePlayersViewModel.statsLoaded {
                loadingMessage = "Loading league statistics..." // Progress update 1
                await loadStatsIfNeeded()
            }
            
            // 🔧 BLANK SHEET FIX: Steps 2-4 - Fast operations with progress feedback
            loadingMessage = "Processing player information..." // Progress update 2
            generatePlayerStatsData(for: player)
            
            loadingMessage = "Loading team depth chart..." // Progress update 3
            generateDepthChartData(for: player)
            
            loadingMessage = "Analyzing fantasy data..." // Progress update 4
            generateFantasyAnalysisData(for: player)
            
            // 🔧 BLANK SHEET FIX: Clear loading state when complete
            // This triggers UI to switch from loading view to main content view
            if !Task.isCancelled {
                isLoadingPlayerData = false
                hasLoadingError = false
                loadingMessage = ""
            }
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