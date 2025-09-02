import Foundation
import SwiftUI

// MARK: - View Helper Methods
extension DraftRoomViewModel {
    
    /// Find SleeperPlayer for a given internal Player
    func findSleeperPlayer(for player: Player) -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        // Direct ID match first
        if let directMatch = PlayerDirectoryStore.shared.players[player.id] {
            return directMatch
        }
        
        // Exact name match
        let nameMatch = allSleeperPlayers.first { sleeperPlayer in
            let nameMatches = sleeperPlayer.shortName.lowercased() == "\(player.firstInitial) \(player.lastName)".lowercased()
            let positionMatches = sleeperPlayer.position?.uppercased() == player.position.rawValue
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return nameMatches && positionMatches && teamMatches
        }
        
        if let nameMatch = nameMatch {
            return nameMatch
        }
        
        // Fuzzy match fallback
        let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
            guard let sleeperFirst = sleeperPlayer.firstName,
                  let sleeperLast = sleeperPlayer.lastName else { return false }
            
            let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == player.firstInitial.uppercased()
            let lastNameMatches = sleeperLast.lowercased().contains(player.lastName.lowercased()) || 
                                   player.lastName.lowercased().contains(sleeperLast.lowercased())
            let teamMatches = sleeperPlayer.team?.uppercased() == player.team.uppercased()
            
            return firstInitialMatches && lastNameMatches && teamMatches
        }
        
        return fuzzyMatch
    }
    
    /// Add player to picks feed
    func addPlayerToFeed(_ suggestion: Suggestion) {
        let currentFeed = picksFeed.isEmpty ? "" : picksFeed + ", "
        picksFeed = currentFeed + suggestion.player.shortKey
        addFeedPick()
    }
    
    /// Lock player as my pick
    func lockPlayerAsPick(_ suggestion: Suggestion) {
        myPickInput = suggestion.player.shortKey
        lockMyPick()
    }
    
    /// Get top suggestions for display (limited count)
    func getTopSuggestions(limit: Int = 5) -> [Suggestion] {
        return Array(suggestions.prefix(limit))
    }
    
    /// Check if there are more suggestions than the display limit
    func hasMoreSuggestions(than limit: Int = 5) -> Bool {
        return suggestions.count > limit
    }
}

// MARK: - View Color Helpers
extension Position {
    var displayColor: Color {
        switch self.rawValue.uppercased() {
        case "QB": return .purple
        case "RB": return .green
        case "WR": return .blue
        case "TE": return .orange
        case "K": return .gray
        case "DEF": return .red
        default: return .gray
        }
    }
}

extension Player {
    var tierColor: Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }
}