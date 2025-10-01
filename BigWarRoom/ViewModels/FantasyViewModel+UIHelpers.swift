//
//  FantasyViewModel+UIHelpers.swift
//  BigWarRoom
//
//  🔥 PHASE 2 MVVM REFACTOR: Converted to proper ViewModel data helpers
//  REMOVED: All View building methods (moved to FantasyMatchupRosterSections.swift)
//  KEPT: Data processing methods that belong in ViewModel layer
//

import Foundation
import SwiftUI

// MARK: -> Data Helpers Extension (MVVM Compliant)
extension FantasyViewModel {
    
    /// Calculate win probability based on scores
    func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double {
        if homeScore == 0 && awayScore == 0 { return 0.5 }
        return homeScore / (homeScore + awayScore)
    }
    
    /// Get score for a team in a matchup
    func getScore(for matchup: FantasyMatchup, teamIndex: Int) -> Double {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        return team.currentScore ?? 0.0
    }
    
    /// Get manager record for display with REAL league data 
    func getManagerRecord(managerID: String) -> String {
        // 🔥 NEW: For Sleeper leagues, don't show any records for ESPN teams
        if let selectedLeague = selectedLeague, selectedLeague.source == .espn {
            return ""  // Don't show any record for ESPN leagues
        }
        
        // First, try to find the team in current matchups to get their record
        for matchup in matchups {
            let homeTeam = matchup.homeTeam
            let awayTeam = matchup.awayTeam
            
            var targetTeam: FantasyTeam? = nil
            
            if homeTeam.id == managerID {
                targetTeam = homeTeam
            } else if awayTeam.id == managerID {
                targetTeam = awayTeam
            }
            
            if let team = targetTeam {
                // Use the team's record if available
                if let record = team.record {
                    let recordString = record.displayString
                    
                    // Calculate league rank based on wins/losses
                    let leagueRank = calculateLeagueRank(for: team)
                    let rankSuffix = getRankSuffix(leagueRank)
                    
                    return "\(recordString) • Rank: \(leagueRank)\(rankSuffix)"
                }
            }
        }
        
        // For Sleeper leagues, return empty string instead of fake data
        return ""
    }
    
    /// Get score difference text for VS section
    func scoreDifferenceText(matchup: FantasyMatchup) -> String {
        let awayScore = getScore(for: matchup, teamIndex: 0)
        let homeScore = getScore(for: matchup, teamIndex: 1)
        return String(format: "%.2f", abs(awayScore - homeScore))
    }
    
