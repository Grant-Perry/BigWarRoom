//
//  PlayerSortingService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Reusable player sorting logic
//  Used across fantasy views for consistent sorting behavior
//

import Foundation

/// **PlayerSortingService**
/// 
/// DRY service for sorting fantasy players with:
/// - Position, Score, Name, Team sorting methods
/// - High-to-low and low-to-high directions
/// - Consistent logic across the entire app
/// - Easy to extend with new sorting methods
struct PlayerSortingService {
    
    /// Sort fantasy players based on method and direction
    static func sortPlayers(
        _ players: [FantasyPlayer], 
        by method: MatchupSortingMethod, 
        highToLow: Bool,
        getPlayerPoints: ((FantasyPlayer) -> Double?)? = nil
    ) -> [FantasyPlayer] {
        
        let sorted = players.sorted { player1, player2 in
            switch method {
            case .position:
                let pos1 = player1.position
                let pos2 = player2.position
                if highToLow {
                    return pos1 > pos2
                } else {
                    return pos1 < pos2
                }
                
            case .score:
                let points1 = getPlayerPoints?(player1) ?? player1.currentPoints ?? 0.0
                let points2 = getPlayerPoints?(player2) ?? player2.currentPoints ?? 0.0
                if highToLow {
                    return points1 > points2
                } else {
                    return points1 < points2
                }
                
            case .name:
                let name1 = player1.fullName
                let name2 = player2.fullName
                if highToLow {
                    return name1 > name2
                } else {
                    return name1 < name2
                }
                
            case .team:
                let team1 = player1.team ?? ""
                let team2 = player2.team ?? ""
                if highToLow {
                    return team1 > team2
                } else {
                    return team1 < team2
                }
                
            case .recentActivity:
                // Live players first, then sort by score
                let live1 = player1.isLive
                let live2 = player2.isLive
                
                if live1 != live2 {
                    return live1
                }
                let points1 = getPlayerPoints?(player1) ?? player1.currentPoints ?? 0.0
                let points2 = getPlayerPoints?(player2) ?? player2.currentPoints ?? 0.0
                return points1 > points2
            }
        }
        
        return sorted
    }
}
