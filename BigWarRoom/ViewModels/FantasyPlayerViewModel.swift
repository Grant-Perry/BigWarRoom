//
//  FantasyPlayerViewModel.swift
//  BigWarRoom
//
//  View model handling business logic for individual fantasy player displays
//  🔥 PHASE 3 DI: Converted to use dependency injection
//

import Foundation
import SwiftUI

/// View model managing business logic for fantasy player card displays
@MainActor
@Observable
class FantasyPlayerViewModel {
    
    // MARK: - Observable Properties
    var teamColor: Color = .gray
    var nflPlayer: NFLPlayer?
    var glowIntensity: Double = 0.0
    var currentWeek: Int = 1
    var statsAvailable: Bool = false
    var showingPlayerDetail: Bool = false
    
    // MARK: - Dependencies (injected)
    private let gameViewModel: NFLGameMatchupViewModel
    private let nflWeekService: NFLWeekService
    // 🔥 PHASE 3 DI: Make livePlayersViewModel internal so FantasyPlayerCard can access it
    internal let livePlayersViewModel: AllLivePlayersViewModel
    // 🔥 PHASE 3 DI: Inject PlayerDirectoryStore
    internal let playerDirectory: PlayerDirectoryStore
    
    private var observationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    // 🔥 PHASE 3: Dependency injection initializer
    init(
        livePlayersViewModel: AllLivePlayersViewModel, 
        playerDirectory: PlayerDirectoryStore,
        nflGameDataService: NFLGameDataService,
        nflWeekService: NFLWeekService
    ) {
        self.livePlayersViewModel = livePlayersViewModel
        self.playerDirectory = playerDirectory
        self.gameViewModel = NFLGameMatchupViewModel(gameDataService: nflGameDataService)
        self.nflWeekService = nflWeekService
        self.currentWeek = nflWeekService.currentWeek
        startObservingDependencies()
    }
    
    deinit {
        Task { @MainActor in
            observationTask?.cancel()
        }
    }
    
    /// Start observing dependencies using @Observable pattern
    private func startObservingDependencies() {
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                let isStatsLoaded = livePlayersViewModel.statsLoaded
                let playerStats = livePlayersViewModel.playerStats
                
                if isStatsLoaded && !statsAvailable {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        statsAvailable = true
                    }
                }
                
                if !playerStats.isEmpty && !statsAvailable {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        statsAvailable = true
                    }
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // Check twice per second
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determines if the player is currently in a live game
    func isPlayerLive(_ player: FantasyPlayer) -> Bool {
        return player.isLive
    }
    
    /// Gets appropriate border colors based on live status
    func borderColors(for player: FantasyPlayer) -> [Color] {
        if isPlayerLive(player) {
            return [.gpGreen, .gpGreen.opacity(0.8), .cyan.opacity(0.6), .gpGreen.opacity(0.9), .gpGreen]
        } else {
            return [teamColor]
        }
    }
    
    /// Gets border width based on live status
    func borderWidth(for player: FantasyPlayer) -> CGFloat {
        return isPlayerLive(player) ? 6 : 2
    }
    
    /// Gets border opacity based on live status
    func borderOpacity(for player: FantasyPlayer) -> Double {
        if isPlayerLive(player) {
            return max(0.8, glowIntensity * 0.9 + 0.3)
        } else {
            return 0.7
        }
    }
    
    /// Gets shadow color based on live status
    func shadowColor(for player: FantasyPlayer) -> Color {
        return isPlayerLive(player) ? .gpGreen.opacity(0.8) : .clear
    }
    
    /// Gets shadow radius based on live status
    func shadowRadius(for player: FantasyPlayer) -> CGFloat {
        return isPlayerLive(player) ? 15 : 0
    }
    
    /// Card height - reduced for more compact layout
    var cardHeight: CGFloat {
        return 100
    }
    
    // MARK: - Business Logic Methods
    
    /// Sets up initial configuration for a player
    func configurePlayer(_ player: FantasyPlayer) {
        setupTeamColor(for: player)
        setupGameData(for: player)
        
        if isPlayerLive(player) {
            startLiveAnimations()
        }
    }
    