    /// Get roster data for a team with proper position sorting (DATA ONLY - NO VIEW)
    func getRosterData(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            let order1 = positionSortOrder(player1.position)
            let order2 = positionSortOrder(player2.position)
            
            if order1 != order2 {
                return order1 < order2
            } else {
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
    }
    
    /// Get roster data with custom sorting (DATA ONLY - NO VIEW)
    func getRosterDataSorted(
        for matchup: FantasyMatchup, 
        teamIndex: Int, 
        isBench: Bool, 
        sortMethod: MatchupSortingMethod, 
        highToLow: Bool
    ) -> [FantasyPlayer] {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        let filteredPlayers = team.roster.filter { player in
            isBench ? !player.isStarter : player.isStarter
        }
        
        return filteredPlayers.sorted { player1, player2 in
            switch sortMethod {
            case .position:
                let order1 = positionSortOrder(player1.position)
                let order2 = positionSortOrder(player2.position)
                
                if order1 != order2 {
                    return highToLow ? order1 > order2 : order1 < order2
                } else {
                    // If same position, sort by score (high to low)
                    let points1 = player1.currentPoints ?? 0.0
                    let points2 = player2.currentPoints ?? 0.0
                    return points1 > points2
                }
                
            case .score:
                let points1 = player1.currentPoints ?? 0.0
                let points2 = player2.currentPoints ?? 0.0
                return highToLow ? points1 > points2 : points1 < points2
                
            case .name:
                let name1 = player1.fullName.lowercased()
                let name2 = player2.fullName.lowercased()
                return highToLow ? name1 > name2 : name1 < name2
                
            case .team: 
                let team1 = player1.team?.lowercased() ?? ""
                let team2 = player2.team?.lowercased() ?? ""
                return highToLow ? team1 > team2 : team1 < team2
            }
        }
    }
    
    /// Get positional ranking for a player (e.g., "RB1", "WR2", "TE1") - DATA ONLY
    func getPositionalRanking(for player: FantasyPlayer, in matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> String {
        let roster = getRosterData(for: matchup, teamIndex: teamIndex, isBench: isBench)
        
        let samePositionPlayers = roster.filter { $0.position.uppercased() == player.position.uppercased() }
        
        if let playerIndex = samePositionPlayers.firstIndex(where: { $0.id == player.id }) {
            let rank = playerIndex + 1
            return "\(player.position.uppercased())\(rank)"
        }
        
        return player.position.uppercased()
    }
    
    /// Position sorting order: QB, WR, RB, TE, FLEX, Super Flex, K, D/ST - DATA ONLY
    private func positionSortOrder(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "WR": return 2
        case "RB": return 3
        case "TE": return 4
        case "FLEX": return 5
        case "SUPER FLEX", "SF", "SUPERFLEX": return 6
        case "K": return 7
        case "D/ST", "DST", "DEF": return 8
        case "BN", "BENCH": return 9
        default: return 10
        }
    }
    
    /// Calculate league rank based on current matchups and records - DATA ONLY
    private func calculateLeagueRank(for targetTeam: FantasyTeam) -> Int {
        var allTeams: [FantasyTeam] = []
        
        // Collect all teams from all matchups
        for matchup in matchups {
            allTeams.append(matchup.homeTeam)
            allTeams.append(matchup.awayTeam)
        }
        
        // Remove duplicates based on team ID
        var uniqueTeams: [FantasyTeam] = []
        var seenIDs = Set<String>()
        
        for team in allTeams {
            if !seenIDs.contains(team.id) {
                uniqueTeams.append(team)
                seenIDs.insert(team.id)
            }
        }
        
        // Sort teams by record (wins first, then win percentage)
        let sortedTeams = uniqueTeams.sorted { team1, team2 in
            guard let record1 = team1.record, let record2 = team2.record else {
                // Teams without records go to the bottom
                return team1.record != nil
            }
            
            // First sort by wins
            if record1.wins != record2.wins {
                return record1.wins > record2.wins
            }
            
            // Then by win percentage (fewer losses is better)
            let totalGames1 = record1.wins + record1.losses + (record1.ties ?? 0)
            let totalGames2 = record2.wins + record2.losses + (record2.ties ?? 0)
            
            if totalGames1 > 0 && totalGames2 > 0 {
                let winPct1 = Double(record1.wins) / Double(totalGames1)
                let winPct2 = Double(record2.wins) / Double(totalGames2)
                return winPct1 > winPct2
            }
            
            return record1.losses < record2.losses
        }
        
        // Find the target team's position
        for (index, team) in sortedTeams.enumerated() {
            if team.id == targetTeam.id {
                return index + 1  // Rank is 1-based
            }
        }
        
        return sortedTeams.count  // Last place if not found
    }
    
    /// Calculate league rank for ESPN teams using espnTeamRecords - DATA ONLY
    private func calculateESPNLeagueRank(for teamID: Int) -> Int {
        let allRecords = Array(espnTeamRecords.values)
        
        guard let targetRecord = espnTeamRecords[teamID] else {
            return allRecords.count
        }
        
        // Sort all records by wins, then by win percentage
        let sortedRecords = allRecords.sorted { record1, record2 in
            // First sort by wins
            if record1.wins != record2.wins {
                return record1.wins > record2.wins
            }
            
            // Then by win percentage
            let totalGames1 = record1.wins + record1.losses + (record1.ties ?? 0)
            let totalGames2 = record2.wins + record2.losses + (record2.ties ?? 0)
            
            if totalGames1 > 0 && totalGames2 > 0 {
                let winPct1 = Double(record1.wins) / Double(totalGames1)
                let winPct2 = Double(record2.wins) / Double(totalGames2)
                return winPct1 > winPct2
            }
            
            return record1.losses < record2.losses
        }
        
        // Find the target record's position
        for (index, record) in sortedRecords.enumerated() {
            if record.wins == targetRecord.wins && 
               record.losses == targetRecord.losses && 
               record.ties == targetRecord.ties {
                return index + 1  // Rank is 1-based
            }
        }
        
        return sortedRecords.count  // Last place if not found
    }
    
    /// Get ordinal suffix for rank (1st, 2nd, 3rd, 4th, etc.) - DATA ONLY
    private func getRankSuffix(_ rank: Int) -> String {
        switch rank {
        case 1: return "st"
        case 2: return "nd" 
        case 3: return "rd"
        default: return "th"
        }
    }
}