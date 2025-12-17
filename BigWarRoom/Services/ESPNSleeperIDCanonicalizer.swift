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
    
    // 🔥 HYBRID PATTERN: Bridge for backward compatibility
    private static var _shared: ESPNSleeperIDCanonicalizer?
    
    static var shared: ESPNSleeperIDCanonicalizer {
        if let existing = _shared {
            return existing
        }
        fatalError("ESPNSleeperIDCanonicalizer.shared accessed before initialization. Call setSharedInstance() first.")
    }
    
    static func setSharedInstance(_ instance: ESPNSleeperIDCanonicalizer) {
        _shared = instance
    }
    
    // MARK: - State Management
    private enum MappingState {
        case notBuilt
        case building
        case built
    }
    
    private var mappingState: MappingState = .notBuilt
    
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
    
    // 🔥 PHASE 3 DI: Inject PlayerDirectoryStore dependency
    private let playerDirectory: PlayerDirectoryStore
    
    // MARK: - Initialization
    
    init(playerDirectory: PlayerDirectoryStore) {
        self.playerDirectory = playerDirectory
        loadCachedMapping()
        // If we loaded from cache successfully, mark as built
        if !canonicalMapping.isEmpty {
            mappingState = .built
            DebugPrint(mode: .playerIDMapping, "✅ Canonical mapping loaded from cache (\(canonicalMapping.count) entries)")
        }
    }
    
    // MARK: - Public Interface
    
    /// Get canonical Sleeper ID for ESPN ID - THE SINGLE SOURCE OF TRUTH
    /// - Parameter espnID: ESPN player ID
    /// - Returns: Canonical Sleeper ID, or the ESPN ID as fallback
    func getCanonicalSleeperID(forESPNID espnID: String) -> String {
        // Build mapping on first use if needed (lazy loading)
        buildCanonicalMappingIfNeeded()
        
        // Check canonical mapping first
        if let sleeperID = canonicalMapping[espnID] {
            return sleeperID
        }
        
        // Not in mapping - return ESPN ID as fallback
        return espnID
    }
    
    /// Build canonical mapping from PlayerDirectoryStore data - IDEMPOTENT
    /// Only builds if not already built or currently building
    func buildCanonicalMapping() {
        buildCanonicalMappingIfNeeded()
    }
    
    /// Internal idempotent mapping builder
    private func buildCanonicalMappingIfNeeded() {
        // Guard against multiple builds
        switch mappingState {
        case .built:
            // Already built, nothing to do
            return
        case .building:
            // Currently building, avoid recursion
            DebugPrint(mode: .playerIDMapping, "⚠️ Canonical mapping already building, skipping duplicate call")
            return
        case .notBuilt:
            // Need to build
            break
        }
        
        mappingState = .building
        DebugPrint(mode: .playerIDMapping, "🏗️ Building canonical ESPN→Sleeper ID mapping...")
        
        var newCanonicalMapping: [String: String] = [:]
        var newReverseMapping: [String: String] = [:]
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
                let canonicalPlayer = selectCanonicalPlayer(from: playersWithSameName)
                let canonicalESPNID = canonicalPlayer.espnID!
                
                // Map ALL ESPN IDs for this player to the canonical Sleeper ID
                for player in playersWithSameName {
                    if let espnID = player.espnID, !espnID.isEmpty {
                        newCanonicalMapping[espnID] = canonicalPlayer.playerID
                        
                        if espnID != canonicalESPNID {
                            duplicateESPNIDs[normalizedName, default: []].append(espnID)
                        }
                    }
                }
                
                // Store reverse mapping with canonical ESPN ID
                newReverseMapping[canonicalPlayer.playerID] = canonicalESPNID
            }
        }
        
        // Update mappings
        canonicalMapping = newCanonicalMapping
        reverseMapping = newReverseMapping
        mappingState = .built
        
        // Save to cache
        saveCachedMapping()
        
        // Log results ONCE
        DebugPrint(mode: .playerIDMapping, "🎯 Canonical mapping complete:")
        DebugPrint(mode: .playerIDMapping, "  📊 Total ESPN→Sleeper mappings: \(canonicalMapping.count)")
        DebugPrint(mode: .playerIDMapping, "  🔗 Players with duplicate ESPN IDs: \(duplicateESPNIDs.count)")
        
        // Show some duplicate examples (limit spam)
        let duplicateExamples = Array(duplicateESPNIDs.prefix(3))
        for (playerName, espnIDs) in duplicateExamples {
            DebugPrint(mode: .playerIDMapping, "  🔄 '\(playerName)' had ESPN IDs: \(espnIDs.joined(separator: ", "))")
        }
    }
    
    /// Force refresh canonical mapping (clears cache and rebuilds)
    func refreshCanonicalMapping() {
        DebugPrint(mode: .playerIDMapping, "♻️ Force refreshing canonical mapping...")
        canonicalMapping.removeAll()
        reverseMapping.removeAll()
        mappingState = .notBuilt
        buildCanonicalMappingIfNeeded()
    }
    
    /// Get debug statistics
    func getDebugStats() -> (totalMappings: Int, duplicatesResolved: Int) {
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
            DebugPrint(mode: .playerIDMapping, "💾 Cached canonical mapping (\(canonicalMapping.count) entries)")
        } catch {
            DebugPrint(mode: .playerIDMapping, "Failed to cache canonical mapping: \(error)")
        }
    }
    
    private func loadCachedMapping() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            DebugPrint(mode: .playerIDMapping, "📭 No cached canonical mapping found, will build on first use")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            canonicalMapping = try JSONDecoder().decode([String: String].self, from: data)
            
            // Rebuild reverse mapping - only keep first ESPN ID for each Sleeper ID
            // (Multiple ESPN IDs can map to same Sleeper ID, but reverse is one-to-one)
            var tempReverseMapping: [String: String] = [:]
            for (espnID, sleeperID) in canonicalMapping {
                // Only set if not already set (keeps first occurrence)
                if tempReverseMapping[sleeperID] == nil {
                    tempReverseMapping[sleeperID] = espnID
                }
            }
            reverseMapping = tempReverseMapping
            
            DebugPrint(mode: .playerIDMapping, "💾 Loaded cached canonical mapping (\(canonicalMapping.count) entries)")
        } catch {
            DebugPrint(mode: .playerIDMapping, "Failed to load cached canonical mapping: \(error)")
            canonicalMapping.removeAll()
            reverseMapping.removeAll()
        }
    }
}