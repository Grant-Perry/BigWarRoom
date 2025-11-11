//
//  ESPNSleeperIDCanonicalizer.swift
//  BigWarRoom
//
//  Creates canonical one-to-one mapping between ESPN IDs and Sleeper IDs
//  Eliminates duplicate ESPN IDs for same players
//

import Foundation
import Observation

/// **ESPNSleeperIDCanonicalizer**
/// 
/// Creates a clean, canonical mapping between ESPN IDs and Sleeper IDs
/// Handles deduplication when Sleeper has multiple ESPN IDs for same player
@Observable
@MainActor
final class ESPNSleeperIDCanonicalizer {
    
    // MARK: - Singleton
    static let shared = ESPNSleeperIDCanonicalizer()
    
    // MARK: - Properties
    
    /// Canonical ESPN ID → Sleeper ID mapping (one-to-one)
    private var canonicalMapping: [String: String] = [:]
    
    /// Reverse mapping: Sleeper ID → ESPN ID (for debugging)
    private var reverseMapping: [String: String] = [:]
    
    /// Cache file URL for persistent storage
    private var cacheFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("ESPNSleeperIDCanonical.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadCachedMapping()
    }
    
    // MARK: - Public Interface
    
    /// Get canonical Sleeper ID for ESPN ID - THE SINGLE SOURCE OF TRUTH
    /// - Parameter espnID: ESPN player ID
    /// - Returns: Canonical Sleeper ID, or the ESPN ID as fallback
    func getCanonicalSleeperID(forESPNID espnID: String) -> String {
        // Check canonical mapping first
        if let sleeperID = canonicalMapping[espnID] {
            return sleeperID
        }
        
        // Not in mapping - return ESPN ID as fallback
        DebugLogger.playerIDMapping("⚠️ ESPN ID '\(espnID)' not in canonical mapping, using as fallback")
        return espnID
    }
    
    /// Build canonical mapping from PlayerDirectoryStore data
    /// This deduplicates multiple ESPN IDs for same player
    func buildCanonicalMapping() {
        DebugLogger.playerIDMapping("🏗️ Building canonical ESPN→Sleeper ID mapping...", level: .info)
        
        let playerDirectory = PlayerDirectoryStore.shared
        var newCanonicalMapping: [String: String] = [:]
        var newReverseMapping: [String: String] = [:]
        var playerNameToSleeperID: [String: String] = [:] // For deduplication
        var duplicateESPNIDs: [String: [String]] = [:] // Track duplicates
        
        // First pass: Group players by normalized name to detect duplicates
        var playersByNormalizedName: [String: [SleeperPlayer]] = [:]
        
        for player in playerDirectory.players.values {
            guard let espnID = player.espnID, !espnID.isEmpty else { continue }
            
            let normalizedName = normalizePlayerName(player.fullName)
            playersByNormalizedName[normalizedName, default: []].append(player)
        }
        
        // Second pass: Create canonical mappings with deduplication
        for (normalizedName, playersWithSameName) in playersByNormalizedName {
            guard !playersWithSameName.isEmpty else { continue }
            
            if playersWithSameName.count == 1 {
                // Single player - straightforward mapping
                let player = playersWithSameName[0]
                if let espnID = player.espnID, !espnID.isEmpty {
                    newCanonicalMapping[espnID] = player.playerID
                    newReverseMapping[player.playerID] = espnID
                }
            } else {
                // Multiple players with same name - DEDUPLICATION NEEDED
                DebugLogger.playerIDMapping("🔍 Found \(playersWithSameName.count) players named '\(normalizedName)':")
                
                // Pick the "canonical" player using smart logic
                let canonicalPlayer = selectCanonicalPlayer(from: playersWithSameName)
                let canonicalESPNID = canonicalPlayer.espnID!
                
                // Map ALL ESPN IDs for this player to the canonical Sleeper ID
                for player in playersWithSameName {
                    if let espnID = player.espnID, !espnID.isEmpty {
                        newCanonicalMapping[espnID] = canonicalPlayer.playerID
                        
                        if espnID != canonicalESPNID {
                            duplicateESPNIDs[normalizedName, default: []].append(espnID)
                            DebugLogger.playerIDMapping("  🔗 Mapping duplicate ESPN ID '\(espnID)' → Sleeper ID '\(canonicalPlayer.playerID)'")
                        }
                    }
                }
                
                // Store reverse mapping with canonical ESPN ID
                newReverseMapping[canonicalPlayer.playerID] = canonicalESPNID
                
                DebugLogger.playerIDMapping("  ✅ Canonical: ESPN ID '\(canonicalESPNID)' → Sleeper ID '\(canonicalPlayer.playerID)'")
            }
        }
        
        // Update mappings
        canonicalMapping = newCanonicalMapping
        reverseMapping = newReverseMapping
        
        // Save to cache
        saveCachedMapping()
        
        // Log results
        DebugLogger.playerIDMapping("🎯 Canonical mapping complete:", level: .info)
        DebugLogger.playerIDMapping("  📊 Total ESPN→Sleeper mappings: \(canonicalMapping.count)")
        DebugLogger.playerIDMapping("  🔗 Players with duplicate ESPN IDs: \(duplicateESPNIDs.count)")
        
        // Show some duplicate examples
        let duplicateExamples = Array(duplicateESPNIDs.prefix(5))
        for (playerName, espnIDs) in duplicateExamples {
            DebugLogger.playerIDMapping("  🔄 '\(playerName)' had ESPN IDs: \(espnIDs.joined(separator: ", "))")
        }
    }
    
