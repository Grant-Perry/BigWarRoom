//
//  PlayerMatchService.swift
//  BigWarRoom
//
//  High-performance player matching service with caching and indexing
//

import Foundation
import Combine

/// **PlayerMatchService**
/// 
/// High-performance player matching with indexing and caching to eliminate O(n) scans
@MainActor
final class PlayerMatchService: ObservableObject {
    static let shared = PlayerMatchService()
    
    // MARK: - Properties
    
    private var playerDirectory: PlayerDirectoryStore { PlayerDirectoryStore.shared }
    
    // Performance indexes
    private var lastNameIndex: [String: [SleeperPlayer]] = [:]
    private var teamPositionIndex: [String: [SleeperPlayer]] = [:]  // "TEAM_POSITION" -> [players]
    private var shortNameIndex: [String: [SleeperPlayer]] = [:]
    
    // Match result cache
    private var matchCache: [String: SleeperPlayer?] = [:]
    
    // Cache invalidation
    private var lastIndexUpdate: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Listen for player directory updates
        playerDirectory.$players
            .sink { [weak self] _ in
                self?.invalidateIndexes()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    /// Convenience method matching the old interface
    /// - Parameters:
    ///   - fullName: Player's full name
    ///   - shortName: Player's short name
    ///   - team: Team code
    ///   - position: Position
    /// - Returns: Matched SleeperPlayer or nil
    func matchPlayer(fullName: String, shortName: String, team: String?, position: String) -> SleeperPlayer? {
        let result = matchPlayerWithConfidence(fullName: fullName, shortName: shortName, team: team, position: position)
        
        print("🔍 MATCH DEBUG: PlayerMatchService result")
        print("   - Input: '\(fullName)' (\(shortName)) - \(team ?? "nil") \(position)")
        print("   - Match found: \(result.player != nil)")
        print("   - Confidence: \(result.confidence)%")
        if let player = result.player {
            print("   - Matched: \(player.fullName) - \(player.team ?? "nil") \(player.position ?? "nil")")
            print("   - ESPN ID: \(player.espnID ?? "NONE")")
        }
        
        return result.player
    }
    
    /// Match a player with confidence scoring
    /// - Parameters:
    ///   - fullName: Player's full name
    ///   - shortName: Player's short name 
    ///   - team: Team code
    ///   - position: Position
    /// - Returns: Tuple of (matched player, confidence score 0-100)
    func matchPlayerWithConfidence(
        fullName: String,
        shortName: String,
        team: String?,
        position: String
    ) -> (player: SleeperPlayer?, confidence: Int) {
        
        print("🔍 MATCH DEBUG: Starting player match")
        print("   - Input: '\(fullName)' (\(shortName)) - \(team ?? "nil") \(position)")
        
        let cacheKey = "\(fullName)|\(shortName)|\(team ?? "")|\(position)"
        
        // Check cache first
        if let cachedResult = matchCache[cacheKey] {
            print("🔍 MATCH DEBUG: Found cached result: \(cachedResult != nil)")
            return (cachedResult, cachedResult != nil ? 90 : 0)
        }
        
        // Ensure indexes are current
        ensureIndexesCurrent()
        
        // Normalize inputs
        let normalizedTeam = TeamCodeNormalizer.normalize(team)?.uppercased()
        let normalizedPosition = normalizePosition(position)
        
        print("🔍 MATCH DEBUG: Normalized team: \(normalizedTeam ?? "nil"), position: \(normalizedPosition)")
        
        // Try matching strategies in order of confidence
        let strategies: [(SleeperPlayer?, Int)] = [
            exactMatch(fullName: fullName, team: normalizedTeam, position: normalizedPosition),
            shortNameMatch(shortName: shortName, team: normalizedTeam, position: normalizedPosition),
            lastNameMatch(fullName: fullName, team: normalizedTeam, position: normalizedPosition),
            fuzzyTeamMatch(fullName: fullName, shortName: shortName, team: normalizedTeam, position: normalizedPosition),
            fuzzyPositionMatch(fullName: fullName, shortName: shortName, team: normalizedTeam, position: normalizedPosition)
        ]
        
        // Return the highest confidence match
        for (player, confidence) in strategies {
            if let player = player {
                print("🔍 MATCH DEBUG: Found match with confidence \(confidence)%")
                print("   - Matched: \(player.fullName) - \(player.team ?? "nil") \(player.position ?? "nil")")
                print("   - ESPN ID: \(player.espnID ?? "NONE")")
                matchCache[cacheKey] = player
                return (player, confidence)
            }
        }
        
        // No match found
        print("🔍 MATCH DEBUG: No match found")
        matchCache[cacheKey] = nil
        return (nil, 0)
    }
    
    // MARK: - Indexing
    
    private func ensureIndexesCurrent() {
        let shouldRebuild = lastIndexUpdate == nil || 
                           Date().timeIntervalSince(lastIndexUpdate!) > 300 // 5 minutes
        
        if shouldRebuild {
            buildIndexes()
        }
    }
    
    private func buildIndexes() {
        let startTime = Date()
        
        // Clear existing indexes
        lastNameIndex.removeAll()
        teamPositionIndex.removeAll()
        shortNameIndex.removeAll()
        matchCache.removeAll()
        
        // Build indexes from player directory
        for player in playerDirectory.players.values {
            // Last name index
            if let lastName = player.lastName?.lowercased() {
                lastNameIndex[lastName, default: []].append(player)
            }
            
            // Team + Position index  
            let team = player.team?.uppercased() ?? ""
            let position = normalizePosition(player.position ?? "")
            let teamPositionKey = "\(team)_\(position)"
            teamPositionIndex[teamPositionKey, default: []].append(player)
            
            // Short name index
            let shortName = player.shortName.lowercased()
            shortNameIndex[shortName, default: []].append(player)
        }
        
        lastIndexUpdate = Date()
        let elapsed = Date().timeIntervalSince(startTime)
        print("🏗️ PlayerMatchService: Built indexes for \(playerDirectory.players.count) players in \(Int(elapsed * 1000))ms")
    }
    
    private func invalidateIndexes() {
        lastIndexUpdate = nil
        matchCache.removeAll()
        print("🗑️ PlayerMatchService: Indexes invalidated")
    }
    
    // MARK: - Matching Strategies
    
    private func exactMatch(fullName: String, team: String?, position: String) -> (SleeperPlayer?, Int) {
        guard let team = team else { 
            print("🔍 EXACT MATCH: No team provided")
            return (nil, 0) 
        }
        
        let teamPositionKey = "\(team)_\(position)"
        let candidates = teamPositionIndex[teamPositionKey] ?? []
        
        print("🔍 EXACT MATCH: Looking for '\(fullName)' in \(teamPositionKey)")
        print("🔍 EXACT MATCH: Found \(candidates.count) candidates")
        
        for candidate in candidates.prefix(5) {  // Log first 5 candidates
            print("   - Candidate: \(candidate.fullName) (ESPN: \(candidate.espnID ?? "NONE"))")
        }
        
        let matches = candidates.filter { 
            $0.fullName.lowercased() == fullName.lowercased() 
        }
        
        print("🔍 EXACT MATCH: Found \(matches.count) exact matches")
        
        return matches.count == 1 ? (matches.first, 100) : (nil, 0)
    }
    
    private func shortNameMatch(shortName: String, team: String?, position: String) -> (SleeperPlayer?, Int) {
        guard let team = team else { return (nil, 0) }
        
        let shortNameCandidates = shortNameIndex[shortName.lowercased()] ?? []
        let matches = shortNameCandidates.filter {
            $0.team?.uppercased() == team && normalizePosition($0.position ?? "") == position
        }
        
        return matches.count == 1 ? (matches.first, 90) : (nil, 0)
    }
    
    private func lastNameMatch(fullName: String, team: String?, position: String) -> (SleeperPlayer?, Int) {
        guard let team = team else { return (nil, 0) }
        
        let lastName = extractLastName(from: fullName).lowercased()
        let lastNameCandidates = lastNameIndex[lastName] ?? []
        
        let matches = lastNameCandidates.filter {
            $0.team?.uppercased() == team && normalizePosition($0.position ?? "") == position
        }
        
        return matches.count == 1 ? (matches.first, 80) : (nil, 0)
    }
    
    private func fuzzyTeamMatch(fullName: String, shortName: String, team: String?, position: String) -> (SleeperPlayer?, Int) {
        guard let team = team else { return (nil, 0) }
        
        let teamAliases = TeamCodeNormalizer.aliases(for: team)
        var matches: [SleeperPlayer] = []
        
        for alias in teamAliases {
            let teamPositionKey = "\(alias.uppercased())_\(position)"
            let candidates = teamPositionIndex[teamPositionKey] ?? []
            
            let nameMatches = candidates.filter { player in
                player.fullName.lowercased() == fullName.lowercased() ||
                player.shortName.lowercased() == shortName.lowercased()
            }
            
            matches.append(contentsOf: nameMatches)
        }
        
        // Remove duplicates
        let uniqueMatches = Array(Set(matches.map { $0.playerID })).compactMap { id in
            matches.first { $0.playerID == id }
        }
        
        return uniqueMatches.count == 1 ? (uniqueMatches.first, 70) : (nil, 0)
    }
    
    private func fuzzyPositionMatch(fullName: String, shortName: String, team: String?, position: String) -> (SleeperPlayer?, Int) {
        guard let team = team else { return (nil, 0) }
        
        let positionAliases = getPositionAliases(for: position)
        var matches: [SleeperPlayer] = []
        
        for alias in positionAliases {
            let teamPositionKey = "\(team)_\(alias)"
            let candidates = teamPositionIndex[teamPositionKey] ?? []
            
            let nameMatches = candidates.filter { player in
                player.fullName.lowercased() == fullName.lowercased() ||
                player.shortName.lowercased() == shortName.lowercased()
            }
            
            matches.append(contentsOf: nameMatches)
        }
        
        // Remove duplicates
        let uniqueMatches = Array(Set(matches.map { $0.playerID })).compactMap { id in
            matches.first { $0.playerID == id }
        }
        
        return uniqueMatches.count == 1 ? (uniqueMatches.first, 60) : (nil, 0)
    }
    
    // MARK: - Utility Methods
    
    private func extractLastName(from fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.last ?? fullName
    }
    
    private func normalizePosition(_ position: String) -> String {
        switch position.uppercased() {
        case "DEF", "D/ST":
            return "DST"
        case "FLEX":
            return "FLEX" 
        default:
            return position.uppercased()
        }
    }
    
    private func getPositionAliases(for position: String) -> [String] {
        switch position.uppercased() {
        case "DST":
            return ["DST", "DEF", "D/ST"]
        case "DEF":
            return ["DST", "DEF", "D/ST"]
        case "FLEX":
            return ["FLEX", "RB", "WR", "TE"]
        case "RB":
            return ["RB", "FLEX"]
        case "WR":
            return ["WR", "FLEX"] 
        case "TE":
            return ["TE", "FLEX"]
        default:
            return [position.uppercased()]
        }
    }
}