    /// Gets positional ranking display string
    func getPositionalRanking(for player: FantasyPlayer, in matchup: FantasyMatchup?, teamIndex: Int?, isBench: Bool, fantasyViewModel: FantasyViewModel) -> String {
        guard let matchup = matchup, let teamIndex = teamIndex else {
            return player.position.uppercased()
        }
        return fantasyViewModel.getPositionalRanking(for: player, in: matchup, teamIndex: teamIndex, isBench: isBench)
    }
    
    /// Formats detailed stat breakdown for display
    func formatPlayerStatBreakdown(for player: FantasyPlayer) -> String? {
        guard let sleeperPlayer = getSleeperPlayerData(for: player) else {
            return nil
        }
        
        guard let stats = livePlayersViewModel.playerStats[sleeperPlayer.playerID] else {
            return nil
        }
        
        let position = player.position
        var breakdown: [String] = []
        
        switch position {
        case "QB":
            formatQuarterbackStats(stats: stats, breakdown: &breakdown)
        case "RB":
            formatRunningBackStats(stats: stats, breakdown: &breakdown)
        case "WR", "TE":
            formatReceiverStats(stats: stats, breakdown: &breakdown, position: position)
        case "K":
            formatKickerStats(stats: stats, breakdown: &breakdown)
        case "DEF", "DST":
            formatDefenseStats(stats: stats, breakdown: &breakdown)
        default:
            return nil
        }
        
        return breakdown.isEmpty ? nil : breakdown.joined(separator: ", ")
    }
    
    /// Gets matching Sleeper player data with robust prioritization
    func getSleeperPlayerData(for player: FantasyPlayer) -> SleeperPlayer? {
        let playerName = player.fullName
        
        // Find all potential matches first
        let potentialMatches = playerDirectory.players.values.filter { sleeperPlayer in
            if sleeperPlayer.fullName.lowercased() == playerName.lowercased() {
                return true
            }
            
            if sleeperPlayer.shortName.lowercased() == player.shortName.lowercased() &&
               sleeperPlayer.team?.lowercased() == player.team?.lowercased() {
                return true
            }
            
            if let firstName = sleeperPlayer.firstName, let lastName = sleeperPlayer.lastName {
                let fullName = "\(firstName) \(lastName)"
                if fullName.lowercased() == playerName.lowercased() {
                    return true
                }
            }
            
            return false
        }
        
        // If only one match, use it
        if potentialMatches.count == 1 {
            return potentialMatches.first
        }
        
        // Robust prioritization system for multiple matches
        if potentialMatches.count > 1 {
            // Priority 1: Player with detailed game stats
            let detailedStatsMatches = potentialMatches.filter { player in
                if let stats = livePlayersViewModel.playerStats[player.playerID] {
                    let hasDetailedStats = stats.keys.contains { key in
                        key.contains("pass_att") || key.contains("rush_att") || 
                        key.contains("rec") || key.contains("fgm") || 
                        key.contains("def_sack") || key.contains("pass_cmp") ||
                        key.contains("rush_yd") || key.contains("rec_yd")
                    }
                    return hasDetailedStats
                }
                return false
            }
            
            if !detailedStatsMatches.isEmpty {
                return detailedStatsMatches.first
            }
            
            // Priority 2: Player with any stats
            let anyStatsMatches = potentialMatches.filter { player in
                return livePlayersViewModel.playerStats[player.playerID] != nil
            }
            
            if !anyStatsMatches.isEmpty {
                return anyStatsMatches.first
            }
            
            // Priority 3: Player with matching team
            let teamMatches = potentialMatches.filter { player in
                return player.team?.lowercased() == player.team?.lowercased()
            }
            
            if !teamMatches.isEmpty {
                return teamMatches.first
            }
            
            // Priority 4: Fallback to first match
            return potentialMatches.first
        }
        
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func setupTeamColor(for player: FantasyPlayer) {
        if let team = player.team {
            if let nflTeam = NFLTeam.team(for: team) {
                teamColor = nflTeam.primaryColor
            } else {
                teamColor = NFLTeamColors.color(for: team)
            }
        }
    }
    
    private func setupGameData(for player: FantasyPlayer) {
        guard let team = player.team else { return }
        
        currentWeek = nflWeekService.currentWeek
        let currentYear = nflWeekService.currentYear
        
        gameViewModel.configure(for: team, week: currentWeek, year: Int(currentYear) ?? 2024)
    }
    
    private func startLiveAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
    }
    