    /// Force refresh canonical mapping (clears cache and rebuilds)
    func refreshCanonicalMapping() {
        DebugLogger.playerIDMapping("♻️ Force refreshing canonical mapping...", level: .info)
        canonicalMapping.removeAll()
        reverseMapping.removeAll()
        buildCanonicalMapping()
    }
    
    /// Get debug statistics
    func getDebugStats() -> (totalMappings: Int, duplicatesResolved: Int) {
        let playerDirectory = PlayerDirectoryStore.shared
        let totalPlayersWithESPNID = playerDirectory.players.values.filter { 
            $0.espnID != nil && !$0.espnID!.isEmpty 
        }.count
        
        return (
            totalMappings: canonicalMapping.count,
            duplicatesResolved: totalPlayersWithESPNID - canonicalMapping.count
        )
    }
    
    // MARK: - Private Helpers
    
    /// Normalize player name for deduplication matching
    private func normalizePlayerName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " jr", with: "")
            .replacingOccurrences(of: " sr", with: "")
            .replacingOccurrences(of: " iii", with: "")
            .replacingOccurrences(of: " ii", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Select the "canonical" player when multiple exist for same name
    /// Prioritizes: Active status > Higher search rank > More recent
    private func selectCanonicalPlayer(from players: [SleeperPlayer]) -> SleeperPlayer {
        guard !players.isEmpty else { fatalError("Cannot select from empty players array") }
        
        // Sort by preference: Active status, search rank, then other factors
        let sortedPlayers = players.sorted { player1, player2 in
            // Priority 1: Active status
            let status1 = player1.status?.lowercased() ?? ""
            let status2 = player2.status?.lowercased() ?? ""
            
            let isActive1 = status1 == "active"
            let isActive2 = status2 == "active"
            
            if isActive1 != isActive2 {
                return isActive1 // Active players first
            }
            
            // Priority 2: Search rank (lower is better, nil is worst)
            let rank1 = player1.searchRank ?? 9999
            let rank2 = player2.searchRank ?? 9999
            
            if rank1 != rank2 {
                return rank1 < rank2
            }
            
            // Priority 3: Has team info
            let hasTeam1 = player1.team != nil
            let hasTeam2 = player2.team != nil
            
            if hasTeam1 != hasTeam2 {
                return hasTeam1
            }
            
            // Priority 4: Player ID (for consistent tie-breaking)
            return player1.playerID < player2.playerID
        }
        
        return sortedPlayers.first!
    }
    
    // MARK: - Caching
    
    private func saveCachedMapping() {
        do {
            let data = try JSONEncoder().encode(canonicalMapping)
            try data.write(to: cacheFileURL)
            DebugLogger.playerIDMapping("💾 Cached canonical mapping (\(canonicalMapping.count) entries)")
        } catch {
            DebugLogger.error("Failed to cache canonical mapping: \(error)", category: .playerIDMapping)
        }
    }
    
    private func loadCachedMapping() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            DebugLogger.playerIDMapping("📭 No cached canonical mapping found, will build on first use")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            canonicalMapping = try JSONDecoder().decode([String: String].self, from: data)
            
            // Rebuild reverse mapping
            reverseMapping = Dictionary(uniqueKeysWithValues: canonicalMapping.map { ($1, $0) })
            
            DebugLogger.playerIDMapping("💾 Loaded cached canonical mapping (\(canonicalMapping.count) entries)")
        } catch {
            DebugLogger.error("Failed to load cached canonical mapping: \(error)", category: .playerIDMapping)
            canonicalMapping.removeAll()
            reverseMapping.removeAll()
        }
    }
}