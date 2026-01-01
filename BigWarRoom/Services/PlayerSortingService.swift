//
//  PlayerSortingService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Pure business logic for sorting players
//  Extracted from AllLivePlayersViewModel to follow MVVM pattern
//

import Foundation

/// Service responsible for all player sorting logic
/// - Pure business logic, no UI state
/// - Stateless and testable
/// - Single Responsibility: Sort players by various criteria
final class PlayerSortingService {
    
    // MARK: - Singleton (stateless service)
    static let shared = PlayerSortingService()
    private init() {}
    
    // MARK: - Public Interface
    
    /// Sort LivePlayerEntry objects based on method and direction (for AllLivePlayersViewModel)
    func sortPlayers(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        by method: AllLivePlayersViewModel.SortingMethod,
        highToLow: Bool
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        
        switch method {
        case .position:
            return sortByPosition(players, highToLow: highToLow)
            
        case .score:
            return sortByScore(players, highToLow: highToLow)
            
        case .name:
            return sortByName(players, highToLow: highToLow)
            
        case .team:
            return sortByTeam(players, highToLow: highToLow)
            
        case .recent:
            return sortByRecentActivity(players)
        }
    }
    
    // MARK: - Generic FantasyPlayer Sorting (for other ViewModels)
    
    /// Sort FantasyPlayer objects based on various criteria
    /// Used by ChoppedTeamRosterViewModel and other roster views
    func sortFantasyPlayers(
        _ players: [FantasyPlayer],
        by method: MatchupSortingMethod,
        highToLow: Bool,
        getPlayerPoints: ((FantasyPlayer) -> Double?)? = nil,
        gameDataService: NFLGameDataService
    ) -> [FantasyPlayer] {
        
        switch method {
        case .position:
            return sortFantasyPlayersByPosition(players, highToLow: highToLow)
            
        case .score:
            return sortFantasyPlayersByScore(players, highToLow: highToLow, getPlayerPoints: getPlayerPoints)
            
        case .name:
            return sortFantasyPlayersByName(players, highToLow: highToLow)
            
        case .team:
            return sortFantasyPlayersByTeam(players, highToLow: highToLow)
            
        case .recentActivity:
            return sortFantasyPlayersByGameStatus(players, gameDataService: gameDataService)
        }
    }
    
    // MARK: - FantasyPlayer Sorting Methods
    
    private func sortFantasyPlayersByPosition(_ players: [FantasyPlayer], highToLow: Bool) -> [FantasyPlayer] {
        return highToLow ?
            players.sorted { positionPriority($0.position) < positionPriority($1.position) } :
            players.sorted { positionPriority($0.position) > positionPriority($1.position) }
    }
    