    // MARK: - Stat Formatting Methods
    
    private func formatQuarterbackStats(stats: [String: Double], breakdown: inout [String]) {
        if let attempts = stats["pass_att"], attempts > 0 {
            let completions = stats["pass_cmp"] ?? 0
            let yards = stats["pass_yd"] ?? 0
            let tds = stats["pass_td"] ?? 0
            breakdown.append("\(Int(completions))/\(Int(attempts)) CMP")
            if yards > 0 { breakdown.append("\(Int(yards)) YD") }
            if tds > 0 { breakdown.append("\(Int(tds)) PASS TD") }
            
            if let passFd = stats["pass_fd"], passFd > 0 {
                breakdown.append("\(Int(passFd)) PASS FD")
            }
        }
        
        if let carries = stats["rush_att"], carries > 0 {
            let rushYards = stats["rush_yd"] ?? 0
            let rushTds = stats["rush_td"] ?? 0
            breakdown.append("\(Int(carries)) CAR")
            if rushYards > 0 { breakdown.append("\(Int(rushYards)) RUSH YD") }
            if rushTds > 0 { breakdown.append("\(Int(rushTds)) RUSH TD") }
            
            if let rushFd = stats["rush_fd"], rushFd > 0 {
                breakdown.append("\(Int(rushFd)) RUSH FD")
            }
        }
    }
    
    private func formatRunningBackStats(stats: [String: Double], breakdown: inout [String]) {
        if let carries = stats["rush_att"], carries > 0 {
            let yards = stats["rush_yd"] ?? 0
            let tds = stats["rush_td"] ?? 0
            breakdown.append("\(Int(carries)) CAR")
            if yards > 0 { breakdown.append("\(Int(yards)) YD") }
            if tds > 0 { breakdown.append("\(Int(tds)) TD") }
        }
        if let receptions = stats["rec"], receptions > 0 {
            let recYards = stats["rec_yd"] ?? 0
            let recTds = stats["rec_td"] ?? 0
            breakdown.append("\(Int(receptions)) REC")
            if recYards > 0 { breakdown.append("\(Int(recYards)) REC YD") }
            if recTds > 0 { breakdown.append("\(Int(recTds)) REC TD") }
        }
    }
    
    private func formatReceiverStats(stats: [String: Double], breakdown: inout [String], position: String) {
        if let receptions = stats["rec"], receptions > 0 {
            let targets = stats["rec_tgt"] ?? receptions
            let yards = stats["rec_yd"] ?? 0
            let tds = stats["rec_td"] ?? 0
            breakdown.append("\(Int(receptions))/\(Int(targets)) REC")
            if yards > 0 { breakdown.append("\(Int(yards)) YD") }
            if tds > 0 { breakdown.append("\(Int(tds)) TD") }
        }
        if position == "WR", let rushYards = stats["rush_yd"], rushYards > 0 {
            breakdown.append("\(Int(rushYards)) RUSH YD")
        }
    }
    
    private func formatKickerStats(stats: [String: Double], breakdown: inout [String]) {
        if let fgMade = stats["fgm"], fgMade > 0 {
            let fgAtt = stats["fga"] ?? fgMade
            breakdown.append("\(Int(fgMade))/\(Int(fgAtt)) FG")
        }
        if let xpMade = stats["xpm"], xpMade > 0 {
            breakdown.append("\(Int(xpMade)) XP")
        }
    }
    
    private func formatDefenseStats(stats: [String: Double], breakdown: inout [String]) {
        if let sacks = stats["def_sack"], sacks > 0 {
            breakdown.append("\(Int(sacks)) SACK")
        }
        if let ints = stats["def_int"], ints > 0 {
            breakdown.append("\(Int(ints)) INT")
        }
        if let fumRec = stats["def_fum_rec"], fumRec > 0 {
            breakdown.append("\(Int(fumRec)) FUM REC")
        }
    }
}
