//
//  PlayerFilteringService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Pure business logic for filtering players
//  Extracted from AllLivePlayersViewModel to follow MVVM pattern
//

import Foundation

/// Service responsible for filtering players by various criteria
/// - Pure business logic, no UI state
/// - Stateless and testable
/// - Single Responsibility: Filter players by position, activity, quality, search
final class PlayerFilteringService {
    
    // MARK: - Singleton (stateless service)
    static let shared = PlayerFilteringService()
    private init() {}
    
    // MARK: - Public Interface
    
    /// Apply all filters to a list of players
    func applyFilters(
        to players: [AllLivePlayersViewModel.LivePlayerEntry],
        selectedPosition: AllLivePlayersViewModel.PlayerPosition,
        showActiveOnly: Bool,
        gameDataService: NFLGameDataService
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        
        var filtered = players
        
        // Step 1: Position filter
        if selectedPosition != .all {
            filtered = filterByPosition(filtered, position: selectedPosition)
        }
        
        // Step 2: Active-only filter
        if showActiveOnly {
            filtered = filterByActiveGame(filtered, gameDataService: gameDataService)
        }
        
        // Step 3: Quality filter (remove invalid/unknown players)
        filtered = filterByQuality(filtered)
        
        return filtered
    }
    
    /// Filter players by search text
    func filterBySearchText(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        searchText: String
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return players
        }
        
        return players.filter { playerNameMatches($0.playerName, searchQuery: searchText) }
    }
    
    /// Filter Sleeper players by search text
    func filterSleeperPlayers(
        _ players: [SleeperPlayer],
        searchText: String
    ) -> [SleeperPlayer] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return players
        }
        
        return players.filter { sleeperPlayerMatches($0, searchQuery: searchText) }
    }
    
    // MARK: - Filter Methods
    
    private func filterByPosition(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        position: AllLivePlayersViewModel.PlayerPosition
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return players.filter { $0.position.uppercased() == position.rawValue }
    }
    
    private func filterByActiveGame(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry],
        gameDataService: NFLGameDataService
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return players.filter { player in
            player.player.isInActiveGame(gameDataService: gameDataService)
        }
    }
    
    private func filterByQuality(
        _ players: [AllLivePlayersViewModel.LivePlayerEntry]
    ) -> [AllLivePlayersViewModel.LivePlayerEntry] {
        return players.filter { player in
            // Keep players with valid names and reasonable data
            let hasValidName = !player.playerName.trimmingCharacters(in: .whitespaces).isEmpty
            let isNotUnknown = player.player.fullName != "Unknown Player"
            let hasReasonableData = player.currentScore >= 0.0 // Allow 0.0 scores
            
            return hasValidName && isNotUnknown && hasReasonableData
        }
    }
    
    // MARK: - Search Matching
    
    /// Smart name matching that handles apostrophes and partial matches
    private func playerNameMatches(_ playerName: String, searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let name = playerName.lowercased()
        
        guard !query.isEmpty else { return false }
        
        // Split both query and name by spaces for flexible matching
        let queryTerms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let nameComponents = name.components(separatedBy: .whitespaces)
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.last ?? ""
        
        // For each query term, check if ANY name field contains it
        for queryTerm in queryTerms {
            let termFound = name.contains(queryTerm) ||
                          firstName.contains(queryTerm) ||
                          lastName.contains(queryTerm)
            
            if termFound {
                return true  // If any term matches, player matches
            }
        }
        
        return false
    }
    
    /// Smart name matching for SleeperPlayer objects
    private func sleeperPlayerMatches(_ player: SleeperPlayer, searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !query.isEmpty else { return false }
        
        let fullName = player.fullName.lowercased()
        let shortName = player.shortName.lowercased()
        let firstName = player.firstName?.lowercased() ?? ""
        let lastName = player.lastName?.lowercased() ?? ""
        
        // Split query by spaces for flexible matching
        let queryTerms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // For each query term, check if ANY name field contains it
        for queryTerm in queryTerms {
            let termFound = fullName.contains(queryTerm) ||
                          shortName.contains(queryTerm) ||
                          firstName.contains(queryTerm) ||
                          lastName.contains(queryTerm)
            
            if termFound {
                return true  // If any term matches, player matches
            }
        }
        
        return false
    }
}