    private func sortFantasyPlayersByScore(
        _ players: [FantasyPlayer],
        highToLow: Bool,
        getPlayerPoints: ((FantasyPlayer) -> Double?)?
    ) -> [FantasyPlayer] {
        return highToLow ?
            players.sorted { player1, player2 in
                let score1 = getPlayerPoints?(player1) ?? player1.currentPoints ?? 0.0
                let score2 = getPlayerPoints?(player2) ?? player2.currentPoints ?? 0.0
                
                if score1 != score2 {
                    return score1 > score2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            } :
            players.sorted { player1, player2 in
                let score1 = getPlayerPoints?(player1) ?? player1.currentPoints ?? 0.0
                let score2 = getPlayerPoints?(player2) ?? player2.currentPoints ?? 0.0
                
                if score1 != score2 {
                    return score1 < score2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            }
    }
    
    private func sortFantasyPlayersByName(_ players: [FantasyPlayer], highToLow: Bool) -> [FantasyPlayer] {
        return highToLow ?
            players.sorted { extractLastName($0.fullName) < extractLastName($1.fullName) } :
            players.sorted { extractLastName($0.fullName) > extractLastName($1.fullName) }
    }
    
    private func sortFantasyPlayersByTeam(_ players: [FantasyPlayer], highToLow: Bool) -> [FantasyPlayer] {
        return highToLow ?
            players.sorted { player1, player2 in
                let team1 = (player1.team ?? "").isEmpty ? "ZZZ" : (player1.team ?? "").uppercased()
                let team2 = (player2.team ?? "").isEmpty ? "ZZZ" : (player2.team ?? "").uppercased()
                
                if team1 != team2 {
                    return team1 < team2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            } :
            players.sorted { player1, player2 in
                let team1 = (player1.team ?? "").isEmpty ? "ZZZ" : (player1.team ?? "").uppercased()
                let team2 = (player2.team ?? "").isEmpty ? "ZZZ" : (player2.team ?? "").uppercased()
                
                if team1 != team2 {
                    return team1 > team2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            }
    }
    
    private func sortFantasyPlayersByGameStatus(
        _ players: [FantasyPlayer],
        gameDataService: NFLGameDataService
    ) -> [FantasyPlayer] {
        return players.sorted { player1, player2 in
            // Check if players are in live games
            let isLive1 = player1.isLive(gameDataService: gameDataService)
            let isLive2 = player2.isLive(gameDataService: gameDataService)
            
            // Live players first
            if isLive1 != isLive2 {
                return isLive1
            }
            
            // Then by score
            let score1 = player1.currentPoints ?? 0.0
            let score2 = player2.currentPoints ?? 0.0
            
            if score1 != score2 {
                return score1 > score2
            }
            
            // Finally by position
            return positionPriority(player1.position) < positionPriority(player2.position)
        }
    }
    
    // MARK: - Sorting Methods
    
    private func sortByPosition(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        highToLow: Bool
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return highToLow ?
            players.sorted { positionPriority($0.position) < positionPriority($1.position) } :
            players.sorted { positionPriority($0.position) > positionPriority($1.position) }
    }
    
    private func sortByScore(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        highToLow: Bool
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        // Sort by score with position priority as tiebreaker
        return highToLow ?
            players.sorted { player1, player2 in
                if player1.currentScore != player2.currentScore {
                    return player1.currentScore > player2.currentScore
                }
                // Secondary sort by position priority when scores are equal
                return positionPriority(player1.position) < positionPriority(player2.position)
            } :
            players.sorted { player1, player2 in
                if player1.currentScore != player2.currentScore {
                    return player1.currentScore < player2.currentScore
                }
                // Secondary sort by position priority when scores are equal
                return positionPriority(player1.position) < positionPriority(player2.position)
            }
    }
    
    private func sortByName(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        highToLow: Bool
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return highToLow ?
            players.sorted { extractLastName($0.playerName) < extractLastName($1.playerName) } :
            players.sorted { extractLastName($0.playerName) > extractLastName($1.playerName) }
    }
    
    private func sortByTeam(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        highToLow: Bool
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return highToLow ?
            players.sorted { player1, player2 in
                let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()
                
                if team1 != team2 {
                    return team1 < team2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            } :
            players.sorted { player1, player2 in
                let team1 = player1.teamName.isEmpty ? "ZZZ" : player1.teamName.uppercased()
                let team2 = player2.teamName.isEmpty ? "ZZZ" : player2.teamName.uppercased()
                
                if team1 != team2 {
                    return team1 > team2
                }
                return positionPriority(player1.position) < positionPriority(player2.position)
            }
    }
    
    private func sortByRecentActivity(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry]
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        // Sort by most recent activity, then by score
        return players.sorted { player1, player2 in
            let time1 = player1.lastActivityTime ?? Date.distantPast
            let time2 = player2.lastActivityTime ?? Date.distantPast
            
            if time1 != time2 {
                return time1 > time2 // Most recent first
            }
            
            // Secondary sort by score
            return player1.currentScore > player2.currentScore
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get position priority for sorting (QB > RB > WR > TE > FLEX > SF > DEF > K)
    private func positionPriority(_ position: String) -> Int {
        switch position.uppercased() {
        case "QB": return 1
        case "RB": return 2
        case "WR": return 3
        case "TE": return 4
        case "FLEX", "W/R/T": return 5
        case "SUPERFLEX", "SUPER FLEX", "SF", "Q/W/R/T": return 6
        case "DEF", "DST", "D/ST": return 7
        case "K": return 8
        default: return 9
        }
    }
    
    /// Extract last name from full name for alphabetical sorting
    private func extractLastName(_ fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }
}