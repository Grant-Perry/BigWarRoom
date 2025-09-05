//
//  FantasyViewModel+UIHelpers.swift
//  BigWarRoom
//
//  UI Helper functionality for FantasyViewModel
//

import Foundation
import SwiftUI

// MARK: -> UI Helpers Extension
extension FantasyViewModel {
    
    /// Calculate win probability based on scores
    func calculateWinProbability(homeScore: Double, awayScore: Double) -> Double {
        if homeScore == 0 && awayScore == 0 { return 0.5 }
        return homeScore / (homeScore + awayScore)
    }
    
    /// Create mock game status for testing
    func createMockGameStatus() -> GameStatus {
        let statuses = ["pregame", "live", "postgame", "bye"]
        let randomStatus = statuses.randomElement() ?? "pregame"
        
        return GameStatus(
            status: randomStatus,
            startTime: Calendar.current.date(byAdding: .hour, value: Int.random(in: 1...6), to: Date()),
            timeRemaining: randomStatus == "live" ? "14:32" : nil,
            quarter: randomStatus == "live" ? "2nd" : nil,
            homeScore: randomStatus != "pregame" ? Int.random(in: 0...35) : nil,
            awayScore: randomStatus != "pregame" ? Int.random(in: 0...35) : nil
        )
    }
    
    /// Get score for a team in a matchup
    func getScore(for matchup: FantasyMatchup, teamIndex: Int) -> Double {
        let team = teamIndex == 0 ? matchup.awayTeam : matchup.homeTeam
        return team.currentScore ?? 0.0
    }
    
    /// Get manager record for display with real ESPN data
    func getManagerRecord(managerID: String) -> String {
        if let selectedLeague = selectedLeague, selectedLeague.source == .espn {
            if let teamID = Int(managerID),
               let record = espnTeamRecords[teamID] {
                return "\(record.wins)-\(record.losses) • Rank: 2nd"
            }
        }
        return "0-0 • Rank: 2nd"
    }
    
    /// Get score difference text for VS section
    func scoreDifferenceText(matchup: FantasyMatchup) -> String {
        let awayScore = getScore(for: matchup, teamIndex: 0)
        let homeScore = getScore(for: matchup, teamIndex: 1)
        return String(format: "%.2f", abs(awayScore - homeScore))
    }
    
    /// Active roster section view
    func activeRosterSection(matchup: FantasyMatchup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Roster")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Active Roster (Left column - teamIndex 0)
                VStack(spacing: 8) {
                    let awayActiveRoster = getRoster(for: matchup, teamIndex: 0, isBench: false)
                    ForEach(awayActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: false
                        )
                    }
                    
                    let awayScore = getScore(for: matchup, teamIndex: 0)
                    let homeScore = getScore(for: matchup, teamIndex: 1)
                    let awayWinning = awayScore > homeScore
                    
                    Text("Active Total: \(String(format: "%.2f", awayScore))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(awayWinning ? .gpGreen : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Home Team Active Roster (Right column - teamIndex 1)
                VStack(spacing: 8) {
                    let homeActiveRoster = getRoster(for: matchup, teamIndex: 1, isBench: false)
                    ForEach(homeActiveRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: false
                        )
                    }
                    
                    let awayScore = getScore(for: matchup, teamIndex: 0)
                    let homeScore = getScore(for: matchup, teamIndex: 1);
                    let homeWinning = homeScore > awayScore
                    
                    Text("Active Total: \(String(format: "%.2f", homeScore))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(homeWinning ? .gpGreen : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Bench section view
    func benchSection(matchup: FantasyMatchup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            HStack(alignment: .top, spacing: 16) {
                // Away Team Bench (Left column - teamIndex 0)
                VStack(spacing: 8) {
                    let awayBenchRoster = getRoster(for: matchup, teamIndex: 0, isBench: true)
                    ForEach(awayBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 0,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = awayBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    Text("Bench Total: \(String(format: "%.2f", benchTotal))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Home Team Bench (Right column - teamIndex 1)
                VStack(spacing: 8) {
                    let homeBenchRoster = getRoster(for: matchup, teamIndex: 1, isBench: true)
                    ForEach(homeBenchRoster, id: \.id) { player in
                        FantasyPlayerCard(
                            player: player, 
                            fantasyViewModel: self,
                            matchup: matchup,
                            teamIndex: 1,
                            isBench: true
                        )
                    }
                    
                    let benchTotal = homeBenchRoster.reduce(0.0) { $0 + ($1.currentPoints ?? 0.0) }
                    Text("Bench Total: \(String(format: "%.2f", benchTotal))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(.secondarySystemBackground), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Get roster for a team with proper position sorting
    private func getRoster(for matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> [FantasyPlayer] {
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
    
    /// Get positional ranking for a player (e.g., "RB1", "WR2", "TE1")
    func getPositionalRanking(for player: FantasyPlayer, in matchup: FantasyMatchup, teamIndex: Int, isBench: Bool) -> String {
        let roster = getRoster(for: matchup, teamIndex: teamIndex, isBench: isBench)
        
        let samePositionPlayers = roster.filter { $0.position.uppercased() == player.position.uppercased() }
        
        if let playerIndex = samePositionPlayers.firstIndex(where: { $0.id == player.id }) {
            let rank = playerIndex + 1
            return "\(player.position.uppercased())\(rank)"
        }
        
        return player.position.uppercased()
    }
    
    /// Position sorting order: QB, WR, RB, TE, FLEX, Super Flex, K, D/ST
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
}